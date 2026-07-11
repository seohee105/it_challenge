# 음식 분류 + 양 추정 + 칼로리 파이프라인

음식 사진 한 장으로 **음식명 → 양(Q1~Q5) → 칼로리·탄단지**를 산출합니다.
분류·칼로리 분석은 **Gemini 3.5 Flash 전문가 엔진**이 담당하고, 방대한 **영양 DB(약 40,400종)**로 칼로리를 정밀 보정합니다.

```
사진 ─▶ ① 음식 분류 (Gemini Vision, 멀티음식)
      └▶ ② 양 추정   (Gemini 기본 / ResNet / 접시기준 면적)
                          └▶ ③ 칼로리·탄단지 (영양DB 매칭 or Gemini 추정)
```

> ℹ️ 초기엔 로컬 YOLOv3 분류기를 썼으나, Gemini 분류가 훨씬 정확해 제거했습니다.
> ResNet 양추정 모델은 옵션으로 남아 있습니다(`--quantity resnet`).

## 구성

| 경로 | 설명 |
|------|------|
| `food_ai.py` | 통합 파이프라인 (분류·양·칼로리, CLI) |
| `portion_ref.py` | 접시기준(면적) 양추정 — cv2만, 오프라인 |
| `build_nutrition_db.py` | 병합 영양DB 생성기 |
| `evaluate.py` | 정확도 자동 평가 하니스 |
| `models/quantity/` | ResNet 양추정 가중치 (옵션) |
| `data/nutrition_db_merged.csv` | 병합 영양DB (약 40,400종, 실제 사용) |
| `data/food_additions.csv` | 직접 추가 음식 (191종, **최우선** 매칭) |
| `data/serving_overrides.csv` | 표준 1인분(g) 보정 |
| `data/sources/` | DB 병합 원본 (식약처·전국통합·전북) |
| `run_food_ai.bat` | 실행 런처 |

## 설치 (최초 1회)

기본 분석은 **Gemini만 있으면 되고 torch가 필요 없습니다.**
**ResNet 양추정(`--quantity resnet`)을 쓸 때만** Python 3.11 + PyTorch가 필요합니다.

```powershell
# 필수: 의존성 (google-genai 등)
pip install -r requirements.txt

# (선택) ResNet 양추정용 전용 venv — torch 필요
py -3.11 -m venv .venv311
.\.venv311\Scripts\python -m pip install -r requirements.txt
.\.venv311\Scripts\python -m pip install --index-url https://download.pytorch.org/whl/cpu torch torchvision

# (선택) 영양DB 재빌드 (food_additions/serving_overrides 수정 후)
python build_nutrition_db.py
```

이어서 **API 키 설정**(아래)을 1회 하면 준비 완료입니다.

## API 키 설정 (Gemini) — 팀원 각자 1회

분류·칼로리 분석은 Gemini를 씁니다. **키는 저장소에 올리지 않으며(보안), 각자 로컬에 둡니다.**

1. [aistudio.google.com/apikey](https://aistudio.google.com/apikey) 에서 **본인 키 발급** (무료)
2. 프로젝트 루트에 **`.gemini_key`** 파일을 만들고 키 한 줄만 붙여넣기:
   ```powershell
   Set-Content -Path .gemini_key -Value "여기에_본인_키" -NoNewline
   ```
   (또는 환경변수 `GEMINI_API_KEY` 설정)

- `.gemini_key`는 `.gitignore`에 등록돼 **커밋되지 않습니다.** 코드가 자동으로 읽습니다.
- 결과는 **어느 키든 동일**합니다(같은 모델). 키가 다른 건 인증만 다를 뿐 성능 영향 없음.
- **각자 본인 키**를 쓰면 무료 일일 한도(쿼터)가 분산돼 좋습니다. ⚠️ 같은 Google 프로젝트의 여러 키는 쿼터를 공유하니, 독립 한도를 원하면 서로 다른 계정/프로젝트 키를 쓰세요.

## 실행

```powershell
# 기본 분석 (분류·양·칼로리 모두 Gemini, 3회 다수결)
python food_ai.py --image test_images\음식.jpg

# JSON 출력 (서버/연동용)
python food_ai.py --image test_images\음식.jpg --json

# 접시 지름/그릇 종류로 면적기반 양추정 (더 정밀)
python food_ai.py --image test_images\음식.jpg --vessel 접시
python food_ai.py --image test_images\음식.jpg --plate-cm 24

# 양 추정을 로컬 ResNet으로 (torch 필요)
python food_ai.py --image test_images\음식.jpg --quantity resnet

# 빠르게 (토큰 절약, 변동↑)
python food_ai.py --image test_images\음식.jpg --gemini-samples 1

# 런처(.bat)
run_food_ai.bat test_images\음식.jpg
```

### 주요 옵션
| 옵션 | 기본값 | 설명 |
|------|--------|------|
| `--image` | (필수) | 분석할 음식 사진 경로 |
| `--quantity` | `gemini` | 양 추정: `gemini`(기본) / `resnet`(로컬·torch) / `hybrid` |
| `--gemini-samples` | `3` | N회 다수결로 안정화(self-consistency). 토큰 아끼려면 `1` |
| `--vessel` | - | 그릇 종류(밥공기/국그릇/대접/접시/큰접시/면기…)로 접시기준 양추정 |
| `--plate-cm` | - | 접시 지름(cm) 직접 지정 → 면적기반 양추정 |
| `--no-search` | - | Google 검색 그라운딩 끄기(속도↑) |
| `--device` | `cpu` | ResNet용 `cpu`/`cuda` |
| `--gemini-model` | `gemini-3.5-flash` | Gemini 모델명 (고정확: `gemini-3.1-pro-preview`, 단 비쌈) |
| `--json` | - | JSON 형식 출력 |

### 동작 방식
- **분류·양·칼로리를 Gemini가 한 번에** 처리(한 사진의 여러 음식을 각각 + 합계). `--gemini-samples 3`으로 다수결 안정화.
- **양(무게) 기반 칼로리** ⭐: Gemini가 음식의 **실제 무게(그램)**를 추정 → **칼로리 = 그램 × 밀도(kcal/g)**. "표준 1인분" 가정 대신 실제 담긴 양에 맞춰 계산(양=Gemini, 밀도=DB로 역할 분리 → 실측상 훨씬 정확).
- **칼로리 신뢰도 자동 표시**:
  - 🟢 **높음** — 영양DB 매칭(흔한 한식 단품). 칼로리·탄단지 **정확**
  - 🟡 **중간** — 일부 DB 미수록(Gemini 추정 포함)
  - 🔴 **낮음** — 혼합접시·뷔페·미수록 다수 → **대략치**
- **혼합접시 보정**: 🔴일 때 항목별 합산이 과대추정되므로, **접시 전체를 통으로 추정**(홀리스틱)해 총칼로리를 보정합니다.

### 양 추정 방식 비교
| 방식 | 특징 |
|------|------|
| `gemini`(기본) | **실제 무게(g) 추정 → 그램×밀도**로 칼로리. 기준물 불필요, 실측상 가장 정확 |
| `resnet` | 로컬·오프라인(torch). 근접촬영을 **과대추정**하는 경향, 보조용 |
| `--vessel`/`--plate-cm` | **면적 실측(접시기준)** — 그릇 크기를 알면 물리적으로 정밀 |

> 남은 한계: 단일 2D 사진은 **스케일(크기) 기준이 없어** 비전형적 크기(특히 초소량·고밀도)에서 오차. 그릇 크기를 알려주면(접시기준) 개선됩니다.

### 접시기준 양추정 (`portion_ref.py`)
접시/그릇 지름을 알면 픽셀→cm 환산으로 음식이 차지한 **실제 면적(cm²)** 을 재서 1인분 대비 양을 계산합니다(cv2만, 완전 오프라인).
- 단독 실행: `python portion_ref.py --image 사진.jpg --vessel 접시 --food 비빔밥`
- **그릇 프리셋**: 밥공기 11 · 국그릇 16 · 대접 18 · 뚝배기 15 · 반찬접시 13 · 접시 23 · 큰접시 27 · 면기 21 (cm)
- **음식종류별 밀도**(g/cm²) 자동: 국/탕/찌개 3.7 · 면 2.8 · 밥 2.25 · 구이/볶음 1.85 · 나물/김치/전 1.3
- 한계: 접시가 보여야 하고 지름 입력 필요, 음식·접시 색이 구분돼야 함.

## 영양 DB (`data/nutrition_db_merged.csv`)

`build_nutrition_db.py` 가 아래 소스를 한 스키마(`name,중량,칼로리,탄수화물,당류,지방,단백질,나트륨,source,basis`)로 병합합니다. **중복 음식명은 우선순위 높은 소스만** 유지합니다.

| 소스 | 우선순위 | 특징 |
|------|:---:|------|
| `추가` (food_additions.csv, 191종) | 1 | 직접 입력 **1인분 기준**. 오매칭·틀린값도 교정 |
| `base` (nutrition_db.xlsx, 400종) | 2 | 정제된 1인분 + 전체 영양소 |
| `식약처음식` (약 14,000종) | 3 | 공식 조리음식. 식품중량 있으면 1인분 환산 |
| `전북` (약 830종) | 4 | 향토음식. 에너지·단백질 위주(탄/지 결손) |
| `전국통합` (약 24,600종) | 5 | 가공식품, 100g 기준 |

- **매칭**: 띄어쓰기만 다른 **정확 매칭을 항상 먼저**(dish→전체), 그 다음 부분포함/유사도(컷오프 0.8). 1인분 소스를 우선 잡고 가공식품(100g)은 최후순위.
- 각 항목 `basis`(1인분/100g) 명시 — 출력에 기준 표시.

### 표준 1인분 보정 (`data/serving_overrides.csv`)
소스 기준이 100g이거나 중량이 빈 음식의 **표준 1인분(g)**을 `name,serving_g,note`로 적으면 빌드 시 재계산됩니다.

### DB에 없는 음식 직접 추가 (`data/food_additions.csv`)
자주 쓰는 음식을 **1인분 기준 탄/단/지/칼로리**로 직접 넣습니다(`name,중량,칼로리,탄수화물,당류,지방,단백질,나트륨`).
- **우선순위 최상**이라 잘못된 유사매칭·틀린 값도 교정(예: 팥빙수 1473→350, 치킨→치킨윙 219→후라이드 600).
- 현재 191종(편의점·다이어트·카페음료/디저트·주류·배달외식 등). 한 줄 추가 후 `python build_nutrition_db.py` 재실행하면 반영.

## 정확도 (측정)

| 단계 | 정확도 | 근거 |
|------|:--:|------|
| ① 분류 | **완전일치 ~96%** (한식 97% · 서양/카페 95%) | 실사진 93장, samples=3, 공정 채점 |
| ③ 칼로리 | **±25% 이내 65% · MAPE 35% · r 0.96** | 실측 무게·칼로리(SimpleFood45) |

**칼로리 정확도 개선 여정 (실측 기준)** — 그램방식 + 3.5-flash 도입으로 대폭 향상:
| 방식 | MAPE | ±25% 이내 |
|------|:--:|:--:|
| Q비율 방식(초기) | 107% | 5% |
| 그램 방식 | 53% | 42% |
| **+ gemini-3.5-flash** | **35%** | **65%** |

> 실측 검증: SimpleFood45(단품 실제 무게)·Nutrition5k(혼합접시). 그램 기반 + 최신 flash 모델로 **±25% 정확도 5%→65%**. 남은 오차는 초소량·비전형 크기(스케일 모호성)에 집중되며, 정상 크기 음식은 대체로 ±10% 이내.

## 정확도 평가 (`evaluate.py`)
라벨(`data/eval_labels_all.csv`: `image,food,q`)로 분류/양 정확도를 자동 측정합니다.
```powershell
python evaluate.py --labels data\eval_labels_all.csv                    # 기본(samples=3)
python evaluate.py --labels data\eval_labels_all.csv --gemini-samples 1 # 빠르게
python evaluate.py --labels data\eval_labels_all.csv --quantity resnet  # 양=ResNet
```
- 완전일치 / 같은 음식군 / 오답 목록 출력. 빈 예측(API 실패)은 오답이 아닌 '미응답'으로 분리 집계.

## Gemini 호출 안정화 (스로틀 / 재시도 / 키 전환)
모든 Gemini 호출은 `GeminiPool`을 거치며 **환경변수**로 제어합니다:

| env | 기본 | 역할 |
|-----|:--:|------|
| `GEMINI_API_KEY` (또는 `.gemini_key` 파일) | - | 1순위 키 |
| `GEMINI_API_KEY2~4` / `GEMINI_API_KEYS`(콤마) | - | 추가 키 — 앞 키가 429면 **자동 전환** |
| `GEMINI_RPM` | 10 | 분당 요청수 상한(요청 간격 조절) |
| `GEMINI_MAX_RETRIES` | 2 | 429 시 백오프 재시도 횟수 |

> ⚠️ 스로틀/재시도는 **분당 한도(RPM)**·일시적 429만 해결합니다. **일일 총량(RPD)**은 늘릴 수 없고,
> 같은 프로젝트의 키 여러 개는 쿼터를 공유합니다 → 한도를 늘리려면 **다른 계정 키** 또는 **유료**.

## 출력 예시
```
📷 이미지: test_images/음식.jpg

[1] 🍽 음식 : 비빔밥   [Gemini 전문가 분석]
    ⚖ 양: 기준(1인분) (Q4, ~100.0%, gemini-expert)
    🔥 칼로리: 639.0 kcal [DB]   (450.0 g)
       탄수 95.0g · 단백 18.0g · 지방 15.0g · 나트륨 900.0mg

  🟢 칼로리 신뢰도: 높음 — 전부 DB 매칭(정확)
```

## 런타임 메모
- 기본 경로(Gemini)는 torch 불필요. ResNet 양추정만 `.venv311`(Python 3.11 + PyTorch CPU) 필요.
- ResNet 가중치는 torch 1.7 시절 것이라 로딩 시 `weights_only=False` 처리.
- 한글 경로 이미지 지원(`imread_unicode`, cv2 imdecode).
