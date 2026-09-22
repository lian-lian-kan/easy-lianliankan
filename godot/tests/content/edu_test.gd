extends SceneTree

# 知识配对：科目牌组完整性、配对规则、发牌变脸、难度分层与每日轮换。

const EDU = preload("res://scripts/content/edu_decks.gd")
const SM = preload("res://scripts/modes/special_modes.gd")
const PATHFINDER = preload("res://scripts/board/board_pathfinder.gd")
const ENGINE = preload("res://scripts/board/board_engine.gd")

var failures := 0

func check(value: bool, message: String) -> void:
	if value:
		print("  ok - %s" % message)
		return
	failures += 1
	push_error("FAIL - %s" % message)

func _init() -> void:
	print("== edu_test")

	# --- decks: 30 whole concepts, even face count, no empty faces
	for subject in EDU.SUBJECT_ORDER:
		var faces: Array = EDU.faces_for(subject)
		check(faces.size() == 60, str(subject) + " deck carries 30 concepts (60 faces)")
		var empty_ok := true
		for face in faces:
			if str(face).strip_edges() == "":
				empty_ok = false
		check(empty_ok, str(subject) + " faces are all non-empty")
	check(EDU.has_subject("hanzi") and EDU.has_subject("english") and EDU.has_subject("math"), "all three subjects registered")
	check(not EDU.has_subject("geography"), "unknown subjects rejected")
	check(EDU.face_text(EDU.faces_for("hanzi"), 1) == "山", "face_text reads prompt faces")
	check(EDU.face_text(EDU.faces_for("hanzi"), 2) == "shān", "face_text reads answer faces")
	check(EDU.face_text([], 7) == "7", "face_text falls back to the number")

	# --- pairing rule: prompt (odd) matches its answer (even), never itself
	check(EDU.values_match(1, 2), "concept 1 prompt matches answer")
	check(EDU.values_match(2, 1), "matching is symmetric")
	check(not EDU.values_match(1, 1), "identical faces never match")
	check(not EDU.values_match(1, 4), "different concepts never match")
	check(not EDU.values_match(3, 2), "cross-concept answers stay apart")
	check(not EDU.values_match(0, 2), "empty cells never match")
	check(PATHFINDER.values_match("edu", 1, 2), "pathfinder routes the edu rule")
	check(not PATHFINDER.values_match("edu", 1, 1), "pathfinder edu rule rejects twins")
	check(PATHFINDER.values_match("", 5, 5), "classic rule untouched")

	# --- apply_edu_faces: every concept splits into exactly prompt+answer
	var board = ENGINE.create_board(6, 6, 18)
	ENGINE.apply_edu_faces(board)
	var face_count := {}
	for row in board:
		for v in row:
			if int(v) > 0:
				face_count[int(v)] = int(face_count.get(int(v), 0)) + 1
	var split_ok := true
	for concept in range(1, 19):
		var prompt = int(face_count.get(concept * 2 - 1, 0))
		var answer = int(face_count.get(concept * 2, 0))
		if prompt != 1 or answer != 1:
			split_ok = false
	check(split_ok, "18-concept deal gives every concept one prompt and one answer")
	check(PATHFINDER.find_any_hint(board, null, "", "edu").size() > 0, "dealt edu board has a connectable hint")

	# --- build_edu_level: tiers, pair count == half the tiles, daily subject
	var configs = SM.normalize_configs(null)
	check(configs.has("edu"), "edu config registered")
	var early = SM.build_edu_level(configs["edu"], 1)
	var mid = SM.build_edu_level(configs["edu"], 6)
	var late = SM.build_edu_level(configs["edu"], 12)
	check(int(early["rows"]) * int(early["cols"]) == 36, "tier 1 board is 6x6")
	check(int(mid["rows"]) * int(mid["cols"]) == 48, "tier 2 board is 8x6")
	check(int(late["rows"]) * int(late["cols"]) == 60, "tier 3 board is 10x6")
	check(int(early["kinds"]) == 18 and int(late["kinds"]) == 30, "kinds equal the pair count")
	check(int(early["time_limit"]) >= 150, "edu clock is generous")
	check(EDU.has_subject(early["subject"]), "level carries a real subject")

	# --- daily rotation: same day -> same subject, next day may differ
	var day_a = {"year": 2026, "month": 9, "day": 17}
	var day_b = {"year": 2026, "month": 9, "day": 18}
	check(EDU.subject_for_date(day_a) == EDU.subject_for_date(day_a), "rotation is deterministic within a day")
	var seen := {EDU.subject_for_date(day_a): true, EDU.subject_for_date(day_b): true}
	var span_ok := true
	for offset in range(3):
		seen[EDU.subject_for_date({"year": 2026, "month": 9, "day": 21 + offset})] = true
	check(seen.size() >= 2, "subjects rotate across days")

	if failures == 0:
		print("edu_test: ALL PASSED")
		quit(0)
	else:
		print("edu_test: %d FAILURES" % failures)
		quit(1)
