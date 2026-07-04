"""
음식 칼로리 분석 임시 프로토타입
====================================
[흐름]  사진 ─▶ ① 음식명 + ② 양(Q1~Q5)  ─▶ ③ 영양DB 조회 ─▶ 칼로리 계산

- ①② (사진 분석) : Google Gemini Vision  → GEMINI_API_KEY 환경변수 필요
- ③  (칼로리 계산): AI Hub 영양DB.xlsx    → 키 없이 지금 바로 작동

[실행 방법]
  python food_calorie_prototype.py --demo                 # 예시 자동 출력 (키 불필요)
  python food_calorie_prototype.py --food 오므라이스 --q Q3   # 음식명 직접 입력 (키 불필요)
  python food_calorie_prototype.py                        # 대화형 입력 (키 불필요)
  python food_calorie_prototype.py --image 사진.jpg        # 진짜 사진 분석 (Gemini 키 필요)

[사진 분석 켜기]
  pip install google-genai pillow
  set GEMINI_API_KEY=발급받은키        (Windows CMD)
  $env:GEMINI_API_KEY="발급받은키"     (PowerShell)
"""
import os, sys, json, argparse, difflib
from pathlib import Path
import openpyxl

try:
    sys.stdout.reconfigure(encoding="utf-8")
except Exception:
    pass

DB_PATH = Path(__file__).parent / "data" / "nutrition_db.xlsx"
GEMINI_MODEL = "gemini-2.5-flash"  # 무료 티어 지원 (구버전 2.0-flash는 2026-06-01 종료)

Q_RATIO = {"Q1": 0.25, "Q2": 0.5, "Q3": 0.75, "Q4": 1.0, "Q5": 1.25}
Q_LABEL = {"Q1": "아주 적음", "Q2": "적음", "Q3": "보통", "Q4": "기준(1인분)", "Q5": "많음"}


def num(v):
    try:
        return float(v)
    except (TypeError, ValueError):
        return 0.0


def load_db(path=DB_PATH):
    wb = openpyxl.load_workbook(path, data_only=True, read_only=True)
    ws = wb.active
    db = {}
    for r in ws.iter_rows(min_row=2, values_only=True):
        if not r or r[0] is None:
            continue
        name = str(r[0]).strip()
        db[name] = {
            "중량": r[1], "칼로리": r[2], "탄수화물": r[3],
            "당류": r[4], "지방": r[5], "단백질": r[6], "나트륨": r[9],
        }
    wb.close()
    return db


def match_food(name, db):
    name = name.strip()
    if name in db:
        return name
    for k in db:
        if name and (name in k or k in name):
            return k
    cand = difflib.get_close_matches(name, list(db.keys()), n=1, cutoff=0.4)
    return cand[0] if cand else None


def calculate(food_name, q, db):
    key = match_food(food_name, db)
    if key is None:
        return None
    info = db[key]
    ratio = Q_RATIO.get(q.upper(), 1.0)
    bw, bk = num(info["중량"]), num(info["칼로리"])
    return {
        "matched": key, "q": q.upper(), "ratio": ratio,
        "grams": round(bw * ratio, 1), "kcal": round(bk * ratio, 1),
        "base_w": round(bw, 1), "base_kcal": round(bk, 1),
        "carb": round(num(info["탄수화물"]) * ratio, 1),
        "protein": round(num(info["단백질"]) * ratio, 1),
        "fat": round(num(info["지방"]) * ratio, 1),
        "sodium": round(num(info["나트륨"]) * ratio, 1),
    }


def print_result(food_name_in, q, db):
    res = calculate(food_name_in, q, db)
    if res is None:
        print(f"  ✗ '{food_name_in}' 와(과) 비슷한 음식을 DB에서 못 찾았어요.")
        return
    print(f"  🍽  음식  : {res['matched']}   (입력: {food_name_in})")
    print(f"  ⚖  양    : {Q_LABEL.get(res['q'], '')} ({res['q']}, x{res['ratio']}) "
          f"→ {res['grams']} g   (기준 {res['base_w']}g)")
    print(f"  🔥 칼로리 : {res['kcal']} kcal   (기준 {res['base_kcal']} kcal)")
    print(f"     탄수 {res['carb']}g · 단백 {res['protein']}g · 지방 {res['fat']}g · 나트륨 {res['sodium']}mg")


def analyze_with_gemini(image_path, db):
    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        print("⚠ 환경변수 GEMINI_API_KEY 가 없어요. 사진 분석엔 Gemini 키가 필요해요.")
        return None
    try:
        from google import genai
    except ImportError:
        print("⚠ google-genai 패키지가 없어요 →  pip install google-genai pillow")
        return None
    import PIL.Image

    names = ", ".join(db.keys())
    prompt = (
        "이 사진 속 음식을 분석해줘.\n"
        f"1) 음식 이름은 다음 목록 중 가장 가까운 하나로만 골라: [{names}]\n"
        "2) 양은 1인분(100%) 대비 Q1(25%), Q2(50%), Q3(75%), Q4(100%), Q5(125%) 중 하나로 판단.\n"
        '다른 말 없이 JSON만 출력: {"food":"<음식명>","q":"Q3"}'
    )
    client = genai.Client(api_key=api_key)
    img = PIL.Image.open(image_path)
    resp = client.models.generate_content(model=GEMINI_MODEL, contents=[img, prompt])
    text = (resp.text or "").strip()
    s, e = text.find("{"), text.rfind("}")
    data = json.loads(text[s:e + 1])
    return data["food"], data["q"]


def main():
    ap = argparse.ArgumentParser(description="음식 칼로리 분석 프로토타입")
    ap.add_argument("--image", help="분석할 음식 사진 경로 (Gemini 키 필요)")
    ap.add_argument("--food", help="음식명 직접 입력 (데모용)")
    ap.add_argument("--q", default="Q4", help="양 Q1~Q5 (데모용, 기본 Q4)")
    ap.add_argument("--demo", action="store_true", help="예시 자동 출력")
    args = ap.parse_args()

    db = load_db()
    print(f"DB 로드 완료: 음식 {len(db)}종\n")

    if args.demo:
        for f, q in [("오므라이스", "Q3"), ("쌀밥", "Q4"), ("김치볶음밥", "Q2"), ("비빔밥", "Q5")]:
            print(f"[{f} / {q}]")
            print_result(f, q, db)
            print()
        return

    if args.image:
        out = analyze_with_gemini(args.image, db)
        if out:
            food, q = out
            print(f"[Gemini 인식 결과] 음식={food}, 양={q}\n")
            print_result(food, q, db)
        return

    if args.food:
        print_result(args.food, args.q, db)
        return

    print("음식명과 양(Q1~Q5)을 입력하세요. (그냥 엔터 치면 종료)\n")
    while True:
        try:
            f = input("음식명> ").strip()
        except EOFError:
            break
        if not f:
            break
        q = input("양(Q1~Q5, 기본 Q4)> ").strip() or "Q4"
        print_result(f, q, db)
        print()


if __name__ == "__main__":
    main()
