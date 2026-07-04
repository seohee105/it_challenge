# -*- coding: utf-8 -*-
"""
음식 코드 ↔ 한글 음식명 매핑 CSV 생성기
=========================================
음식분류(YOLOv3) 모델은 클래스를 'AI Hub 음식 코드'(예: 01011001)로 출력합니다.
반면 영양DB(nutrition_db.xlsx)와 칼로리 계산은 '한글 음식명'을 사용합니다.
이 둘을 잇는 다리(bridge) 파일 data/food_code_map.csv 를 만듭니다.

[매핑 방식]
- 403food.names 의 코드는 AI Hub 표준 코드 순서로 정렬되어 있고,
  nutrition_db.xlsx 도 동일 데이터셋에서 같은 코드 순서로 정렬돼 있습니다.
- 따라서 (배경코드 00000000, sp* 코드 제외) 음식 코드 403개를
  영양DB 400개 이름과 코드 순서대로 정렬 매칭합니다.
- 코드(403)와 이름(400)의 개수 차이(3개)만큼 뒤쪽 일부 코드는 unmapped 로 남습니다.
  → 정밀 매핑이 필요하면 AI Hub 공식 영양정보 엑셀(코드+이름 동봉)로
    이 CSV 를 교체하세요. 형식: code,name (헤더 포함) 만 지키면 됩니다.

[실행] python build_food_code_map.py
"""
import csv
import sys
from pathlib import Path

import openpyxl

ROOT = Path(__file__).parent
NAMES_PATH = ROOT / "models" / "classifier" / "data" / "403food.names"
DB_PATH = ROOT / "data" / "nutrition_db.xlsx"
OUT_PATH = ROOT / "data" / "food_code_map.csv"

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass


def load_codes(path):
    return [ln.strip() for ln in path.read_text(encoding="utf-8").splitlines() if ln.strip()]


def load_db_names(path):
    wb = openpyxl.load_workbook(path, read_only=True, data_only=True)
    ws = wb.active
    names = [str(r[0]).strip() for r in ws.iter_rows(min_row=2, values_only=True)
             if r and r[0] is not None]
    wb.close()
    return names


def main():
    codes = load_codes(NAMES_PATH)
    names = load_db_names(DB_PATH)

    # 배경(00000000) 및 특수(sp*) 코드를 제외한 실제 음식 코드만 추림
    food_codes = [c for c in codes if c != "00000000" and not c.startswith("sp")]

    print(f"전체 코드 {len(codes)}개 (배경/sp 포함)")
    print(f"음식 코드 {len(food_codes)}개, 영양DB 음식명 {len(names)}개")

    rows = []  # (code, name, status)
    for c in codes:
        if c == "00000000":
            rows.append((c, "", "background"))
        elif c.startswith("sp"):
            rows.append((c, "", "special"))
        else:
            idx = food_codes.index(c)
            if idx < len(names):
                rows.append((c, names[idx], "auto"))
            else:
                rows.append((c, "", "unmapped"))

    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    with OUT_PATH.open("w", encoding="utf-8-sig", newline="") as f:
        w = csv.writer(f)
        w.writerow(["code", "name", "status"])
        w.writerows(rows)

    mapped = sum(1 for r in rows if r[2] == "auto")
    unmapped = sum(1 for r in rows if r[2] == "unmapped")
    print(f"\n매핑 완료 → {OUT_PATH}")
    print(f"  매핑됨(auto): {mapped}   미매핑(unmapped): {unmapped}")
    if unmapped:
        print("  ※ 미매핑 코드는 코드/이름 개수 차이로 남은 항목입니다. "
              "정밀 매핑은 AI Hub 공식 엑셀로 CSV 교체 권장.")


if __name__ == "__main__":
    main()
