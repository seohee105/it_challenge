# -*- coding: utf-8 -*-
"""
영양 DB 병합기
================
기존 nutrition_db.xlsx(400종, 정제된 1인분 데이터)에
공공데이터 CSV 2종을 정규화·병합해 data/nutrition_db_merged.csv 를 만든다.

[소스]
- base : data/nutrition_db.xlsx                          (우선순위 1, 1인분 기준)
- 전북 : data/sources/전북특별자치도_음식 영양소...csv   (우선순위 2, 향토음식)
- 전국 : data/sources/전국통합식품영양성분정보표준데이터.csv (우선순위 3, 가공식품 100g 기준)

[정규화 스키마]  name, 중량, 칼로리, 탄수화물, 당류, 지방, 단백질, 나트륨, source
- 중복 음식명(공백 제거 기준)은 우선순위가 높은 소스만 유지.
- 전국통합: 영양성분함량기준량(보통 100g) 기준 → 중량=100, 값은 그대로(100g당).
- 전북: 에너지·단백질만 존재(탄수/지방/나트륨 없음), 중량 정보 없음 → 빈칸.

[실행] python build_nutrition_db.py
"""
import csv
import sys
from pathlib import Path

import openpyxl

ROOT = Path(__file__).parent
BASE_XLSX = ROOT / "data" / "nutrition_db.xlsx"
SRC_A = ROOT / "data" / "sources" / "전국통합식품영양성분정보표준데이터.csv"
SRC_B = ROOT / "data" / "sources" / "전북특별자치도_음식 영양소_20191219.csv"
SRC_MFDS = ROOT / "data" / "sources" / "20251229_음식DB 19495건.xlsx"
OVERRIDES = ROOT / "data" / "serving_overrides.csv"
ADDITIONS = ROOT / "data" / "food_additions.csv"
OUT = ROOT / "data" / "nutrition_db_merged.csv"

FIELDS = ["name", "중량", "칼로리", "탄수화물", "당류", "지방", "단백질", "나트륨", "source", "basis"]

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass


def fnum(v):
    """문자열 → float(또는 None). 콤마/공백/빈칸/문자 처리."""
    if v is None:
        return None
    s = str(v).strip().replace(",", "")
    if s in ("", "-", "N/A", "해당없음"):
        return None
    try:
        return float(s)
    except ValueError:
        # "100g", "100ml" 같은 값에서 숫자만 추출
        num = "".join(ch for ch in s if (ch.isdigit() or ch == "."))
        return float(num) if num else None


def norm_key(name):
    return name.replace(" ", "").strip()


def load_base():
    wb = openpyxl.load_workbook(BASE_XLSX, read_only=True, data_only=True)
    ws = wb.active
    out = []
    for r in ws.iter_rows(min_row=2, values_only=True):
        if not r or r[0] is None:
            continue
        out.append({
            "name": str(r[0]).strip(), "중량": r[1], "칼로리": r[2],
            "탄수화물": r[3], "당류": r[4], "지방": r[5], "단백질": r[6],
            "나트륨": r[9], "source": "base", "basis": "1인분",
        })
    wb.close()
    return out


def load_jeonbuk():
    out = []
    with open(SRC_B, encoding="cp949", newline="") as f:
        r = csv.reader(f)
        next(r, None)
        for row in r:
            if len(row) < 3 or not row[1].strip():
                continue
            out.append({
                "name": row[1].strip(), "중량": None, "칼로리": fnum(row[2]),
                "탄수화물": None, "당류": None, "지방": None,
                "단백질": fnum(row[3]) if len(row) > 3 else None,
                "나트륨": None, "source": "전북", "basis": "1인분",
            })
    return out


def load_national():
    out = []
    with open(SRC_A, encoding="cp949", newline="") as f:
        r = csv.reader(f)
        next(r, None)
        for row in r:
            if len(row) < 18 or not row[1].strip():
                continue
            basis = fnum(row[5]) or 100.0  # 보통 100g
            out.append({
                "name": row[1].strip(), "중량": basis, "칼로리": fnum(row[4]),
                "탄수화물": fnum(row[10]), "당류": fnum(row[11]), "지방": fnum(row[8]),
                "단백질": fnum(row[7]), "나트륨": fnum(row[17]), "source": "전국통합",
                "basis": "100g",
            })
    return out


def _mfds_name(food, rep):
    """식약처 식품명('대표_세부')을 자연스러운 이름으로. 예: 국밥_순대국밥→순대국밥,
    국밥_돼지머리→돼지머리국밥, 국밥_콩나물→콩나물국밥."""
    food = (food or "").strip()
    rep = (rep or "").strip()
    if "_" not in food:
        return food
    sub = food.split("_", 1)[1].strip()
    if not sub or sub == "해당없음":
        return rep or food
    if not rep or rep in sub:
        return sub
    return sub + rep  # 세부 + 대표 (돼지머리+국밥)


def load_mfds():
    """식약처 음식 DB(19,495건, 음식, 100g/ml 기준, 전체 영양소).
    식품중량(또는 1인분 참고량)이 있으면 1인분으로 환산, 없으면 100g 기준 유지."""
    if not SRC_MFDS.exists():
        return []
    wb = openpyxl.load_workbook(SRC_MFDS, read_only=True, data_only=True)
    ws = wb.active
    it = ws.iter_rows(min_row=1, values_only=True)
    hdr = list(next(it))
    ix = {h: i for i, h in enumerate(hdr)}

    def g(row, name):
        i = ix.get(name)
        return row[i] if i is not None and i < len(row) else None

    out = []
    for row in it:
        name = _mfds_name(g(row, "식품명"), g(row, "대표식품명"))
        if not name:
            continue
        per100 = {
            "칼로리": fnum(g(row, "에너지(kcal)")), "탄수화물": fnum(g(row, "탄수화물(g)")),
            "당류": fnum(g(row, "당류(g)")), "지방": fnum(g(row, "지방(g)")),
            "단백질": fnum(g(row, "단백질(g)")), "나트륨": fnum(g(row, "나트륨(mg)")),
        }
        serving = fnum(g(row, "1인(회)분량 참고량")) or fnum(g(row, "식품중량"))
        if serving and serving > 0:
            scale = serving / 100.0
            rec = {k: (v * scale if v is not None else None) for k, v in per100.items()}
            rec.update({"name": name, "중량": round(serving, 1), "source": "식약처음식", "basis": "1인분"})
        else:  # 1인분 무게 없음 → 100g 기준 유지
            rec = dict(per100)
            rec.update({"name": name, "중량": 100, "source": "식약처음식", "basis": "100g"})
        out.append(rec)
    wb.close()
    return out


def load_additions():
    """DB에 없는 자주 쓰는 음식 수기 추가(1인분 기준, 탄·단·지·칼로리). data/food_additions.csv"""
    if not ADDITIONS.exists():
        return []
    out = []
    with open(ADDITIONS, encoding="utf-8-sig", newline="") as f:
        for r in csv.DictReader(f):
            nm = (r.get("name") or "").strip()
            if not nm:
                continue
            out.append({
                "name": nm, "중량": fnum(r.get("중량")), "칼로리": fnum(r.get("칼로리")),
                "탄수화물": fnum(r.get("탄수화물")), "당류": fnum(r.get("당류")),
                "지방": fnum(r.get("지방")), "단백질": fnum(r.get("단백질")),
                "나트륨": fnum(r.get("나트륨")), "source": "추가", "basis": "1인분",
            })
    return out


def apply_overrides(merged):
    """data/serving_overrides.csv 의 표준 1인분(g)으로 해당 음식을 재계산.
    - 100g 기준 항목: 영양소를 serving/100 로 환산하고 중량=serving, basis=1인분
    - 중량 미상(전북 등): 칼로리는 이미 1인분이므로 중량만 채움
    공백 무시 정규화로 매칭(예: '후라이드치킨'↔'후라이드 치킨')."""
    if not OVERRIDES.exists():
        return 0
    norm_idx = {k.replace(" ", ""): k for k in merged}
    nutrients = ["칼로리", "탄수화물", "당류", "지방", "단백질", "나트륨"]
    applied = 0
    with open(OVERRIDES, encoding="utf-8-sig", newline="") as f:
        for row in csv.DictReader(f):
            nm = (row.get("name") or "").strip()
            serving = fnum(row.get("serving_g"))
            if not nm or not serving or serving <= 0:
                continue
            key = norm_idx.get(nm.replace(" ", ""))
            if not key:
                continue
            rec = merged[key]
            old_w = fnum(rec.get("중량")) or 0
            if old_w > 0:  # 100g 등 기준량 → 비율 환산
                scale = serving / old_w
                for fld in nutrients:
                    v = fnum(rec.get(fld))
                    if v is not None:
                        rec[fld] = round(v * scale, 1)
            rec["중량"] = serving
            rec["basis"] = "1인분"
            if "검색보정" not in (rec.get("source") or ""):
                rec["source"] = (rec.get("source") or "") + "+검색보정"
            applied += 1
    return applied


def main():
    print("소스 로딩 중...")
    adds = load_additions()
    print(f"  수기 추가: {len(adds)}행")
    base = load_base()
    print(f"  base(xlsx): {len(base)}행")
    mfds = load_mfds()
    print(f"  식약처 음식 xlsx: {len(mfds)}행")
    jb = load_jeonbuk()
    print(f"  전북 CSV  : {len(jb)}행")
    nat = load_national()
    print(f"  전국통합 CSV: {len(nat)}행")

    merged = {}  # norm_key -> record (우선순위 높은 것만 유지)
    dup = 0
    # 우선순위: 수기추가(큐레이션) > base > 식약처음식 > 전북 > 전국통합(가공 100g)
    for src in (adds, base, mfds, jb, nat):
        for rec in src:
            k = norm_key(rec["name"])
            if not k:
                continue
            if k in merged:
                dup += 1
                continue
            merged[k] = rec

    # 표준 1인분 오버라이드 적용(자주 쓰는 음식의 100g/중량없음 → 1인분으로 재계산)
    n_ov = apply_overrides(merged)
    print(f"  표준 1인분 보정: {n_ov}건 적용")

    OUT.parent.mkdir(parents=True, exist_ok=True)
    with OUT.open("w", encoding="utf-8-sig", newline="") as f:
        w = csv.DictWriter(f, fieldnames=FIELDS)
        w.writeheader()
        for rec in merged.values():
            w.writerow(rec)

    by_src = {}
    for rec in merged.values():
        by_src[rec["source"]] = by_src.get(rec["source"], 0) + 1
    print(f"\n병합 완료 → {OUT}")
    print(f"  고유 음식 {len(merged)}종 (중복 건너뜀 {dup}건)")
    print(f"  소스별: {by_src}")


if __name__ == "__main__":
    main()
