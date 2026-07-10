# Godot AI Integration

## Recommended structure

Godot should own the game loop, cards, dungeon state, UI, coins, and collection book.
Python should own food image analysis.

```text
Godot game
  -> sends food photo to Python AI server
  <- receives JSON: calories, macros, reliability
  -> updates daily diet variables
  -> opens dungeon / upgrades cards / gives coins
```

This is easier than embedding Python directly into Godot, especially for mobile builds.
It also keeps the Gemini API key out of the Godot client.

## Run the AI server

From the project folder:

```powershell
.\.venv311\Scripts\python.exe -m pip install fastapi uvicorn python-multipart
.\.venv311\Scripts\python.exe -m uvicorn ai_server:app --host 127.0.0.1 --port 8000
```

Analyze a photo:

```text
POST http://127.0.0.1:8000/analyze
form-data:
  image: food photo file
  bmr_kcal: optional
  exercise_kcal: optional
```

The response includes:

```json
{
  "ok": true,
  "analysis": {
    "total_kcal": 520.0,
    "detections": []
  },
  "game_delta": {
    "meal_kcal": 520.0,
    "net_kcal": -320.0,
    "daily_goal_met": true,
    "card_upgrade_allowed": true,
    "bonus_coin": 1
  }
}
```

## Godot side

Use `HTTPRequest` to upload the image. Keep these as game variables:

```text
daily_intake_kcal
bmr_kcal
exercise_kcal
net_kcal = daily_intake_kcal - bmr_kcal - exercise_kcal
goal_met = -500 <= net_kcal <= -200
```

Game mapping:

```text
goal_met true  -> card upgrade allowed
goal_met false -> only existing cards available
macro_bonus    -> bonus coin
day % 7 == 0   -> boss dungeon
```

## Mobile release note

For Android/iOS, do not ship the Gemini key inside the app. Use a small online backend:

```text
Godot mobile app -> your backend server -> Gemini / food_ai.py
```

Local `127.0.0.1` is good for development on PC, but a real phone build should use a hosted server URL.
