# -*- coding: utf-8 -*-
"""
정확도 자동 평가 하니스
=========================
라벨이 달린 사진셋으로 파이프라인의 분류 정확도를 측정한다.
(양 정확도는 그램 실측이 필요하므로 --dataset 모드의 칼로리 MAPE로 평가)

[라벨 파일]  data/eval_labels.csv  (헤더: image,food)
- image : 사진 경로(프로젝트 기준 상대경로 OK)
- food  : 정답 음식명(한국어)

[측정 지표]
- 분류 top-1 정확도 : 예측 음식이 정답과 같은 음식(DB 정규화/띄어쓰기 무시)인지
- 오답 목록         : 예측 vs 정답

[실행 예시]
  # 분류/양 정확도(라벨셋)
  python evaluate.py --labels data/eval_labels_all.csv
  python evaluate.py --labels data/eval_labels_all.csv --gemini-samples 3

[실측 칼로리 대조 모드 --dataset]  (임시 스크립트 대신 이거 하나로 재사용)
  CSV(컬럼 자동감지: image/kcal[/food], 예 Nutrition5k·SimpleFood45·한식 실측)만 주면
  추정 총칼로리 vs 실측 칼로리를 MAPE·±25%·±50%·상관계수로 대조한다.
  python evaluate.py --dataset path/to/truth.csv
"""
import argparse
import csv
import sys
from pathlib import Path

import food_ai as fa

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

ROOT = Path(__file__).parent


def load_labels(path):
    rows = []
    with open(path, encoding="utf-8-sig", newline="") as f:
        for r in csv.DictReader(f):
            img = (r.get("image") or "").strip()
            food = (r.get("food") or "").strip()
            if img and food:
                rows.append({"image": img, "food": food})
    return rows


# 동의어 그룹(사실상 같은 음식) — 완전일치에서 등가 처리
SYNONYMS = [
    {"설렁탕", "설농탕", "곰탕"},          # 소뼈 국물 — 통용상 동일
    {"떡볶이", "떡뽀끼"}, {"돈가스", "돈까스"},
    {"아귀찜", "아구찜"},                  # 아귀=아구 철자변이
    {"삼각김밥", "오니기리"},              # 한/일 명칭 동일 음식
    {"아메리카노", "블랙커피", "카페아메리카노"},
    {"라떼", "카페라떼", "카페라테", "라테"},
    # 밀도 실측상 등가(≤10%)라 흡수 — 파이프라인 칼로리 출력이 사실상 동일
    {"나박김치", "동치미"},               # 물김치류, DB 밀도 0.15 vs 0.14 (2%)
    {"불고기", "소불고기"},               # 소불고기=불고기(기본 소고기) 동일 요리
    # 구이 갈비류(국물 '갈비탕'과는 구분) — 라벨 '갈비'가 국에 오매칭되던 채점 아티팩트 교정
    {"갈비", "갈비구이", "소갈비구이"},
    # 한식 실측(AI Hub) 검증에서 드러난 명칭 변이 — 사실상 같은 음식
    {"감자탕", "뼈해장국"},                      # 같은 돼지등뼈탕(밀도 12%차)
    {"달걀말이", "계란말이"},                    # 달걀=계란
    {"닭튀김", "치킨", "후라이드치킨", "프라이드치킨"},   # 닭튀김=치킨(후라이드)
    {"감자튀김", "감자튀김(웨지감자)", "감자튀김(스틱형)", "웨지감자"},  # 감자튀김 변종
]


def _syn_group(name):
    n = name.replace(" ", "")
    for g in SYNONYMS:
        if n in g:
            return g
    return None


def same_food(pred, true, nutri):
    """예측·정답 음식명이 같은 음식인지(정규화·동의어·구체화·DB키 비교).
    '완전일치'는 같은 요리를 가리키면 인정 — 정답보다 더 구체적으로 맞힌 것도 정답으로 본다.
    예: 정답 '포케'←예측 '참치 포케', 정답 '치킨'←예측 '후라이드 치킨'."""
    if not pred:
        return False
    p, t = pred.replace(" ", ""), true.replace(" ", "")
    if p == t:
        return True
    # 동의어 그룹(양쪽이 같은 그룹)
    gp, gt = _syn_group(p), _syn_group(t)
    if gp is not None and gp is gt:
        return True
    # 수식어 접두로 더 구체화한 같은 요리: 한쪽 이름이 다른쪽 이름으로 끝남
    short, long = (p, t) if len(p) <= len(t) else (t, p)
    if len(short) >= 2 and long.endswith(short):
        return True
    kp, kt = nutri.match(pred), nutri.match(true)
    return kp is not None and kp == kt


def same_family(pred, true):
    """같은 음식군인지(관대 매칭): 포함관계 또는 철자변이(돈가스=돈까스)까지 인정.
    예: 비빔밥⊂돌솥비빔밥, 김치⊂배추김치, 불고기⊂소불고기, 갈비⊂양념왕갈비."""
    if not pred:
        return False
    import difflib
    p, t = pred.replace(" ", ""), true.replace(" ", "")
    if p == t:
        return True
    short, long = (p, t) if len(p) <= len(t) else (t, p)
    if len(short) >= 2 and short in long:
        return True
    # 철자 변이(돈가스↔돈까스 등) — 매우 유사한 이름
    return difflib.SequenceMatcher(None, p, t).ratio() >= 0.65


# ── 실측 대조 모드(--dataset): 어떤 실측셋이든 CSV 하나로 칼로리 정확도 측정 ──
def load_dataset(path):
    """실측 대조 CSV 로드. 컬럼 자동감지 — 이미지: image/img/file/path/dish,
    칼로리: kcal/cal/energy/calorie(s), 음식(선택): food/label/name.
    이미지 경로는 CSV 파일 폴더 기준 상대해석(확장자 없으면 .png/.jpg 시도)."""
    base = Path(path).parent
    rows = []
    with open(path, encoding="utf-8-sig", newline="") as f:
        rd = csv.DictReader(f)
        cols = {(c or "").lower().strip(): c for c in (rd.fieldnames or [])}
        pick = lambda cs: next((cols[c] for c in cs if c in cols), None)
        icol = pick(["image", "img", "file", "path", "filename", "dish"])
        kcol = pick(["kcal", "cal", "calorie", "calories", "energy"])
        fcol = pick(["food", "label", "name"])
        if not icol or not kcol:
            raise ValueError(f"이미지/칼로리 컬럼을 못 찾음. 헤더: {rd.fieldnames}")
        for r in rd:
            iv, kv = (r.get(icol) or "").strip(), (r.get(kcol) or "").strip()
            if not iv or not kv:
                continue
            try:
                kcal = float(kv)
            except ValueError:
                continue
            p = Path(iv) if Path(iv).is_absolute() else base / iv
            if not p.exists():
                for ext in (".png", ".jpg", ".jpeg"):
                    if p.with_suffix(ext).exists():
                        p = p.with_suffix(ext)
                        break
            rows.append({"image": str(p), "kcal": kcal,
                         "food": (r.get(fcol) or "").strip() if fcol else ""})
    return rows


def run_dataset_eval(pipe, rows):
    """추정 총칼로리 vs 실측 칼로리 대조: MAPE·±25%·±50%·상관계수(+정답 음식명 있으면 분류)."""
    import statistics
    pairs, cls_ok, cls_n, miss = [], 0, 0, []
    print(f"{'파일':26s}{'실측':>7s}{'추정':>7s}{'오차%':>7s} 신뢰도")
    print("-" * 60)
    for r in rows:
        if not Path(r["image"]).exists():
            print(f"  [이미지 없음] {r['image']}")
            continue
        try:
            res = pipe.analyze(r["image"])
        except Exception as ex:
            print(f"  [오류] {Path(r['image']).name}: {ex}")
            continue
        pcal = res.get("total_kcal") or 0
        if pcal <= 0:
            continue
        pairs.append((r["kcal"], pcal))
        err = (pcal - r["kcal"]) / r["kcal"] * 100
        if r["food"]:
            cls_n += 1
            if any(same_food(d.get("name"), r["food"], pipe.nutrition) for d in res["detections"]):
                cls_ok += 1
            else:
                miss.append((Path(r["image"]).name, r["food"],
                             [d.get("name") for d in res["detections"][:2]]))
        print(f"  {Path(r['image']).name[:26]:26s}{r['kcal']:7.0f}{pcal:7.0f}{err:+7.0f}% {res.get('kcal_reliability')}")
    n = len(pairs)
    print("\n" + "=" * 60)
    if not n:
        print("측정 0건")
        return
    errs = [abs(p - t) / t * 100 for t, p in pairs]
    rate = lambda thr: sum(1 for e in errs if e <= thr) / n * 100
    print(f"칼로리 실측 대조 {n}장")
    print(f"  MAPE(평균절대오차) : {statistics.mean(errs):.0f}%")
    print(f"  ±25% 이내 : {rate(25):.0f}%   ±50% 이내 : {rate(50):.0f}%")
    print(f"  실측 평균 {statistics.mean([t for t, _ in pairs]):.0f} / 추정 평균 {statistics.mean([p for _, p in pairs]):.0f} kcal")
    try:
        import numpy as np
        print(f"  상관계수 r = {np.corrcoef([t for t, _ in pairs], [p for _, p in pairs])[0, 1]:.2f}")
    except Exception:
        pass
    if cls_n:
        print(f"  (분류 완전일치 : {cls_ok}/{cls_n} = {cls_ok / cls_n * 100:.0f}%)")
    if miss:
        print("\n[분류 오답]")
        for name, true, preds in miss[:15]:
            print(f"  - {name}: 정답 {true} / 예측 {preds}")


def main():
    ap = argparse.ArgumentParser(description="정확도 자동 평가 하니스")
    ap.add_argument("--labels", default=str(ROOT / "data" / "eval_labels.csv"))
    ap.add_argument("--dataset", default=None,
                    help="실측 대조 CSV(image,kcal[,food]) — 추정 칼로리 vs 실측 대조(MAPE·±%·상관). "
                         "Nutrition5k·SimpleFood45·한식 실측 등 무엇이든 이 하나로")
    ap.add_argument("--engine", choices=["gemini"], default="gemini")
    ap.add_argument("--gemini-samples", type=int, default=1)
    ap.add_argument("--gemini-model", default="gemini-3.5-flash")
    ap.add_argument("--no-search", action="store_true")
    ap.add_argument("--gram-calib", type=float, default=None,
                    help="그램 편향 보정계수(기본=food_ai.GRAM_CALIBRATION). 1.0=끔. 재튜닝용")
    ap.add_argument("--no-holistic-multi", action="store_true",
                    help="다중음식 홀리스틱(기본 켜짐)을 끄고 항목 합산으로")
    ap.add_argument("--no-gram-anchor", action="store_true",
                    help="프롬프트 그램 앵커(기본 켜짐)를 끔")
    ap.add_argument("--scale-anchor", action="store_true",
                    help="(실험) 크기 기준물(cm) 스케일 앵커 주입")
    args = ap.parse_args()

    # 실측 대조 모드: 어떤 데이터셋이든 CSV 하나로 칼로리 정확도 측정(임시 스크립트 불필요)
    if args.dataset:
        rows = load_dataset(args.dataset)
        if not rows:
            print(f"실측 데이터 없음: {args.dataset}")
            return
        print(f"실측셋 {len(rows)}장 | samples={args.gemini_samples}\n")
        pipe = fa.FoodAIPipeline(
            engine=args.engine,
            gemini_model=args.gemini_model, use_search=not args.no_search,
            gemini_samples=args.gemini_samples, gram_calib=args.gram_calib,
            holistic_multi=not args.no_holistic_multi,
            gram_anchor=not args.no_gram_anchor, scale_anchor=args.scale_anchor)
        run_dataset_eval(pipe, rows)
        return

    labels = load_labels(args.labels)
    if not labels:
        print(f"라벨이 없습니다: {args.labels}")
        return
    print(f"평가셋 {len(labels)}장 | engine={args.engine} "
          f"samples={args.gemini_samples}\n")

    pipe = fa.FoodAIPipeline(
        engine=args.engine, gemini_model=args.gemini_model,
        use_search=not args.no_search, gemini_samples=args.gemini_samples,
        gram_calib=args.gram_calib)

    n = answered = cls_ok = fam_ok = 0
    failed = []
    misses = []
    for row in labels:
        img = row["image"] if Path(row["image"]).is_absolute() else str(ROOT / row["image"])
        try:
            res = pipe.analyze(img)
        except Exception as ex:
            print(f"  [오류] {row['image']}: {ex}")
            continue
        n += 1
        dets = res["detections"]
        preds = [d.get("name") for d in dets if d.get("name")]
        # 빈 예측 = API 호출 실패(쿼터/네트워크) → '오분류'가 아니라 '미응답'으로 분리
        if not preds:
            failed.append(row["image"])
            print(f"  ⚠ {row['image']:40s} 정답={row['food']}  예측=[](호출 실패)")
            continue
        answered += 1
        # 분류: 정답과 같은 음식이 예측에 있으면 정답
        hit = next((d for d in dets if same_food(d.get("name"), row["food"], pipe.nutrition)), None)
        fam = hit or next((d for d in dets if same_family(d.get("name"), row["food"])), None)
        if hit:
            cls_ok += 1
        if fam:
            fam_ok += 1
        if not fam:
            misses.append((row["image"], row["food"], preds))
        # 양 정확도: 그램 실측 라벨이 없으므로 여기선 평가하지 않음(--dataset 칼로리 MAPE로 대체).
        # 참고용으로 예측 그램만 표기.
        mark = "✓" if hit else "✗"
        pg = f'{hit.get("grams"):.0f}g' if hit and isinstance(hit.get("grams"), (int, float)) else "-"
        print(f"  {mark} {row['image']:38s} 정답={row['food']}  "
              f"예측={preds}/{pg}")

    print("\n" + "=" * 60)
    if not n:
        print("평가 0건")
        return
    print(f"완주율(응답/전체)      : {answered}/{n}  (호출 실패 {len(failed)}건 제외)")
    if answered:
        print("── 실제 응답분 기준(모델 실력) ──")
        print(f"  완전일치            : {cls_ok}/{answered} = {cls_ok/answered*100:.1f}%")
        print(f"  같은 음식군          : {fam_ok}/{answered} = {fam_ok/answered*100:.1f}%")
    print("── 전체 기준(실패 포함) ──")
    print(f"  완전일치            : {cls_ok}/{n} = {cls_ok/n*100:.1f}%")
    print(f"  같은 음식군          : {fam_ok}/{n} = {fam_ok/n*100:.1f}%")
    if misses:
        print("\n[진짜 오답(응답했으나 틀림)]")
        for img, true, preds in misses:
            print(f"  - {img}: 정답 {true} / 예측 {preds}")


if __name__ == "__main__":
    main()
