@echo off
cd /d C:\Users\AnnLee\Desktop\it_challenge-ai_model
C:\Users\AnnLee\Desktop\it_challenge-ai_model\.venv311\Scripts\python.exe -m uvicorn ai_server:app --host 0.0.0.0 --port 8000
