class_name TrackOverlay
extends Control

## Disegna i segnalini sui tracciati e nelle caselle, usando le coordinate ESATTE estratte dal
## modulo Vassal (board_layout.json): celle del tracciato perimetrale 0-49, caselle Available
## Forces, US Alliance, Eligible/Ineligible. Cilindri Risorse, Aiuti, marcatori di vittoria,
## Alleanza USA, pezzi disponibili e idoneità delle Fazioni.

const MK := 26.0       # dimensione segnalino su tracciato
const STACK := 20.0    # scostamento per segnalini sulla stessa cella

var _track: Dictionary = {}    # "0".."49" -> [x,y] normalizzati
var _polarization_track: Dictionary = {}  # ABB: slot 0..10 del tracciato Polarization
var _sop: Dictionary = {}      # ABB: posizione cilindri Sequence of Play
var _cell_slots: Dictionary = {}  # ABB: "<fid>_cell" -> [[x,y],...] slot Vassal
var _box: Dictionary = {}      # nome -> [x0,y0,x1,y1] normalizzati
var _circles: Dictionary = {}  # fazione -> [[x,y],...] centri dei cerchietti basi/casinò (Vassal)
var _loose: Dictionary = {}    # fazione -> tipo -> [x0,y0,x1,y1] area dei pezzi sciolti
var _disp: Dictionary = {}     # chiave segnalino -> valore mostrato (float, animato)
var _target: Dictionary = {}   # chiave segnalino -> valore obiettivo (int)


func _ready() -> void:
	var f := FileAccess.open(GameRegistry.data_path("board_layout.json"), FileAccess.READ)
	if f != null:
		var d = JSON.parse_string(f.get_as_text())
		if d is Dictionary:
			_track = d.get("track", {})
			_polarization_track = d.get("polarization_track", {})
			_sop = d.get("sop", {})
			_cell_slots = d.get("cell_slots", {})
			_box = d.get("box", {})
			_circles = d.get("avail_circles", {})
			_loose = d.get("avail_loose", {})


func _cell(value: int) -> Vector2:
	var v := clampi(value, 0, 49)
	var p: Array = _track.get(str(v), [0.5, 0.5])
	return Vector2(p[0] * size.x, p[1] * size.y)


## Posizione sullo speciale Polarization Track (0..10) per ABB.
func _polarization_cell(value: int) -> Vector2:
	var v := clampi(value, 0, 10)
	var p: Array = _polarization_track.get(str(v), [0.5, 0.5])
	return Vector2(p[0] * size.x, p[1] * size.y)


func _box_rect(name: String) -> Rect2:
	var b: Array = _box.get(name, [0, 0, 0, 0])
	return Rect2(b[0] * size.x, b[1] * size.y, (b[2] - b[0]) * size.x, (b[3] - b[1]) * size.y)


func _draw() -> void:
	var s: GameState = GameController.state
	if s == null or _track.is_empty():
		return
	# Chip per gioco attivo: Cuba ha aid/US Alliance/vittoria; ABB ha
	# polarization/vassalage/town pop/networks ecc. Selezione su game_id.
	var chips: Array = _abb_chips(s) if GameRegistry.game_id == "all_bridges_burning" else _cuba_chips(s)
	var counts := {}
	for ch in chips:
		var key: String = ch[0]
		var v := clampi(int(ch[1]), 0, 49)
		_target[key] = v
		if not _disp.has(key):
			_disp[key] = float(v)
		var idx := int(counts.get(v, 0))
		counts[v] = idx + 1
		# Polarization su tracciato dedicato (0..10) per ABB.
		var c: Vector2
		if key == "abb_polarization" and not _polarization_track.is_empty():
			c = _polarization_cell(int(_disp[key]))
		else:
			c = _interp_cell(float(_disp[key]))
			if v <= 30:
				c.y += idx * STACK
			else:
				c.x -= idx * STACK
		_blit(ch[2], c)

	# Alleanza USA nella casella attiva (solo Cuba Libre).
	if GameRegistry.game_id == "cuba_libre":
		var ai := int(s.tracks.get("us_alliance", 0))
		var abox: String = ["us_alliance_firm", "us_alliance_reluctant", "us_alliance_embargoed"][ai]
		_blit(CLAssets.alliance_marker(), _box_rect(abox).get_center())

	_draw_available(s)
	if GameRegistry.game_id == "all_bridges_burning":
		_abb_draw_sop(s)
		_abb_draw_capabilities(s)
		_abb_draw_political_display(s)
		_abb_draw_prisoners(s)
	else:
		_draw_eligibility(s)
		_draw_capabilities(s)


## Chip per Cuba Libre (logica originale, isolata).
func _cuba_chips(s: GameState) -> Array:
	var mod = GameController.module
	return [
		["res_government", s.get_resources("government"), CLAssets.res_token("government")],
		["res_m26", s.get_resources("m26"), CLAssets.res_token("m26")],
		["res_directorio", s.get_resources("directorio"), CLAssets.res_token("directorio")],
		["res_syndicate", s.get_resources("syndicate"), CLAssets.res_token("syndicate")],
		["aid", int(s.tracks.get("aid", 0)), CLAssets.aid_marker()],
		["vic_support", s.total_support(), CLAssets.vic_support()],
		["vic_opp", mod.opposition_plus_bases(s) if mod else 0, CLAssets.vic_opp_bases()],
		["vic_dr", mod.dr_pop_plus_bases(s) if mod else 0, CLAssets.vic_dr()],
		["vic_casinos", mod.open_casinos(s) if mod else 0, CLAssets.vic_casinos()],
	]


## Chip per All Bridges Burning (rulebook §1.5-§1.12, §7.0).
## Tutti i marker stanno sull'edge track 0..30 in alto.
func _abb_chips(s: GameState) -> Array:
	var out: Array = []
	for fid in ["reds", "senate", "moderates", "germans"]:
		out.append(["res_%s" % fid, s.get_resources(fid), CLAssets.res_token(fid)])
	out.append(["abb_senate_town_pop", int(s.tracks.get("senate_town_pop", 0)), CLAssets.abb_senate_town_pop()])
	out.append(["abb_oppose_admins",   int(s.tracks.get("oppose_admins", 0)),   CLAssets.abb_oppose_admins()])
	out.append(["abb_cells_on_map",    int(s.tracks.get("cells_on_map", 0)),    CLAssets.abb_cells_on_map()])
	out.append(["abb_issues_networks", int(s.tracks.get("issues_networks", 0)), CLAssets.abb_networks_issues()])
	out.append(["abb_vassal_german",   int(s.tracks.get("vassalage_german", 0)), CLAssets.abb_vassalage_german()])
	out.append(["abb_vassal_russian",  int(s.tracks.get("vassalage_russian", 0)), CLAssets.abb_vassalage_russian()])
	# Polarization vive su tracciato dedicato; per ora sull'edge track.
	out.append(["abb_polarization",    int(s.tracks.get("polarization", 0)),    CLAssets.abb_polarization()])
	return out


## Posizione (schermo) interpolata tra le celle per un valore frazionario lungo il tracciato.
func _interp_cell(v: float) -> Vector2:
	var lo := clampi(int(floor(v)), 0, 49)
	var hi := clampi(lo + 1, 0, 49)
	return _cell(lo).lerp(_cell(hi), v - float(lo))


## Anima i segnalini verso il valore obiettivo (scivolano lungo il tracciato).
func _process(delta: float) -> void:
	var moving := false
	for key in _target:
		var cur: float = float(_disp.get(key, _target[key]))
		var tgt := float(_target[key])
		if abs(cur - tgt) > 0.02:
			_disp[key] = cur + (tgt - cur) * minf(1.0, delta * 7.0)
			moving = true
		else:
			_disp[key] = tgt
	if moving:
		queue_redraw()


func _blit(t: Texture2D, center: Vector2) -> void:
	if t == null:
		return
	draw_texture_rect(t, Rect2(center - Vector2(MK, MK) * 0.5, Vector2(MK, MK)), false)


# Quale "Base" sta sul tracciato a cerchietti di ogni box (le Basi/Casinò sono tonde
# e nel gioco reale si posano nei cerchietti numerati = quante ce ne sono sulla mappa).
const BASE_TRACK := {
	"government": "base", "syndicate": "casino", "m26": "base", "directorio": "base",
}


func _draw_available(s: GameState) -> void:
	var tok := size.x * 0.028
	# ABB: per ogni fazione disegna i pezzi disponibili nel box "available_<fid>".
	if GameRegistry.game_id == "all_bridges_burning":
		_abb_draw_available(s, tok)
		return
	# 1) Pezzi sciolti (cubi/guerriglie): ognuno disegnato singolarmente nell'area aperta del box.
	for fac in _loose:
		for t in _loose[fac]:
			var n := s.available(fac, t)
			if n <= 0:
				continue
			var st := "underground" if t == "guerrilla" else ""
			_fill_pieces(_rect_from(_loose[fac][t]), n, CLAssets.piece(fac, t, st), tok)
	# 2) Basi/Casinò: posate nei cerchietti, dal numero (Basi sulla mappa)+1 in su.
	#    Così il cerchietto vuoto più alto = quante Basi/Casinò ci sono sulla mappa.
	for fac in BASE_TRACK:
		var bt: String = BASE_TRACK[fac]
		var fdef: FactionDef = s.game_def.faction(fac)
		if fdef == null:
			continue
		var total := int(fdef.force_pool.get(bt, 0))
		var on_map := total - s.available(fac, bt)
		var circles: Array = _circles.get(fac, [])
		var st := "closed" if bt == "casino" else ""
		var tex := CLAssets.piece(fac, bt, st)
		var ctok := tok * 1.2
		for i in range(on_map + 1, total + 1):
			if i < 0 or i >= circles.size() or tex == null:
				continue
			var p: Array = circles[i]
			var c := Vector2(p[0] * size.x, p[1] * size.y)
			draw_texture_rect(tex, Rect2(c - Vector2(ctok, ctok) * 0.5, Vector2(ctok, ctok)), false)


func _rect_from(a: Array) -> Rect2:
	return Rect2(a[0] * size.x, a[1] * size.y, (a[2] - a[0]) * size.x, (a[3] - a[1]) * size.y)


## Distribuisce n copie del pezzo in una griglia adattiva dentro `rect` (impila in verticale
## se i pezzi disponibili sono molti, come le pedine ammucchiate nella scatola).
func _fill_pieces(rect: Rect2, n: int, tex: Texture2D, tok: float) -> void:
	if n <= 0 or tex == null:
		return
	var cols := maxi(1, int(rect.size.x / (tok * 0.9)))
	var rows := int(ceil(float(n) / float(cols)))
	var stepx := tok * 0.9
	var stepy := minf(tok * 0.9, rect.size.y / float(maxi(1, rows)))
	for i in n:
		var r := i / cols
		var c := i % cols
		var cx := rect.position.x + tok * 0.5 + c * stepx
		var cy := rect.position.y + tok * 0.5 + r * stepy
		draw_texture_rect(tex, Rect2(Vector2(cx - tok * 0.5, cy - tok * 0.5), Vector2(tok, tok)), false)


# Fazione a cui appartiene ogni Capacità Insorgente (per il colore del chip).
const CAP_FACTION := {
	"Guantánamo Bay": "m26", "El Che": "m26", "The Guerrilla Life": "m26",
	"Pact of Caracas": "directorio", "Morgan": "directorio",
	"Mafia Offensive": "syndicate", "Santo Trafficante Jr": "syndicate",
}


## Capacità Insorgenti attive: chip colorati nel box "Insurgent Capabilities" in basso.
func _draw_capabilities(s: GameState) -> void:
	var r := _box_rect("insurgent_capabilities")
	if r.size == Vector2.ZERO or s.active_capabilities.is_empty():
		return
	var font := ThemeDB.fallback_font
	var n := s.active_capabilities.size()
	# Altezza dei chip adattiva: tutti entrano sotto il titolo stampato del box.
	var top := r.position.y + r.size.y * 0.36
	var avail_h := r.size.y * 0.60
	var slot := avail_h / float(n)
	var ch := minf(20.0, slot - 3.0)
	var y := top
	for title in s.active_capabilities:
		var fac: String = CAP_FACTION.get(title, "m26")
		var chip := Rect2(r.position.x + r.size.x * 0.04, y, r.size.x * 0.92, ch)
		draw_rect(chip, GameController.faction_color(fac), true)
		draw_string(font, Vector2(chip.position.x + 8, y + ch * 0.76), String(title),
			HORIZONTAL_ALIGNMENT_LEFT, chip.size.x - 14, clampi(int(ch * 0.74), 9, 16), Color.WHITE)
		y += slot


const ELIG_SZ := 24.0


func _draw_eligibility(s: GameState) -> void:
	# I cilindri vanno: nelle caselle azione (1ª/2ª Op/Op+SA/Evento/LimOp/Pass) se la Fazione
	# ha agito su questa carta; altrimenti in Eligible/Ineligible Factions.
	var seq = GameController.seq
	var counts := {}
	for fid in ["government", "m26", "directorio", "syndicate"]:
		var key := ""
		if seq != null and seq.action_box.has(fid):
			key = String(seq.action_box[fid])
		elif int(s.eligibility.get(fid, 0)) == 0:
			key = "eligible"
		else:
			key = "ineligible"
		var r := _box_rect(key)
		if r.size == Vector2.ZERO:
			continue
		var t := CLAssets.res_token(fid)
		if t == null:
			continue
		var idx := int(counts.get(key, 0))
		counts[key] = idx + 1
		# Impilamento VERTICALE (centrato in orizzontale) nella casella/colonna.
		var pos := Vector2(r.position.x + r.size.x * 0.5 - ELIG_SZ * 0.5,
			r.position.y + 8.0 + idx * (ELIG_SZ + 4.0))
		draw_texture_rect(t, Rect2(pos, Vector2(ELIG_SZ, ELIG_SZ)), false)


## Disegna i pezzi disponibili (force_pool - on_map) nei box ABB.
func _abb_draw_available(s: GameState, tok: float) -> void:
	# (faction_id, [piece_types]) — ordini consistenti con l'apparizione storica.
	var faction_types: Array = [
		["reds", ["cell", "admin"]],
		["senate", ["cell"]],
		["moderates", ["cell", "network"]],
		["germans", ["troops"]],
		["russians", ["troops"]],
	]
	for ft in faction_types:
		var fid: String = ft[0]
		var fdef: FactionDef = s.game_def.faction(fid)
		if fdef == null:
			continue
		var box_name: String = "available_%s" % fid
		var r := _box_rect(box_name)
		if r.size == Vector2.ZERO:
			continue
		# Numero totale di pezzi disponibili per la fazione (somma sui suoi tipi).
		var available_counts: Array = []
		for pt in ft[1]:
			var ptid: String = pt
			var avail: int = s.available(fid, ptid)
			if avail > 0:
				available_counts.append({"type": ptid, "count": avail})
		if available_counts.is_empty():
			continue
		# Suddivido il box verticalmente fra i tipi di pezzo della fazione.
		var sub_h: float = r.size.y / float(max(1, available_counts.size()))
		var y: float = r.position.y
		for entry in available_counts:
			var ptid_e: String = entry["type"]
			var n_e: int = entry["count"]
			var tex: Texture2D = CLAssets.piece(fid, ptid_e, "underground" if ptid_e == "cell" else "")
			if tex == null:
				y += sub_h
				continue
			# Se Vassal fornisce slot dedicati per questo tipo, usali (un pezzo per
			# slot, partendo dal primo). Altrimenti fallback al riempimento a griglia.
			var slot_key: String = "%s_%s" % [fid, ptid_e]
			var slots: Array = _cell_slots.get(slot_key, [])
			# Admin/Network sono cerchi grandi sulla mappa stampata: bump del 35%.
			var tok_use: float = tok * 1.35 if ptid_e in ["admin", "network"] else tok
			if not slots.is_empty():
				_draw_slotted(slots, n_e, tex, tok_use)
			else:
				var sub_rect := Rect2(r.position.x, y, r.size.x, sub_h)
				_fill_pieces(sub_rect, n_e, tex, tok_use)
			y += sub_h
		# Moderati: aggiungi marker News (max 2) + Personality nei loro slot riservati,
		# se NON sono già sulla mappa.
		if fid == "moderates":
			_abb_draw_moderates_extra(s, r, tok)


## Disegna News (×2) + Personality nei 3 grandi cerchi stampati del box Moderati.
## I cerchi sono nella metà SINISTRA del box, riga centrale.
func _abb_draw_moderates_extra(s: GameState, box: Rect2, _tok: float) -> void:
	# Conta quanti marker News/Personality sono sulla mappa.
	var news_on_map := 0
	var pers_on_map := false
	for sid in s.spaces.keys():
		var st: SpaceState = s.space_state(sid)
		news_on_map += st.marker("news")
		if st.marker("personality") > 0:
			pers_on_map = true
	# Disponibili: 2 News - su mappa, 1 Personality - su mappa.
	var news_avail: int = maxi(0, 2 - news_on_map)
	var pers_avail: int = 0 if pers_on_map else 1
	# Calibrato sulla map.jpg ABB misurando i 3 grandi cerchi stampati
	# News News Personality del box Moderates Available Forces.
	var cy: float = box.position.y + box.size.y * 0.48
	var slot_size: float = box.size.x * 0.16
	var nt := CLAssets.news()
	var pt := CLAssets.personality()
	var centers_x: Array = [
		box.position.x + box.size.x * 0.20,
		box.position.x + box.size.x * 0.37,
		box.position.x + box.size.x * 0.54,
	]
	for i in range(news_avail):
		if nt != null:
			var cx: float = float(centers_x[i])
			draw_texture_rect(nt,
				Rect2(Vector2(cx - slot_size * 0.5, cy - slot_size * 0.5),
					Vector2(slot_size, slot_size)), false)
	if pers_avail > 0:
		if pt != null:
			var cx_p: float = float(centers_x[2])
			draw_texture_rect(pt,
				Rect2(Vector2(cx_p - slot_size * 0.5, cy - slot_size * 0.5),
					Vector2(slot_size, slot_size)), false)


## Disegna fino a `n` copie di `tex` posizionate sui primi `n` slot Vassal.
func _draw_slotted(slots: Array, n: int, tex: Texture2D, tok: float) -> void:
	var lim := mini(n, slots.size())
	for i in lim:
		var p: Array = slots[i]
		var cx: float = float(p[0]) * size.x
		var cy: float = float(p[1]) * size.y
		draw_texture_rect(tex, Rect2(Vector2(cx - tok * 0.5, cy - tok * 0.5),
			Vector2(tok, tok)), false)


const SOP_CYL := 22.0


## Disegna i cilindri Eligibility nella Sequence of Play (rulebook §2.3, box laterale).
## Russians non hanno cilindro (non è una "sequence faction" in ABB).
func _abb_draw_sop(s: GameState) -> void:
	if _sop.is_empty():
		return
	var cols: Dictionary = _sop.get("cols", {})
	var rows: Dictionary = _sop.get("rows", {})
	if cols.is_empty() or rows.is_empty():
		return
	var frame: Array = _sop.get("frame", [])
	var font := ThemeDB.fallback_font
	if frame.size() == 4:
		var fr := Rect2(frame[0] * size.x, frame[1] * size.y,
			(frame[2] - frame[0]) * size.x, (frame[3] - frame[1]) * size.y)
		draw_rect(fr, Color(0, 0, 0, 0.20), false, 1.5)
		# Badge "PHASE II" in alto a destra del riquadro quando attiva (post Red Revolt!).
		if int(s.tracks.get("phase", 1)) >= 2:
			var pad := 4.0
			var badge_w := 78.0
			var badge_h := 18.0
			var bx := fr.position.x + fr.size.x - badge_w - pad
			var by := fr.position.y + pad
			draw_rect(Rect2(bx, by, badge_w, badge_h), Color(0.65, 0.10, 0.10, 0.85), true)
			draw_rect(Rect2(bx, by, badge_w, badge_h), Color.BLACK, false, 1.0)
			draw_string(font, Vector2(bx + 8, by + badge_h - 4), "PHASE II",
				HORIZONTAL_ALIGNMENT_LEFT, badge_w - 12, 12, Color.WHITE)
	var seq = GameController.seq
	# Slot esatti dal Vassal estratti in board_layout.sop_slots.
	var slots: Dictionary = _sop_slots_load_once()
	for fid in ["reds", "senate", "moderates", "germans"]:
		var pos: Vector2 = _sop_slot_for(s, seq, fid, slots)
		if pos == Vector2.ZERO:
			continue
		var color: Color = GameController.faction_color(fid)
		var radius: float = SOP_CYL * 0.5
		draw_circle(pos, radius, color)
		draw_arc(pos, radius, 0, TAU, 24, Color.BLACK, 1.5)
		var lbl: String = fid.substr(0, 1).to_upper()
		draw_string(font, Vector2(pos.x - 4, pos.y + 4), lbl,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.WHITE)


var _sop_slots_cache: Dictionary = {}


func _sop_slots_load_once() -> Dictionary:
	if _sop_slots_cache.is_empty():
		var f := FileAccess.open(GameRegistry.data_path("board_layout.json"), FileAccess.READ)
		if f != null:
			var d = JSON.parse_string(f.get_as_text())
			if d is Dictionary:
				_sop_slots_cache = d.get("sop_slots", {})
	return _sop_slots_cache


## Restituisce la posizione (pixel) dove disegnare il cilindro di fid, sulla
## base di Phase + action_box + eligibility + ordine di pass/eligible.
func _sop_slot_for(s: GameState, seq, fid: String, slots: Dictionary) -> Vector2:
	var ph: int = int(s.tracks.get("phase", 1))
	# Germans hanno propri slot
	if fid == "germans":
		if ph < 2:
			# Phase I: sempre Germany Ineligible
			return _slot_pos(slots, "germany_ineligible")
		var roll: int = int(s.tracks.get("german_eligibility_roll", 0))
		if roll == 0:
			# Roll non ancora fatto: Germany Eligible (first slot row di Eligibile)
			return _slot_pos(slots, "germany_first")
		if roll <= 3:
			return _slot_pos(slots, "germany_first")
		return _slot_pos(slots, "germany_last")
	# Player factions (reds/senate/moderates)
	if seq != null and seq.action_box.has(fid):
		var k := String(seq.action_box[fid])
		if k == "pass":
			var pass_idx := _passers_index(seq, fid)
			var pass_slot := ["pass_a", "pass_b", "pass_c"][min(pass_idx, 2)]
			return _slot_pos(slots, pass_slot)
		# Agito: scegli slot in base all'azione + ordine
		var actor_idx := _actor_index(seq, fid)
		return _action_slot(k, actor_idx, slots)
	# Non ha ancora agito → Eligible 1st/2nd/3rd o Ineligible
	if int(s.eligibility.get(fid, CoinEnums.Eligibility.ELIGIBLE)) == CoinEnums.Eligibility.INELIGIBLE:
		var ineligible_slots := ["ineligible_1", "ineligible_2", "ineligible_3"]
		var idx := ["reds", "senate", "moderates"].find(fid)
		return _slot_pos(slots, ineligible_slots[max(0, idx)])
	# Eligible nella propria riga (1st/2nd/3rd basato su rank)
	var rank := _eligible_rank(s, seq, fid)
	var elig_slots := ["eligible_1st", "eligible_2nd", "eligible_3rd"]
	return _slot_pos(slots, elig_slots[clampi(rank, 0, 2)])


func _slot_pos(slots: Dictionary, key: String) -> Vector2:
	if not slots.has(key):
		return Vector2.ZERO
	var p: Array = slots[key]
	return Vector2(float(p[0]) * size.x, float(p[1]) * size.y)


## Mappa l'azione (action_box value) al slot Vassal corretto.
## actor_idx 0 = 1° player ad agire (colonna X=3107),
## actor_idx 1+ = 2°/3° player (colonna X=3315).
func _action_slot(action_key: String, actor_idx: int, slots: Dictionary) -> Vector2:
	if actor_idx == 0:
		match action_key:
			"1st_op_only", "1st_op_sa", "2nd_op_sa": return _slot_pos(slots, "cmd_3107")
			"1st_event", "2nd_limop_or_event": return _slot_pos(slots, "event_d")
			"2nd_limop": return _slot_pos(slots, "lim_cmd_d")
		return _slot_pos(slots, "cmd_3107")
	# 2°/3° player (X=3315 column, 6 slot varianti)
	match action_key:
		"2nd_limop": return _slot_pos(slots, "lim_cmd_c_top")
		"2nd_limop_or_event": return _slot_pos(slots, "event_c")
		"2nd_op_sa", "1st_op_sa": return _slot_pos(slots, "cmd_3315_mid")
		"1st_op_only": return _slot_pos(slots, "cmd_3315_top")
		"1st_event": return _slot_pos(slots, "event_c")
	return _slot_pos(slots, "cmd_3315_mid")


## Indice 0-based della fazione tra chi ha passato (usa action_box).
func _passers_index(seq, fid: String) -> int:
	if seq == null:
		return 0
	var i := 0
	for ff in seq.action_box.keys():
		if String(seq.action_box[ff]) == "pass":
			if String(ff) == fid:
				return i
			i += 1
	return i


## Indice della fazione fra gli attori (chi ha già agito, escluso pass).
func _actor_index(seq, fid: String) -> int:
	if seq == null:
		return 0
	var i := 0
	for ff in seq.action_box.keys():
		var k := String(seq.action_box[ff])
		if k != "pass":
			if String(ff) == fid:
				return i
			i += 1
	return i


## Rank della fazione nella lista di eligibili (0 = 1st, 1 = 2nd, 2 = 3rd).
func _eligible_rank(s: GameState, seq, fid: String) -> int:
	var order := ["reds", "senate", "moderates"]
	if seq != null:
		# Idea: per ABB il rank Eligible deriva da SeqRank (computed) ma noi
		# usiamo un'approssimazione: i NON-attori restano in ordine reds<senate<moderates.
		var elig := []
		for f in order:
			if not seq.action_box.has(f):
				if int(s.eligibility.get(f, CoinEnums.Eligibility.ELIGIBLE)) == CoinEnums.Eligibility.ELIGIBLE:
					elig.append(f)
		var idx := elig.find(fid)
		return idx if idx >= 0 else 0
	return order.find(fid)


## Capacità attive ABB: chip nel box "capabilities" (estratto dalla Zone Vassal).
## Default color = Reds: la maggior parte delle Capacità ABB sono Insorgenti.
## Mappa Capability ABB → fazione che la controlla (per il colore del chip).
## Cannons/Trains = Senate (rulebook §1.7).
const ABB_CAP_FACTION := {
	"Cannons": "senate",
	"Trains":  "senate",
}


func _abb_draw_capabilities(s: GameState) -> void:
	var r := _box_rect("capabilities")
	if r.size == Vector2.ZERO or s.active_capabilities.is_empty():
		return
	var font := ThemeDB.fallback_font
	var n := s.active_capabilities.size()
	var top := r.position.y + r.size.y * 0.30
	var avail_h := r.size.y * 0.65
	var slot := avail_h / float(n)
	var ch := minf(20.0, slot - 3.0)
	var y := top
	for title in s.active_capabilities:
		var fac: String = ABB_CAP_FACTION.get(String(title), "reds")
		var chip := Rect2(r.position.x + r.size.x * 0.04, y, r.size.x * 0.92, ch)
		draw_rect(chip, GameController.faction_color(fac), true)
		draw_string(font, Vector2(chip.position.x + 8, y + ch * 0.76), String(title),
			HORIZONTAL_ALIGNMENT_LEFT, chip.size.x - 14, clampi(int(ch * 0.74), 9, 16), Color.WHITE)
		y += slot


## Mappa lo stato Sequence/Eligibility della fazione a una colonna del SoP.
func _sop_col_for(s: GameState, seq, fid: String) -> String:
	# Germans: in Phase II, posizione dipende dal roll German Eligibility.
	if fid == "germans" and int(s.tracks.get("phase", 1)) >= 2:
		var roll: int = int(s.tracks.get("german_eligibility_roll", 0))
		if roll > 0:
			return "eligible"  # ha agito o agirà; la colonna acted è gestita dopo
	if seq != null and seq.action_box.has(fid):
		var k := String(seq.action_box[fid])
		if k == "pass":
			return "pass"
		return "acted"
	if int(s.eligibility.get(fid, CoinEnums.Eligibility.ELIGIBLE)) == CoinEnums.Eligibility.INELIGIBLE:
		return "ineligible"
	return "eligible"


## Political Display §1.11: cubi Senato/Rossi (current Issue) + 3 Resolved badges.
func _abb_draw_political_display(s: GameState) -> void:
	var r := _box_rect("political_display")
	if r.size == Vector2.ZERO:
		return
	var font := ThemeDB.fallback_font
	var pd: Dictionary = s.tracks.get("political_display", {"senate": 0, "reds": 0})
	var senate_cubes := int(pd.get("senate", 0))
	var reds_cubes := int(pd.get("reds", 0))
	# Cubi nella semicirconferenza: bianco Senato a sinistra, rosso Rossi a destra.
	var cube_size: float = minf(r.size.y * 0.10, 22.0)
	var mid_x := r.position.x + r.size.x * 0.5
	var top_y := r.position.y + r.size.y * 0.10
	# Senato (bianchi) impilati colonna sinistra.
	for i in senate_cubes:
		var px := r.position.x + r.size.x * 0.15 + (i % 4) * (cube_size + 2.0)
		var py := top_y + int(i / 4) * (cube_size + 2.0)
		draw_rect(Rect2(Vector2(px, py), Vector2(cube_size, cube_size)),
			GameController.faction_color("senate"), true)
		draw_rect(Rect2(Vector2(px, py), Vector2(cube_size, cube_size)), Color.BLACK, false, 1.0)
	# Rossi a destra.
	for i in reds_cubes:
		var px2 := mid_x + r.size.x * 0.10 + (i % 4) * (cube_size + 2.0)
		var py2 := top_y + int(i / 4) * (cube_size + 2.0)
		draw_rect(Rect2(Vector2(px2, py2), Vector2(cube_size, cube_size)),
			GameController.faction_color("reds"), true)
		draw_rect(Rect2(Vector2(px2, py2), Vector2(cube_size, cube_size)), Color.BLACK, false, 1.0)
	# 3 badge Resolved Issues in basso.
	var issues: Array = s.tracks.get("issues", [])
	var badge_w: float = (r.size.x - 16.0) / 3.0
	var badge_h: float = r.size.y * 0.22
	var by := r.position.y + r.size.y - badge_h - 4.0
	for i in range(min(issues.size(), 3)):
		var entry: Dictionary = issues[i]
		var bx := r.position.x + 4.0 + i * (badge_w + 4.0)
		var rect := Rect2(bx, by, badge_w, badge_h)
		var by_who: String = String(entry.get("resolved_by", ""))
		var fill: Color
		if by_who == "":
			fill = Color(0.85, 0.85, 0.85, 0.35)  # Unresolved (grigio chiaro)
		elif by_who == "senate":
			fill = GameController.faction_color("senate")
		elif by_who == "reds":
			fill = GameController.faction_color("reds")
		else:
			fill = GameController.faction_color("moderates")
		fill.a = 0.85
		draw_rect(rect, fill, true)
		draw_rect(rect, Color.BLACK, false, 1.0)
		var labels: Array = ["Working", "Reform", "Social"]
		draw_string(font, Vector2(bx + 4, by + badge_h - 4), labels[i],
			HORIZONTAL_ALIGNMENT_LEFT, badge_w - 6, 10, Color.WHITE)


## Prisoners of War §6.5: chip Senato + chip Rossi col conteggio.
func _abb_draw_prisoners(s: GameState) -> void:
	var r := _box_rect("prisoners_of_war")
	if r.size == Vector2.ZERO:
		return
	var pris: Dictionary = s.tracks.get("prisoners", {"senate": 0, "reds": 0})
	var sn := int(pris.get("senate", 0))
	var rd := int(pris.get("reds", 0))
	if sn == 0 and rd == 0:
		return
	var font := ThemeDB.fallback_font
	var chip_w: float = (r.size.x - 16.0) * 0.5
	var chip_h: float = r.size.y * 0.30
	var y := r.position.y + r.size.y - chip_h - 4.0
	# Senato chip
	if sn > 0:
		var rect := Rect2(r.position.x + 4.0, y, chip_w, chip_h)
		var col := GameController.faction_color("senate"); col.a = 0.85
		draw_rect(rect, col, true)
		draw_rect(rect, Color.BLACK, false, 1.0)
		draw_string(font, Vector2(rect.position.x + 4, y + chip_h - 4),
			"Senate × %d" % sn, HORIZONTAL_ALIGNMENT_LEFT, chip_w - 8, 11, Color.WHITE)
	# Rossi chip
	if rd > 0:
		var rect2 := Rect2(r.position.x + 8.0 + chip_w, y, chip_w, chip_h)
		var col2 := GameController.faction_color("reds"); col2.a = 0.85
		draw_rect(rect2, col2, true)
		draw_rect(rect2, Color.BLACK, false, 1.0)
		draw_string(font, Vector2(rect2.position.x + 4, y + chip_h - 4),
			"Reds × %d" % rd, HORIZONTAL_ALIGNMENT_LEFT, chip_w - 8, 11, Color.WHITE)
