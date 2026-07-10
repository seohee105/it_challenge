# -*- coding: utf-8 -*-
r"""HTTP bridge for using food_ai.py from a Godot game.

Run:
    .\.venv311\Scripts\python.exe -m pip install fastapi uvicorn python-multipart
    .\.venv311\Scripts\python.exe -m uvicorn ai_server:app --host 127.0.0.1 --port 8000

Godot can POST a food photo to /analyze and receive both the raw AI result and
game-friendly values such as total calories, macro totals, and goal status.
"""

from __future__ import annotations

import tempfile
import traceback  # 🔍 에러 추적을 위한 모듈 추가
from pathlib import Path
from typing import Any

from fastapi import FastAPI, File, Form, HTTPException, UploadFile
from pydantic import BaseModel

from food_ai import FoodAIPipeline


app = FastAPI(title="Diet Dungeon Food AI")

_pipeline: FoodAIPipeline | None = None


def get_pipeline() -> FoodAIPipeline:
    global _pipeline
    if _pipeline is None:
        _pipeline = FoodAIPipeline(
            quantity_backend="gemini",
            engine="gemini",
            gemini_model="gemini-2.5-flash",
            use_search=True,
            gemini_samples=1,
        )
    return _pipeline


def summarize_macros(analysis: dict[str, Any]) -> dict[str, float]:
    totals = {"carb_g": 0.0, "protein_g": 0.0, "fat_g": 0.0, "sodium_mg": 0.0}
    for item in analysis.get("detections", []):
        nutrition = item.get("nutrition") or {}
        totals["carb_g"] += float(nutrition.get("carb") or 0)
        totals["protein_g"] += float(nutrition.get("protein") or 0)
        totals["fat_g"] += float(nutrition.get("fat") or 0)
        totals["sodium_mg"] += float(nutrition.get("sodium") or 0)
    return {key: round(value, 1) for key, value in totals.items()}


def macro_bonus(macros: dict[str, float]) -> bool:
    carb_kcal = macros["carb_g"] * 4
    protein_kcal = macros["protein_g"] * 4
    fat_kcal = macros["fat_g"] * 9
    total = carb_kcal + protein_kcal + fat_kcal
    if total <= 0:
        return False

    carb_ratio = carb_kcal / total
    protein_ratio = protein_kcal / total
    fat_ratio = fat_kcal / total
    return 0.45 <= carb_ratio <= 0.65 and 0.15 <= protein_ratio <= 0.30 and 0.15 <= fat_ratio <= 0.30


def build_game_delta(
    analysis: dict[str, Any],
    bmr_kcal: float | None,
    exercise_kcal: float | None,
) -> dict[str, Any]:
    total_kcal = float(analysis.get("total_kcal") or 0)
    macros = summarize_macros(analysis)
    delta: dict[str, Any] = {
        "meal_kcal": round(total_kcal, 1),
        "macros": macros,
        "macro_bonus": macro_bonus(macros),
        "food_count": len(analysis.get("detections", [])),
        "kcal_reliability": analysis.get("kcal_reliability"),
    }

    if bmr_kcal is not None and exercise_kcal is not None:
        net = total_kcal - bmr_kcal - exercise_kcal
        goal_met = -500 <= net <= -200
        delta.update(
            {
                "net_kcal": round(net, 1),
                "daily_goal_met": goal_met,
                "card_upgrade_allowed": goal_met,
                "bonus_coin": 1 if macro_bonus(macros) else 0,
            }
        )
    return delta


@app.post("/analyze")
async def analyze_food(
    image: UploadFile = File(...),
    bmr_kcal: float | None = Form(default=None),
    exercise_kcal: float | None = Form(default=None),
) -> dict[str, Any]:
    suffix = Path(image.filename or "food.jpg").suffix or ".jpg"
    with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
        tmp.write(await image.read())
        image_path = Path(tmp.name)

    try:
        print(f"\n[디버그] {image_path.name} 임시 파일 생성 완료. AI 분석 파이프라인을 실행합니다...")
        
        # 실제 AI 파이프라인 분석 실행
        analysis = get_pipeline().analyze(str(image_path))
        
        print("[디버그] AI 파이프라인 분석 완료! 수신된 데이터:")
        print("Raw Analysis JSON:", analysis)
        
        return {
            "ok": True,
            "analysis": analysis,
            "game_delta": build_game_delta(analysis, bmr_kcal, exercise_kcal),
        }
    except Exception as exc:  # noqa: BLE001
        # ⚠️ 파이썬 터미널 창에 에러 원인과 추적 이력을 강제로 자세히 출력합니다.
        print("\n❌❌❌ [AI 파이프라인 내부 에러 발생] ❌❌❌")
        traceback.print_exc() 
        print("==================================================\n")
        
        raise HTTPException(status_code=500, detail=str(exc)) from exc
    finally:
        image_path.unlink(missing_ok=True)


class DailyResultRequest(BaseModel):
    intake_kcal: float
    bmr_kcal: float
    exercise_kcal: float
    carb_g: float = 0
    protein_g: float = 0
    fat_g: float = 0


@app.post("/daily-result")
def daily_result(req: DailyResultRequest) -> dict[str, Any]:
    macros = {
        "carb_g": req.carb_g,
        "protein_g": req.protein_g,
        "fat_g": req.fat_g,
        "sodium_mg": 0.0,
    }
    net = req.intake_kcal - req.bmr_kcal - req.exercise_kcal
    goal_met = -500 <= net <= -200
    return {
        "ok": True,
        "net_kcal": round(net, 1),
        "daily_goal_met": goal_met,
        "card_upgrade_allowed": goal_met,
        "bonus_coin": 1 if macro_bonus(macros) else 0,
    }