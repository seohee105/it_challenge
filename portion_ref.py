# -*- coding: utf-8 -*-
"""
기준 물체(접시 지름) 기반 양추정 프로토타입
=============================================
아이디어: 사진 속 '접시 지름(cm)'을 알면 픽셀→cm 스케일이 정해진다.
그러면 음식이 차지한 '실제 면적(cm²)'을 잴 수 있고, 면적×두께(밀도)로 대략적인 g을 추정한다.
→ 같은 "화면상 절반"이라도 접시가 크면 실제 양이 더 많다는 걸 반영(스케일 인식).

완전 오프라인: OpenCV/numpy만 사용 (torch·API 불필요).

[한계] 단안 사진이라 두께는 가정(면적당 밀도). 접시/음식 색 분리는 휴리스틱.
정밀 g보다 '스케일을 반영한 상대 양(면적·비율)'이 핵심 가치.
"""
import numpy as np

# 음식 종류별 '면적당 유효 무게(g/cm²)' — 국물은 깊어서 높고, 나물·전은 얇아서 낮음.
# 유효밀도 ≈ 1인분 무게 / 1인분이 접시에서 차지하는 면적 (물리적 근사).
# ※ 합성 밥 Q세트(정답 Q 명확)로 보정: q4(1인분)→ratio 1.0이 되도록 전 밀도 ×1.41 상향
#   (구값은 체계적으로 ~40% 과소추정이었음). 보정 후 합성 4/4.
_DENSITY_BY_KEYWORD = [
    (("국", "탕", "찌개", "전골", "스프", "죽"), 3.7),   # 깊은 국물/걸쭉 → 높음
    (("면", "국수", "냉면", "라면", "파스타", "우동", "짜장", "짬뽕"), 2.8),
    (("밥", "덮밥", "볶음밥", "비빔밥", "리조또"), 2.25),
    (("구이", "볶음", "조림", "찜", "불고기", "제육", "갈비", "스테이크"), 1.85),
    (("김치", "장아찌", "젓", "절임", "무침", "나물", "겉절이", "샐러드"), 1.3),
    (("전", "부침", "튀김", "까스", "가스", "피자", "빵", "과자"), 1.3),  # 납작
]
_DENSITY_DEFAULT = 2.0

# 그릇 종류별 대표 지름(cm) — 접시 지름을 정확히 모를 때 종류로 선택(--vessel).
VESSEL_CM = {
    "밥공기": 11, "국그릇": 16, "대접": 18, "뚝배기": 15,
    "반찬접시": 13, "접시": 23, "큰접시": 27, "면기": 21, "쟁반": 30,
}


def vessel_cm(name):
    """그릇 종류명 → 대표 지름(cm). 숫자를 주면 그대로 float로."""
    if name is None:
        return None
    try:
        return float(name)
    except (TypeError, ValueError):
        return VESSEL_CM.get(str(name).strip())


def density_for(food_name):
    """음식명 키워드로 면적당 유효 밀도(g/cm²) 추정."""
    if food_name:
        for kws, d in _DENSITY_BY_KEYWORD:
            if any(k in food_name for k in kws):
                return d
    return _DENSITY_DEFAULT


def _imread(path):
    import cv2
    data = np.fromfile(str(path), dtype=np.uint8)
    return cv2.imdecode(data, cv2.IMREAD_COLOR) if data.size else None


def estimate_portion(image_path, plate_cm, food_name=None, nutrition=None,
                     areal_density=None, bg_thr=28, food_thr=25, region=None):
    """접시 지름(cm) 기준으로 음식 면적(cm²)·대략 g·1인분 대비 비율을 추정.
    areal_density: 면적당 무게(g/cm²). None이면 음식종류별 자동(density_for).
    region: (x0,y0,x1,y1) 픽셀 박스. 주면 그 영역 안의 음식만 계산(멀티음식 반찬별)."""
    if areal_density is None:
        areal_density = density_for(food_name)
    bgr = _imread(image_path)
    if bgr is None:
        raise FileNotFoundError(image_path)
    img = bgr.astype(int)
    H, W = bgr.shape[:2]

    # 1) 배경색(네 모서리) → 배경이 아닌 영역(접시+음식) 마스크
    c = 12
    corners = np.concatenate([bgr[:c, :c].reshape(-1, 3), bgr[:c, -c:].reshape(-1, 3),
                              bgr[-c:, :c].reshape(-1, 3), bgr[-c:, -c:].reshape(-1, 3)])
    bg = np.median(corners, axis=0)
    dist_bg = np.linalg.norm(img - bg, axis=2)
    notbg = dist_bg > bg_thr
    ys, xs = np.where(notbg)
    if len(xs) < 200:
        return None

    # 2) 접시 지름(px) = 접시+음식 영역의 최대 폭 → cm/px 스케일
    plate_diam_px = max(xs.max() - xs.min(), ys.max() - ys.min())
    cm_per_px = plate_cm / plate_diam_px

    # 3) 접시 타원 마스크(모서리 배경 제외) + 접시 색(접시 영역 중앙값)
    x0, x1, y0, y1 = xs.min(), xs.max(), ys.min(), ys.max()
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    ax, by = max(1, (x1 - x0) / 2), max(1, (y1 - y0) / 2)
    Y, X = np.ogrid[:H, :W]
    plate_ellipse = ((X - cx) ** 2 / ax ** 2 + (Y - cy) ** 2 / by ** 2) <= 1.0
    plate_color = np.median(bgr[notbg], axis=0)  # 접시 대표색(밥은 배경과 비슷해 notbg에서 빠짐 → notbg≈접시)

    # 4) 음식 = 접시 타원 안쪽에서 접시색과 충분히 다른 픽셀(중앙의 밥/반찬)
    dist_plate = np.linalg.norm(img - plate_color, axis=2)
    food = plate_ellipse & (dist_plate > food_thr)
    if region is not None:  # 멀티음식: 특정 박스 영역만
        rx0, ry0, rx1, ry1 = [int(v) for v in region]
        box_mask = np.zeros((H, W), dtype=bool)
        box_mask[max(0, ry0):min(H, ry1), max(0, rx0):min(W, rx1)] = True
        food = food & box_mask
    food_px = int(food.sum())
    plate_px = int(plate_ellipse.sum())
    food_area_cm2 = food_px * cm_per_px ** 2
    grams = food_area_cm2 * areal_density

    out = {
        "plate_cm": plate_cm, "cm_per_px": round(cm_per_px, 4),
        "food_area_cm2": round(food_area_cm2, 1),
        "areal_density": areal_density,
        "grams_est": round(grams, 1),
        "coverage_%": round(food_px / max(1, plate_px) * 100, 1),
    }
    # 5) DB 1인분과 비교 → 비율·칼로리
    if nutrition is not None and food_name:
        key = nutrition.match(food_name)
        if key:
            info = nutrition.db[key]
            serving = float(info.get("중량") or 0)
            kcal_serv = float(info.get("칼로리") or 0)
            out["matched"] = key
            if serving > 0:
                ratio = grams / serving
                out["serving_g"] = serving
                out["ratio"] = round(ratio, 2)
                out["kcal_est"] = round(kcal_serv * ratio, 1)
    return out


if __name__ == "__main__":
    import argparse, json, sys, food_ai
    try:
        sys.stdout.reconfigure(encoding="utf-8")
    except Exception:
        pass
    ap = argparse.ArgumentParser(description="기준 물체(접시) 기반 양추정")
    ap.add_argument("--image", required=True)
    ap.add_argument("--plate-cm", type=float, default=None, help="접시 지름(cm)")
    ap.add_argument("--vessel", default=None,
                    help="접시 지름 대신 그릇 종류: " + "/".join(VESSEL_CM) + " (또는 숫자 cm)")
    ap.add_argument("--food", help="음식명(DB 1인분 대비 비율·칼로리 계산용)")
    ap.add_argument("--density", type=float, default=None, help="면적당 무게 g/cm²(기본: 음식종류별 자동)")
    args = ap.parse_args()
    plate_cm = args.plate_cm or vessel_cm(args.vessel)
    if plate_cm is None:
        ap.error("--plate-cm(지름 cm) 또는 --vessel(그릇 종류) 중 하나가 필요합니다.")
    nut = food_ai.NutritionDB() if args.food else None
    res = estimate_portion(args.image, plate_cm, args.food, nut, areal_density=args.density)
    print(json.dumps(res, ensure_ascii=False, indent=2))
