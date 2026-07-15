# -*- coding: utf-8 -*-
"""회귀 방지 테스트 (stdlib unittest — 추가 설치 불필요, API 호출 없음).

Gemini 호출은 가짜 analyzer로 대체해 파이프라인의 '계산 로직'만 검증한다.
실행:  .venv311/Scripts/python -m unittest discover -s tests   (또는 pytest tests)
"""
import glob
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

import food_ai  # noqa: E402
import evaluate  # noqa: E402

# 키 없이도 파이프라인이 생성되도록 키 조회를 더미로 대체(구성 시 API 호출은 없음).
food_ai.gemini_keys = lambda *a, **k: ["test-dummy-key"]

_IMGS = glob.glob(os.path.join(os.path.dirname(food_ai.__file__), "test_images", "eval", "*.jpg"))
TEST_IMG = _IMGS[0] if _IMGS else None


class FakeAnalyzer:
    """gemini_analyzer 대역: analyze()가 미리 정한 음식 리스트를 반환(또는 예외)."""
    def __init__(self, foods=None, raise_exc=None, total=None):
        self._foods = foods if foods is not None else []
        self._raise = raise_exc
        self._total = total

    def analyze(self, pil):
        if self._raise is not None:
            raise self._raise
        return list(self._foods)

    def estimate_total_kcal(self, pil):
        return self._total


def food(name, grams=None, kcal=400, kper=200, carb=10, protein=5, fat=3,
         from_label=False):
    return {"food": name, "grams": grams, "amount_reason": "t",
            "kcal_estimate": kcal, "kcal_per_100g": kper,
            "carb_g": carb, "protein_g": protein, "fat_g": fat,
            "from_label": from_label, "box": None}


def run(foods, total=None, **pipe_kw):
    pipe = food_ai.FoodAIPipeline(**pipe_kw)
    pipe.gemini_analyzer = FakeAnalyzer(foods, total=total)
    return pipe.analyze_gemini(TEST_IMG)


@unittest.skipIf(TEST_IMG is None, "테스트 이미지 없음")
class TestQuantityAndCalorie(unittest.TestCase):
    def test_gram_calibration_single_food(self):
        """단품 OOD: 그램에 0.88 보정 적용 → kcal = grams*0.88 * kper/100."""
        r = run([food("존재안함zzz", grams=200, kper=250)], gram_calib=0.88)
        d = r["detections"][0]
        self.assertEqual(d["grams"], 176)                 # 200*0.88
        self.assertAlmostEqual(d["kcal"], 440.0, places=1)  # 176*250/100

    def test_calibration_not_applied_multifood(self):
        """다중음식: 보정 미적용(편향 방향이 반대라)."""
        r = run([food("존재안함A", grams=200, kper=250),
                 food("존재안함B", grams=300, kper=100)], gram_calib=0.88)
        self.assertEqual(r["detections"][0]["grams"], 200)  # 무보정
        self.assertEqual(r["detections"][1]["grams"], 300)

    def test_ood_gram_times_density(self):
        r = run([food("존재안함zzz", grams=100, kper=300)], gram_calib=1.0)
        self.assertAlmostEqual(r["detections"][0]["kcal"], 300.0, places=1)

    def test_missing_grams_falls_back_to_1serving(self):
        """DB 음식인데 그램 없음 → 1인분(ratio 1.0) 폴백."""
        db_name = food_ai.NutritionDB().match("비빔밥")
        self.assertIsNotNone(db_name)
        r = run([food(db_name, grams=None)])
        d = r["detections"][0]
        self.assertEqual(d["portion_pct"], 100.0)
        self.assertEqual(d["qty_source"], "gemini-1인분(그램추정없음)")


@unittest.skipIf(TEST_IMG is None, "테스트 이미지 없음")
class TestNutritionLabel(unittest.TestCase):
    def test_from_label_uses_label_value(self):
        """영양성분표 판독값이 DB/추정보다 우선."""
        r = run([food("단백질바", grams=120, kcal=250, from_label=True)])
        d = r["detections"][0]
        self.assertEqual(d["kcal"], 250)
        self.assertEqual(d["kcal_source"], "영양성분표(라벨)")
        self.assertTrue(d["from_label"])
        self.assertEqual(r["kcal_reliability"], "높음")  # 라벨은 신뢰 높음


@unittest.skipIf(TEST_IMG is None, "테스트 이미지 없음")
class TestHolistic(unittest.TestCase):
    def test_multifood_triggers_holistic(self):
        db1 = food_ai.NutritionDB().match("비빔밥")
        db2 = food_ai.NutritionDB().match("김치찌개")
        r = run([food(db1, grams=300), food(db2, grams=300)],
                total=900.0, holistic_multi=True)
        self.assertEqual(r["total_kcal_method"], "홀리스틱(접시전체 추정)")
        self.assertEqual(r["total_kcal"], 900.0)

    def test_single_food_no_holistic(self):
        db1 = food_ai.NutritionDB().match("비빔밥")
        r = run([food(db1, grams=300)], total=900.0, holistic_multi=True)
        self.assertEqual(r["total_kcal_method"], "합산")

    def test_disable_holistic(self):
        db1 = food_ai.NutritionDB().match("비빔밥")
        db2 = food_ai.NutritionDB().match("김치찌개")
        r = run([food(db1, grams=300), food(db2, grams=300)],
                total=900.0, holistic_multi=False)
        self.assertEqual(r["total_kcal_method"], "합산")


@unittest.skipIf(TEST_IMG is None, "테스트 이미지 없음")
class TestRobustness(unittest.TestCase):
    def test_api_failure_surfaces_error(self):
        """호출 전부 실패 → '음식 없음'이 아니라 error로 명시."""
        pipe = food_ai.FoodAIPipeline()
        pipe.gemini_analyzer = FakeAnalyzer(raise_exc=RuntimeError("429 quota"))
        r = pipe.analyze_gemini(TEST_IMG)
        self.assertTrue(r.get("error"))
        self.assertEqual(r["detections"], [])

    def test_genuine_no_food_is_empty_not_error(self):
        r = run([])          # 응답은 왔으나 음식 없음
        self.assertIsNone(r.get("error"))
        self.assertEqual(r["detections"], [])


class TestNutritionDB(unittest.TestCase):
    def setUp(self):
        self.nb = food_ai.NutritionDB()

    def test_alias_소불고기_to_불고기(self):
        """DB 정합성: 소불고기(0.87 오류)가 불고기(2.58)로 흡수."""
        k = self.nb.match("소불고기")
        self.assertEqual(k, "불고기")
        w = food_ai.num(self.nb.db[k]["중량"]); c = food_ai.num(self.nb.db[k]["칼로리"])
        self.assertGreater(c / w, 2.0)   # 밀도 2.58대(국물수준 0.87 아님)

    def test_added_foods_present(self):
        for name in ("불닭볶음면", "감자탕", "아사이볼", "엽떡"):
            self.assertIsNotNone(self.nb.match(name), f"{name} 매칭 실패")

    def test_calculate_ratio(self):
        db_name = self.nb.match("비빔밥")
        base = self.nb.calculate(db_name, ratio=1.0)
        half = self.nb.calculate(db_name, ratio=0.5)
        self.assertAlmostEqual(half["kcal"], base["kcal"] * 0.5, places=1)


class TestSynonymScoring(unittest.TestCase):
    def setUp(self):
        self.nb = food_ai.NutritionDB()

    def test_equivalents_scored_same(self):
        for a, b in [("나박김치", "동치미"), ("불고기", "소불고기"),
                     ("갈비", "소갈비구이"), ("설농탕", "곰탕")]:
            self.assertTrue(evaluate.same_food(b, a, self.nb), f"{a}~{b} 등가 실패")

    def test_real_error_not_equated(self):
        # 수정과 vs 오미자차: 칼로리 크게 달라 동의어 처리 금지(게이밍 방지)
        self.assertFalse(evaluate.same_food("오미자차", "수정과", self.nb))


if __name__ == "__main__":
    unittest.main(verbosity=2)
