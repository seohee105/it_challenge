# -*- coding: utf-8 -*-
"""
정확도 자동 평가 하니스
=========================
라벨이 달린 사진셋으로 파이프라인의 분류/양 정확도를 측정한다.

[라벨 파일]  data/eval_labels.csv  (헤더: image,food,q)
- image : 사진 경로(프로젝트 기준 상대경로 OK)
- food  : 정답 음식명(한국어)
- q     : 정답 양 단계 Q1~Q5 (선택; 비우면 양 평가 제외)

[측정 지표]
- 분류 top-1 정확도 : 예측 음식이 정답과 같은 음식(DB 정규화/띄어쓰기 무시)인지
- 양 정확도         : 정확히 같은 Q단계 / ±1단계 이내
- 오답 목록         : 예측 vs 정답

[실행 예시]
  # 기본(Gemini 전문가 엔진)
  python evaluate.py --labels data/eval_labels_all.csv
  # 다수결 3샘플로 변동 안정화
  python evaluate.py --labels data/eval_labels_all.csv --gemini-samples 3
  # 양추정을 로컬 ResNet으로
  python evaluate.py --labels data/eval_labels_all.csv --quantity resnet
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
Q_ORDER = {"Q1": 0, "Q2": 1, "Q3": 2, "Q4": 3, "Q5": 4}


def load_labels(path):
    rows = []
    with open(path, encoding="utf-8-sig", newline="") as f:
        for r in csv.DictReader(f):
            img = (r.get("image") or "").strip()
            food = (r.get("food") or "").strip()
            if img and food:
                rows.append({"image": img, "food": food, "q": (r.get("q") or "").strip().upper()})
    return rows


# 동의어 그룹(사실상 같은 음식) — 완전일치에서 등가 처리
SYNONYMS = [
    {"설렁탕", "설농탕", "곰탕"},          # 소뼈 국물 — 통용상 동일
    {"떡볶이", "떡뽀끼"}, {"돈가스", "돈까스"},
]


def _syn_group(name):
    n = name.replace(" ", "")
    for g in SYNONYMS:
        if n in g:
            return g
    return None


def same_food(pred, true, nutri):
    """예측·정답 음식명이 같은 음식인지(정규화·동의어·DB키 비교)."""
    if not pred:
        return False
    p, t = pred.replace(" ", ""), true.replace(" ", "")
    if p == t:
        return True
    g = _syn_group(p)
    if g and t in g:
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


def main():
    ap = argparse.ArgumentParser(description="정확도 자동 평가 하니스")
    ap.add_argument("--labels", default=str(ROOT / "data" / "eval_labels.csv"))
    ap.add_argument("--engine", choices=["gemini"], default="gemini")
    ap.add_argument("--quantity", choices=["gemini", "resnet"], default="gemini")
    ap.add_argument("--gemini-samples", type=int, default=1)
    ap.add_argument("--gemini-model", default="gemini-2.5-flash")
    ap.add_argument("--no-search", action="store_true")
    args = ap.parse_args()

    labels = load_labels(args.labels)
    if not labels:
        print(f"라벨이 없습니다: {args.labels}")
        return
    print(f"평가셋 {len(labels)}장 | engine={args.engine} "
          f"quantity={args.quantity} samples={args.gemini_samples}\n")

    pipe = fa.FoodAIPipeline(
        quantity_backend=args.quantity,
        engine=args.engine, gemini_model=args.gemini_model,
        use_search=not args.no_search, gemini_samples=args.gemini_samples)

    n = answered = cls_ok = fam_ok = q_exact = q_near = q_total = 0
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
        # 양: 정답 q가 있고, 해당 음식을 맞췄을 때만 평가
        if row["q"] in Q_ORDER and hit and hit.get("q") in Q_ORDER:
            q_total += 1
            diff = abs(Q_ORDER[hit["q"]] - Q_ORDER[row["q"]])
            if diff == 0:
                q_exact += 1
            if diff <= 1:
                q_near += 1
        mark = "✓" if hit else "✗"
        pq = hit.get("q") if hit else "-"
        print(f"  {mark} {row['image']:38s} 정답={row['food']}/{row['q'] or '-'}  "
              f"예측={preds}/{pq}")

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
    if q_total:
        print(f"양 정확도(정확)   : {q_exact}/{q_total} = {q_exact/q_total*100:.1f}%")
        print(f"양 정확도(±1단계) : {q_near}/{q_total} = {q_near/q_total*100:.1f}%")
    if misses:
        print("\n[진짜 오답(응답했으나 틀림)]")
        for img, true, preds in misses:
            print(f"  - {img}: 정답 {true} / 예측 {preds}")


if __name__ == "__main__":
    main()
