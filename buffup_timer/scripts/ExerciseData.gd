extends Node
## 운동 카테고리 & MET 데이터셋
## 칼로리(kcal) = met * 체중(kg) * (운동시간(분) / 60)

const CATEGORIES: Array[Dictionary] = [
	{
		"id": "hometraining",
		"name": "홈트",
		"met": 5.0,
		"is_custom": false,
	},
	{
		"id": "outdoor_cardio",
		"name": "야외 유산소",
		"met": 6.0,
		"is_custom": false,
	},
	{
		"id": "gym",
		"name": "헬스",
		"met": 5.0,
		"is_custom": false,
	},
	{
		"id": "yoga_pilates",
		"name": "요가/필라테스",
		"met": 3.0,
		"is_custom": false,
	},
	{
		"id": "pt",
		"name": "PT",
		"met": 6.0,
		"is_custom": false,
	},
	{
		"id": "sports",
		"name": "스포츠",
		"met": 7.0,
		"is_custom": false,
	},
	{
		"id": "other_cardio",
		"name": "기타 유산소 운동",
		"met": 6.0,
		"is_custom": true,
		"examples": "예: 줄넘기, 수영, 계단오르기, 에어로빅, 사이클",
	},
	{
		"id": "other_strength",
		"name": "기타 근력 운동",
		"met": 5.0,
		"is_custom": true,
		"examples": "예: 맨몸운동, 밴드 트레이닝, 크로스핏 근력",
	},
	{
		"id": "other_functional",
		"name": "기타 기능성 운동",
		"met": 5.5,
		"is_custom": true,
		"examples": "예: 코어운동, 밸런스 트레이닝, 가동성 운동",
	},
	{
		"id": "other_hiit",
		"name": "기타 인터벌(HIIT/고강도) 운동",
		"met": 8.0,
		"is_custom": true,
		"examples": "예: 타바타, 버피, 서킷 HIIT",
	},
]


func get_category(id: String) -> Dictionary:
	for c in CATEGORIES:
		if c.id == id:
			return c
	return {}
