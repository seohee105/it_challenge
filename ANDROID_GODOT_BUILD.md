# Android Godot Build Guide

## 1. Godot project files

Modified files:

- `control.tscn`
- `godot_food_ai_client.gd`
- `scripts/AIClient.gd`
- `scripts/CameraManager.gd`
- `scripts/UIManager.gd`
- `scripts/Main.gd`
- `android/plugins/FoodPhotoPicker.gdap`
- `android_plugin/FoodPhotoPicker/**`

## 2. Build the Android plugin AAR

1. In Godot, install Android build templates from `Project > Install Android Build Template`.
2. Copy Godot's Android library AAR into:
   `foodaicamera/android_plugin/FoodPhotoPicker/godot-lib.release.aar`
3. Open a terminal:

```powershell
cd C:\Users\AnnLee\Desktop\foodaicamera\android_plugin\FoodPhotoPicker
gradle :plugin:assembleRelease
```

4. Copy the generated AAR:

```powershell
copy .\plugin\build\outputs\aar\plugin-release.aar ..\..\android\plugins\FoodPhotoPicker.aar
```

## 3. Godot export settings

1. Open `foodaicamera` in Godot 4.7.
2. Open `Project > Export`.
3. Add Android preset.
4. Enable:
   - Internet permission
   - Camera permission
   - Custom Android build
   - `FoodPhotoPicker` plugin
5. Set package name, for example:
   `com.example.foodaicamera`

## 4. Server URL

- Android emulator to local PC: `http://10.0.2.2:8000/analyze`
- Physical Android device: use the PC LAN IP, for example `http://192.168.0.10:8000/analyze`

Update `Main.gd` `ai_server_url` export value in the Inspector if needed.

## 5. Run FastAPI

```powershell
cd C:\Users\AnnLee\Desktop\it_challenge-ai_model
.\.venv311\Scripts\python.exe -m uvicorn ai_server:app --host 0.0.0.0 --port 8000
```

## 6. Expected flow

Camera or Gallery button opens Android UI, returns a real image file path to Godot, previews it in `TextureRect`, uploads the selected image to `/analyze`, and displays all foods plus `game_delta` in the UI.
