extends Reference

# 关卡工坊 (level workshop): UGC board editor + share codes. Pure grid math —
# encode/decode/validate — plus the custom-session level assembly; the modal
# UI lives in ui_panels.gd. Share code format: "LK1" + base64( rows byte,
# cols byte, kinds byte, cell nibbles (low nibble first, two per byte),
# checksum byte = sum of payload bytes mod 251 ).

const CODE_PREFIX = "LK1"
const CHECKSUM_MOD = 251
const MIN_DIM = 4
const MAX_ROWS = 10
const MAX_COLS = 10
const MAX_KINDS = 12
const MIN_TILES = 4

static func blank_grid(rows: int, cols: int) -> Array:
	var grid = []
	for r in range(rows):
		var row = []
		for c in range(cols):
			row.append(0)
		grid.append(row)
	return grid

# Fresh editor scratchpad: a small blank canvas with the first kind armed.
static func default_state() -> Dictionary:
	return {"rows": 6, "cols": 6, "kinds": 4, "grid": blank_grid(6, 6), "active_kind": 1}

static func dims_ok(rows: int, cols: int, kinds: int) -> bool:
	return rows >= MIN_DIM and rows <= MAX_ROWS and cols >= MIN_DIM and cols <= MAX_COLS \
		and kinds >= 2 and kinds <= MAX_KINDS and (rows * cols) % 2 == 0

# Layout validation for play/share: legal values, per-kind parity, a healthy
# tile count and at least one connectable hint on the classic rules.
static func validate_layout(grid, kinds: int) -> Dictionary:
	if grid.size() == 0:
		return {"ok": false, "reason": "棋盘是空的"}
	var rows = grid.size()
	var cols = grid[0].size()
	if not dims_ok(rows, cols, kinds):
		return {"ok": false, "reason": "棋盘尺寸不合法"}
	var counts = {}
	var total = 0
	for r in range(rows):
		for c in range(cols):
			var v = int(grid[r][c])
			if v < 0 or v > kinds:
				return {"ok": false, "reason": "有图案编号超出范围"}
			if v == 0:
				continue
			counts[v] = int(counts.get(v, 0)) + 1
			total += 1
	if total < MIN_TILES:
		return {"ok": false, "reason": "至少要放 %d 块牌" % MIN_TILES}
	if total % 2 != 0:
		return {"ok": false, "reason": "牌数必须是偶数"}
	for kind in counts:
		if int(counts[kind]) % 2 != 0:
			return {"ok": false, "reason": "每种图案都要成对（编号 %d 是奇数块）" % int(kind)}
	var pathfinder = PATHFINDER
	if pathfinder.find_any_hint(grid).empty():
		return {"ok": false, "reason": "至少要有一对能连起来的牌"}
	return {"ok": true, "reason": ""}

const PATHFINDER = preload("res://scripts/board/board_pathfinder.gd")

# --- Share code codec ---

static func encode(grid, kinds: int) -> String:
	var rows = grid.size()
	var cols = grid[0].size()
	var payload = PoolByteArray([rows, cols, kinds])
	var nibble_high = true
	var current = 0
	for r in range(rows):
		for c in range(cols):
			var v = int(grid[r][c]) & 0x0F
			if nibble_high:
				current = v
				nibble_high = false
			else:
				payload.append((current | (v << 4)) & 0xFF)
				nibble_high = true
	if not nibble_high:
		payload.append(current & 0xFF)
	var checksum = 0
	for i in range(payload.size()):
		checksum = (checksum + int(payload[i])) % CHECKSUM_MOD
	payload.append(checksum)
	return CODE_PREFIX + Marshalls.raw_to_base64(payload)

# Decode + full validation; returns {ok, grid, kinds} or {ok:false, reason}.
static func decode(code) -> Dictionary:
	var text := str(code).strip_edges().replace(" ", "")
	if text.begins_with(str(CODE_PREFIX).to_lower()):
		text = CODE_PREFIX + text.substr(CODE_PREFIX.length())
	if not text.begins_with(CODE_PREFIX):
		return {"ok": false, "reason": "分享码要以 LK1 开头"}
	var raw = Marshalls.base64_to_raw(text.substr(CODE_PREFIX.length()))
	if raw.size() < 5:
		return {"ok": false, "reason": "分享码不完整"}
	var rows = int(raw[0])
	var cols = int(raw[1])
	var kinds = int(raw[2])
	var cell_bytes = raw.size() - 4
	if cell_bytes * 2 < rows * cols:
		return {"ok": false, "reason": "分享码长度对不上棋盘"}
	var checksum = 0
	for i in range(raw.size() - 1):
		checksum = (checksum + int(raw[i])) % CHECKSUM_MOD
	if checksum != int(raw[raw.size() - 1]):
		return {"ok": false, "reason": "分享码校验失败，检查有没有抄错"}
	if not dims_ok(rows, cols, kinds):
		return {"ok": false, "reason": "分享码里的棋盘尺寸不合法"}
	var grid = blank_grid(rows, cols)
	for r in range(rows):
		for c in range(cols):
			var cell_index = r * cols + c
			var byte = int(raw[3 + int(cell_index / 2)])
			var v = byte % 16 if cell_index % 2 == 0 else int(byte / 16)
			if v > kinds:
				return {"ok": false, "reason": "分享码里有超出图案范围的格子"}
			grid[r][c] = v
	var verdict = validate_layout(grid, kinds)
	if not verdict["ok"]:
		return {"ok": false, "reason": "分享码里的关卡不可玩：" + str(verdict["reason"])}
	return {"ok": true, "reason": "", "grid": grid, "kinds": kinds, "rows": rows, "cols": cols}

# --- Custom session assembly ---

# A validated grid becomes a virtual level; the clock scales with the board
# so even a maximal custom board stays comfortable.
static func build_custom_level(grid, kinds: int) -> Dictionary:
	var rows = grid.size()
	var cols = grid[0].size()
	var tiles = 0
	for r in range(rows):
		for c in range(cols):
			if int(grid[r][c]) != 0:
				tiles += 1
	return {
		"id": 1,
		"name": "自定义关卡",
		"mode": "custom",
		"rows": rows,
		"cols": cols,
		"kinds": kinds,
		"time_limit": 60 + tiles * 2,
		"custom_grid": grid.duplicate(true)
	}
