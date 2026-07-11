# -*- coding: utf-8 -*-
"""
음식 분류 + 양(그램) 추정 + 칼로리 통합 파이프라인 (Gemini 전문가 엔진)
================================================================
사진 ─▶ ① 음식 분류 (Gemini Vision, 멀티음식/검색 그라운딩)
      └▶ ② 양 추정   (Gemini 그램 추정 / 접시기준 면적)
                          └▶ ③ 영양DB 조회 ─▶ 칼로리/탄단지 계산

[모델]
- ① 음식분류 : Gemini(gemini-3.5-flash). ※로컬 YOLOv3 분류기는 제거됨
- ② 양추정   : Gemini가 사진 속 '실제 무게(그램)'를 추정 → DB 밀도로 칼로리 환산.
               (실측 대조상 Q1~Q5 상대비율 방식보다 우수해 그램 단일화. ResNet 양추정기 제거됨)
- ③ 영양DB   : data/nutrition_db_merged.csv (없으면 nutrition_db.xlsx)

[실행]  (Gemini는 GEMINI_API_KEY 필요)
  python food_ai.py --image 사진.jpg                    # 기본(분류·양·칼로리 모두 Gemini)
  python food_ai.py --image 사진.jpg --plate-cm 24      # 접시 지름 주면 면적기반 양추정
  python food_ai.py --image 사진.jpg --json             # JSON 출력
"""
import os
import sys
import json
import argparse
import difflib
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).parent

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

# ---- 설정 -----------------------------------------------------------------
# (음식분류 YOLOv3·양추정 ResNet 모델은 제거됨 — 분류·양 모두 Gemini 엔진이 담당)
DB_PATH = ROOT / "data" / "nutrition_db.xlsx"
MERGED_DB = ROOT / "data" / "nutrition_db_merged.csv"

# Gemini 그램(양) 추정 편향 보정계수. 실측 대조(SimpleFood45·Nutrition5k, 3.5-flash)에서
# 정상분량이 일관되게 +12~16% 과다추정(추정/실측 중앙값 1.12) → 0.88을 곱해 보정.
# 검증셋 정상분량(≥30kcal, 16장) MAPE 18→14%, ±25% 75→88%. 여러 모델·데이터셋에서
# 편향 방향이 일치해 전역 적용. 한계: 서양·혼합접시 실측 기반이라 한식 실측 확보 시
# 재튜닝 권장. 1.0=보정 없음. --gram-calib 로 오버라이드 가능.
GRAM_CALIBRATION = 0.88


def num(v):
    try:
        return float(v)
    except (TypeError, ValueError):
        return 0.0


KEY_FILE = ROOT / ".gemini_key"  # 로컬 키 저장 파일(한 줄에 키 하나). git 커밋 금지.


def gemini_keys(primary=None):
    """Gemini API 키 목록(우선순위 순). 환경변수 우선, 없으면 로컬 파일에서 수집:
    환경변수 GEMINI_API_KEY, GEMINI_API_KEY2~4, 콤마구분 GEMINI_API_KEYS.
    파일 `.gemini_key`(프로젝트 루트, 한 줄에 키 하나)도 폴백으로 읽는다.
    앞 키가 쿼터 소진(429)되면 다음 키로 자동 전환된다."""
    cands = [primary] if primary else []
    for var in ("GEMINI_API_KEY", "GEMINI_API_KEY2", "GEMINI_API_KEY3", "GEMINI_API_KEY4"):
        cands.append(os.environ.get(var))
    multi = os.environ.get("GEMINI_API_KEYS")
    if multi:
        cands += multi.split(",")
    # 환경변수에 키가 하나도 없으면 로컬 파일에서 읽는다
    if not any((c or "").strip() for c in cands):
        try:
            if KEY_FILE.exists():
                cands += KEY_FILE.read_text(encoding="utf-8").splitlines()
        except Exception:
            pass
    out, seen = [], set()
    for k in cands:
        k = (k or "").strip()
        if k and k not in seen:
            seen.add(k)
            out.append(k)
    return out


def _is_quota_error(ex):
    """재시도/키전환 대상인 일시적 오류(쿼터 429 + 서버 과부하 503)."""
    s = str(ex).lower()
    return ("429" in s or "resource_exhausted" in s or "quota" in s
            or "503" in s or "unavailable" in s or "overload" in s)


class RateLimiter:
    """분당 요청수(RPM) 준수용 최소 간격 스로틀. acquire()가 필요한 만큼 대기시킨다."""

    def __init__(self, rpm):
        self.min_interval = 60.0 / rpm if rpm and rpm > 0 else 0.0
        self._last = 0.0

    def acquire(self):
        import time
        if self.min_interval <= 0:
            return
        now = time.monotonic()
        wait = self._last + self.min_interval - now
        if wait > 0:
            time.sleep(wait)
        self._last = time.monotonic()


class GeminiPool:
    """여러 API 키를 보유하고, RPM 스로틀 + 429 백오프 재시도 + 키 자동전환을 수행하는 풀.
    - RPM: 요청 간격을 띄워 분당 한도 초과(폭주) 방지 (env GEMINI_RPM, 기본 10)
    - 429: 짧은 백오프로 재시도(일시적 RPM 한도 해소용) 후, 안 되면 다음 키로 전환
    - RPD(일일 총량)는 스로틀로 못 늘림 → 다른 계정 키/유료 필요"""

    def __init__(self, keys, rpm=None, max_retries=None):
        if not keys:
            raise RuntimeError("GEMINI_API_KEY 환경변수가 없습니다. "
                               "(PowerShell: $env:GEMINI_API_KEY=\"키\")")
        from google import genai
        self.keys = keys
        self.clients = [genai.Client(api_key=k) for k in keys]
        self.idx = 0  # 현재 사용 중인 키 인덱스(작동하는 키에 고정)
        rpm = rpm if rpm is not None else int(os.environ.get("GEMINI_RPM", "10"))
        self.limiter = RateLimiter(rpm)
        self.max_retries = max_retries if max_retries is not None else int(os.environ.get("GEMINI_MAX_RETRIES", "2"))

    def generate(self, **kwargs):
        import time
        import random
        last = None
        for off in range(len(self.clients)):
            i = (self.idx + off) % len(self.clients)
            for attempt in range(self.max_retries + 1):
                self.limiter.acquire()  # RPM 준수(요청 간격 띄우기)
                try:
                    r = self.clients[i].models.generate_content(**kwargs)
                    if i != self.idx:
                        print(f"  ↪ Gemini 키 #{i + 1}로 전환(이전 키 한도)")
                    self.idx = i  # 작동하는 키로 고정
                    return r
                except Exception as ex:
                    if not _is_quota_error(ex):
                        raise
                    last = ex
                    if attempt < self.max_retries:  # 일시적 RPM 한도 → 백오프 후 재시도
                        wait = min(5 * (2 ** attempt) + random.uniform(0, 1), 30)
                        time.sleep(wait)
                    # 재시도 소진 → 다음 키로 전환
        raise last or RuntimeError("모든 Gemini 키 호출 실패")
        raise last or RuntimeError("모든 Gemini 키 호출 실패")


def imread_unicode(path):
    """한글 등 비ASCII 경로도 읽도록 cv2.imread 대체 (Windows 호환)."""
    import cv2
    data = np.fromfile(str(path), dtype=np.uint8)
    if data.size == 0:
        return None
    return cv2.imdecode(data, cv2.IMREAD_COLOR)


# ---- Gemini 음식 칼로리 분석 전문가 (멀티 음식 + 검색 그라운딩) -----------
class GeminiFoodAnalyzer:
    """음식 사진을 분석하는 '음식 칼로리 분석 전문가'.
    한 사진의 여러 음식을 각각 {food, grams, amount_reason, kcal_estimate} 로 반환한다.
    DB에 없는 음식은 Google 검색 그라운딩으로 1인분 기준 자료를 찾아 칼로리를 추정한다."""

    PROMPT = (
        "너는 음식 사진을 분석하는 \"음식 칼로리 분석 전문가\"야. "
        "사용자가 음식 사진을 주면 음식의 종류, 양, 대략적인 칼로리를 판단해.\n\n"
        "## 1. 음식 이름 (food)\n"
        "- 사진 속 음식이 무엇인지 한국어로 정확히 판단해.\n"
        "- **재료·조리법을 서술하지 말고, 한국에서 통용되는 '표준 음식명(요리 이름)'으로 답해라.** "
        "'구이·볶음·조림·찜·부침개'처럼 조리법을 단독으로 쓰지 말고 반드시 특정 요리명으로. "
        "예: '구운 돼지고기'/'돼지고기 구이'(X)→'삼겹살'(O), "
        "'야채 부침개'/'부침개'(X)→'파전'·'감자전' 등 재료로 특정한 이름(O), "
        "'생선 구이'(X)→'고등어구이'·'갈치구이'(O).\n"
        "- **가장 널리 쓰이는 '대표 명칭' 하나로 답해라. 불필요한 세부 변종을 붙이지 마라.** "
        "예: 꼬리곰탕(X)→곰탕(O), 소불고기(X)→불고기(O), 물냉면(X)→냉면(O), "
        "배추김치/포기김치(X)→김치(O), 연어덮밥(X)→회덮밥(O). "
        "단, 종류가 뚜렷한 요리는 종류까지(예: 찌개→김치찌개, 전→감자전).\n"
        "- **한 그릇에 재료가 조합된 '단일 요리'는 재료로 쪼개지 말고 그 요리 하나로 인식해라.** "
        "예: 밥+연어+아보카도+양파+날치알이 한 그릇이면 → '연어 포케볼' 하나. "
        "비빔밥·덮밥·김밥·볶음밥·샐러드·파스타 등도 마찬가지로 하나로.\n"
        "- **반대로, 칸이나 접시로 물리적으로 나뉘어 따로 담긴 음식들은 각각 따로 분석해라.** "
        "예: 급식판·한상차림처럼 밥·국·반찬이 칸마다 있으면 칸별로 각각.\n\n"
        "## 2. 양 (grams) — 사진에 실제로 담긴 '무게(그램)'\n"
        "- **표준 1인분을 가정하지 말고, 사진에 실제로 담긴 양의 무게(g)를 사실적으로 추정**해라. "
        "작으면 작게, 크면 크게.\n"
        "- **사진 속 크기를 아는 물체(수저·젓가락·접시 테두리·손)를 '자'로 삼아 실제 크기를 가늠**해라.\n"
        "- **국·탕·찌개는 그릇 깊이(국물이 찬 높이)까지 고려**해라(윗넓이만 보지 말 것).\n"
        "- 낱개 세기보다 전체 양으로 판단. 식당·가정의 흔한 정상 서빙 무게를 감안하되, "
        "실제로 수북하거나 적으면 그만큼 반영해라.\n\n"
        "## 3. 영양 추정 (칼로리 + 탄단지)\n"
        "- 사진에 보이는 양 기준의 대략적인 **총 칼로리(kcal)와 탄수화물(g)·단백질(g)·지방(g)**을 추정해.\n"
        "- **그리고 이 음식의 '100g당 칼로리(kcal_per_100g)'도 추정해라** — 음식 자체의 열량밀도"
        "(예: 삼겹살구이 약 330, 밥 약 150, 국물류 약 40).\n"
        "- 신뢰할 수 있는 자료를 근거로 추정하고, DB에 없는 음식이면 검색해서 표준 영양성분으로 계산해.\n"
        "- 숫자만(단위 제외), 대략치라도 반드시 채워라.\n\n"
        "## 4. 위치 (box)\n"
        "- 각 음식이 사진에서 차지하는 영역을 **0~1000 정규화 바운딩박스 [ymin,xmin,ymax,xmax]**로 표시해.\n\n"
        "## 출력 형식 — 반드시 아래 JSON 배열만, 다른 말은 절대 하지 마. "
        "음식이 하나여도 원소 1개짜리 배열로 출력해:\n"
        '[{"food":"<음식 이름>","grams":<실제 무게 숫자>,'
        '"amount_reason":"<무게를 그렇게 판단한 짧은 이유>",'
        '"kcal_estimate":<숫자>,"kcal_per_100g":<숫자>,'
        '"carb_g":<숫자>,"protein_g":<숫자>,"fat_g":<숫자>,'
        '"box":[<ymin>,<xmin>,<ymax>,<xmax>]}]'
    )

    def __init__(self, model="gemini-3.5-flash", api_key=None, use_search=True, n_samples=1):
        self.model = model
        self.use_search = use_search
        self.n_samples = max(1, n_samples)
        self.pool = GeminiPool(gemini_keys(api_key))

    def _config(self, with_search):
        from google.genai import types
        # 단일샷은 결정적(0.0)으로 실행마다 흔들리는 변동 제거.
        # 다수결(n_samples>1)일 때만 다양성 확보 위해 온도를 준다.
        temp = 0.0 if self.n_samples == 1 else 0.5
        kwargs = {"temperature": temp}
        if with_search:
            kwargs["tools"] = [types.Tool(google_search=types.GoogleSearch())]
        return types.GenerateContentConfig(**kwargs)

    @staticmethod
    def _extract_json_array(text):
        """검색 그라운딩 인용([1][2])·코드펜스가 섞여도 JSON 배열을 안전 추출."""
        import re
        text = re.sub(r"```(?:json)?", "", text)
        m = re.search(r"\[\s*\{", text)  # 객체 배열의 시작 '[{'
        if m:
            depth, start = 0, m.start()
            for i in range(start, len(text)):
                if text[i] == "[":
                    depth += 1
                elif text[i] == "]":
                    depth -= 1
                    if depth == 0:
                        return text[start:i + 1]
        m2 = re.search(r"\{", text)  # 단일 객체 폴백
        if m2:
            depth, start = 0, m2.start()
            for i in range(start, len(text)):
                if text[i] == "{":
                    depth += 1
                elif text[i] == "}":
                    depth -= 1
                    if depth == 0:
                        return "[" + text[start:i + 1] + "]"
        return None

    def _analyze_once(self, img):
        err, got_response, items = None, False, None
        for with_search in ([True, False] if self.use_search else [False]):
            try:
                resp = self.pool.generate(
                    model=self.model, contents=[img, self.PROMPT],
                    config=self._config(with_search))
                got_response = True
                payload = self._extract_json_array((resp.text or "").strip())
                if payload:
                    try:
                        items = json.loads(payload)
                        if items:
                            break
                    except json.JSONDecodeError:
                        pass
                items = None
            except Exception as ex:  # 호출 자체 실패(쿼터/네트워크/503 등)
                err = ex
        if not items:
            # 한 번도 응답을 못 받았고 예외만 있었다면 '음식 없음'이 아니라 호출 실패 →
            # 상위에서 사용자에게 실패를 알릴 수 있게 전파(빈 결과로 삼키지 않음).
            if not got_response and err is not None:
                raise err
            return []
        out = []
        for it in items:
            box = it.get("box")
            if not (isinstance(box, (list, tuple)) and len(box) == 4):
                box = None
            try:
                grams = float(it.get("grams")) if it.get("grams") is not None else None
            except (TypeError, ValueError):
                grams = None
            out.append({"food": str(it.get("food", "")).strip(), "grams": grams,
                        "amount_reason": it.get("amount_reason") or it.get("q_reason"),
                        "kcal_estimate": it.get("kcal_estimate"),
                        "kcal_per_100g": it.get("kcal_per_100g"),
                        "carb_g": it.get("carb_g"), "protein_g": it.get("protein_g"),
                        "fat_g": it.get("fat_g"), "box": box})
        return out

    def analyze(self, pil_img):
        """N회 분석 후 음식별로 비율·칼로리 중앙값으로 안정화(self-consistency)."""
        import statistics
        img = pil_img.convert("RGB")
        runs, err = [], None
        for _ in range(self.n_samples):
            try:
                runs.append(self._analyze_once(img))
            except Exception as ex:  # 이 샘플은 호출 자체가 실패
                err = ex
        good = [r for r in runs if r]
        if not good:
            # 응답을 한 번도 못 받고 전부 예외였다면 호출 실패를 상위에 전파,
            # 응답은 왔으나 비었으면(runs에 [] 존재) 진짜 '음식 없음'.
            if not runs and err is not None:
                raise err
            return []
        runs = good
        if len(runs) == 1:
            return runs[0]
        # 음식명(공백제거) 기준으로 여러 실행 결과를 묶어 중앙값 집계
        groups = {}
        for run in runs:
            for f in run:
                key = f["food"].replace(" ", "")
                if not key:
                    continue
                groups.setdefault(key, []).append(f)
        need = max(1, len(runs) // 2)  # 과반 실행에서 등장한 음식만 채택
        out = []
        for key, items in groups.items():
            if len(items) < need:
                continue

            def med(field):
                vals = [float(i[field]) for i in items if isinstance(i.get(field), (int, float))]
                return round(statistics.median(vals), 1) if vals else None
            # 대표 항목: 그램 중앙값에 가장 가까운 실행(그램 없으면 첫 실행)
            gvals = [i for i in items if isinstance(i.get("grams"), (int, float))]
            if gvals:
                mg = statistics.median([i["grams"] for i in gvals])
                rep = min(gvals, key=lambda i: abs(i["grams"] - mg))
            else:
                rep = items[0]
            out.append({
                "food": rep["food"], "grams": med("grams"), "amount_reason": rep.get("amount_reason"),
                "kcal_estimate": med("kcal_estimate"), "kcal_per_100g": med("kcal_per_100g"),
                "carb_g": med("carb_g"), "protein_g": med("protein_g"), "fat_g": med("fat_g"),
                "box": rep.get("box"), "samples": len(items),
            })
        return out or runs[0]

    _HOLISTIC_PROMPT = (
        "이 사진은 한 접시(또는 그릇)에 담긴 음식 전체다. "
        "개별 음식으로 쪼개서 각각 1인분으로 합산하지 말고, "
        "접시에 실제로 담긴 '전체 양'을 보고 이 한 접시의 총 칼로리(kcal)를 하나의 숫자로 추정해라. "
        "작은 맛보기·샘플러 접시면 그만큼 적게, 푸짐하면 많게 — 실제 담긴 양 기준의 현실적 총 칼로리만. "
        'JSON만 출력: {"total_kcal": <숫자>}'
    )

    def estimate_total_kcal(self, pil_img):
        """접시 전체를 통으로 본 홀리스틱 총 칼로리(kcal). 혼합/OOD 접시의 과대합산 보정용.
        실측(Nutrition5k)상 항목합산 대비 오차 절반(MAPE 249%→126%, 상관 0.18→0.59)."""
        import statistics
        import re as _re
        img = pil_img.convert("RGB")
        ests = []
        for _ in range(self.n_samples):
            try:
                resp = self.pool.generate(
                    model=self.model, contents=[img, self._HOLISTIC_PROMPT],
                    config=self._config(False))
                m = _re.search(r'total_kcal"?\s*:\s*([0-9]+(?:\.[0-9]+)?)', resp.text or "")
                if m:
                    ests.append(float(m.group(1)))
            except Exception:
                pass
        return round(statistics.median(ests), 1) if ests else None


# Gemini의 대체 표현(공백제거) → DB 표준 음식명. DB에 없는 이름을 표준명으로 정규화해
# OOD(미매칭)·근사명칭 혼동을 줄인다. ※이미 DB에 있는 이름은 match에서 먼저 잡히므로 무영향.
_FOOD_ALIASES = {
    "오니기리": "삼각김밥",
    "블랙커피": "아메리카노", "아메리카노커피": "아메리카노",
    "라테": "카페라떼", "카페라테": "카페라떼",
    "떡뽀끼": "떡볶이", "떡뽀키": "떡볶이",
    "프라이드치킨": "후라이드치킨", "후라이드": "후라이드치킨",
}


# ---- ③ 영양DB -------------------------------------------------------------
class NutritionDB:
    def __init__(self, db_path=DB_PATH, merged_path=MERGED_DB):
        import csv
        import openpyxl

        self.db = {}
        if Path(merged_path).exists():
            # 병합 DB(기존 400 + 공공데이터 CSV 2종) 우선 로드
            with open(merged_path, encoding="utf-8-sig", newline="") as f:
                for row in csv.DictReader(f):
                    name = (row.get("name") or "").strip()
                    if not name or name in self.db:
                        continue
                    self.db[name] = {
                        "중량": row.get("중량"), "칼로리": row.get("칼로리"),
                        "탄수화물": row.get("탄수화물"), "당류": row.get("당류"),
                        "지방": row.get("지방"), "단백질": row.get("단백질"),
                        "나트륨": row.get("나트륨"), "source": row.get("source"),
                        "basis": row.get("basis") or "1인분",
                    }
        else:
            wb = openpyxl.load_workbook(db_path, read_only=True, data_only=True)
            ws = wb.active
            for r in ws.iter_rows(min_row=2, values_only=True):
                if not r or r[0] is None:
                    continue
                self.db[str(r[0]).strip()] = {
                    "중량": r[1], "칼로리": r[2], "탄수화물": r[3],
                    "당류": r[4], "지방": r[5], "단백질": r[6], "나트륨": r[9],
                    "source": "base", "basis": "1인분",
                }
        # 정규화 인덱스: dish(=base/전북, 1인분 기준)을 먼저, all(전국통합 포함)을 나중에
        # → 일상 음식은 1인분 기준 항목으로, 가공식품(100g)은 최후순위로만 매칭
        self._norm_dish, self._norm_all = {}, {}
        for k, info in self.db.items():
            nk = k.replace(" ", "")
            self._norm_all.setdefault(nk, k)
            if info.get("source") in ("base", "전북"):
                self._norm_dish.setdefault(nk, k)

    def _fuzzy_in(self, nm, norm):
        # 부분 포함은 길이 차이가 크지 않을 때만 허용(짧은 공통 음절 오매칭 방지)
        for k0, k in norm.items():
            if (nm in k0 or k0 in nm) and min(len(nm), len(k0)) / max(len(nm), len(k0)) >= 0.6:
                return k
        # 유사도 매칭은 높은 컷오프(0.8)로 — 음식종류 글자만 다른 오매칭 방지(계란김밥↛계란덮밥)
        cand = difflib.get_close_matches(nm, list(norm.keys()), n=1, cutoff=0.8)
        return norm[cand[0]] if cand else None

    def match(self, name):
        """음식명 → DB 키. 띄어쓰기만 다른 '정확 매칭'을 (dish→전체) 항상 먼저 시도하고,
        그래도 없을 때만 부분포함/유사도 매칭으로 넘어간다.
        → '김치 찌개'가 형제메뉴(참치김치찌개)로 새지 않고 정확히 '김치찌개'로 매칭됨.
        전혀 다른 음식은 매칭 안 함(마라탕 ↛ 고구마맛탕)."""
        if not name:
            return None
        if name in self.db:
            return name
        nm = name.replace(" ", "")
        nm = _FOOD_ALIASES.get(nm, nm)  # 동의어 → DB 표준명 정규화(오니기리→삼각김밥 등)
        # 1) 정확(띄어쓰기만 다른) 매칭 — dish(1인분) 먼저, 없으면 전체
        exact = self._norm_dish.get(nm) or self._norm_all.get(nm)
        if exact:
            return exact
        # 2) 부분포함/유사도 매칭 — dish 먼저, 없으면 전체
        return self._fuzzy_in(nm, self._norm_dish) or self._fuzzy_in(nm, self._norm_all)

    def calculate(self, name, ratio=1.0):
        """1인분 대비 ratio(연속 배수)로 영양을 계산. ratio 미지정 시 1.0(1인분)."""
        key = self.match(name)
        if key is None:
            return None
        info = self.db[key]
        if ratio is None:
            ratio = 1.0
        bw, bk = num(info["중량"]), num(info["칼로리"])
        return {
            "matched": key, "ratio": round(ratio, 3),
            "grams": round(bw * ratio, 1), "kcal": round(bk * ratio, 1),
            "base_w": round(bw, 1), "base_kcal": round(bk, 1),
            "carb": round(num(info["탄수화물"]) * ratio, 1),
            "protein": round(num(info["단백질"]) * ratio, 1),
            "fat": round(num(info["지방"]) * ratio, 1),
            "sodium": round(num(info["나트륨"]) * ratio, 1),
            "source": info.get("source"), "basis": info.get("basis", "1인분"),
        }


def _kcal_reliability(results, has_reference=False):
    """총칼로리 신뢰도 판정. 실측(Nutrition5k) 검증상 '여러 음식·DB미매칭'일수록
    각 항목을 1인분으로 잡아 합산해 과대추정 위험이 커짐 → 정직하게 표시한다.
    반환: (신뢰도 '높음/중간/낮음', 설명) — 판정 불가면 (None, None)."""
    named = [r for r in results if r.get("name")]
    n = len(named)
    if n == 0:
        return None, None
    ood = sum(1 for r in named if not r.get("in_db"))
    if has_reference:  # 접시기준(면적)으로 실제 양을 잰 경우
        return "높음", "접시기준(면적) 반영"
    if n >= 4 or (n >= 2 and ood >= 2 and ood >= n - ood):
        return "낮음", "여러 음식·DB미매칭 다수 → 총칼로리 과대가능(대략치)"
    if ood > 0:
        return "중간", "일부 DB미매칭(Gemini 추정 포함)"
    return "높음", "전부 DB 매칭(정확)"


# ---- 통합 파이프라인 -------------------------------------------------------
class FoodAIPipeline:
    def __init__(self, engine="gemini",
                 gemini_model="gemini-3.5-flash", use_search=True,
                 gemini_samples=1, plate_cm=None, gram_calib=None):
        self.engine = engine
        self.plate_cm = plate_cm
        # 그램 편향 보정계수(None이면 전역 기본 GRAM_CALIBRATION). 실측/재튜닝·해제용.
        self.gram_calib = GRAM_CALIBRATION if gram_calib is None else gram_calib
        self.gemini_analyzer = None
        self.nutrition = NutritionDB()

        # Gemini 전문가 엔진이 유일 지원 모드(분류·양·칼로리 모두 Gemini).
        # 로컬 YOLO 분류기·ResNet 양추정기는 제거됨.
        if engine != "gemini":
            raise RuntimeError(
                "로컬 모델은 제거되었습니다. '--engine gemini'를 사용하세요 "
                "(분류·양·칼로리 모두 Gemini).")
        self.gemini_analyzer = GeminiFoodAnalyzer(
            model=gemini_model, use_search=use_search, n_samples=gemini_samples)

    def analyze(self, image_path):
        return self.analyze_gemini(image_path)

    def analyze_gemini(self, image_path):
        """순수 Gemini 전문가 엔진: 한 사진의 여러 음식을 분석.
        DB에 있으면 DB 칼로리(정확)를, 없으면 Gemini의 검색기반 추정 칼로리를 사용."""
        bgr = imread_unicode(image_path)
        if bgr is None:
            raise FileNotFoundError(f"이미지를 열 수 없습니다: {image_path}")
        pil_full = Image.fromarray(bgr[:, :, ::-1])
        try:
            foods = self.gemini_analyzer.analyze(pil_full)
        except Exception as ex:
            # Gemini 호출이 전부 실패(쿼터 초과·네트워크·서버 과부하 등). '음식 없음'과
            # 구분해 error로 명시 → 사용자가 재시도할지 알 수 있게 한다.
            return {"image": str(image_path), "detections": [], "total_kcal": 0,
                    "kcal_reliability": None, "kcal_note": None, "total_kcal_method": "합산",
                    "error": f"AI 분석 호출 실패(쿼터 초과·네트워크·서버 과부하 등): {ex}"}

        results = []
        for f in foods:
            name = f["food"]
            matched = self.nutrition.match(name)
            grams = f.get("grams")
            # 편향 보정: Gemini는 양을 체계적으로 +12~16% 과다추정 → 보정계수를 곱해
            # DB경로(ratio=grams/중량)·OOD경로(grams×밀도)·표시 그램에 일관 반영.
            if isinstance(grams, (int, float)) and grams > 0 and self.gram_calib != 1.0:
                grams = grams * self.gram_calib
            has_grams = isinstance(grams, (int, float)) and grams > 0
            # 양 = Gemini의 '실제 무게(그램)' 추정. DB 1인분 중량으로 나눠 연속 비율(ratio) 산출.
            # 칼로리 = DB칼로리 × (그램/1인분중량) = 그램 × DB밀도. 그램이 없으면 1인분 가정.
            ratio, qty_source = 1.0, "gemini-grams"
            if not has_grams:
                qty_source = "gemini-1인분(그램추정없음)"
            elif matched:
                base_w = num(self.nutrition.db[matched]["중량"])
                if base_w > 0:
                    ratio = grams / base_w
            if matched:
                nut = self.nutrition.calculate(name, ratio=ratio)
                kcal, kcal_src = nut["kcal"], "DB"
            else:
                # DB 미수록 → Gemini 추정값. 그램·밀도(100g당kcal) 있으면 그램×밀도로 칼로리
                # (Gemini 총kcal 직접값보다 안정적 — 실측상 그램방식이 우수).
                kper = f.get("kcal_per_100g")
                if has_grams and isinstance(kper, (int, float)) and kper > 0:
                    kcal = round(grams * kper / 100.0, 1)
                    kcal_src = "Gemini(그램×밀도)"
                else:
                    kcal = f.get("kcal_estimate")
                    kcal_src = "Gemini(검색추정)"
                nut = None
                if any(f.get(k) is not None for k in ("carb_g", "protein_g", "fat_g")):
                    nut = {
                        "matched": name, "kcal": kcal, "base_kcal": kcal,
                        "grams": None, "base_w": None, "basis": "1인분",
                        "carb": f.get("carb_g"), "protein": f.get("protein_g"),
                        "fat": f.get("fat_g"), "sodium": None, "source": "Gemini추정",
                    }
            results.append({
                "code": None, "name": name, "english": None,
                "conf": None, "clf_src": "gemini-expert", "in_db": matched is not None,
                "grams": round(grams, 0) if has_grams else None,
                # portion_pct: 1인분 대비 %(DB매칭일 때만 의미 — 1인분 기준이 존재). OOD는 None.
                "portion_pct": round(ratio * 100, 1) if matched else None,
                "qty_source": qty_source, "amount_reason": f.get("amount_reason"),
                "kcal": kcal, "kcal_source": kcal_src,
                "nutrition": nut, "box": f.get("box"), "fallback": False,
            })
        # 접시 기준 양추정: 접시 지름으로 실제 면적→양을 재계산(단일=접시전체, 멀티=음식별 박스)
        named = [r for r in results if r.get("name")]
        if self.plate_cm and named:
            H, W = bgr.shape[:2]
            for r in named:
                region = None
                if len(named) > 1 and r.get("box"):  # 멀티음식: 정규화(0~1000) 박스 → 픽셀
                    ymin, xmin, ymax, xmax = r["box"]
                    region = (xmin / 1000 * W, ymin / 1000 * H, xmax / 1000 * W, ymax / 1000 * H)
                elif len(named) > 1:
                    continue  # 멀티인데 박스 없으면 접시전체 적용은 부정확 → 건너뜀
                self._plate_ref_override(image_path, r, region=region)

        total = sum(r["kcal"] for r in results if isinstance(r.get("kcal"), (int, float)))
        rel, note = _kcal_reliability(results, has_reference=bool(self.plate_cm))
        # 혼합/OOD 접시(신뢰도 낮음)는 항목별 1인분 합산이 과대추정 →
        # 접시 전체를 통으로 본 홀리스틱 총 칼로리로 보정(실측상 오차 절반).
        # 각 항목 칼로리·탄단지도 비율만큼 축소해 합계와 맞춘다.
        total_method = "합산"
        if rel == "낮음" and not self.plate_cm:
            h = self.gemini_analyzer.estimate_total_kcal(pil_full)
            if h is not None and total > 0:
                h = min(h, 2500.0)  # 상식 상한(폭주 방지)
                factor = h / total
                for r in results:
                    if isinstance(r.get("kcal"), (int, float)):
                        r["kcal"] = round(r["kcal"] * factor, 1)
                    nut = r.get("nutrition")
                    if nut:
                        for kk in ("kcal", "carb", "protein", "fat"):
                            if isinstance(nut.get(kk), (int, float)):
                                nut[kk] = round(nut[kk] * factor, 1)
                total = h
                total_method = "홀리스틱(접시전체 추정)"
                note = (note or "") + " · 총합=접시전체 추정으로 보정(합산 과대 방지)"
        return {"image": str(image_path), "detections": results, "total_kcal": round(total, 1),
                "kcal_reliability": rel, "kcal_note": note, "total_kcal_method": total_method,
                "error": None}

    def _plate_ref_override(self, image_path, r, region=None):
        """접시 기준(면적) 양추정으로 비율·칼로리를 덮어쓴다. region=박스면 그 영역만."""
        try:
            import portion_ref
            ref = portion_ref.estimate_portion(image_path, self.plate_cm, r["name"],
                                               self.nutrition, region=region)
        except Exception:
            return
        if not ref or ref.get("ratio") is None:
            return
        ratio = ref["ratio"]
        r["portion_pct"] = round(ratio * 100, 1)
        r["qty_source"] = f"접시기준({self.plate_cm}cm)"
        r["amount_reason"] = (f'음식 면적 {ref["food_area_cm2"]}cm²(접시 채움 {ref["coverage_%"]}%) '
                              f'→ 1인분의 약 {int(ratio * 100)}%')
        if self.nutrition.match(r["name"]):
            nut = self.nutrition.calculate(r["name"], ratio=ratio)
            r["nutrition"] = nut
            r["kcal"] = nut["kcal"]
            r["kcal_source"] = "DB(접시기준 양)"


def print_result(res):
    print(f'\n📷 이미지: {res["image"]}')
    dets = res["detections"]
    if res.get("error"):
        print(f'  ⚠ {res["error"]}')
        print("  → 음식이 없는 게 아니라 분석 호출이 실패했습니다. 잠시 후 다시 시도해 주세요.")
        return
    if not dets:
        print("  음식을 찾지 못했습니다.")
        return
    for i, d in enumerate(dets, 1):
        name = d["name"] or f'(코드 {d["code"]}, 매핑없음)'
        eng = f' ({d["english"]})' if d.get("english") else ""
        tag = " [폴백:전체분류]" if d.get("fallback") else ""
        src = d.get("clf_src", "yolo")
        if src == "gemini-expert":
            hdr = "[Gemini 전문가 분석]"
        else:
            vote_txt = f', 투표 {d["votes"]}' if d.get("votes") else ""
            hdr = f'[분류:{src}, 신뢰도 {d["conf"]}{vote_txt}]'
        print(f'\n[{i}] 🍽 음식 : {name}{eng}   {hdr}{tag}')
        if d.get("low_conf") and d.get("alternatives"):
            alts = ", ".join(f'{a["name"]}({a["conf"]})' for a in d["alternatives"])
            print(f'       🤔 확신 낮음 — 다른 후보: {alts}')
        if not d.get("in_db", True):
            if d.get("kcal") is not None:
                print("       ⓘ 영양DB 미수록 → 칼로리는 Gemini 검색 기반 추정값")
            else:
                print("       ⓘ 영양DB 미수록 음식 → 분류·양은 Gemini 추정, 칼로리는 계산 불가")
        # 양: Gemini 그램 추정을 우선 표시. DB매칭이면 1인분 대비 %도 함께.
        gram_txt = f'약 {d["grams"]:.0f}g' if isinstance(d.get("grams"), (int, float)) else "그램추정 없음"
        pct = d.get("portion_pct")
        pct_txt = f' (1인분의 ~{pct:.0f}%)' if isinstance(pct, (int, float)) else ""
        qsrc = d.get("qty_source", "")
        print(f'    ⚖ 양: {gram_txt}{pct_txt}  [{qsrc}]')
        if d.get("amount_reason"):
            print(f'       └ 근거: {d["amount_reason"]}')
        n = d["nutrition"]
        if n:
            src_tag = f' [{d["kcal_source"]}]' if d.get("kcal_source") else ""
            if n.get("basis") == "100g":
                base_txt = f'100g당 {n["base_kcal"]} kcal · 전국통합DB'
            elif n.get("base_w"):
                base_txt = f'기준 {n["base_kcal"]} kcal/{n["base_w"]}g'
            else:  # 중량 미상(전북 등)
                base_txt = f'기준 1인분 {n["base_kcal"]} kcal'
            grams_txt = f'{n["grams"]} g, ' if n.get("base_w") else ""
            print(f'    🔥 칼로리: {n["kcal"]} kcal{src_tag}   ({grams_txt}{base_txt})')
            macros = []
            for lab, key, unit in [("탄수", "carb", "g"), ("단백", "protein", "g"),
                                   ("지방", "fat", "g"), ("나트륨", "sodium", "mg")]:
                if n.get(key) is not None:
                    macros.append(f'{lab} {n[key]}{unit}')
            if macros:
                print("       " + " · ".join(macros))
        elif d.get("kcal") is not None:
            print(f'    🔥 칼로리: 약 {d["kcal"]} kcal   [{d.get("kcal_source", "추정")}]')
        elif d.get("in_db", True):
            # DB에 있어야 하는데 매칭 실패한 경우만 경고(개방분류 OOD는 위 ⓘ로 안내됨)
            print("    (영양DB 매칭 실패 — 음식명 확인 필요)")
    if res.get("total_kcal") is not None and len(dets) > 1:
        mtag = "" if res.get("total_kcal_method", "합산") == "합산" else " [접시전체 추정]"
        print(f'\n  Σ 합계: 약 {res["total_kcal"]} kcal  ({len(dets)}개 음식){mtag}')
    rel = res.get("kcal_reliability")
    if rel:
        icon = {"높음": "🟢", "중간": "🟡", "낮음": "🔴"}.get(rel, "")
        print(f'  {icon} 칼로리 신뢰도: {rel} — {res.get("kcal_note", "")}')


def main():
    ap = argparse.ArgumentParser(description="음식 분류(Gemini) + 양 추정 + 칼로리 통합 파이프라인")
    ap.add_argument("--image", help="분석할 음식 사진 경로")
    ap.add_argument("--engine", choices=["gemini"], default="gemini",
                    help="gemini(Gemini 전문가 분석: 멀티음식+양(그램)+칼로리+검색). 로컬 모델은 제거됨")
    ap.add_argument("--no-search", action="store_true", help="gemini 엔진에서 Google 검색 그라운딩 끄기")
    ap.add_argument("--gemini-samples", type=int, default=1,
                    help="Gemini self-consistency 샘플 수(중앙값/다수결). 기본 1"
                         "(3.5-flash는 단발도 안정적: 실측검증상 분류 -1.4pp·칼로리 동급, 비용 1/3·속도 3배). "
                         "안정성 더 원하면 3")
    ap.add_argument("--plate-cm", type=float, default=None,
                    help="접시/그릇 지름(cm). 주면 면적 기반(접시기준)으로 양을 더 정확히 추정")
    ap.add_argument("--vessel", default=None,
                    help="지름 대신 그릇 종류(밥공기/국그릇/접시/큰접시 등)로 접시기준 양추정")
    ap.add_argument("--gemini-model", default="gemini-3.5-flash", help="Gemini 모델명")
    ap.add_argument("--gram-calib", type=float, default=None,
                    help=f"그램 편향 보정계수(기본 {GRAM_CALIBRATION}). 1.0=보정끔. 실측 재튜닝용")
    ap.add_argument("--json", action="store_true", help="JSON으로 출력")
    args = ap.parse_args()

    if not args.image:
        ap.error("--image 가 필요합니다")

    plate_cm = args.plate_cm
    if plate_cm is None and args.vessel:
        import portion_ref
        plate_cm = portion_ref.vessel_cm(args.vessel)
        if plate_cm is None:
            ap.error(f"알 수 없는 그릇 종류: {args.vessel} (예: {'/'.join(portion_ref.VESSEL_CM)})")
    try:
        pipe = FoodAIPipeline(engine=args.engine, gemini_model=args.gemini_model,
                              use_search=not args.no_search,
                              gemini_samples=args.gemini_samples,
                              plate_cm=plate_cm, gram_calib=args.gram_calib)
    except RuntimeError as ex:
        print(f"⚠ {ex}")
        print("  → Gemini 기능은 GEMINI_API_KEY 가 필요합니다 (환경변수 설정).")
        sys.exit(1)
    res = pipe.analyze(args.image)

    if args.json:
        print(json.dumps(res, ensure_ascii=False, indent=2))
    else:
        print_result(res)


if __name__ == "__main__":
    main()
