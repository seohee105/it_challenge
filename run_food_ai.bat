@echo off
REM 음식 분류 + 양 추정 파이프라인 실행 런처 (전용 가상환경 사용)
REM 사용법:  run_food_ai.bat 사진경로 [추가옵션]
REM 예:      run_food_ai.bat test_images\food.jpg --save out.jpg
setlocal
set HERE=%~dp0
set PY=%HERE%.venv311\Scripts\python.exe
if not exist "%PY%" (
  echo [오류] 가상환경(.venv311)이 없습니다. README_food_ai.md 의 설치 절차를 먼저 진행하세요.
  exit /b 1
)
if "%~1"=="" (
  echo 사용법: run_food_ai.bat 사진경로 [--save out.jpg] [--json] [--conf 0.3]
  exit /b 1
)
"%PY%" "%HERE%food_ai.py" --image %*
endlocal
