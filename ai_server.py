# -*- coding: utf-8 -*-
"""FastAPI bridge for the Godot Android food camera app."""

from __future__ import annotations

import os
import tempfile
import traceback
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
            engine="gemini",
            gemini_model=os.environ.get("GEMINI_MODEL", "gemini-3.5-flash"),
            use_search=True,
            gemini_samples=1,
        )
    return _pipeline


def to_float(value: Any, default: float = 0.0) -> float:
    try:
        if value is None:
            return default
        return float(value)
    except (TypeError, ValueError):
        return default


def round_number(value: Any, digits: int = 1) -> int | float:
    rounded = round(to_float(value), digits)
    if float(rounded).is_integer():
        return int(rounded)
    return rounded


def normalize_foods(analysis: dict[str, Any]) -> list[dict[str, Any]]:
    foods: list[dict[str, Any]] = []
    for item in analysis.get("detections", []):
        name = str(item.get("name") or item.get("food") or "").strip()
        if not name:
            continue

        nutrition = item.get("nutrition") or {}
        calorie = item.get("kcal")
        if calorie is None:
            calorie = nutrition.get("kcal")

        confidence = item.get("confidence")
        if confidence is None:
            confidence = item.get("conf")
        if confidence is None:
            confidence = 0.0

        foods.append(
            {
                "name": name,
                "confidence": min(max(round_number(confidence, 2), 0.0), 1.0),
                "calorie": round_number(calorie, 1),
                "carb": round_number(nutrition.get("carb"), 1),
                "protein": round_number(nutrition.get("protein"), 1),
                "fat": round_number(nutrition.get("fat"), 1),
                "sodium": round_number(nutrition.get("sodium"), 1),
            }
        )
    return foods


def build_game_delta(
    foods: list[dict[str, Any]],
    bmr_kcal: float | None,
    exercise_kcal: float | None,
) -> dict[str, Any]:
    meal_kcal = round_number(sum(to_float(food.get("calorie")) for food in foods), 1)
    macros = {
        "carb_g": round_number(sum(to_float(food.get("carb")) for food in foods), 1),
        "protein_g": round_number(sum(to_float(food.get("protein")) for food in foods), 1),
        "fat_g": round_number(sum(to_float(food.get("fat")) for food in foods), 1),
        "sodium_mg": round_number(sum(to_float(food.get("sodium")) for food in foods), 1),
    }
    delta: dict[str, Any] = {
        "meal_kcal": meal_kcal,
        "food_count": len(foods),
        "macros": macros,
    }

    if bmr_kcal is not None and exercise_kcal is not None:
        net = meal_kcal - bmr_kcal - exercise_kcal
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


@app.get("/health")
def health() -> dict[str, Any]:
    return {"ok": True}


@app.post("/analyze")
async def analyze_food(
    image: UploadFile = File(...),
    bmr_kcal: float | None = Form(default=None),
    exercise_kcal: float | None = Form(default=None),
) -> dict[str, Any]:
    suffix = Path(image.filename or "food.jpg").suffix or ".jpg"
    with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
        image_bytes = await image.read()
        if not image_bytes:
            raise HTTPException(status_code=400, detail="업로드된 이미지가 비어 있습니다.")
        tmp.write(image_bytes)
        image_path = Path(tmp.name)

    try:
        analysis = get_pipeline().analyze(str(image_path))
        foods = normalize_foods(analysis)
        game_delta = build_game_delta(foods, bmr_kcal, exercise_kcal)
        return {
            "ok": True,
            "foods": foods,
            "game_delta": game_delta,
        }
    except Exception as exc:  # noqa: BLE001
        traceback.print_exc()
        raise HTTPException(status_code=500, detail=f"AI 분석 중 오류가 발생했습니다: {exc}") from exc
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
