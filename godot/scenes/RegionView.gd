class_name RegionView
extends Control

## Zona di uno spazio sagomata sui contorni della mappa. Il Control copre l'intera mappa
## ma reagisce (clic/drag-and-drop) solo dentro il poligono, grazie a `_has_point()`.
## Disegna l'evidenziazione lungo il contorno e tinge il territorio col colore del controllante.
## I pezzi e i marcatori sono impilati sull'`anchor`.

signal space_clicked(space_id: String)
signal piece_dropped(from_id: String, to_id: String, faction: String, type: String)

var space_id: String
var space_def: SpaceDef
var _poly_norm: PackedVector2Array = PackedVector2Array()
var _anchor_norm := Vector2(0.5, 0.5)
var _cbox := Vector2(-1, -1)
var _sbox := Vector2(-1, -1)
var _circle := Vector3(-1, -1, -1)   # (cx, cy, r) normalizzati; r in unità di larghezza
var _bounds_w := 0.1                  # larghezza zona (normalizzata) per impilare i pezzi
var _highlight := false
var _control := ""
var _mask_tex: Texture2D = null
var _mask_rect_norm := Rect2()

var _stack: VBoxContainer
var _ctrl_tr: TextureRect
var _sup_tr: TextureRect
var _pieces: Array = []   # token dei pezzi (posizionati a griglia)


func setup(sd: SpaceDef, poly: Array, anchor: Vector2, cbox := Vector2(-1, -1),
		sbox := Vector2(-1, -1), circle := Vector3(-1, -1, -1)) -> void:
	space_id = sd.id
	space_def = sd
	_anchor_norm = anchor
	_cbox = cbox
	_sbox = sbox
	_circle = circle
	for p in poly:
		_poly_norm.append(Vector2(p[0], p[1]))
	# Larghezza normalizzata della zona (per distribuire i pezzi entro lo spazio).
	if _circle.z >= 0.0:
		_bounds_w = _circle.z * 1.7
	elif _poly_norm.size() > 0:
		var minx := 1.0
		var maxx := 0.0
		for p in _poly_norm:
			minx = minf(minx, p.x)
			maxx = maxf(maxx, p.x)
		_bounds_w = maxf(0.05, (maxx - minx) * 0.8)
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = sd.name

	# Contenitore pezzi/marcatori (posizionato sull'anchor in _relayout)
	_stack = VBoxContainer.new()
	_stack.add_theme_constant_override("separation", 0)
	_stack.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_stack)

	# Marcatori Controllo/Supporto nelle caselle stampate
	_ctrl_tr = _make_marker_rect()
	_sup_tr = _make_marker_rect()


func _make_marker_rect() -> TextureRect:
	var tr := TextureRect.new()
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = Vector2(30, 30)
	tr.size = Vector2(30, 30)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(tr)
	return tr


func _scaled_poly() -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in _poly_norm:
		out.append(Vector2(p.x * size.x, p.y * size.y))
	return out


# Definisce la regione cliccabile: dentro il cerchio (città/EC) o il poligono (province).
func _has_point(point: Vector2) -> bool:
	if _circle.z >= 0.0:
		var c := Vector2(_circle.x * size.x, _circle.y * size.y)
		return point.distance_to(c) <= _circle.z * size.x
	return Geometry2D.is_point_in_polygon(point, _scaled_poly())


const PSZ := 23.0      # dimensione pezzo
const STEP := 15.0     # passo griglia base (< PSZ -> sovrapposizione)
const MIN_STEP := 8.0  # passo minimo (massima sovrapposizione quando è affollato)


func relayout() -> void:
	var a := Vector2(_anchor_norm.x * size.x, _anchor_norm.y * size.y)
	# Pezzi a GRIGLIA centrata sull'anchor; il passo si stringe (più sovrapposizione)
	# quanti più pezzi ci sono, così restano dentro lo spazio/cerchio.
	var n := _pieces.size()
	var grid_top := a.y
	if n > 0:
		# Larghezza/altezza utili della zona (per i cerchi ~ diametro).
		var aw := maxf(PSZ, _bounds_w * size.x)
		var ah: float = aw if _circle.z >= 0.0 else aw * 1.6
		var cols := clampi(int(round(sqrt(float(n)))), 1, n)
		var rows := int(ceil(float(n) / float(cols)))
		# Passi che fanno stare la griglia nella zona (con sovrapposizione se serve).
		var stepx := STEP
		if cols > 1:
			stepx = clampf((aw - PSZ) / float(cols - 1), MIN_STEP, STEP)
		var stepy := STEP
		if rows > 1:
			stepy = clampf((ah - PSZ) / float(rows - 1), MIN_STEP, STEP)
		var total_h := (rows - 1) * stepy + PSZ
		var origin_y := a.y - total_h * 0.5
		grid_top = origin_y
		for i in range(n):
			var col := i % cols
			var row := i / cols
			# ultima riga (eventualmente incompleta) centrata
			var in_row := cols if row < rows - 1 else (n - row * cols)
			var row_w := (in_row - 1) * stepx + PSZ
			var rx := a.x - row_w * 0.5 + col * stepx
			_pieces[i].size = Vector2(PSZ, PSZ)
			_pieces[i].position = Vector2(rx, origin_y + row * stepy)
	# Terrore/Sabotaggio appena sopra la griglia.
	_stack.reset_size()
	_stack.position = Vector2(a.x - _stack.size.x * 0.5, grid_top - 16.0)
	# Marcatori Controllo/Supporto nelle caselle.
	# Dimensione native Vassal: ~94×92 px su mappa 3829×3000 → ~3.1% larghezza
	# rispettiamo il rapporto sulla mappa ABB renderizzata.
	var mk_w: float = size.x * 0.031 if GameRegistry.game_id == "all_bridges_burning" else size.x * 0.028
	var mk_h: float = mk_w * 0.97  # rapporto Vassal 94×92
	if _ctrl_tr != null:
		_ctrl_tr.size = Vector2(mk_w, mk_h)
		_ctrl_tr.custom_minimum_size = _ctrl_tr.size
		var cp := _cbox if _cbox.x >= 0 else Vector2(_anchor_norm.x - 0.012, _anchor_norm.y - 0.03)
		_ctrl_tr.position = Vector2(cp.x * size.x, cp.y * size.y) - _ctrl_tr.size * 0.5
	if _sup_tr != null:
		_sup_tr.size = Vector2(mk_w, mk_h)
		_sup_tr.custom_minimum_size = _sup_tr.size
		var sp := _sbox if _sbox.x >= 0 else Vector2(_anchor_norm.x + 0.012, _anchor_norm.y - 0.03)
		_sup_tr.position = Vector2(sp.x * size.x, sp.y * size.y) - _sup_tr.size * 0.5
	queue_redraw()


func refresh(state: GameState) -> void:
	var st: SpaceState = state.space_state(space_id)
	_control = st.control
	for c in _stack.get_children():
		c.queue_free()

	# Controllo/Supporto nelle rispettive caselle (cbox/sbox da Vassal).
	_ctrl_tr.texture = CLAssets.control(st.control) if st.control != "" and st.control != "russians" and st.control != "germans" else null
	if space_def.has_population() and st.support != 0:
		_sup_tr.texture = CLAssets.support(st.support)
	else:
		_sup_tr.texture = null

	# Terrore/Sabotaggio restano vicino allo spazio (con i pezzi)
	var mrow := HBoxContainer.new()
	mrow.add_theme_constant_override("separation", 1)
	mrow.mouse_filter = Control.MOUSE_FILTER_PASS
	_stack.add_child(mrow)
	for i in range(st.marker("terror")):
		_add_marker(mrow, CLAssets.terror())
	if st.marker("sabotage") > 0:
		_add_marker(mrow, CLAssets.sabotage())

	# Pezzi (sprite trascinabili) - posizionati a griglia centrata in relayout.
	for p in _pieces:
		p.queue_free()
	_pieces = []
	# Itera sulle fazioni del gioco attivo (no più hardcoded a Cuba Libre).
	for f in GameController.game_def.factions:
		var fid: String = f.id
		for g in _piece_groups(st, fid):
			for k in range(g.count):
				var tok := PieceToken.new()
				tok.setup(space_id, fid, g.type, g.state, "%s %s" % [fid, g.type])
				add_child(tok)
				_pieces.append(tok)
		for k in range(st.cash_for(fid)):
			var cm := TextureRect.new()
			cm.texture = CLAssets.cash()
			cm.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			cm.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			cm.mouse_filter = Control.MOUSE_FILTER_IGNORE
			add_child(cm)
			_pieces.append(cm)

	call_deferred("relayout")


func _add_marker(parent: Node, t: Texture2D) -> void:
	if t == null:
		return
	var tr := TextureRect.new()
	tr.texture = t
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.custom_minimum_size = Vector2(15, 15)
	tr.size = Vector2(15, 15)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(tr)


func _piece_groups(st: SpaceState, fid: String) -> Array:
	var groups: Array = []
	# (piece_type_id, optional_state). I tipi vengono dal GameDef del gioco
	# attivo; aggiungiamo gli "stati" noti per quei tipi che li usano
	# (guerrilla/cell con underground/active, casino con open/closed).
	for pt in GameController.game_def.piece_types:
		var ptid: String = pt.id
		var states: Array = []
		match ptid:
			"guerrilla":
				states = ["underground", "active"]
			"cell":
				states = ["underground", "active"]
			"casino":
				states = ["open", "closed"]
			_:
				states = [""]
		for s in states:
			var n := st.count(fid, ptid, s if s != "" else null)
			if n > 0:
				groups.append({"type": ptid, "state": s, "count": n})
	return groups


## Centro dello spazio in coordinate locali della mappa (cerchio per le città, anchor per le province).
func center_point() -> Vector2:
	if _circle.z >= 0.0:
		return Vector2(_circle.x * size.x, _circle.y * size.y)
	return Vector2(_anchor_norm.x * size.x, _anchor_norm.y * size.y)


## Mask Vassal pixel-perfect: usata come tint del Controllo invece del fill poligono.
func set_mask(tex: Texture2D, rect_norm: Rect2) -> void:
	_mask_tex = tex
	_mask_rect_norm = rect_norm
	queue_redraw()


func set_highlight(on: bool) -> void:
	_highlight = on
	queue_redraw()


var _flash := 0.0
var _flash_color := Color(1, 1, 0)


## Lampeggio di evidenziazione (lo spazio è cambiato).
func flash(col := Color(1, 0.9, 0.2)) -> void:
	_flash_color = col
	var tw := create_tween()
	tw.tween_method(_set_flash, 1.0, 0.0, 0.85)


func _set_flash(v: float) -> void:
	_flash = v
	queue_redraw()


func _draw() -> void:
	var outline := Color("f1c40f") if _highlight else Color(1, 1, 1, 0.35)
	var width := 3.0 if _highlight else 1.0
	# Città/EC: cerchio
	if _circle.z >= 0.0:
		var c := Vector2(_circle.x * size.x, _circle.y * size.y)
		var r := _circle.z * size.x
		if _control != "":
			var cc := GameController.faction_color(_control); cc.a = 0.22
			draw_circle(c, r, cc)
		if _flash > 0.0:
			var fc := _flash_color; fc.a = _flash * 0.55
			draw_circle(c, r, fc)
		draw_arc(c, r, 0, TAU, 48, outline, width + _flash * 4.0)
		return
	# Province: poligono
	var poly := _scaled_poly()
	if poly.size() < 3:
		return
	# Tint del Controllo: preferisci la mask Vassal (pixel-perfect) se disponibile.
	if _control != "":
		var col := GameController.faction_color(_control)
		col.a = 0.22
		if _mask_tex != null and _mask_rect_norm.size != Vector2.ZERO:
			var dst := Rect2(
				_mask_rect_norm.position * size,
				_mask_rect_norm.size * size,
			)
			draw_texture_rect(_mask_tex, dst, false, col)
		else:
			draw_colored_polygon(poly, col)
	if _flash > 0.0:
		var fc2 := _flash_color; fc2.a = _flash * 0.45
		draw_colored_polygon(poly, fc2)
	var line := poly + PackedVector2Array([poly[0]])
	draw_polyline(line, outline, width + _flash * 4.0)
	_draw_abb_markers()


## Disegna i marker Moderates (Personality, News) sopra l'anchor della regione.
## Controllo/Supporto sono renderizzati come TextureRect figli (cbox/sbox).
func _draw_abb_markers() -> void:
	if GameRegistry.game_id != "all_bridges_burning":
		return
	var s: GameState = GameController.state
	if s == null or not s.spaces.has(space_id):
		return
	var st: SpaceState = s.space_state(space_id)
	var ax := _anchor_norm.x * size.x
	var ay := _anchor_norm.y * size.y
	var sz := size.x * 0.022
	var offset := sz * 1.15
	if st.marker("personality") > 0:
		var pt := CLAssets.personality()
		if pt != null:
			draw_texture_rect(pt, Rect2(Vector2(ax - sz * 0.5, ay - sz * 1.8), Vector2(sz, sz)), false)
	if st.marker("news") > 0:
		var nt := CLAssets.news()
		if nt != null:
			draw_texture_rect(nt, Rect2(Vector2(ax - sz * 0.5 + offset, ay - sz * 1.8), Vector2(sz, sz)), false)
	# Capability markers su mappa (Jaeger/Commander).
	var col := 0
	for cap_key in ["jaeger_senate", "commander_reds"]:
		if st.marker(cap_key) > 0:
			var ct := CLAssets.abb_cap(cap_key)
			if ct != null:
				draw_texture_rect(ct,
					Rect2(Vector2(ax - sz * 0.5 + col * offset, ay + sz * 0.8),
						Vector2(sz, sz)), false)
				col += 1


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		emit_signal("space_clicked", space_id)


func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
	return typeof(data) == TYPE_DICTIONARY and data.get("kind", "") == "piece"


func _drop_data(_pos: Vector2, data: Variant) -> void:
	emit_signal("piece_dropped", data["from"], space_id, data["faction"], data["type"])
