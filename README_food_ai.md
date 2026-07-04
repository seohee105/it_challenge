# 음식 분류 + 양 추정 통합 파이프라인

제공된 `03.AI모델`(AI 알고리즘 소스코드)의 **음식분류(YOLOv3)** 모델과
**음식양추정(ResNet)** 모델을 그대로 활용해, 음식 사진 한 장으로
**음식명 → 양(Q1~Q5) → 칼로리/영양소**를 산출하는 파이프라인입니다.

```
사진 ─▶ ① 음식 분류 (YOLOv3, 403종 음식코드) ─▶ 코드→한글명 매핑
      └▶ ② 양 추정   (ResNet, Q1~Q5)
                          └▶ ③ 영양DB 조회 ─▶ 칼로리/영양소 계산
```

## 구성

| 경로 | 설명 |
|------|------|
| `models/classifier/` | YOLOv3 음식분류 (가중치 `best_403food_e200b150v2.pt`, 403종) |
| `models/quantity/`   | ResNet 양추정 (가중치 `new_opencv_ckpt_b84_e200.pth`, Q1~Q5) |
| `data/nutrition_db.xlsx` | 원본 영양정보 DB (400종, 한글 음식명 기준) |
| `data/nutrition_db_merged.csv` | **병합 영양DB (26,650종)** — 원본 400 + 공공데이터 2종 (실제 사용) |
| `data/sources/` | 병합 원본 CSV (전국통합 식품영양 / 전북 음식 영양) |
| `build_nutrition_db.py` | 병합 DB 생성기 |
| `evaluate.py` + `data/eval_labels.csv` | **정확도 자동 평가 하니스** (분류/양 정확도, 오답 목록) |
| `data/food_code_map.csv` | **코드↔한글명 매핑 다리 파일** (자동 생성) |
| `food_ai.py` | 통합 파이프라인 (분류+양추정+칼로리) |
| `build_food_code_map.py` | `food_code_map.csv` 생성기 |
| `food_calorie_prototype.py` | 기존 Gemini Vision 기반 프로토타입(별도) |
| `run_food_ai.bat` | 가상환경으로 실행하는 런처 |

## 설치 (최초 1회)

> ⚠️ 이 모델들은 PyTorch 기반이며, **Python 3.10~3.11**이 필요합니다.
> 시스템 기본 Python 3.14에서는 PyTorch가 설치되지 않습니다.
> 아래 절차로 만든 전용 가상환경 `.venv311` 은 이미 구성되어 있습니다.
> (새로 구성해야 한다면:)

```powershell
# 1) Python 3.11 설치 (winget)
winget install --id Python.Python.3.11 --source winget

# 2) 전용 가상환경 생성
py -3.11 -m venv .venv311

# 3) PyTorch(CPU) 설치
.\.venv311\Scripts\python -m pip install --upgrade pip
.\.venv311\Scripts\python -m pip install --index-url https://download.pytorch.org/whl/cpu torch torchvision

# 4) 나머지 의존성
.\.venv311\Scripts\python -m pip install -r requirements.txt

# 5) 코드↔이름 매핑 CSV 생성
.\.venv311\Scripts\python build_food_code_map.py

# 6) (선택) 영양DB 병합 — 원본 400 + 공공데이터 CSV 2종 → nutrition_db_merged.csv
.\.venv311\Scripts\python build_nutrition_db.py
```

## 정확도 평가 (`evaluate.py`)
라벨(`data/eval_labels.csv`: `image,food,q`)을 채우고 실행하면 모드별 정확도를 자동 측정합니다.
```powershell
.\.venv311\Scripts\python evaluate.py                                   # 로컬
.\.venv311\Scripts\python evaluate.py --classify hybrid                 # 하이브리드 분류
.\.venv311\Scripts\python evaluate.py --classify hybrid --quantity gemini --gemini-samples 3
```
- 분류 top-1 정확도 / 양 정확도(정확·±1단계) / 오답 목록 출력
- 측정값 예(테스트 3장): **로컬 33% → 하이브리드 100%** (분류). 단 표본이 작아 참고용.

## 영양 DB (`data/nutrition_db_merged.csv`, 40,236종)
`build_nutrition_db.py` 가 아래 소스들을 한 스키마(`name,중량,칼로리,탄수화물,당류,지방,단백질,나트륨,source,basis`)로 병합합니다. **중복 음식명은 우선순위 높은 소스만** 유지합니다.

| 소스 | 종수(고유) | 우선순위 | 특징 |
|------|------|:---:|------|
| `base` (nutrition_db.xlsx) | 400 | 1 | 정제된 **1인분 기준** + 전체 영양소 |
| `식약처음식` (음식DB 19,495건) | 14,396 | 2 | 식약처 공식 **조리음식**, 전체 영양소. 식품중량 있으면 **1인분 환산**, 없으면 100g |
| `전북` 음식 영양 | 842 | 3 | 향토음식. **에너지·단백질만** (탄수/지방/나트륨 없음) |
| `전국통합` 식품영양 | 24,598 | 4 | 가공식품, **100g 기준** 전체 영양소 |

> 식약처 음식 DB는 식품명('대표_세부')을 자연스러운 이름으로 정리합니다(예: `국밥_순대국밥`→순대국밥, `국밥_돼지머리`→돼지머리국밥).

### 표준 1인분 보정 (`data/serving_overrides.csv`)
일부 음식은 소스 기준이 100g이거나 중량이 비어 1인분 칼로리가 작게 잡힙니다. 자주 쓰는 음식의
**표준 1인분(g)**을 이 파일(`name,serving_g,note`)에 적어두면 빌드 시 자동 재계산됩니다.
- 100g 기준 항목: 영양소를 `serving/100`로 환산 + 중량=serving + basis=1인분
- 예: 마라탕 100g/66kcal → **700g/462kcal**, 제육볶음 → 200g/302kcal, 후라이드치킨 → 250g/625kcal
- 음식을 더 추가하려면 CSV에 한 줄 적고 `python build_nutrition_db.py` 재실행하면 됩니다.

### DB에 없는 음식 직접 추가 (`data/food_additions.csv`)
DB에 없는 자주 쓰는 음식(파스타·보쌈·연어포케·규동·곱창·버블티 등)을 **1인분 기준 탄/단/지/칼로리**로
직접 넣습니다(`name,중량,칼로리,탄수화물,당류,지방,단백질,나트륨`; 당류·나트륨은 비워도 됨).
- 우선순위 최상이라 **잘못된 유사매칭도 교정**합니다(예: 두유→`호두유`, 고구마→`고구마맛탕`, 두부→`두부전` 오매칭을 정확한 항목으로).
- 현재 68종 등록(양식·일식·중식·디저트·음료·과일·내장구이 등). 한 줄 추가 후 빌드 재실행하면 반영.

> ⚠️ 소스별로 칼로리 기준이 다릅니다: base=1인분, 전북=1인분(중량 미상), 전국통합=100g.
> 원본 xlsx는 보존되며, 병합 CSV가 있으면 파이프라인이 그것을 우선 사용합니다(없으면 xlsx).

**칼로리 기준 통일 처리**
- 각 항목에 `basis`(1인분/100g) 명시. 출력에 `100g당 ... · 전국통합DB` 처럼 기준을 표시해 오해 방지.
- **매칭 우선순위**: 1인분 기준 음식(base·전북)을 먼저 매칭하고, 없을 때만 전국통합(100g)을 사용
  → 일상 음식은 항상 1인분 칼로리로 잡히고, 가공식품(100g)은 최후순위로만 매칭됩니다.
- 유사도 매칭 컷오프 0.8 — 음식종류 글자만 다른 오매칭 방지(예: `계란김밥` ↛ `계란덮밥`).

## 실행

```powershell
# 기본 분석
.\.venv311\Scripts\python food_ai.py --image test_images\음식.jpg

# 박스를 그린 결과 이미지 저장
.\.venv311\Scripts\python food_ai.py --image test_images\음식.jpg --save out.jpg

# JSON 출력 (서버/연동용)
.\.venv311\Scripts\python food_ai.py --image test_images\음식.jpg --json

# 양 추정을 Gemini로 (하이브리드: 분류=로컬 YOLOv3, 양추정=Gemini)
#   사전: pip install google-genai  +  $env:GEMINI_API_KEY="발급키"
.\.venv311\Scripts\python food_ai.py --image test_images\음식.jpg --quantity gemini

# 두 모델 함께(앙상블): ResNet + Gemini 결과를 모두 보여주고 평균 비율로 계산
.\.venv311\Scripts\python food_ai.py --image test_images\음식.jpg --quantity both

# 하이브리드 분류: YOLOv3 후보 → Gemini가 최종 확정 (변종 혼동 해결)
#   DB에 없는 음식이면 Gemini가 분류+양까지 담당
.\.venv311\Scripts\python food_ai.py --image test_images\음식.jpg --classify hybrid --quantity both

# Gemini 전문가 엔진: 한 사진의 여러 음식을 각각 분석(이름+양+칼로리)
#   DB에 없는 음식은 Google 검색으로 1인분 기준 자료를 찾아 칼로리 추정
.\.venv311\Scripts\python food_ai.py --image test_images\음식.jpg --engine gemini

# 런처(.bat) 사용
run_food_ai.bat test_images\음식.jpg --save out.jpg
```

### 주요 옵션
| 옵션 | 기본값 | 설명 |
|------|--------|------|
| `--image` | (필수) | 분석할 음식 사진 경로 |
| `--img-size` | 224 | 분류 입력 크기 (학습 크기=224에서 성능 최상) |
| `--conf` | 0.3 | 탐지 신뢰도 임계값 |
| `--iou` | 0.5 | NMS IoU 임계값 |
| `--device` | cpu | `cpu` 또는 `cuda` (GPU용 torch 설치 시) |
| `--quantity` | resnet | 양 추정 방식: `resnet`(로컬) / `gemini`(API키) / `both`(둘 다+블렌딩) |
| `--classify` | yolo | 분류 방식: `yolo`(로컬) / `hybrid`(YOLOv3 후보→Gemini 확정, DB미수록시 Gemini 개방분류) |
| `--engine` | local | `local`(로컬 모델 위주) / `gemini`(Gemini 전문가 분석: 멀티음식+칼로리+검색) |
| `--no-search` | - | gemini 엔진에서 Google 검색 그라운딩 끄기 |
| `--gemini-samples` | 1 | Gemini 양추정을 N회 샘플링해 **중앙값**으로 안정화(self-consistency). 예: 3 |
| `--abstain` | 0.5 | 분류 신뢰도가 이 값 미만이면 **'확신 낮음' + top-3 후보** 표시 |
| `--plate-cm` | - | 접시/그릇 지름(cm). 주면 **면적 기반으로 양을 더 정확히** 추정(단일 음식). Gemini의 대략적 Q보다 정밀 |
| `--gemini-model` | gemini-2.5-flash | Gemini 모델명 |

### Gemini 호출 안정화 (스로틀/재시도/키전환)
모든 Gemini 호출은 `GeminiPool`을 거치며 **환경변수**로 제어합니다:
| env | 기본 | 역할 |
|-----|:--:|------|
| `GEMINI_API_KEY` | - | 1순위 키 |
| `GEMINI_API_KEY2~4` / `GEMINI_API_KEYS`(콤마) | - | 추가 키 — 앞 키가 429면 **자동 전환** |
| `GEMINI_RPM` | 10 | 분당 요청수 상한(요청 간격을 띄워 RPM 폭주 방지) |
| `GEMINI_MAX_RETRIES` | 2 | 429 시 백오프 재시도 횟수 |

> ⚠️ 스로틀/재시도는 **분당 한도(RPM)**·일시적 429만 해결합니다. **일일 총량(RPD)**은 늘릴 수 없으며,
> 같은 프로젝트의 키 여러 개는 쿼터를 공유합니다 → 한도를 늘리려면 **다른 계정 키** 또는 **유료(결제)**.
| `--save` | - | 박스 표시 결과 이미지 저장 경로 |
| `--json` | - | JSON 형식 출력 |

### 양 추정 방식 비교
| 방식 | 장점 | 단점 |
|------|------|------|
| `resnet`(기본) | 오프라인·무료·빠름. softmax 분포로 **연속 비율%** 산출 | 그릇/거리에 다소 민감, 근거 없음 |
| `gemini` | 그릇·채움정도·각도 종합 판단, **근거(reason)와 대략 %** 제시 | API 키·네트워크·요금 필요 |
| `both` | 두 모델 결과를 **나란히 표시** + **평균 비율로 블렌딩**(서로의 편차 보완) | Gemini 키 필요(없으면 ResNet 단독으로 자동 전환) |

> 칼로리는 Q단계(25/50/75/100/125%)에 스냅하지 않고 **추정된 연속 비율**을 그대로 적용해 계산합니다.

### 분류 방식 (`--classify`)
| 방식 | 동작 |
|------|------|
| `yolo`(기본) | 로컬 YOLOv3 단독. 오프라인·무료. 세부 변종(참치/돼지 김치찌개 등)은 혼동 가능 |
| `hybrid` | **① YOLOv3 top-10 후보 + 같은 음식종류 형제메뉴로 확장 → ② Gemini가 최종 확정**. 변종 정확도↑ |

> **후보 확장**: 로컬 후보의 음식종류 접미사(예: `김밥`)를 인식해 DB의 같은 종류 메뉴(일반김밥 등)를
> 후보에 추가합니다. 덕분에 로컬 모델이 정확한 변종을 못 올려도 Gemini가 DB에 있는 이름으로 확정해
> 칼로리가 끊기지 않습니다(예: 김밥 사진이 OOD로 빠지지 않고 DB의 `김밥`으로 매칭).

**하이브리드의 DB 미수록 처리** — 사진 속 음식이 영양DB 400종에 없으면:
- Gemini가 후보에 얽매이지 않고 **자유롭게 음식명을 판단**(개방분류)
- **양 추정도 Gemini가 담당**(로컬 ResNet은 학습 범위 밖이라 신뢰도 낮음)
- 칼로리는 DB에 없어 계산 불가 → `ⓘ 영양DB 미수록` 안내와 함께 분류·양만 제공

> 예) `김치찌개` 사진을 `--classify hybrid` 로 돌리면 로컬 모델이 "참치김치찌개"로 헷갈려도
> Gemini가 삼겹살을 인식해 **"돼지고기 김치찌개"** 로 바로잡고 칼로리도 정확히 계산합니다.

### Gemini 전문가 엔진 (`--engine gemini`)
로컬 모델을 거치지 않고 **Gemini가 "음식 칼로리 분석 전문가"로서 사진을 직접 분석**합니다.
- **여러 음식 동시 분석**: 한 접시에 쌀밥+김치가 있으면 각각 따로 (이름·양·칼로리) + 합계
- **양(Q1~Q5)**: 그릇 채움 정도 기준 (낱개 세기 의존 줄임)
- **칼로리 + 탄단지**:
  - 영양DB에 있는 음식 → **DB 값(정확)**: 칼로리·탄수·단백·지방·나트륨 (`[DB]`)
  - DB에 없는 음식 → **Gemini가 칼로리 + 탄수·단백·지방까지 추정** (`[Gemini(검색추정)]`, 나트륨은 없으면 생략)
- 출력(JSON): 음식별 `{food, q, q_reason, kcal_estimate, carb_g, protein_g, fat_g}` + `total_kcal`

> 검색 그라운딩이 불필요하면 `--no-search` 로 끌 수 있습니다(속도↑, 근거 자료 없이 추정).

> ※ 단일 사진만으로 절대량 추정은 스케일 기준이 없어 부정확합니다.
> **`--plate-cm`(접시 지름)** 을 주면 픽셀→cm 스케일이 잡혀 음식 면적을 실측 → **양이 크게 정밀**해집니다.

### 기준 물체 기반 양추정 (`--plate-cm`, `portion_ref.py`)
접시/그릇 지름(cm)을 알면 픽셀→cm 환산이 가능 → 음식이 차지한 **실제 면적(cm²)** 을 재서 1인분 대비 양을 계산합니다(완전 오프라인, cv2만 사용).
- **검증**: 쌀밥 4단계 합성 이미지(25/50/75/100%)에서 **4/4 정확히 구분** (Gemini는 1/4, samples=3도 2/4)
- 단독 실행: `python portion_ref.py --image 사진.jpg --plate-cm 12 --food 쌀밥`
- 파이프라인: `--engine gemini --plate-cm 12` (단일 음식일 때 Gemini Q를 면적 실측값으로 대체)
- **음식종류별 밀도 보정**: 면적당 무게(g/cm²)를 음식 종류로 자동 결정 — 국/탕/찌개 2.6(깊음)·면 2.0·밥 1.6·구이볶음 1.3·나물무침/김치 0.9·전튀김 0.9. (`density_for`)
- **멀티음식 지원**: `--engine gemini --plate-cm N` 이면 Gemini가 음식별 **바운딩박스**를 반환하고, 각 박스 영역의 면적을 재서 **반찬별 양/칼로리**를 계산(급식판 등).
- 한계: 접시가 보여야 하고 지름 입력 필요, 음식·접시 색이 구분돼야 함. 작은 반찬은 밀도·1인분 기준 오차 여지.
> 분류는 두 경우 모두 로컬 YOLOv3로 동일하게 수행됩니다(하이브리드).

## 출력 예시

```
📷 이미지: test_images/음식.jpg

[1] 🍽 음식 : 미역오이냉국   (코드 04013023, 신뢰도 0.093) [폴백:전체분류]
    ⚖ 양   : 적음 (Q2, x0.5, 확률 0.675)
    🔥 칼로리: 38.7 kcal   (225.0 g, 기준 77.3 kcal/450.0g)
       탄수 9.9g · 단백 2.8g · 지방 0.7g · 나트륨 741.8mg
```

- **양(Q) 비율**: Q1 25% · Q2 50% · Q3 75% · Q4 100%(1인분 기준) · Q5 125%
- 탐지가 신뢰도 임계값을 못 넘으면 **이미지 전체 top-1 분류로 폴백**하여
  항상 최선의 추정값을 반환합니다(`[폴백:전체분류]` 표시).

## 정확도 / 한계 메모

1. **입력 이미지**: 모델은 AI Hub 한식 데이터셋 스타일(접시 위 단일 음식, 위에서 촬영)에서
   성능이 가장 좋습니다. 여러 음식이 섞이거나 배경이 복잡하면 신뢰도가 낮아질 수 있습니다.
2. **코드↔이름 매핑** (`data/food_code_map.csv`):
   분류 모델은 403종을 *음식 코드*로 출력하고, 영양DB는 *한글명* 400종을 사용합니다.
   둘 다 동일 AI Hub 데이터셋의 **표준 코드 순서**로 정렬돼 있어 코드 순서대로 자동 매칭했습니다.
   다만 개수 차이(403 vs 400)로 끝부분 3개 코드는 `unmapped` 입니다.
   **정밀 매핑이 필요하면** AI Hub 공식 영양정보 엑셀(코드+이름 포함)을 받아
   `food_code_map.csv`(헤더 `code,name`)를 교체하세요. 앞부분의 흔한 음식
   (쌀밥·비빔밥·볶음밥·국 등)은 정상 매핑됩니다.
3. **런타임**: 모델 원본은 torch 1.7/Python 3.7 기준이지만, 본 파이프라인은
   최신 PyTorch 2.x(CPU)에서 동작하도록 로딩 코드를 보정했습니다
   (`weights_only=False`, `thop` 프로파일 버퍼 무시 등).
```
