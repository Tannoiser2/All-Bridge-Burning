extends Control

## Scena principale (schema COIN comune): barra superiore con le Fazioni, mappa con
## comandi di vista, registro sotto la mappa e PANNELLO AZIONE a destra (Fazione di
## turno, istruzioni, Comando, Attività speciale, Evento, tasto Esegui contestuale).
##
## All Bridges Burning ha il suo flusso (Comandi su spazi scelti → "Esegui"); il flusso
## di Cuba Libre resta più sotto per l'export alternativo dello stesso motore.

# Centri normalizzati (0..1) degli spazi di Cuba Libre (export alternativo).
const LAYOUT := {
	"pinar_del_rio": Vector2(0.085, 0.47),
	"ec_pinar_habana": Vector2(0.15, 0.33),
	"havana": Vector2(0.225, 0.30),
	"la_habana": Vector2(0.205, 0.43),
	"matanzas": Vector2(0.305, 0.44),
	"ec_lasvillas_camaguey": Vector2(0.40, 0.40),
	"las_villas": Vector2(0.46, 0.46),
	"camaguey_province": Vector2(0.565, 0.41),
	"camaguey_city": Vector2(0.545, 0.66),
	"oriente": Vector2(0.715, 0.51),
	"ec_oriente_sierra": Vector2(0.77, 0.57),
	"sierra_maestra": Vector2(0.80, 0.61),
	"santiago_de_cuba": Vector2(0.875, 0.74),
}

const OP_NAMES := {
	# Cuba Libre
	"train": "Addestramento", "garrison": "Guarnigione", "sweep": "Perlustrazione",
	"assault": "Assalto", "rally": "Rally", "march": "Marcia",
	"attack": "Attacco", "terror": "Terrorismo", "build": "Costruzione",
	# All Bridges Burning (rally/march/attack/terror condivisi)
	"message": "Messaggio", "activism": "Attivismo", "negotiate": "Negoziato",
}
# Cosa permette di fare ogni Comando/Operazione (mostrato sotto i tasti quando è scelto).
const OP_DESC := {
	"train": "Clicca uno spazio per piazzare cubi (riclicca per +1, fino a 4); un altro click cicla a Base (da 2 cubi) o Azione Civica (1 sola Att. speciale per Addestramento).",
	"garrison": "Sposta cubi verso Città/EC (trascina); attiva le Guerriglie negli EC. Clicca un EC per un Assalto gratuito lì.",
	"sweep": "Sposta Truppe negli spazi adiacenti e attiva 1 Guerriglia clandestina nemica per ogni Truppa/Polizia.",
	"assault": "Rimuovi pezzi nemici scoperti (1 per Truppa, o per Polizia in Città): prima le Guerriglie Attive, poi le Basi.",
	"build": "Sindacato (5 Risorse/spazio): clicca per un nuovo Casinò chiuso; riclicca per aprirne uno già chiuso, dove possibile.",
	# All Bridges Burning
	"rally": "Rally (§3.2.1): piazza Cellule negli spazi scelti (+1 per Supporto/Opposizione amica); riclicca per Amministrazione/Network.",
	"march": "Marcia (§3.2.5, Fase II): clicca uno spazio con tue Cellule clandestine, poi uno adiacente; ripeti per spostarne altre. Chi entra dove c'è il nemico si Attiva.",
	"attack": "Attacco (§3.2.4, Fase II): 1d6 contro la forza d'Attacco negli spazi scelti (1 Risorsa per spazio).",
	"terror": "Terrorismo (§3.2.3): serve una tua Cellula Attiva; poni Terror e rimuovi 1 pezzo nemico (2 con Polarizzazione ≥ 6). Polarizzazione +1.",
	"activism": "Attivismo (§3.2.2): con una Cellula amica, gira una Cellula nemica Attiva (o attiva una tua). Polarizzazione −1.",
	"negotiate": "Negoziato (§3.3.3): Attiva una tua Cellula clandestina e Disattiva 1 Cellula nemica Attiva; Polarizzazione −1 (1 Risorsa per spazio).",
	"message": "Messaggio (Moderati): sposta i News e gira le Cellule. Non ancora implementato nel motore.",
}
# Cosa permette di fare ogni Attività Speciale.
const SA_DESC := {
	"transport": "Sposta fino a 3 Truppe da una Città o da una Base verso un qualsiasi spazio.",
	"air_strike": "Rimuovi 1 Guerriglia Attiva (o, se assente, 1 Base) in una Provincia/EC. Vietato durante l'Embargo.",
	"reprisal": "In uno spazio a Controllo Govt: poni Terrore, riduci l'Opposizione e sposta 1 Guerriglia in uno spazio adiacente.",
	"infiltrate": "Rimpiazza 1 cubo del Governo con una Guerriglia 26J in uno spazio senza Supporto (serve una clandestina 26J lì o adiacente).",
	"kidnap": "Trasferisci Risorse/Denaro dal Governo al 26J e chiudi 1 Casinò; servono più Guerriglie 26J che Polizia.",
	"assassinate": "Rimuovi 1 pezzo nemico (anche una Base) dove le Guerriglie DR superano la Polizia.",
	"profit": "Accumula 1 Denaro in 1-2 spazi con un Casinò aperto.",
	"muscle": "Sposta 1-2 Polizia (verso Città) o Truppe (verso Provincia/EC) in uno spazio con Casinò aperto o EC.",
	"bribe": "Spendi 3 Risorse del Sindacato per rimuovere fino a 2 cubi/Guerriglie nemici (o 1 Base) in uno spazio.",
	# All Bridges Burning
	"agitate": "Agitazione (Reds): spendi 1 Risorsa per spostare il Supporto verso l'Opposizione dove hai una Cellula.",
	"ambush": "Imboscata (Reds): con una Cellula clandestina, rimuovi fino a 2 pezzi nemici senza tiro (la Cellula si Attiva).",
	"subvert": "Sovversione (Reds): con una Cellula clandestina, rimuovi 1 Cellula del Senato o dei Moderati.",
	"crackdown": "Repressione (Senato): togli 1 Terror e sposta il Supporto verso il Senato dove hai una Cellula.",
	"coordinate": "Coordinamento (Senato, §4.2.4, Fase II): piazza il marker Coordinate — la prossima azione tedesca è guidata dal Senato.",
	"dialogue": "Dialogo (Moderati): sposta Supporto/Opposizione di un passo verso il Neutrale dove hai una Cellula.",
	"foreign_relations": "Relazioni Estere (Moderati): sposta il Vassallaggio tedesco o russo di un passo.",
	"tax": "Tassazione: incassa Risorse pari alla Popolazione di uno spazio con una tua Cellula.",
}
# Att.Speciali con scelte multiple: ogni variante è un tasto distinto col suo bersaglio valido.
const SA_VARIANTS := {
	"kidnap": [
		{"id": "kidnap:government", "label": "Sequestro (Governo)", "p": {"target": "government"}},
		{"id": "kidnap:syndicate", "label": "Sequestro (Sindacato)", "p": {"target": "syndicate"}},
	],
	"profit": [
		{"id": "profit:cash", "label": "Profitto (incassa Denaro)", "p": {"mode": "cash"}},
		{"id": "profit:convert", "label": "Profitto (converti in Risorse)", "p": {"mode": "convert"}},
	],
	"bribe": [
		{"id": "bribe:cubes", "label": "Corruzione (cubi)", "p": {"action": "cubes"}},
		{"id": "bribe:guerrillas_remove", "label": "Corruzione (rimuovi Guerriglie)", "p": {"action": "guerrillas_remove"}},
		{"id": "bribe:guerrillas_flip", "label": "Corruzione (gira Guerriglie)", "p": {"action": "guerrillas_flip"}},
		{"id": "bribe:base", "label": "Corruzione (rimuovi Base)", "p": {"action": "base"}},
	],
	"foreign_relations": [
		{"id": "foreign_relations:germans+", "label": "Rel. Estere: Germania +1", "p": {"power": "germans", "delta": 1}},
		{"id": "foreign_relations:germans-", "label": "Rel. Estere: Germania −1", "p": {"power": "germans", "delta": -1}},
		{"id": "foreign_relations:russians+", "label": "Rel. Estere: Russia +1", "p": {"power": "russians", "delta": 1}},
		{"id": "foreign_relations:russians-", "label": "Rel. Estere: Russia −1", "p": {"power": "russians", "delta": -1}},
	],
}
# Tipo di flusso per ogni Operazione (Cuba Libre).
const OP_KIND := {
	"train": "space_list", "assault": "space_list", "rally": "space_list",
	"attack": "space_list", "terror": "space_list", "build": "space_list",
	"sweep": "moves", "garrison": "moves", "march": "moves",
}

const PIECE_NAMES := {
	"troops": "Truppa", "police": "Polizia", "guerrilla": "Guerriglia",
	"base": "Base", "casino": "Casinò",
	"cell": "Cellula", "admin": "Amministrazione", "network": "Network",
}
const SA_NAMES := {
	"transport": "Trasporto", "air_strike": "Attacco Aereo", "reprisal": "Rappresaglia",
	"infiltrate": "Infiltrazione", "ambush": "Imboscata", "kidnap": "Sequestro",
	"subvert": "Sovversione", "assassinate": "Assassinio",
	"profit": "Profitto", "muscle": "Muscle", "bribe": "Corruzione",
	# ABB
	"agitate": "Agitazione", "crackdown": "Repressione",
	"coordinate": "Coordinamento", "negotiate": "Negoziato",
	"dialogue": "Dialogo", "foreign_relations": "Relazioni Estere",
	"tax": "Tassazione",
}
const ACTION_NAMES := {
	0: "Passa", 1: "Comando", 2: "Comando + Att. speciale", 3: "Comando Limitato", 4: "Evento",
}

## Numero di build, accanto al titolo del registro (striscia in basso). Permanente: serve a
## confermare a colpo d'occhio quale versione il browser ha caricato (cache del .pck).
const BUILD_VERSION := "b158"

const PANEL_W := 352.0
const GAP := 10.0

# --- Struttura della scena ---
var _space_views: Dictionary = {}     # space_id -> RegionView
var _board: ScrollContainer
var _map_frame: Panel                 # cornice d'ottone attorno alla mappa
var _map_wrap: Control
var _map: TextureRect
var _top: TopBar                      # barra superiore (Fazioni, Potenze, carte, comandi)
var _strip: BottomStrip               # striscia inferiore (registro + carta in gioco)
var _panel: PanelContainer            # pannello azione (colonna di destra)
var _log: LogView
var _track_overlay: TrackOverlay
var _moves_overlay: MovesOverlay      # frecce degli spostamenti in coda
var _zoom := 1.0
var _view_ready := false
var _zoom_box: PanelContainer
var _zoom_lbl: Label
var _confirm_new: ConfirmationDialog
var _auto_bot := false                # se true, i Bot giocano da soli

# --- Pannello azione ---
var _head: PanelContainer
var _head_tok: TextureRect
var _head_name: Label
var _head_sub: Label
var _head_stamp: Label
var _banner: PanelContainer
var _turn_banner: Label
var _instr: Label
var _op_btns: GridContainer
var _op_btn_map: Dictionary = {}      # op_id -> Button
var _op_desc: Label
var _sa_btns: GridContainer
var _sa_btn_map: Dictionary = {}      # sa_id (con variante) -> Button
var _sa_desc: Label
var _cur_img: TextureRect
var _next_img: TextureRect
var _ev_title: Label
var _btn_ev_u: Button
var _btn_ev_s: Button
var _event_side := ""                 # "", "unshaded", "shaded": Evento scelto, da eseguire
var _preview: TipLabel
var _btn_clear: Button
var _btn_exec: Button
var _btn_pass: Button
var _btn_end: Button
var _btn_bot: Button = null           # (comando "Gioca Bot" vive nella barra superiore)

# --- Stato del flusso azione ---
var _mode := "idle"
var _limited := false                 # Comando Limitato: 1 spazio, niente Att.Speciale
var _cur_faction := "reds"
var _cur_action := ""                 # Comando (Operazione) in preparazione
var _selected: Array = []
var _pending_moves: Array = []        # [{from, to, count, type}]
var _pending_sa := ""                 # Att.Speciale in preparazione
var _resume_mode := "idle"            # modalità Operazione da riprendere dopo l'Att.Speciale (Cuba)

# Cuba Libre: dettagli del flusso (export alternativo).
var _rally_choice: Dictionary = {}
var _train_plan: Dictionary = {}
var _build_choice: Dictionary = {}
var _garrison_ec := ""
var _reprisal_from := ""
var _attack_target: Dictionary = {}
var _sa_move_to := ""
var _sa_move_count := 0
var _sa_spaces: Array = []
var _profit_mode := "cash"
var _sa_from := ""
var _sa_valid: Array = []

# All Bridges Burning: dettagli del flusso.
var _abb_rally_mode: Dictionary = {}  # sid -> "cell" | "admin" | "network"
var _abb_march_from := ""
var _abb_sa_target := ""

# --- Animazioni ---
var _prev_fp: Dictionary = {}
var _anim_layer: Control
var _prev_pc: Dictionary = {}
var _avail_box: Dictionary = {}
const ANIM_SZ := 26.0
const ANIM_DUR := 0.9
var _endgame_shown := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	# Tema "dispaccio 1918": vale per la scena, i menu a tendina e le finestre.
	theme = CoinTheme.dark_theme()
	get_window().theme = CoinTheme.dark_theme()
	if GameController.game_def != null and not GameController.game_def.factions.is_empty():
		_cur_faction = GameController.game_def.factions[0].id
	# Su schermi touch (iPad): canvas logico più piccolo = testi e bersagli più grandi.
	if DisplayServer.is_touchscreen_available():
		get_window().content_scale_size = Vector2i(1180, 650)
	_build_ui()
	_strip.set_version(BUILD_VERSION)
	GameController.state_changed.connect(_refresh)
	GameController.action_logged.connect(_log.add_line)
	GameController.bot_decision.connect(_log.add_decision)
	get_viewport().size_changed.connect(_layout_board)
	_rebuild_action_buttons(_cur_faction)
	# Driver automatico delle Fazioni Bot (gioca da sole al loro turno).
	var bot_timer := Timer.new()
	bot_timer.wait_time = 1.0
	bot_timer.one_shot = false
	add_child(bot_timer)
	bot_timer.timeout.connect(_auto_bot_tick)
	bot_timer.start()
	_refresh()
	_layout_board.call_deferred()


func _is_abb() -> bool:
	return GameRegistry.game_id == "all_bridges_burning"


# ---------------------------------------------------------------------------
# Costruzione UI
# ---------------------------------------------------------------------------

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = CoinTheme.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	_top = TopBar.new()
	_top.role_toggle_requested.connect(_toggle_role)
	_top.undo_requested.connect(_on_undo_action)
	_top.auto_bot_toggled.connect(_toggle_auto_bot)
	_top.menu_id_pressed.connect(_on_game_menu)
	_top.bot_turn_requested.connect(func(): GameController.bot_act_pending())
	add_child(_top)

	# Cornice della mappa (ottone) e area scrollabile per zoom/pan.
	_map_frame = Panel.new()
	var fsb := CoinTheme.flat(CoinTheme.BG)
	fsb.set_border_width_all(2)
	fsb.border_color = CoinTheme.BRASS.darkened(0.25)
	fsb.set_corner_radius_all(3)
	fsb.expand_margin_left = 3
	fsb.expand_margin_right = 3
	fsb.expand_margin_top = 3
	fsb.expand_margin_bottom = 3
	_map_frame.add_theme_stylebox_override("panel", fsb)
	_map_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_map_frame)
	_board = ScrollContainer.new()
	add_child(_board)
	_map_wrap = Control.new()
	_map_wrap.mouse_filter = Control.MOUSE_FILTER_PASS
	_board.add_child(_map_wrap)
	_map = TextureRect.new()
	_map.texture = CLAssets.map()
	_map.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_map.stretch_mode = TextureRect.STRETCH_SCALE
	_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map.size_flags_horizontal = 0
	_map.size_flags_vertical = 0
	_map_wrap.add_child(_map)

	# Zone poligonali sagomate sui contorni (figlie della mappa).
	var regions: Dictionary = _load_regions()
	for sid in regions.keys():
		if GameController.game_def.space(sid) == null:
			continue
		var sd: SpaceDef = GameController.game_def.space(sid)
		var rv := RegionView.new()
		var r: Dictionary = regions[sid]
		var cbox := Vector2(-1, -1)
		var sbox := Vector2(-1, -1)
		if r.has("cbox"):
			cbox = Vector2(r["cbox"][0], r["cbox"][1])
		if r.has("sbox"):
			sbox = Vector2(r["sbox"][0], r["sbox"][1])
		var circle := Vector3(-1, -1, -1)
		if r.has("circle"):
			circle = Vector3(r["circle"][0], r["circle"][1], r["circle"][2])
		rv.setup(sd, r.get("polygon", []), Vector2(r["anchor"][0], r["anchor"][1]), cbox, sbox, circle)
		# Vassal mask (pixel-perfect): se presente, ne fa il tint del Controllo.
		if r.has("mask") and r.has("mask_rect"):
			var mr: Array = r["mask_rect"]
			var mtex: Texture2D = CLAssets.tex(String(r["mask"]))
			if mtex != null:
				rv.set_mask(mtex, Rect2(mr[0], mr[1], mr[2] - mr[0], mr[3] - mr[1]))
		rv.space_clicked.connect(_on_space_clicked)
		rv.piece_dropped.connect(_on_piece_dropped)
		_map.add_child(rv)
		_space_views[sid] = rv

	_track_overlay = TrackOverlay.new()
	_track_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_map.add_child(_track_overlay)
	_moves_overlay = MovesOverlay.new()
	_moves_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_moves_overlay.z_index = 40
	_moves_overlay.color = CoinTheme.BRASS_HI
	_map.add_child(_moves_overlay)
	_anim_layer = Control.new()
	_anim_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_anim_layer.z_index = 50
	_map.add_child(_anim_layer)
	_avail_box = _load_avail_boxes()

	_build_zoom_box()

	_strip = BottomStrip.new()
	_log = _strip.log_view
	add_child(_strip)

	_panel = _build_action_panel()
	add_child(_panel)

	_confirm_new = ConfirmationDialog.new()
	_confirm_new.title = "Nuova partita"
	_confirm_new.dialog_text = "Iniziare una nuova partita?\nLa partita in corso andrà persa."
	_confirm_new.ok_button_text = "Nuova partita"
	_confirm_new.cancel_button_text = "Annulla"
	_confirm_new.confirmed.connect(_on_new_game)
	add_child(_confirm_new)

	resized.connect(_layout_board)
	_layout_board()


func _load_regions() -> Dictionary:
	var path := GameRegistry.data_path("regions.json")
	var data = JSON.parse_string(FileAccess.get_file_as_string(path))
	return data.get("regions", {}) if typeof(data) == TYPE_DICTIONARY else {}


func _mk_btn(text: String, cb: Callable) -> Button:
	var b := TipButton.new()
	b.text = text
	b.pressed.connect(cb)
	CoinTheme.style_button(b)
	return b


## Comandi di vista sopra la mappa: zoom e inquadratura.
func _build_zoom_box() -> void:
	_zoom_box = PanelContainer.new()
	_zoom_box.add_theme_stylebox_override("panel", CoinTheme.dark_box())
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 2)
	_zoom_box.add_child(h)
	var minus := _mk_btn("−", func(): _zoom_at(1.0 / 1.25))
	minus.tooltip_text = "Riduci (rotellina o −)"
	minus.custom_minimum_size = Vector2(36, 34)
	h.add_child(minus)
	_zoom_lbl = CoinTheme.label("100%", CoinTheme.TEXT, 14)
	_zoom_lbl.custom_minimum_size = Vector2(48, 0)
	_zoom_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_zoom_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	h.add_child(_zoom_lbl)
	var plus := _mk_btn("+", func(): _zoom_at(1.25))
	plus.tooltip_text = "Ingrandisci (rotellina o +)"
	plus.custom_minimum_size = Vector2(36, 34)
	h.add_child(plus)
	var fit := _mk_btn("Finlandia" if _is_abb() else "Isola", _view_island)
	fit.tooltip_text = "Inquadra gli spazi della mappa" if _is_abb() else "Inquadra Cuba"
	h.add_child(fit)
	var whole := _mk_btn("Tutta", func(): _set_zoom(1.0))
	whole.tooltip_text = "Mostra tutta la plancia, con tracciati, Political Display e forze disponibili (0)"
	h.add_child(whole)
	add_child(_zoom_box)


## Pannello azione: Fazione e istruzioni in testa, poi Comando, Attività speciale,
## Evento con le carte, e in fondo il tasto Esegui contestuale con Passa e Concludi.
func _build_action_panel() -> PanelContainer:
	var pc := PanelContainer.new()
	pc.theme = CoinTheme.paper_theme()
	pc.add_theme_stylebox_override("panel", CoinTheme.paper_box(0.0))
	pc.clip_contents = true
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 0)
	pc.add_child(outer)

	# Intestazione nel colore della Fazione di turno.
	_head = PanelContainer.new()
	outer.add_child(_head)
	var hh := HBoxContainer.new()
	hh.add_theme_constant_override("separation", 10)
	_head.add_child(hh)
	_head_tok = TextureRect.new()
	_head_tok.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_head_tok.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_head_tok.custom_minimum_size = Vector2(30, 38)
	hh.add_child(_head_tok)
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", -3)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hh.add_child(hv)
	_head_name = CoinTheme.label("", Color.WHITE, 25, CoinTheme.display())
	_head_name.clip_text = true
	hv.add_child(_head_name)
	_head_sub = CoinTheme.label("", Color(1, 1, 1, 0.85), 14)
	_head_sub.clip_text = true
	hv.add_child(_head_sub)
	_head_stamp = CoinTheme.label("", Color.WHITE, 12, CoinTheme.typewriter_bold())
	var stamp_sb := StyleBoxFlat.new()
	stamp_sb.bg_color = Color(0, 0, 0, 0)
	stamp_sb.set_border_width_all(2)
	stamp_sb.border_color = Color.WHITE
	stamp_sb.content_margin_left = 6
	stamp_sb.content_margin_right = 6
	stamp_sb.content_margin_top = 1
	stamp_sb.content_margin_bottom = 1
	_head_stamp.add_theme_stylebox_override("normal", stamp_sb)
	_head_stamp.rotation_degrees = -6.0
	_head_stamp.resized.connect(func(): _head_stamp.pivot_offset = _head_stamp.size * 0.5)
	_head_stamp.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hh.add_child(_head_stamp)

	# Istruzioni di turno, subito sotto la Fazione: cosa fare adesso.
	_banner = InstrBox.new()
	var bsb := CoinTheme.flat(CoinTheme.PAPER_DARK, 0)
	bsb.content_margin_left = 14
	bsb.content_margin_right = 14
	bsb.content_margin_top = 7
	bsb.content_margin_bottom = 7
	bsb.border_width_bottom = 1
	bsb.border_color = Color("c9c0a8")
	_banner.add_theme_stylebox_override("panel", bsb)
	_banner.mouse_filter = Control.MOUSE_FILTER_STOP
	_banner.mouse_entered.connect(func(): _banner.tooltip_text = "%s\n%s" % [_turn_banner.text, _instr.text])
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 1)
	bv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_banner.add_child(bv)
	_turn_banner = CoinTheme.label("", CoinTheme.INK, 15, CoinTheme.ui_heavy())
	_turn_banner.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_turn_banner.max_lines_visible = 2
	bv.add_child(_turn_banner)
	_instr = CoinTheme.label("", CoinTheme.INK, 12, CoinTheme.typewriter())
	_instr.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_instr.max_lines_visible = 2
	bv.add_child(_instr)
	outer.add_child(_banner)

	# Corpo scorrevole (schermi bassi), con il blocco "Esegui" sempre in fondo.
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	outer.add_child(scroll)
	var m := MarginContainer.new()
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	m.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 14)
	m.add_theme_constant_override("margin_top", 8)
	m.add_theme_constant_override("margin_bottom", 4)
	scroll.add_child(m)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 5)
	m.add_child(body)

	body.add_child(CoinTheme.section_title("Comando" if _is_abb() else "Operazione"))
	_op_btns = GridContainer.new()
	_op_btns.columns = 2
	_op_btns.add_theme_constant_override("h_separation", 6)
	_op_btns.add_theme_constant_override("v_separation", 6)
	body.add_child(_op_btns)
	_op_desc = CoinTheme.label("", CoinTheme.INK_DIM, 12, CoinTheme.typewriter())
	_op_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_op_desc.max_lines_visible = 3
	_op_desc.visible = false
	body.add_child(_op_desc)

	var sa_title := HBoxContainer.new()
	sa_title.add_child(CoinTheme.section_title("Attività speciale"))
	var opt := CoinTheme.label(" (facoltativa)", CoinTheme.INK_DIM, 13)
	opt.size_flags_vertical = Control.SIZE_SHRINK_END
	sa_title.add_child(opt)
	body.add_child(sa_title)
	_sa_btns = GridContainer.new()
	_sa_btns.columns = 2
	_sa_btns.add_theme_constant_override("h_separation", 6)
	_sa_btns.add_theme_constant_override("v_separation", 6)
	body.add_child(_sa_btns)
	_sa_desc = CoinTheme.label("", CoinTheme.INK_DIM, 12, CoinTheme.typewriter())
	_sa_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_sa_desc.max_lines_visible = 3
	_sa_desc.visible = false
	body.add_child(_sa_desc)

	# Evento: carta corrente, titolo con i due lati, prossima carta in piccolo.
	body.add_child(CoinTheme.section_title("Evento"))
	var cards := HBoxContainer.new()
	cards.add_theme_constant_override("separation", 8)
	body.add_child(cards)
	_cur_img = _card_thumb(Vector2(64, 90), "Carta corrente: clicca per ingrandire")
	cards.add_child(_cur_img)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 5)
	cv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cards.add_child(cv)
	_ev_title = CoinTheme.label("", CoinTheme.INK, 18, CoinTheme.display())
	_ev_title.clip_text = true
	_ev_title.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_ev_title.mouse_filter = Control.MOUSE_FILTER_PASS
	cv.add_child(_ev_title)
	_btn_ev_u = _mk_btn("Chiaro", func(): _pick_event("unshaded"))
	_btn_ev_u.tooltip_text = "Scegli il lato chiaro (non ombreggiato) dell'Evento, poi 'Esegui'"
	_btn_ev_s = _mk_btn("Ombreggiato", func(): _pick_event("shaded"))
	_btn_ev_s.tooltip_text = "Scegli il lato ombreggiato dell'Evento, poi 'Esegui'"
	for eb in [_btn_ev_u, _btn_ev_s]:
		eb.custom_minimum_size = Vector2(0, 30)
		eb.add_theme_font_size_override("font_size", 14)
		cv.add_child(eb)
	var nv := VBoxContainer.new()
	nv.add_theme_constant_override("separation", 0)
	nv.alignment = BoxContainer.ALIGNMENT_END
	cards.add_child(nv)
	var nl := CoinTheme.label("Prossima", CoinTheme.INK_DIM, 12)
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	nv.add_child(nl)
	_next_img = _card_thumb(Vector2(50, 70), "Prossima carta: clicca per ingrandire")
	_next_img.modulate = Color(1, 1, 1, 0.85)
	nv.add_child(_next_img)

	# Fondo fisso: anteprima, Esegui contestuale, Passa / Concludi turno.
	var foot_m := MarginContainer.new()
	for side in ["left", "right"]:
		foot_m.add_theme_constant_override("margin_" + side, 14)
	foot_m.add_theme_constant_override("margin_top", 6)
	foot_m.add_theme_constant_override("margin_bottom", 12)
	outer.add_child(foot_m)
	var foot := VBoxContainer.new()
	foot.add_theme_constant_override("separation", 7)
	foot_m.add_child(foot)
	var prow := HBoxContainer.new()
	prow.add_theme_constant_override("separation", 6)
	foot.add_child(prow)
	_preview = TipLabel.new()
	_preview.add_theme_font_override("font", CoinTheme.ui_heavy())
	_preview.add_theme_font_size_override("font_size", 15)
	_preview.add_theme_color_override("font_color", CoinTheme.INK)
	_preview.mouse_filter = Control.MOUSE_FILTER_STOP
	_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_preview.clip_text = true
	_preview.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	prow.add_child(_preview)
	_btn_clear = _mk_btn("Annulla scelta", _on_cancel_selection)
	_btn_clear.tooltip_text = "Scarta la scelta in preparazione, senza toccare le azioni già eseguite (Esc)"
	_btn_clear.add_theme_font_size_override("font_size", 13)
	_btn_clear.custom_minimum_size = Vector2(0, 30)
	prow.add_child(_btn_clear)

	_btn_exec = _mk_btn("Esegui", _on_execute)
	_btn_exec.tooltip_text = "Applica la scelta preparata (Invio)"
	CoinTheme.primary_button(_btn_exec)
	_btn_exec.custom_minimum_size = Vector2(0, 50)
	_btn_exec.clip_text = true
	foot.add_child(_btn_exec)

	var row_a := GridContainer.new()
	row_a.columns = 2
	row_a.add_theme_constant_override("h_separation", 8)
	foot.add_child(row_a)
	_btn_pass = _mk_btn("Passa", func(): GameController.seq_pass())
	_btn_pass.tooltip_text = "La Fazione passa e guadagna Risorse"
	_btn_end = _mk_btn("Concludi turno", func(): _on_execute_and_end())
	_btn_end.tooltip_text = "Esegui (se serve) e chiudi il turno della Fazione (Spazio)"
	for b in [_btn_pass, _btn_end]:
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 40)
		row_a.add_child(b)
	# "Concludi turno" pieno d'inchiostro: chiude ogni turno.
	CoinTheme.accent_button(_btn_end, CoinTheme.INK, CoinTheme.INK, CoinTheme.PAPER)
	return pc


func _card_thumb(sz: Vector2, tip: String) -> TextureRect:
	var r := TextureRect.new()
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.custom_minimum_size = sz
	r.mouse_filter = Control.MOUSE_FILTER_STOP
	r.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	r.tooltip_text = tip
	r.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and r.texture != null:
			_show_card_zoom(r.texture))
	return r


## Carta ingrandita sopra tutto (clic per chiudere).
func _show_card_zoom(tex: Texture2D) -> void:
	if tex == null:
		return
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.z_index = 100
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	var big := TextureRect.new()
	big.texture = tex
	big.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	big.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	big.set_anchors_preset(Control.PRESET_FULL_RECT)
	big.offset_left = 30
	big.offset_top = 30
	big.offset_right = -30
	big.offset_bottom = -30
	big.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.add_child(big)
	var hint := CoinTheme.label("clicca per chiudere", CoinTheme.TEXT_DIM, 12)
	hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint.offset_top = -24
	dim.add_child(hint)
	dim.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed:
			dim.queue_free())
	add_child(dim)


# ---------------------------------------------------------------------------
# Layout, zoom e viste
# ---------------------------------------------------------------------------

func _map_aspect() -> float:
	return 2350.0 / 3000.0 if _is_abb() else 2040.0 / 2640.0


## Riquadro (normalizzato) che contiene gli spazi giocabili: la vista "Finlandia"/"Isola".
func _focus_rect() -> Rect2:
	return Rect2(0.03, 0.075, 0.74, 0.85) if _is_abb() else Rect2(0.0, 0.12, 1.0, 0.72)


func _set_zoom(z: float) -> void:
	_zoom = clampf(z, 0.5, 4.0)
	_layout_board()


## Zoom mantenendo fermo il punto della mappa sotto il pivot (mouse/pinch).
func _zoom_at(factor: float, screen_pos: Vector2 = Vector2(-1, -1)) -> void:
	if _board == null:
		return
	var local := screen_pos - _board.global_position
	if screen_pos.x < 0 or local.x < 0 or local.y < 0 or local.x > _board.size.x or local.y > _board.size.y:
		local = _board.size * 0.5
	var old_zoom := _zoom
	var target := clampf(_zoom * factor, 0.5, 4.0)
	if is_equal_approx(target, old_zoom):
		return
	var map_pt := (Vector2(_board.scroll_horizontal, _board.scroll_vertical) + local - _map.position) / old_zoom
	_zoom = target
	_layout_board()
	var off := _map.position
	_board.scroll_horizontal = int(map_pt.x * _zoom + off.x - local.x)
	_board.scroll_vertical = int(map_pt.y * _zoom + off.y - local.y)


func _layout_board() -> void:
	if _top == null or _board == null or _strip == null or _panel == null:
		return
	var W := size.x
	var H := size.y
	var compact := W < 1300.0
	_top.set_compact(compact)
	_strip.set_compact(compact)
	_top.position = Vector2.ZERO
	_top.size = Vector2(W, TopBar.HEIGHT)
	var top := TopBar.HEIGHT + GAP
	var panel_w := PANEL_W if not compact else 316.0
	var left := 12.0
	var map_w := maxf(300.0, W - left - GAP - panel_w - 12.0)
	var strip_h := BottomStrip.HEIGHT if not compact else 112.0
	var map_h := maxf(200.0, H - top - GAP - strip_h - 12.0)
	_panel.position = Vector2(W - 12.0 - panel_w, top)
	_panel.size = Vector2(panel_w, H - top - 12.0)
	_strip.position = Vector2(left, top + map_h + GAP)
	_strip.size = Vector2(map_w, strip_h)
	_board.position = Vector2(left, top)
	_board.size = Vector2(map_w, map_h)
	_map_frame.position = _board.position
	_map_frame.size = _board.size
	var zb := _zoom_box.get_combined_minimum_size()
	_zoom_box.position = Vector2(left + map_w - zb.x - 10.0, top + 10.0)
	_zoom_box.size = zb
	# Dimensione base (zoom=1) = tutta la plancia nel riquadro; lo zoom è una SCALA.
	var aspect := _map_aspect()
	var mw0 := map_w
	var mh0 := mw0 * aspect
	if mh0 > map_h:
		mh0 = map_h
		mw0 = mh0 / aspect
	var base := Vector2(mw0, mh0)
	if not _view_ready and map_w > 300.0:
		_view_ready = true
		_view_island.call_deferred()
	var scaled := base * _zoom
	_map.custom_minimum_size = base
	_map.size = base
	_map.scale = Vector2(_zoom, _zoom)
	_map.position = ((_board.size - scaled) * 0.5).max(Vector2.ZERO)
	_map_wrap.custom_minimum_size = scaled.max(_board.size)
	_map_wrap.size = scaled.max(_board.size)
	_zoom_lbl.text = "%d%%" % roundi(_zoom * 100.0)
	for sid in _space_views.keys():
		var rv: RegionView = _space_views[sid]
		rv.position = Vector2.ZERO
		rv.size = base
		rv.relayout()
	_track_overlay.position = Vector2.ZERO
	_track_overlay.size = base
	_track_overlay.queue_redraw()
	_anim_layer.position = Vector2.ZERO
	_anim_layer.size = base
	_moves_overlay.position = Vector2.ZERO
	_moves_overlay.size = base
	_update_moves_overlay()


## Inquadra gli spazi giocabili (Finlandia / Cuba) facendoli entrare tutti.
func _view_island() -> void:
	if _board == null or _board.size.x <= 0.0:
		return
	var aspect := _map_aspect()
	var mw0 := _board.size.x
	var mh0 := mw0 * aspect
	if mh0 > _board.size.y:
		mh0 = _board.size.y
		mw0 = mh0 / aspect
	var fr := _focus_rect()
	_zoom = clampf(minf(_board.size.x / (mw0 * fr.size.x), _board.size.y / (mh0 * fr.size.y)), 0.5, 4.0)
	_layout_board()
	var c := (fr.position + fr.size * 0.5) * Vector2(mw0, mh0) * _zoom + _map.position
	await get_tree().process_frame
	_board.scroll_horizontal = int(maxf(0.0, c.x - _board.size.x * 0.5))
	_board.scroll_vertical = int(maxf(0.0, c.y - _board.size.y * 0.5))


## Scorciatoie: Esc annulla la scelta, Invio esegue, Spazio conclude il turno,
## Ctrl+Z disfa, +/-/0 regolano la vista.
func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_ESCAPE:
			_on_cancel_selection()
		KEY_ENTER, KEY_KP_ENTER:
			_on_execute()
		KEY_SPACE:
			_on_execute_and_end()
		KEY_Z:
			if event.ctrl_pressed or event.meta_pressed:
				_on_undo_action()
			else:
				return
		KEY_PLUS, KEY_EQUAL, KEY_KP_ADD:
			_zoom_at(1.25)
		KEY_MINUS, KEY_KP_SUBTRACT:
			_zoom_at(1.0 / 1.25)
		KEY_0, KEY_KP_0:
			_set_zoom(1.0)
		_:
			return
	get_viewport().set_input_as_handled()


var _touch_pts: Dictionary = {}


## Zoom da rotellina (sull'area mappa), gesto magnify (trackpad) e pinch (touch).
func _input(event: InputEvent) -> void:
	if _board == null:
		return
	var board_rect := Rect2(_board.global_position, _board.size)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and board_rect.has_point(event.position):
			_zoom_at(1.15, event.position)
			get_viewport().set_input_as_handled()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and board_rect.has_point(event.position):
			_zoom_at(1.0 / 1.15, event.position)
			get_viewport().set_input_as_handled()
	elif event is InputEventMagnifyGesture:
		if board_rect.has_point(event.position):
			_zoom_at(event.factor, event.position)
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenTouch:
		if event.pressed:
			_touch_pts[event.index] = event.position
		else:
			_touch_pts.erase(event.index)
	elif event is InputEventScreenDrag and _touch_pts.has(event.index):
		if _touch_pts.size() == 2:
			var other := Vector2.ZERO
			for i in _touch_pts:
				if i != event.index:
					other = _touch_pts[i]
			var d_old: float = (_touch_pts[event.index] as Vector2).distance_to(other)
			_touch_pts[event.index] = event.position
			var d_new: float = (event.position as Vector2).distance_to(other)
			if d_old > 8.0 and d_new > 8.0:
				_zoom_at(d_new / d_old, (event.position + other) * 0.5)
				get_viewport().set_input_as_handled()
		else:
			_touch_pts[event.index] = event.position


# ---------------------------------------------------------------------------
# Aggiornamento viste
# ---------------------------------------------------------------------------

func _refresh() -> void:
	if GameController.game_over:
		_show_endgame_dialog()
	else:
		_endgame_shown = false
	_animate_moves()
	for sid in _space_views.keys():
		_space_views[sid].refresh(GameController.state)
	if _track_overlay != null:
		_track_overlay.queue_redraw()
	_flash_changes()
	_refresh_turn_banner()
	_refresh_event_box()
	_top.refresh()
	_strip.refresh()


## Schermata di fine partita: classifica con margini (una volta sola).
func _show_endgame_dialog() -> void:
	if _endgame_shown or not _is_abb():
		return
	_endgame_shown = true
	var vs: Dictionary = GameController.module.victory_status(GameController.state)
	var order: Array = ["reds", "senate", "moderates"]
	order.sort_custom(func(a, b): return int(vs[a]["margin"]) > int(vs[b]["margin"]))
	var txt := "Vince: %s\n\nClassifica (valore/soglia · margine):\n" % CoinTheme.faction_label(GameController.winner)
	var pos := 1
	for fid in order:
		var v: Dictionary = vs[fid]
		txt += "  %d. %s — %d/%d (%+d)\n" % [pos, CoinTheme.faction_label(fid), int(v["value"]), int(v["threshold"]), int(v["margin"])]
		pos += 1
	txt += "\nVassallaggi: tedesco %d · russo %d · Polarizzazione %d\nPropaganda giocate: %d/4" % [
		int(GameController.state.tracks.get("vassalage_german", 0)),
		int(GameController.state.tracks.get("vassalage_russian", 0)),
		int(GameController.state.tracks.get("polarization", 0)),
		GameController.propaganda_played]
	var dlg := AcceptDialog.new()
	dlg.title = "Fine partita"
	dlg.dialog_text = txt
	dlg.ok_button_text = "Chiudi"
	add_child(dlg)
	dlg.popup_centered()
	dlg.confirmed.connect(func(): dlg.queue_free())
	dlg.canceled.connect(func(): dlg.queue_free())


## I 4 numeri delle carte Propaganda (cards.json), in ordine di Round.
var _PROP_CARDS: Array = [22, 23, 46, 47]


## Numero carta per l'IMMAGINE: la Propaganda (sentinel 0) diventa quella specifica.
func _card_image_number(card_num: int) -> int:
	if card_num == 0 and _is_abb():
		return int(_PROP_CARDS[clampi(GameController.propaganda_played, 0, 3)])
	return card_num


## Carte e titolo dell'Evento (corrente e prossima).
func _refresh_event_box() -> void:
	var s: GameState = GameController.state
	var cc: int = s.current_card
	_cur_img.texture = CLAssets.card(_card_image_number(cc)) if cc >= 0 else null
	var nc: int = GameController.next_card()
	_next_img.texture = CLAssets.card(_card_image_number(nc)) if nc >= 0 else null
	if cc > 0:
		var c: CardDef = GameController.game_def.card(cc)
		var tag := ""
		if c.is_capability:
			tag = " · Capacità"
		elif c.is_momentum:
			tag = " · Momentum"
		_ev_title.text = "%d · %s" % [c.number, c.title]
		_ev_title.tooltip_text = "%s%s\n\n%s" % [c.title, tag, c.translation]
		_cur_img.tooltip_text = "%s%s\n\n%s\n\n(clicca per ingrandire)" % [c.title, tag, c.translation]
	elif cc == 0:
		_ev_title.text = "Propaganda"
		_ev_title.tooltip_text = ""
	else:
		_ev_title.text = "Mazzo esaurito"
		_ev_title.tooltip_text = ""


## Intestazione del pannello: Fazione di turno, posto nella sequenza, Risorse, ruolo.
func _refresh_panel_header(fid: String, sub: String, stamp: String) -> void:
	var col := CoinTheme.faction(fid) if fid != "" else CoinTheme.INK
	var hsb := CoinTheme.flat(col, 0)
	hsb.content_margin_left = 14
	hsb.content_margin_right = 14
	hsb.content_margin_top = 8
	hsb.content_margin_bottom = 8
	hsb.corner_radius_top_left = 2
	hsb.corner_radius_top_right = 2
	hsb.border_width_bottom = 3
	hsb.border_color = col.darkened(0.25) if fid != "" else CoinTheme.BRASS
	_head.add_theme_stylebox_override("panel", hsb)
	var fg := CoinTheme.faction_fg(fid) if fid != "" else CoinTheme.PAPER
	_head_tok.texture = CLAssets.res_token(fid) if fid != "" else null
	_head_tok.visible = fid != ""
	_head_name.text = CoinTheme.faction_label(fid) if fid != "" else "In attesa"
	_head_name.add_theme_color_override("font_color", fg)
	_head_sub.text = sub
	_head_sub.add_theme_color_override("font_color", CoinTheme.faction_fg_dim(fid) if fid != "" else CoinTheme.TEXT_DIM)
	_head_stamp.text = stamp
	_head_stamp.visible = stamp != ""
	_head_stamp.add_theme_color_override("font_color", fg)
	(_head_stamp.get_theme_stylebox("normal") as StyleBoxFlat).border_color = fg


## Evidenzia la scelta in corso e dà al tasto Esegui il nome di ciò che eseguirà.
func _mark_op_button() -> void:
	var op_on: String = _cur_action if _mode != "idle" and _cur_action != "" else ""
	var sa_on: String = _pending_sa
	var fcol := CoinTheme.faction_ink(_cur_faction)
	for op in _op_btn_map:
		var b: Button = _op_btn_map[op]
		if op == op_on:
			CoinTheme.accent_button(b, fcol, fcol)
		else:
			CoinTheme.style_button(b)
	for sa in _sa_btn_map:
		var sb: Button = _sa_btn_map[sa]
		if sa == sa_on:
			CoinTheme.accent_button(sb, fcol, fcol)
		else:
			CoinTheme.style_button(sb)
	for pair in [[_btn_ev_u, "unshaded"], [_btn_ev_s, "shaded"]]:
		var eb: Button = pair[0]
		if _event_side == pair[1]:
			CoinTheme.accent_button(eb, CoinTheme.INK, CoinTheme.INK, CoinTheme.PAPER)
		else:
			CoinTheme.style_button(eb)
	var label := "Esegui"
	if sa_on != "":
		label = "Esegui %s" % _sa_label(sa_on)
	elif op_on != "":
		label = "Esegui %s" % OP_NAMES.get(op_on, op_on)
	elif _event_side != "":
		label = "Esegui Evento %s" % ("chiaro" if _event_side == "unshaded" else "ombreggiato")
	_btn_exec.text = label
	_sa_desc.visible = sa_on != "" and _sa_desc.text != ""
	_op_desc.visible = op_on != "" and _op_desc.text != ""


## Scelta del lato dell'Evento: si esegue poi con "Esegui" (o "Concludi turno").
func _pick_event(side: String) -> void:
	if _event_side == side:
		_event_side = ""
	else:
		_clear_pending()
		_event_side = side
		_instr.text = "Evento %s scelto: premi 'Esegui' per giocarlo (chiude il turno della Fazione)." % \
			("chiaro" if side == "unshaded" else "ombreggiato")
	_refresh_turn_banner()


## Esegui la scelta preparata (se c'è) e concludi il turno della Fazione.
func _on_execute_and_end() -> void:
	if _event_side != "":
		_on_execute()   # l'Evento chiude già il turno della Fazione
		return
	if _pending_sa != "" or (_cur_action != "" and _mode != "idle"):
		if not _on_execute():
			return   # esecuzione fallita: l'errore è mostrato, il turno resta aperto
	GameController.end_turn()


func _set_btn(b: Button, on: bool) -> void:
	if b != null:
		b.disabled = not on


## C'è qualcosa in preparazione (spazi scelti, spostamenti, Att.Speciale)?
func _has_pending_choice() -> bool:
	return _pending_sa != "" or (_cur_action != "" and _mode != "idle")


func _refresh_turn_banner() -> void:
	if _btn_exec == null:
		return
	var st := GameController.seq_status()
	var card: int = GameController.state.current_card
	var turn_active: bool = st.get("active", false) and String(st.get("pending", "")) != ""
	# Cambio di Fazione PRIMA di abilitare i tasti appena ricreati.
	if turn_active and String(st["pending"]) != _cur_faction:
		_select_faction(String(st["pending"]))
	_set_btn(_btn_end, turn_active)
	_set_btn(_btn_clear, _mode != "idle" or _pending_sa != "" or not _selected.is_empty() \
		or not _pending_moves.is_empty() or _event_side != "")
	_set_btn(_btn_exec, turn_active and (_has_pending_choice() or _event_side != "" \
		or (not _is_abb() and _mode in ["sa_move_confirm", "sa_profit"])))
	_top.set_undo(GameController.undo_depth(), GameController.undo_label())
	_refresh_preview()
	_mark_op_button()
	var legal: Array = st.get("legal", [])
	var event_ok := turn_active and legal.has(CoinEnums.ActionType.EVENT) and card > 0
	_set_btn(_btn_ev_u, event_ok)
	_set_btn(_btn_ev_s, event_ok)
	if not event_ok:
		_event_side = ""
	var lim := GameController.seq_is_limited_only()
	var sa_legal := turn_active and legal.has(CoinEnums.ActionType.OPERATION_WITH_SPECIAL)
	var ph := int(GameController.state.tracks.get("phase", 1))
	# Un solo Comando e una sola Attività speciale per turno: scelto (o svolto) un
	# Comando, gli altri si bloccano; si può solo proseguire quello.
	var done_op: String = GameController.turn_op()
	var prep_op: String = _cur_action if _mode != "idle" and _cur_action != "" else ""
	var lock_op := prep_op if prep_op != "" else done_op
	var lim_used := lim and done_op != ""
	for op in _op_btn_map:
		var ob: Button = _op_btn_map[op]
		var why := _op_unavailable(op, ph)
		var locked: bool = lock_op != "" and op != lock_op
		ob.disabled = not turn_active or GameController.turn_event_done() or lim_used \
			or locked or _event_side != "" or why != ""
		if why != "":
			ob.tooltip_text = why
		elif locked:
			ob.tooltip_text = "In questo turno il Comando è %s" % OP_NAMES.get(lock_op, lock_op)
		else:
			ob.tooltip_text = OP_DESC.get(op, "")
	var sa_done := GameController.turn_special_done()
	for sa in _sa_btn_map:
		var sb: Button = _sa_btn_map[sa]
		var why_sa := _sa_unavailable(sa, ph)
		sb.disabled = not turn_active or not sa_legal or lim or sa_done \
			or (_pending_sa != "" and sa != _pending_sa) or _event_side != "" or why_sa != ""
		var base_tip := "%s\n%s" % [_sa_label(sa), SA_DESC.get(_sa_base(sa), "")]
		if why_sa != "":
			sb.tooltip_text = why_sa
		elif turn_active and (not sa_legal or lim):
			sb.tooltip_text = "%s\n\nIn questa casella della sequenza non è ammessa un'Attività speciale." % base_tip
		else:
			sb.tooltip_text = base_tip
	# Evento: solo se in questo turno non si è ancora fatto nulla.
	if done_op != "" or sa_done or prep_op != "" or _pending_sa != "":
		_set_btn(_btn_ev_u, false)
		_set_btn(_btn_ev_s, false)
	_set_btn(_btn_pass, turn_active and done_op == "" and not sa_done)

	if not turn_active:
		_turn_banner.add_theme_color_override("font_color", CoinTheme.INK)
		_refresh_panel_header("", "Nessuna Fazione di turno", "")
		if GameController.game_over:
			if GameController.winner != "":
				_turn_banner.text = "Partita conclusa — vince %s" % CoinTheme.faction_label(GameController.winner)
				_turn_banner.add_theme_color_override("font_color", CoinTheme.faction_ink(GameController.winner))
			else:
				_turn_banner.text = "Partita conclusa"
		elif card == -1:
			_turn_banner.text = "Mazzo esaurito"
		else:
			_turn_banner.text = ""
		_banner.visible = _turn_banner.text != "" or _instr.text != ""
		return
	var pending: String = st["pending"]
	_turn_banner.add_theme_color_override("font_color", CoinTheme.faction_ink(pending))
	var slot := "1ª" if st.get("first_slot", true) else "2ª"
	var s: GameState = GameController.state
	var res_txt := ("Risorse %d" % s.get_resources(pending)) if s.tracks_resources(pending) else "Risorse —"
	var lim_txt := " · Limitato" if lim else ""
	_refresh_panel_header(pending, "%s Fazione · %s%s" % [slot, res_txt, lim_txt],
		"IN AZIONE" if GameController.is_player(pending) else "BOT")
	_banner.visible = true
	if _mode == "idle" and _pending_sa == "":
		_op_desc.text = ""
	var step := ""
	if _pending_sa != "":
		step = "Att. speciale %s: %s" % [_sa_label(_pending_sa),
			"premi 'Esegui'" if _abb_sa_target != "" or not _sa_needs_space(_pending_sa) else "clicca lo spazio bersaglio evidenziato"]
	elif _mode == "idle":
		var acts: Array = []
		for a in legal:
			acts.append(ACTION_NAMES.get(int(a), str(a)))
		step = "scegli un Comando, un'Attività speciale o l'Evento (possibili: %s)" % ", ".join(acts)
		if done_op != "" or sa_done:
			var parts: Array = []
			if done_op != "":
				parts.append("%s svolto: puoi proseguirlo in altri spazi" % OP_NAMES.get(done_op, done_op))
			if not sa_done and sa_legal and not lim:
				parts.append("aggiungere un'Attività speciale")
			elif sa_done:
				parts.append("Attività speciale svolta")
			step = "%s, oppure 'Concludi turno'" % ", ".join(parts)
	elif _mode in ["moves", "abb_march_from", "abb_march_to"]:
		step = "%s: %d spostamenti in coda, poi 'Esegui' o 'Concludi turno'" % [
			OP_NAMES.get(_cur_action, _cur_action), _pending_moves.size()]
	else:
		step = "clicca gli spazi evidenziati (scelti: %d), poi 'Esegui' o 'Concludi turno'" % _selected.size()
	_turn_banner.text = step.substr(0, 1).to_upper() + step.substr(1)


## Motivo per cui un Comando non è disponibile in assoluto ("" = disponibile).
func _op_unavailable(op: String, ph: int) -> String:
	if not _is_abb():
		return ""
	if op in ["march", "attack"] and ph < 2:
		return "%s: disponibile solo in Fase II (dopo Red Revolt!, §3.2.4/§3.2.5)" % OP_NAMES.get(op, op)
	if op == "message":
		return "Messaggio: non ancora implementato nel motore"
	return ""


## Motivo per cui un'Attività speciale non è disponibile in assoluto ("" = disponibile).
func _sa_unavailable(sa: String, ph: int) -> String:
	if _is_abb() and sa == "coordinate":
		if ph < 2:
			return "Coordinamento: disponibile solo in Fase II (§4.2.4)"
		if int(GameController.state.tracks.get("coordinate_marker", 0)) > 0:
			return "Coordinamento: il marker è già sul cilindro tedesco"
	return ""


## Anteprima del Comando in preparazione: costo in Risorse ed esito previsto,
## calcolati simulando l'azione su una copia dello stato (non tocca la partita).
func _refresh_preview() -> void:
	if _preview == null:
		return
	var fid := _cur_faction
	var s: GameState = GameController.state
	var targets: Array = []   # [{kind, id, sid, args}]
	if _is_abb() and _pending_sa != "" and (_abb_sa_target != "" or not _sa_needs_space(_pending_sa)):
		targets.append({"kind": "sa", "id": _sa_base(_pending_sa), "sid": _abb_sa_target, "args": _sa_variant_p(_pending_sa)})
	elif _is_abb() and _cur_action == "march":
		for mv in _pending_moves:
			targets.append({"kind": "op", "id": "march", "sid": mv["to"], "args": mv})
	elif _is_abb() and _cur_action != "":
		for sid in _selected:
			targets.append({"kind": "op", "id": _cur_action, "sid": sid, "args": {"mode": _abb_rally_mode.get(sid, "cell")}})
	if targets.is_empty():
		_preview.text = "—"
		_preview.add_theme_color_override("font_color", CoinTheme.INK_FAINT)
		_preview.tooltip_text = ""
		return
	var cost := 0
	for t in targets:
		var r: Dictionary = GameController.abb_preview(String(t["kind"]), String(t["id"]), fid, String(t["sid"]), t["args"])
		if not r.get("ok", false):
			_preview.text = "⚠ non eseguibile"
			_preview.add_theme_color_override("font_color", CoinTheme.WARN_INK)
			_preview.tooltip_text = String(r.get("error", ""))
			return
		cost += int(r.get("cost", 0))
	if not s.tracks_resources(fid):
		_preview.text = "costo — (Bot)"
		_preview.add_theme_color_override("font_color", CoinTheme.INK_DIM)
		_preview.tooltip_text = "Le Fazioni Bot non pagano Risorse (§8.1.2)"
		return
	var have := s.get_resources(fid)
	_preview.text = "costo %d / %d" % [cost, have]
	_preview.add_theme_color_override("font_color", CoinTheme.OK_INK if cost <= have else CoinTheme.ERR_INK)
	_preview.tooltip_text = "Costo previsto in Risorse (ogni spazio simulato da solo)"


func _select_faction(fid: String) -> void:
	_cur_faction = fid
	_rebuild_action_buttons(fid)
	_clear_pending()


## Ricrea i tasti dei Comandi e delle Attività speciali per la Fazione data:
## un tasto per ogni Attività speciale e per ogni sua variante (niente tendine).
func _rebuild_action_buttons(fid: String) -> void:
	for c in _op_btns.get_children():
		c.queue_free()
	_op_btn_map.clear()
	var fdef: FactionDef = GameController.game_def.faction(fid)
	if fdef == null:
		return
	for op in fdef.operations:
		var ob: Button = _mk_btn(OP_NAMES.get(op, op), _start_op.bind(op))
		ob.tooltip_text = OP_DESC.get(op, "")
		ob.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ob.custom_minimum_size = Vector2(0, 38)
		ob.add_theme_font_size_override("font_size", 16)
		_op_btns.add_child(ob)
		_op_btn_map[op] = ob
	for c in _sa_btns.get_children():
		c.queue_free()
	_sa_btn_map.clear()
	for sa in fdef.special_activities:
		var ids: Array = []
		if SA_VARIANTS.has(sa):
			for v in SA_VARIANTS[sa]:
				ids.append(String(v["id"]))
		else:
			ids.append(String(sa))
		for id in ids:
			var sb: Button = _mk_btn(_sa_label(id), _do_special.bind(id))
			sb.custom_minimum_size = Vector2(0, 32)
			sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			sb.clip_text = true
			sb.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			sb.add_theme_font_size_override("font_size", 14)
			_sa_btns.add_child(sb)
			_sa_btn_map[id] = sb


## Messaggio di ERRORE nella riga istruzioni: ceralacca, poi torna all'inchiostro.
func _err(text: String) -> void:
	_instr.text = text
	_banner.visible = true
	_instr.add_theme_color_override("font_color", CoinTheme.ERR_INK)
	var tw := create_tween()
	tw.tween_interval(2.5)
	tw.tween_callback(func(): _instr.add_theme_color_override("font_color", CoinTheme.INK))


# ---------------------------------------------------------------------------
# Menu di partita, ruoli, Bot
# ---------------------------------------------------------------------------

func _on_game_menu(id: int) -> void:
	match id:
		TopBar.MenuId.NEW_GAME:
			_confirm_new.popup_centered()
		TopBar.MenuId.ALL_BOTS:
			_on_all_bots()
		TopBar.MenuId.FULL_GAME:
			GameController.run_full_game_paced()
		TopBar.MenuId.SPEED_SLOW:
			GameController.pace_delay = 1.8
		TopBar.MenuId.SPEED_MED:
			GameController.pace_delay = 1.1
		TopBar.MenuId.SPEED_FAST:
			GameController.pace_delay = 0.7
		TopBar.MenuId.COORDINATE:
			_on_coordinate_germans()


func _on_all_bots() -> void:
	# Risolve la carta corrente con i bot, una mossa alla volta (con pausa/flash).
	GameController.run_card_paced()


## Marker Coordinate (§4.2.4): interruttore manuale (Menu › Potenze) che fa decidere
## al Senato l'azione dei Germans questo turno. Solo in Fase II.
func _on_coordinate_germans() -> void:
	if int(GameController.state.tracks.get("phase", 1)) < 2:
		return
	var cur := int(GameController.state.tracks.get("coordinate_marker", 0))
	GameController.state.tracks["coordinate_marker"] = 0 if cur > 0 else 1
	GameController.emit_signal("state_changed")


func _toggle_role(fid: String) -> void:
	# Le Potenze (Germania/Russia) sono sempre gestite dal motore.
	if _is_abb() and fid in ["germans", "russians"]:
		return
	GameController.set_role(fid, "bot" if GameController.is_player(fid) else "player")


func _toggle_auto_bot() -> void:
	_auto_bot = not _auto_bot
	_top.set_auto_bot(_auto_bot)


func _auto_bot_tick() -> void:
	if not _auto_bot or GameController.game_over or _mode != "idle" or _pending_sa != "":
		return
	var s: GameState = GameController.state
	if s == null or s.current_card <= 0:
		return
	var st := GameController.seq_status()
	var pending := String(st.get("pending", ""))
	if pending != "" and bool(st.get("active", false)) and GameController.is_bot(pending):
		GameController.bot_act_pending()


## Nuova partita: ripulisce il registro e la selezione, poi reinizializza.
func _on_new_game() -> void:
	_clear_pending()
	_log.clear_log()
	_prev_pc = {}
	_prev_fp = {}
	GameController.new_game()
	_view_island()


## "Annulla scelta": scarta soltanto la selezione in preparazione (mai distruttivo).
func _on_cancel_selection() -> void:
	var had := _mode != "idle" or _pending_sa != "" or not _selected.is_empty() \
		or not _pending_moves.is_empty() or _event_side != ""
	_clear_pending()
	_instr.text = "Scelta annullata" if had else "Niente da annullare in preparazione"
	_refresh_turn_banner()


## "Annulla" (barra superiore): disfa l'ultima azione già eseguita su questa carta.
func _on_undo_action() -> void:
	if GameController.undo_last():
		_clear_pending()
		_instr.text = "Azione annullata"
	else:
		_err("Nessuna azione da annullare su questa carta")
	_refresh_turn_banner()


## Pulizia interna della selezione/coda in preparazione (senza undo).
func _clear_pending() -> void:
	_mode = "idle"
	_cur_action = ""
	_event_side = ""
	_selected.clear()
	_rally_choice.clear()
	_train_plan.clear()
	_build_choice.clear()
	_garrison_ec = ""
	_reprisal_from = ""
	_attack_target.clear()
	_sa_move_to = ""
	_sa_move_count = 0
	_sa_spaces = []
	_pending_moves.clear()
	_pending_sa = ""
	_sa_from = ""
	_sa_valid = []
	_abb_rally_mode.clear()
	_abb_march_from = ""
	_abb_sa_target = ""
	_resume_mode = "idle"
	if _op_desc != null:
		_op_desc.text = ""
		_sa_desc.text = ""
	_clear_highlights()
	_update_moves_overlay()
	if _instr != null:
		_instr.text = ""


func _clear_highlights() -> void:
	for sid in _space_views.keys():
		_space_views[sid].set_highlight(false)


## Aggiorna le frecce di anteprima degli spostamenti in coda.
func _update_moves_overlay() -> void:
	if _moves_overlay == null:
		return
	var segs: Array = []
	for m in _pending_moves:
		var fi: String = m["from"]
		var ti: String = m["to"]
		if _space_views.has(fi) and _space_views.has(ti):
			var fv: RegionView = _space_views[fi]
			var tv: RegionView = _space_views[ti]
			segs.append({"from": fv.center_point(), "to": tv.center_point()})
	_moves_overlay.set_segments(segs)


func _space_name(sid: String) -> String:
	var sd: SpaceDef = GameController.game_def.space(sid)
	return sd.name if sd != null else sid


# ---------------------------------------------------------------------------
# Flusso azione: smistamento fra All Bridges Burning e Cuba Libre
# ---------------------------------------------------------------------------

## Avvia il Comando scelto (tasto): evidenzia gli spazi validi e imposta il flusso.
func _start_op(op_id: String) -> void:
	_event_side = ""
	if _is_abb():
		_abb_start_op(op_id)
	else:
		_cuba_start_op(op_id)
	_op_desc.text = OP_DESC.get(op_id, "")
	_refresh_turn_banner()


func _on_space_clicked(sid: String) -> void:
	if _is_abb():
		_abb_space_clicked(sid)
	else:
		_cuba_space_clicked(sid)


## Esegue la scelta preparata. Restituisce true se è andata a buon fine.
func _on_execute() -> bool:
	if _event_side != "":
		var side := _event_side
		_event_side = ""
		_on_event(side)
		return true
	if _is_abb():
		return _abb_execute()
	return _cuba_execute()


## Avvia l'Attività speciale (tasto): evidenzia SOLO gli spazi dove ha davvero effetto.
func _do_special(sa: String) -> void:
	if _pending_sa == sa:
		# Secondo clic sullo stesso tasto: rinuncia all'Att.Speciale (il Comando resta).
		_abb_end_sa()
		return
	var why := GameController.special_block_reason()
	if _limited or GameController.seq_is_limited_only():
		_err("Comando Limitato: niente Attività speciale")
		return
	if why != "":
		_err(why)
		return
	_event_side = ""
	if _is_abb():
		_abb_start_special(sa)
	else:
		_cuba_start_special(sa)
	# Le descrizioni ABB iniziano già col nome dell'Attività: niente doppione.
	var sdesc: String = SA_DESC.get(_sa_base(sa), "")
	var sname: String = SA_NAMES.get(_sa_base(sa), "")
	_sa_desc.text = sdesc if sname != "" and sdesc.begins_with(sname) else "%s: %s" % [_sa_label(sa), sdesc]
	_refresh_turn_banner()


## Gioca l'Evento della carta corrente (lato chiaro/ombreggiato).
func _on_event(side: String) -> void:
	var params := {}
	if _selected.size() > 0:
		params["space"] = _selected[0]
	var res := GameController.play_event(side, params)
	_clear_pending()
	if not res.get("ok", false):
		_err("! " + String(res.get("error", "Evento non eseguibile")))
	else:
		_instr.text = "Evento giocato - turno concluso"
	_refresh_turn_banner()


func _on_piece_dropped(from_id: String, to_id: String, faction: String, type: String) -> void:
	if _is_abb():
		# Marcia ABB anche trascinando una propria Cellula: equivale ai due clic.
		if _cur_action == "march" and faction == _cur_faction and type == "cell":
			_abb_queue_march(from_id, to_id)
		else:
			_err("Per spostare le Cellule scegli prima il Comando Marcia (Fase II)")
		return
	_cuba_piece_dropped(from_id, to_id, faction, type)


# ---------------------------------------------------------------------------
# All Bridges Burning: Comandi
# ---------------------------------------------------------------------------

## Spazi dove il Comando avrebbe effetto ORA (simulazione su copia dello stato).
func _abb_op_valid(op_id: String, args: Dictionary = {}) -> Array:
	var out: Array = []
	var used: Array = GameController.turn_op_spaces()
	for sid in _space_views.keys():
		if used.has(sid):
			continue
		if bool(GameController.abb_preview("op", op_id, _cur_faction, sid, args).get("ok", false)):
			out.append(sid)
	return out


## Origini valide per la Marcia: spazi con Cellule clandestine proprie da cui almeno
## una destinazione adiacente è raggiungibile.
func _abb_march_origins() -> Array:
	var out: Array = []
	for sid in _space_views.keys():
		if not _abb_march_dests(sid).is_empty():
			out.append(sid)
	return out


func _abb_march_queued_from(from_id: String) -> int:
	var n := 0
	for mv in _pending_moves:
		if String(mv["from"]) == from_id:
			n += int(mv["count"])
	return n


func _abb_march_dests(from_id: String) -> Array:
	var out: Array = []
	var st: SpaceState = GameController.state.space_state(from_id)
	if st == null or st.count(_cur_faction, "cell", "underground") <= _abb_march_queued_from(from_id):
		return out
	for to in GameController.game_def.space(from_id).adjacent:
		var args := {"from": from_id, "to": String(to), "count": 1, "type": "cell"}
		if bool(GameController.abb_preview("op", "march", _cur_faction, String(to), args).get("ok", false)):
			out.append(String(to))
	return out


func _abb_start_op(op_id: String) -> void:
	if _cur_action == op_id and _mode != "idle":
		_err("%s già scelto: clicca gli spazi, poi 'Esegui' (o 'Annulla scelta')" % OP_NAMES.get(op_id, op_id))
		return
	var why := GameController.op_block_reason(op_id, {})
	if why != "":
		_err(why)
		return
	_pending_sa = ""
	_abb_sa_target = ""
	_cur_action = op_id
	_selected.clear()
	_pending_moves.clear()
	_abb_rally_mode.clear()
	_limited = GameController.seq_is_limited_only()
	var lim := " (Limitato: 1 spazio)" if _limited else ""
	if op_id == "march":
		_mode = "abb_march_from"
		_abb_march_from = ""
		_abb_highlight(_abb_march_origins())
		_instr.text = "Marcia%s — clicca uno spazio con tue Cellule clandestine, poi uno adiacente." % lim
		if _abb_march_origins().is_empty():
			_err("Marcia: nessuna Cellula clandestina può muovere ora")
	else:
		_mode = "abb_space_pick"
		var valid := _abb_op_valid(op_id)
		_abb_highlight(valid)
		_instr.text = "%s%s — clicca gli spazi evidenziati, poi 'Esegui'." % [OP_NAMES.get(op_id, op_id), lim]
		if valid.is_empty():
			_err("%s: nessuno spazio dove sia possibile al momento" % OP_NAMES.get(op_id, op_id))


func _abb_highlight(spaces: Array) -> void:
	_clear_highlights()
	for sid in spaces:
		if _space_views.has(sid):
			_space_views[sid].set_highlight(true)
	for sid in _selected:
		if _space_views.has(sid):
			_space_views[sid].set_highlight(true)


## Modalità di Rally possibili in uno spazio (la 1ª è il default).
func _abb_rally_modes(sid: String) -> Array:
	var out: Array = []
	for mode in ["cell", "admin", "network"]:
		var pt: String = "admin" if mode == "admin" else ("network" if mode == "network" else "cell")
		if GameController.state.available(_cur_faction, pt) <= 0 and mode != "cell":
			continue
		if bool(GameController.abb_preview("op", "rally", _cur_faction, sid, {"mode": mode}).get("ok", false)):
			out.append(mode)
	return out


const _RALLY_LABEL := {"cell": "Cellule", "admin": "Amministrazione", "network": "Network"}


func _abb_space_clicked(sid: String) -> void:
	# Attività speciale in corso: il clic sceglie il bersaglio.
	if _pending_sa != "":
		if not _sa_needs_space(_pending_sa):
			return
		if not _abb_sa_valid(_pending_sa).has(sid):
			_err("%s: spazio non valido, scegline uno evidenziato" % _sa_label(_pending_sa))
			return
		_abb_sa_target = "" if _abb_sa_target == sid else sid
		_clear_highlights()
		if _abb_sa_target != "":
			_space_views[sid].set_highlight(true)
			_space_views[sid].flash(CoinTheme.FROST)
			_instr.text = "%s su %s — premi 'Esegui'." % [_sa_label(_pending_sa), _space_name(sid)]
		else:
			_abb_highlight(_abb_sa_valid(_pending_sa))
		_refresh_turn_banner()
		return
	match _mode:
		"abb_space_pick":
			if _selected.has(sid):
				# Rally: riclicca per cambiare cosa piazzare, poi deseleziona.
				if _cur_action == "rally":
					var modes := _abb_rally_modes(sid)
					var i := modes.find(String(_abb_rally_mode.get(sid, "cell")))
					if i + 1 < modes.size():
						_abb_rally_mode[sid] = modes[i + 1]
					else:
						_selected.erase(sid)
						_abb_rally_mode.erase(sid)
				else:
					_selected.erase(sid)
			else:
				if not _abb_op_valid(_cur_action).has(sid):
					_err("%s: qui non è possibile, scegli uno spazio evidenziato" % OP_NAMES.get(_cur_action, _cur_action))
					return
				if _limited and _selected.size() >= 1:
					_selected.clear()
					_abb_rally_mode.clear()
				_selected.append(sid)
				if _cur_action == "rally":
					var m0 := _abb_rally_modes(sid)
					_abb_rally_mode[sid] = m0[0] if not m0.is_empty() else "cell"
				_space_views[sid].flash(Color(0.4, 1.0, 0.5))
			_abb_highlight(_abb_op_valid(_cur_action))
			var parts: Array = []
			for s in _selected:
				var extra := ""
				if _cur_action == "rally":
					extra = " [%s]" % _RALLY_LABEL.get(_abb_rally_mode.get(s, "cell"), "")
				parts.append(_space_name(s) + extra)
			_instr.text = ("%s: %s — 'Esegui'%s" % [OP_NAMES.get(_cur_action, _cur_action), ", ".join(parts),
				"; riclicca per cambiare cosa piazzare" if _cur_action == "rally" else ""]) \
				if not parts.is_empty() else "%s: clicca gli spazi evidenziati" % OP_NAMES.get(_cur_action, _cur_action)
		"abb_march_from":
			if not _abb_march_origins().has(sid):
				_err("Marcia: scegli uno spazio evidenziato con tue Cellule clandestine")
				return
			_abb_march_from = sid
			_mode = "abb_march_to"
			_clear_highlights()
			_space_views[sid].set_highlight(true)
			for d in _abb_march_dests(sid):
				_space_views[d].set_highlight(true)
			_instr.text = "Marcia da %s — clicca lo spazio ADIACENTE di destinazione (riclicca %s per cambiare origine)." % [
				_space_name(sid), _space_name(sid)]
		"abb_march_to":
			if sid == _abb_march_from:
				_mode = "abb_march_from"
				_abb_march_from = ""
				_abb_highlight(_abb_march_origins())
				_instr.text = "Marcia — clicca uno spazio con tue Cellule clandestine."
			else:
				_abb_queue_march(_abb_march_from, sid)
	_refresh_turn_banner()


## Mette in coda 1 Cellula da `from_id` a `to_id` (stessa coppia = +1 Cellula).
func _abb_queue_march(from_id: String, to_id: String) -> void:
	if not _abb_march_dests(from_id).has(to_id):
		_err("Marcia: destinazione non valida (adiacente, bordo non sabotato, Cellule clandestine disponibili)")
		return
	if _limited:
		for mv in _pending_moves:
			if String(mv["to"]) != to_id:
				_err("Comando Limitato: una sola destinazione")
				return
	var found := false
	for mv in _pending_moves:
		if String(mv["from"]) == from_id and String(mv["to"]) == to_id:
			mv["count"] = int(mv["count"]) + 1
			found = true
	if not found:
		_pending_moves.append({"from": from_id, "to": to_id, "count": 1, "type": "cell"})
	_space_views[from_id].flash(Color(0.35, 0.6, 1.0))
	_space_views[to_id].flash(Color(0.4, 1.0, 0.5))
	_update_moves_overlay()
	_mode = "abb_march_from"
	_abb_march_from = ""
	_abb_highlight(_abb_march_origins())
	var parts: Array = []
	for mv in _pending_moves:
		parts.append("%d da %s a %s" % [int(mv["count"]), _space_name(mv["from"]), _space_name(mv["to"])])
	_instr.text = "Marcia: %s — altri spostamenti o 'Esegui'." % "; ".join(parts)


## Esegue la scelta ABB preparata: prima l'Attività speciale, se c'è, poi il Comando.
func _abb_execute() -> bool:
	var fid := _cur_faction
	if _pending_sa != "":
		if _sa_needs_space(_pending_sa) and _abb_sa_target == "":
			_err("%s: scegli prima lo spazio bersaglio" % _sa_label(_pending_sa))
			return false
		var sa := _pending_sa
		var res: Dictionary = GameController.abb_special(_sa_base(sa), fid, _abb_sa_target, _sa_variant_p(sa))
		_abb_log(_sa_label(sa), _space_name(_abb_sa_target) if _abb_sa_target != "" else "", res)
		if not res.get("ok", false):
			return false
		_abb_end_sa()
		return true
	if _cur_action == "" or _mode == "idle":
		return false
	var op := _cur_action
	if op == "march":
		if _pending_moves.is_empty():
			_err("Marcia: metti in coda almeno uno spostamento")
			return false
		while not _pending_moves.is_empty():
			var mv: Dictionary = _pending_moves[0]
			var r: Dictionary = GameController.abb_operation("march", fid, String(mv["to"]), mv)
			_abb_log(OP_NAMES["march"], "%s → %s (%d)" % [_space_name(mv["from"]), _space_name(mv["to"]), int(mv["count"])], r)
			if not r.get("ok", false):
				_update_moves_overlay()
				return false
			_pending_moves.remove_at(0)
	else:
		if _selected.is_empty():
			_err("%s: scegli almeno uno spazio" % OP_NAMES.get(op, op))
			return false
		while not _selected.is_empty():
			var sid: String = _selected[0]
			var r2: Dictionary = GameController.abb_operation(op, fid, sid, {"mode": _abb_rally_mode.get(sid, "cell")})
			_abb_log(OP_NAMES.get(op, op), _space_name(sid), r2)
			if not r2.get("ok", false):
				return false
			_selected.remove_at(0)
	_clear_pending()
	_instr.text = "%s eseguito: puoi proseguirlo in altri spazi, aggiungere un'Attività speciale o 'Concludi turno'." % OP_NAMES.get(op, op)
	_refresh_turn_banner()
	return true


## Riga di registro dell'esito di un Comando/Att.Speciale ABB del giocatore.
func _abb_log(label: String, target: String, res: Dictionary) -> void:
	var ok: bool = bool(res.get("ok", false))
	var msg: String = "%s %s%s" % ["✓" if ok else "✗", label, (" @ " + target) if target != "" else ""]
	if not ok:
		msg += " — " + String(res.get("error", ""))
		_err(msg)
	elif res.has("roll"):
		msg += " (1d6=%d/%d)" % [int(res["roll"]), int(res.get("strength", 0))]
	GameController.emit_signal("action_logged", msg, _cur_faction if ok else "")
	if ok:
		_instr.text = msg
	GameController.emit_signal("state_changed")


# ---------------------------------------------------------------------------
# All Bridges Burning: Attività speciali
# ---------------------------------------------------------------------------

## Att.Speciali senza spazio bersaglio (si confermano subito con "Esegui").
func _sa_needs_space(sa: String) -> bool:
	return not (_sa_base(sa) in ["coordinate", "foreign_relations"])


## Spazi dove l'Att.Speciale ABB avrebbe effetto (simulazione su copia).
func _abb_sa_valid(sa: String) -> Array:
	var out: Array = []
	for sid in _space_views.keys():
		if bool(GameController.abb_preview("sa", _sa_base(sa), _cur_faction, sid, _sa_variant_p(sa)).get("ok", false)):
			out.append(sid)
	return out


func _abb_start_special(sa: String) -> void:
	_pending_sa = sa
	_abb_sa_target = ""
	_clear_highlights()
	if not _sa_needs_space(sa):
		var pv: Dictionary = GameController.abb_preview("sa", _sa_base(sa), _cur_faction, "", _sa_variant_p(sa))
		if not pv.get("ok", false):
			_pending_sa = ""
			_err("%s: %s" % [_sa_label(sa), String(pv.get("error", "non possibile"))])
			_abb_restore_op_highlight()
			return
		_instr.text = "%s — premi 'Esegui'." % _sa_label(sa)
		return
	var valid := _abb_sa_valid(sa)
	if valid.is_empty():
		_pending_sa = ""
		_err("%s: nessuno spazio valido al momento" % _sa_label(sa))
		_abb_restore_op_highlight()
		return
	for sid in valid:
		_space_views[sid].set_highlight(true)
	_instr.text = "%s — clicca lo spazio bersaglio evidenziato, poi 'Esegui'." % _sa_label(sa)


## Fine (o rinuncia) dell'Att.Speciale: il Comando in preparazione riprende da dov'era.
func _abb_end_sa() -> void:
	if not _is_abb():
		_end_sa()
		return
	_pending_sa = ""
	_abb_sa_target = ""
	_sa_desc.text = ""
	_abb_restore_op_highlight()
	_refresh_turn_banner()


func _abb_restore_op_highlight() -> void:
	_clear_highlights()
	if _cur_action == "" or _mode == "idle":
		return
	if _mode == "abb_march_from" or _mode == "abb_march_to":
		_mode = "abb_march_from"
		_abb_march_from = ""
		_abb_highlight(_abb_march_origins())
	else:
		_abb_highlight(_abb_op_valid(_cur_action))
	_instr.text = "Continua %s, poi 'Esegui' o 'Concludi turno'" % OP_NAMES.get(_cur_action, _cur_action)


## Att.Speciale di base dietro a un id-variante ("bribe:cubes" -> "bribe").
func _sa_base(sa: String) -> String:
	var i := sa.find(":")
	return sa.substr(0, i) if i >= 0 else sa


## Parametri extra di una variante, o {} se non è una variante.
func _sa_variant_p(sa: String) -> Dictionary:
	var base := _sa_base(sa)
	for v in SA_VARIANTS.get(base, []):
		if v["id"] == sa:
			return v["p"]
	return {}


## Etichetta da mostrare (variante o nome base).
func _sa_label(sa: String) -> String:
	var base := _sa_base(sa)
	for v in SA_VARIANTS.get(base, []):
		if v["id"] == sa:
			return v["label"]
	return SA_NAMES.get(sa, sa)


# ---------------------------------------------------------------------------
# Animazioni dei pezzi e lampeggi (comuni)
# ---------------------------------------------------------------------------

## Centri normalizzati dei box "Forze Disponibili" (per animare piazzamenti/rimozioni).
func _load_avail_boxes() -> Dictionary:
	var out: Dictionary = {}
	var data = JSON.parse_string(FileAccess.get_file_as_string(GameRegistry.data_path("board_layout.json")))
	if typeof(data) != TYPE_DICTIONARY:
		return out
	var box: Dictionary = data.get("box", {})
	for f in GameController.game_def.factions:
		var fid: String = f.id
		var r = box.get("available_%s" % fid, null)
		if r != null:
			out[fid] = Vector2((r[0] + r[2]) * 0.5, (r[1] + r[3]) * 0.5)
	return out


## Anima i pezzi che si sono spostati dall'ultimo aggiornamento: da zona a zona, e
## da/verso i box Forze Disponibili. Confronta i conteggi per (spazio, fazione, tipo).
func _animate_moves() -> void:
	if _anim_layer == null:
		return
	var s: GameState = GameController.state
	var base: Vector2 = _map.size
	# Nuovi conteggi
	var nc: Dictionary = {}
	for sid in _space_views.keys():
		var st: SpaceState = s.space_state(sid)
		for fdef in GameController.game_def.factions:
			var f: String = fdef.id
			for ptdef in GameController.game_def.piece_types:
				var t: String = ptdef.id
				var n := st.count(f, t)
				if n > 0:
					nc["%s|%s|%s" % [sid, f, t]] = n
	# Primo aggiornamento: memorizza soltanto.
	if _prev_pc.is_empty():
		_prev_pc = nc
		return
	# Raccoglie sorgenti e destinazioni per (fazione, tipo).
	var ghosts: Array = []   # {f,t,from,to}
	for fdef in GameController.game_def.factions:
		var f: String = fdef.id
		var bc_norm: Vector2 = _avail_box.get(f, Vector2(0.5, 0.5))
		var box_c := bc_norm * base
		for ptdef in GameController.game_def.piece_types:
			var t: String = ptdef.id
			var sources: Array = []   # [sid, qty]
			var dests: Array = []
			for sid in _space_views.keys():
				var key := "%s|%s|%s" % [sid, f, t]
				var d: int = int(nc.get(key, 0)) - int(_prev_pc.get(key, 0))
				if d < 0:
					sources.append([sid, -d])
				elif d > 0:
					dests.append([sid, d])
			# Accoppia sorgenti->destinazioni (movimento mappa->mappa); le restanti
			# destinazioni vengono dal box Disponibili, le restanti sorgenti vi tornano.
			var si := 0
			var sleft := 0 if sources.is_empty() else int(sources[0][1])
			for de in dests:
				var dv: RegionView = _space_views[de[0]]
				var dc := dv.center_point()
				for _k in range(int(de[1])):
					var from_pos := box_c
					if si < sources.size():
						var sv: RegionView = _space_views[sources[si][0]]
						from_pos = sv.center_point()
						sleft -= 1
						if sleft <= 0:
							si += 1
							sleft = 0 if si >= sources.size() else int(sources[si][1])
					ghosts.append({"f": f, "t": t, "from": from_pos, "to": dc})
			while si < sources.size():
				var rv: RegionView = _space_views[sources[si][0]]
				var sc := rv.center_point()
				for _k2 in range(sleft):
					ghosts.append({"f": f, "t": t, "from": sc, "to": box_c})
				si += 1
				sleft = 0 if si >= sources.size() else int(sources[si][1])
	_prev_pc = nc
	# Troppi movimenti insieme (nuova partita / Propaganda): salta per non intasare.
	if ghosts.size() > 24:
		return
	for g in ghosts:
		_spawn_ghost(String(g["f"]), String(g["t"]), g["from"], g["to"])


## Anima un pezzo che vola da `from_pos` a `to_pos` con una scia luminosa (effetto cometa):
## una "testa" brillante più alcune copie sfalsate che la inseguono attenuandosi.
func _spawn_ghost(faction: String, type: String, from_pos: Vector2, to_pos: Vector2) -> void:
	var tex := CLAssets.piece(faction, type, "")
	if tex == null:
		return
	var half := Vector2(ANIM_SZ, ANIM_SZ) * 0.5
	var echoes := 4
	for e in range(echoes):
		var g := TextureRect.new()
		g.texture = tex
		g.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		g.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		g.size = Vector2(ANIM_SZ, ANIM_SZ)
		g.pivot_offset = half
		g.mouse_filter = Control.MOUSE_FILTER_IGNORE
		g.position = from_pos - half
		var head := e == 0
		# Testa brillante e ingrandita; le copie della scia più piccole e attenuate.
		g.modulate = Color(1.5, 1.5, 1.2, 1.0) if head else Color(1.2, 1.2, 1.1, 0.5 - 0.1 * float(e))
		g.scale = Vector2(1.45, 1.45) if head else Vector2(1.2, 1.2)
		_anim_layer.add_child(g)
		var lead := float(e) * 0.08   # ritardo crescente -> la copia resta "indietro" (scia)
		var tw := create_tween()
		tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		if lead > 0.0:
			tw.tween_interval(lead)
		tw.tween_property(g, "position", to_pos - half, ANIM_DUR)
		tw.parallel().tween_property(g, "scale", Vector2(1, 1), ANIM_DUR)
		tw.parallel().tween_property(g, "modulate:a", 0.0, ANIM_DUR * 0.45).set_delay(ANIM_DUR * 0.55)
		tw.tween_callback(g.queue_free)


## Lampeggia gli spazi il cui stato è cambiato dall'ultimo aggiornamento (feedback visivo).
func _flash_changes() -> void:
	var s: GameState = GameController.state
	var first := _prev_fp.is_empty()
	for sid in _space_views.keys():
		var fp := _space_fp(s, sid)
		if not first and _prev_fp.get(sid, "") != fp:
			_space_views[sid].flash()
		_prev_fp[sid] = fp


func _space_fp(s: GameState, sid: String) -> String:
	var st: SpaceState = s.space_state(sid)
	var out := "%s,%d,%d,%d" % [st.control, st.support, st.marker("terror"), st.marker("sabotage")]
	for fdef in GameController.game_def.factions:
		for ptdef in GameController.game_def.piece_types:
			out += "," + str(st.count(fdef.id, ptdef.id))
	return out


# ---------------------------------------------------------------------------
# Cuba Libre (export alternativo dello stesso motore): flusso guidato originale
# ---------------------------------------------------------------------------

func _cuba_start_op(op_id: String) -> void:
	var kind: String = OP_KIND.get(op_id, "space_list")
	var valid := _valid_spaces(_cur_faction, op_id)
	if kind == "space_list" and valid.is_empty():
		_err("%s: nessuno spazio dove sia efficace al momento" % OP_NAMES.get(op_id, op_id))
		return
	_cur_action = op_id
	_selected.clear()
	_pending_moves.clear()
	_limited = GameController.seq_is_limited_only()
	_mode = kind
	_clear_highlights()
	for sid in valid:
		_space_views[sid].set_highlight(true)
	var lim := " (Op Limitata: 1 spazio, niente Att.Speciale)" if _limited else ""
	var hint := "trascina i pezzi nei loro spazi" if _mode == "moves" else "clicca gli spazi evidenziati"
	_instr.text = "%s%s — %s, poi 'Esegui' o 'Concludi turno'" % [OP_NAMES.get(op_id, op_id), lim, hint]


func _cuba_execute() -> bool:
	if _mode == "sa_move_confirm":
		if _sa_move_count <= 0:
			_err("Nessun cubo da spostare")
			return false
		_run_sa_move(_pending_sa, _sa_from, _sa_move_to, _sa_move_count)
		_sa_move_to = ""
		_end_sa()
		return true
	if _mode == "sa_profit":
		if _sa_spaces.is_empty():
			_err("Profitto: scegli almeno 1 Casinò")
			return false
		var pp := {"mode": _profit_mode}
		if _profit_mode == "cash":
			pp["spaces"] = _sa_spaces.duplicate()
		else:
			pp["close"] = _sa_spaces.duplicate()
		GameController.run_special("profit", pp)
		_sa_spaces = []
		_end_sa()
		return true
	if _cur_action == "":
		return false
	var res: Dictionary = GameController.run_operation(_cur_action, _build_params())
	if not res.get("ok", false):
		_err("✗ %s" % String(res.get("error", "Operazione non eseguibile")))
		return false
	_clear_pending()
	_refresh_turn_banner()
	return true


func _cuba_space_clicked(sid: String) -> void:
	# Bersaglio Attività Speciale
	if _mode == "sa_point":
		if not _sa_valid.has(sid):
			_instr.text = "%s: spazio non valido, scegline uno evidenziato" % _sa_label(_pending_sa)
			return
		# Rappresaglia: dopo il bersaglio, scelta opzionale dello spostamento di 1 Guerriglia.
		if _sa_base(_pending_sa) == "reprisal" and _reprisal_movable(sid) != "" and not _reprisal_dests(sid).is_empty():
			_reprisal_from = sid
			_sa_valid = _reprisal_dests(sid)
			_mode = "sa_reprisal"
			_clear_highlights()
			_space_views[sid].set_highlight(true)
			for d in _sa_valid:
				_space_views[d].set_highlight(true)
			_instr.text = "Rappresaglia a %s - clicca uno spazio ADIACENTE per spostarci 1 Guerriglia, oppure riclicca %s per non spostare" % [GameController.game_def.space(sid).name, GameController.game_def.space(sid).name]
			return
		_run_sa(_pending_sa, sid)
		_end_sa()
		return
	# Rappresaglia: 2° passo (spostamento opzionale).
	if _mode == "sa_reprisal":
		if sid == _reprisal_from:
			GameController.run_special("reprisal", {"space": _reprisal_from, "move": {}})
			_reprisal_from = ""
			_end_sa()
			return
		if not _sa_valid.has(sid):
			_instr.text = "Spostamento non valido: scegli uno spazio adiacente evidenziato"
			return
		GameController.run_special("reprisal", {"space": _reprisal_from, "move": {"faction": _reprisal_movable(_reprisal_from), "to": sid}})
		_reprisal_from = ""
		_end_sa()
		return
	if _mode == "sa_move":
		if _sa_from == "":
			if not _sa_valid.has(sid):
				_instr.text = "Origine non valida: scegline una evidenziata"
				return
			_sa_from = sid
			# Mostra solo le destinazioni valide per questa origine.
			_sa_valid = _sa_valid_dests(_pending_sa, sid)
			_clear_highlights()
			for d in _sa_valid:
				_space_views[d].set_highlight(true)
			if _sa_valid.is_empty():
				_instr.text = "Nessuna destinazione valida da %s - Annulla per cambiare" % GameController.game_def.space(sid).name
			else:
				_instr.text = "Origine: %s - clicca una DESTINAZIONE evidenziata" % GameController.game_def.space(sid).name
		else:
			if not _sa_valid.has(sid):
				_instr.text = "Destinazione non valida: scegline una evidenziata"
				return
			# Passo numero cubi: scegli quanti spostarne (riclicca la destinazione per ciclare).
			_sa_move_to = sid
			_sa_move_count = _sa_move_max(_pending_sa, _sa_from, sid)
			_mode = "sa_move_confirm"
			_clear_highlights()
			_space_views[sid].set_highlight(true)
			_sa_move_instr()
		return
	# Trasporto/Muscle: scelta del numero di cubi.
	if _mode == "sa_move_confirm":
		if sid == _sa_move_to:
			var mx := _sa_move_max(_pending_sa, _sa_from, _sa_move_to)
			_sa_move_count = (_sa_move_count % mx) + 1 if mx > 0 else 0
			_sa_move_instr()
		return
	# Profitto: selezione di 1-2 Casinò (cash) o dei Casinò da chiudere (convert).
	if _mode == "sa_profit":
		if not _sa_valid.has(sid):
			_instr.text = "Profitto: scegli uno spazio con Casinò aperto evidenziato"
			return
		if _sa_spaces.has(sid):
			_sa_spaces.erase(sid)
		elif _profit_mode == "cash" and _sa_spaces.size() >= 2:
			_instr.text = "Profitto (incassa): massimo 2 spazi"
			return
		else:
			_sa_spaces.append(sid)
		_space_views[sid].flash(Color(0.4, 1.0, 0.5))
		_profit_instr()
		return
	if _mode != "select_spaces" and _mode != "space_list":
		return
	# Riorganizzazione: ogni spazio ha un'AZIONE che si cambia ri-cliccando
	# (Guerriglie -> Base -> ... -> deseleziona), così si può anche costruire una Base.
	if _cur_action == "rally":
		_rally_click(sid)
		return
	if _cur_action == "train":
		_train_click(sid)
		return
	if _cur_action == "attack":
		_attack_click(sid)
		return
	if _cur_action == "build":
		_build_click(sid)
		return
	# Guarnigione (modalità trascinamento): clicca un EC per l'Assalto gratuito opzionale.
	if _cur_action == "garrison" and _mode == "moves":
		if GameController.game_def.space(sid).is_economic():
			_garrison_ec = "" if _garrison_ec == sid else sid
			_space_views[sid].flash(Color(1.0, 0.7, 0.3))
			var nm := GameController.game_def.space(sid).name
			_instr.text = ("Guarnigione: Assalto gratuito a %s - trascina i cubi e 'Esegui'" % nm) if _garrison_ec != "" else "Guarnigione: Assalto in EC annullato"
		return
	if _selected.has(sid):
		_selected.erase(sid)
	else:
		# Accetta solo gli spazi dove l'Operazione è efficace.
		if not _valid_spaces(_cur_faction, _cur_action).has(sid):
			_instr.text = "%s: qui non è efficace, scegli uno spazio evidenziato" % OP_NAMES.get(_cur_action, _cur_action)
			return
		if _limited and _selected.size() >= 1:
			for prev in _selected:
				_space_views[prev].set_highlight(false)
			_selected.clear()
		_selected.append(sid)
		_space_views[sid].set_highlight(true)
	_instr.text = "Selezionati: %s" % ", ".join(_selected)
	_refresh_turn_banner()


const RALLY_LABEL := {"place": "Guerriglie", "extra": "Guerriglie", "base": "Base", "flip": "Clandestine"}


## Azioni di Riorganizzazione possibili in uno spazio (la 1ª è il default).
func _rally_options(sid: String) -> Array:
	var f := _cur_faction
	var st: SpaceState = GameController.state.space_state(sid)
	var has_base := st.count(f, "base") > 0
	var opts: Array = ["extra"] if has_base else ["place"]
	if st.count(f, "guerrilla") >= 2 and GameController.module.can_place_base(GameController.state, sid, false):
		opts.append("base")  # sostituisci 2 Guerriglie con 1 Base
	if has_base and st.count(f, "guerrilla", "active") > 0:
		opts.append("flip")  # gira le Guerriglie Clandestine
	return opts


## Click su uno spazio durante la Riorganizzazione: seleziona o cicla l'azione.
func _rally_click(sid: String) -> void:
	if not _selected.has(sid):
		if not _valid_spaces(_cur_faction, "rally").has(sid):
			_instr.text = "Riorganizzazione: qui non è efficace, scegli uno spazio evidenziato"
			return
		_selected.append(sid)
		_rally_choice[sid] = _rally_options(sid)[0]
		_space_views[sid].set_highlight(true)
	else:
		var opts := _rally_options(sid)
		var i := opts.find(String(_rally_choice.get(sid, opts[0])))
		if i + 1 < opts.size():
			_rally_choice[sid] = opts[i + 1]   # azione successiva
		else:
			_selected.erase(sid)               # dopo l'ultima: deseleziona
			_rally_choice.erase(sid)
			_space_views[sid].set_highlight(false)
	var parts: Array = []
	for s in _selected:
		parts.append("%s [%s]" % [GameController.game_def.space(s).name, RALLY_LABEL.get(_rally_choice.get(s, "place"), "?")])
	_instr.text = "Riorganizza: %s - riclicca uno spazio per cambiare azione, poi 'Esegui'" % ", ".join(parts) if not parts.is_empty() else "Riorganizzazione: clicca gli spazi"
	_refresh_turn_banner()


# ---- Attacco: bersaglio (Fazione) scelto per ogni spazio ----

func _attack_enemies(sid: String) -> Array:
	var st: SpaceState = GameController.state.space_state(sid)
	var out: Array = []
	for ff in ["m26", "directorio", "syndicate", "government"]:
		if ff == _cur_faction:
			continue
		if st.count(ff, "guerrilla") + st.count(ff, "troops") + st.count(ff, "police") \
				+ st.count(ff, "base") + st.count(ff, "casino", "open") > 0:
			out.append(ff)
	return out

func _attack_click(sid: String) -> void:
	if not _selected.has(sid):
		if not _valid_spaces(_cur_faction, "attack").has(sid):
			_instr.text = "Attacco: serve una tua Guerriglia e un nemico - scegli uno spazio evidenziato"
			return
		_selected.append(sid)
		var en := _attack_enemies(sid)
		_attack_target[sid] = en[0] if not en.is_empty() else ""
		_space_views[sid].set_highlight(true)
	else:
		var en := _attack_enemies(sid)
		var i := en.find(String(_attack_target.get(sid, "")))
		if i + 1 < en.size():
			_attack_target[sid] = en[i + 1]
		else:
			_selected.erase(sid)
			_attack_target.erase(sid)
			_space_views[sid].set_highlight(false)
	var parts: Array = []
	for s in _selected:
		parts.append("%s -> %s" % [GameController.game_def.space(s).name, GameController.faction_name(String(_attack_target.get(s, "")))])
	_instr.text = "Attacco: %s - riclicca uno spazio per cambiare bersaglio, poi 'Esegui'" % ", ".join(parts) if not parts.is_empty() else "Attacco: clicca gli spazi"
	_refresh_turn_banner()


# ---- Addestramento (Train): cubi per spazio + 1 azione speciale (Base/Civica) ----

func _train_base_ok(sid: String) -> bool:
	var st: SpaceState = GameController.state.space_state(sid)
	return st.count("government", "troops") + st.count("government", "police") >= 2 \
		and GameController.module.can_place_base(GameController.state, sid, false)

func _train_civic_ok(sid: String) -> bool:
	var st: SpaceState = GameController.state.space_state(sid)
	return st.control == "government" and st.count("government", "troops") > 0 and st.count("government", "police") > 0

## Lo spazio che già ospita la singola Att. speciale di Train (Base/Civica), o "".
func _train_special_owner(exclude: String) -> String:
	for s in _train_plan:
		if s != exclude and String(_train_plan[s].get("kind", "cubes")) in ["base", "civic"]:
			return s
	return ""

func _train_click(sid: String) -> void:
	if not _selected.has(sid):
		if not _valid_spaces(_cur_faction, "train").has(sid):
			_instr.text = "Addestramento: scegli una Città o uno spazio con una Base del Governo"
			return
		_selected.append(sid)
		_train_plan[sid] = {"kind": "cubes", "n": 1}
		_space_views[sid].set_highlight(true)
	else:
		var p: Dictionary = _train_plan[sid]
		var kind := String(p["kind"])
		if kind == "cubes" and int(p["n"]) < 4:
			p["n"] = int(p["n"]) + 1
		elif kind == "cubes":
			# Una sola Att. speciale per Addestramento.
			if _train_special_owner(sid) == "" and _train_base_ok(sid):
				p["kind"] = "base"
			elif _train_special_owner(sid) == "" and _train_civic_ok(sid):
				p["kind"] = "civic"
			else:
				_train_drop(sid); _train_instr(); return
		elif kind == "base":
			if _train_civic_ok(sid):
				p["kind"] = "civic"
			else:
				_train_drop(sid); _train_instr(); return
		else:
			_train_drop(sid); _train_instr(); return
	_train_instr()

func _train_drop(sid: String) -> void:
	_selected.erase(sid)
	_train_plan.erase(sid)
	_space_views[sid].set_highlight(false)

func _train_instr() -> void:
	var parts: Array = []
	for s in _selected:
		var p: Dictionary = _train_plan.get(s, {"kind": "cubes", "n": 1})
		var nm: String = GameController.game_def.space(s).name
		match String(p["kind"]):
			"base": parts.append("%s [Base]" % nm)
			"civic": parts.append("%s [Civica]" % nm)
			_:
				var typ := "Polizia" if GameController.game_def.space(s).type == CoinEnums.SpaceType.CITY else "Truppe"
				parts.append("%s [%d %s]" % [nm, int(p["n"]), typ])
	_instr.text = "Addestramento: %s - riclicca per +cubo / Base / Civica, poi 'Esegui'" % ", ".join(parts) if not parts.is_empty() else "Addestramento: clicca gli spazi"
	_refresh_turn_banner()


# ---- Costruzione (Build, Sindacato): nuovo Casinò chiuso oppure apri uno chiuso ----

func _build_options(sid: String) -> Array:
	var s: GameState = GameController.state
	var st: SpaceState = s.space_state(sid)
	var opts: Array = []
	if st.count("syndicate", "casino", "closed") > 0:
		opts.append("open")
	if GameController.module.can_place_base(s, sid, true):
		opts.append("new")
	return opts if not opts.is_empty() else ["new"]

func _build_click(sid: String) -> void:
	if not _selected.has(sid):
		if not _valid_spaces(_cur_faction, "build").has(sid):
			_instr.text = "Costruzione: scegli uno spazio con Controllo Govt o Sindacato"
			return
		_selected.append(sid)
		_build_choice[sid] = _build_options(sid)[0]
		_space_views[sid].set_highlight(true)
	else:
		var opts := _build_options(sid)
		var i := opts.find(String(_build_choice.get(sid, opts[0])))
		if i + 1 < opts.size():
			_build_choice[sid] = opts[i + 1]
		else:
			_selected.erase(sid)
			_build_choice.erase(sid)
			_space_views[sid].set_highlight(false)
	var parts: Array = []
	for s in _selected:
		var lbl := "apri Casinò" if String(_build_choice.get(s, "new")) == "open" else "nuovo Casinò"
		parts.append("%s [%s]" % [GameController.game_def.space(s).name, lbl])
	_instr.text = "Costruzione: %s - riclicca per cambiare, poi 'Esegui'" % ", ".join(parts) if not parts.is_empty() else "Costruzione: clicca gli spazi"
	_refresh_turn_banner()


# ---- Trasporto/Muscle: numero di cubi ----

func _sa_move_max(sa: String, from_id: String, to_id: String) -> int:
	var from_st: SpaceState = GameController.state.space_state(from_id)
	if sa == "muscle":
		var dest: SpaceDef = GameController.game_def.space(to_id)
		var typ := "police" if dest.type == CoinEnums.SpaceType.CITY else "troops"
		return mini(2, from_st.count("government", typ))
	return mini(3, from_st.count("government", "troops"))

func _sa_move_instr() -> void:
	_instr.text = "%s: sposta %d da %s a %s - riclicca la destinazione per cambiare numero, poi 'Esegui'" % [
		_sa_label(_pending_sa), _sa_move_count,
		GameController.game_def.space(_sa_from).name, GameController.game_def.space(_sa_move_to).name]
	_refresh_turn_banner()

func _profit_instr() -> void:
	var names: Array = []
	for s in _sa_spaces:
		names.append(GameController.game_def.space(s).name)
	var verb := "incassa Denaro in" if _profit_mode == "cash" else "converti (chiudi)"
	_instr.text = "Profitto: %s %s - poi 'Esegui'" % [verb, ", ".join(names) if not names.is_empty() else "(scegli i Casinò)"]
	_refresh_turn_banner()


func _cuba_piece_dropped(from_id: String, to_id: String, faction: String, type: String) -> void:
	if _mode != "moves":
		_err("Per spostare i pezzi scegli prima un'operazione di movimento (Marcia / Perlustrazione / Guarnigione / Trasporto)")
		return
	if from_id == to_id:
		return
	_pending_moves.append({"from": from_id, "to": to_id, "count": 1, "type": type})
	# Feedback: lampeggia origine (blu) e destinazione (verde).
	if _space_views.has(from_id):
		_space_views[from_id].flash(Color(0.35, 0.6, 1.0))
	if _space_views.has(to_id):
		_space_views[to_id].flash(Color(0.4, 1.0, 0.5))
	var pn: String = PIECE_NAMES.get(type, type)
	var fn: String = GameController.game_def.space(from_id).name
	var tn: String = GameController.game_def.space(to_id).name
	_instr.text = "In coda (%d): 1 %s da %s -> %s - poi 'Esegui'" % [_pending_moves.size(), pn, fn, tn]
	_update_moves_overlay()
	_refresh_turn_banner()


func _cuba_start_special(sa: String) -> void:
	var sa_name: String = _sa_label(sa)
	var sa_desc: String = SA_DESC.get(_sa_base(sa), "")
	# Avvia la selezione del BERSAGLIO dell'Attività Speciale (prima/durante/dopo l'Operazione).
	var resume := _mode if _mode in ["space_list", "select_spaces", "moves"] else "idle"
	if _sa_base(sa) == "profit":
		var pvalid := _sa_valid_spaces(sa)
		if pvalid.is_empty():
			_instr.text = "%s: nessun Casinò aperto al momento" % sa_name
			return
		_resume_mode = resume
		_pending_sa = sa
		_profit_mode = String(_sa_variant_p(sa).get("mode", "cash"))
		_sa_spaces = []
		_sa_valid = pvalid
		_clear_highlights()
		for s in pvalid:
			_space_views[s].set_highlight(true)
		_mode = "sa_profit"
		_profit_instr()
		return
	if sa == "transport" or sa == "muscle":
		var origins := _sa_valid_origins(sa)
		if origins.is_empty():
			_instr.text = "%s: nessuna origine valida al momento" % sa_name
			return
		_resume_mode = resume
		_pending_sa = sa
		_sa_from = ""
		_sa_valid = origins
		_clear_highlights()
		for s in origins:
			_space_views[s].set_highlight(true)
		_mode = "sa_move"
		_instr.text = "%s - %s\n> clicca un'ORIGINE evidenziata, poi la destinazione" % [sa_name, sa_desc]
	else:
		var valid := _sa_valid_spaces(sa)
		if valid.is_empty():
			_instr.text = "%s: nessuno spazio valido al momento" % sa_name
			return
		_resume_mode = resume
		_pending_sa = sa
		_sa_from = ""
		_sa_valid = valid
		_clear_highlights()
		for s in valid:
			_space_views[s].set_highlight(true)
		_mode = "sa_point"
		_instr.text = "%s - %s\n> clicca uno spazio bersaglio evidenziato" % [sa_name, sa_desc]
	_refresh_turn_banner()


## Fazione Insorgente con una Guerriglia da spostare nella Rappresaglia (o "").
func _reprisal_movable(sid: String) -> String:
	var st: SpaceState = GameController.state.space_state(sid)
	for f in ["m26", "directorio", "syndicate"]:
		if st.count(f, "guerrilla") > 0:
			return f
	return ""


## Spazi adiacenti dove spostare la Guerriglia nella Rappresaglia.
func _reprisal_dests(sid: String) -> Array:
	return Array(GameController.game_def.space(sid).adjacent)


## sa_id effettivo (Imboscata dipende dalla Fazione attiva).
func _sa_target_id(sa: String) -> String:
	var base := _sa_base(sa)
	if base == "ambush":
		return "ambush_m26" if _cur_faction == "m26" else "ambush_dr"
	return base


## Parametri per un'Att.Speciale a bersaglio singolo su `space`.
func _sa_params(sa: String, space: String) -> Dictionary:
	var vp := _sa_variant_p(sa)
	match _sa_base(sa):
		"profit":
			if String(vp.get("mode", "cash")) == "convert":
				return {"mode": "convert", "close": [space]}
			return {"mode": "cash", "spaces": [space]}
		"reprisal": return {"space": space, "move": {}}
		"kidnap": return {"space": space, "target": String(vp.get("target", "government"))}
		"bribe": return {"space": space, "action": String(vp.get("action", "cubes"))}
		_: return {"space": space, "faction": _cur_faction}


## Spazi dove l'Att.Speciale a bersaglio singolo ha davvero effetto (simulazione su copia).
func _sa_valid_spaces(sa: String) -> Array:
	var out: Array = []
	var sid_id := _sa_target_id(sa)
	var st: GameState = GameController.state
	for s in _space_views.keys():
		# Profitto (anche "converti") agisce solo dove c'è un Casinò aperto da chiudere/usare.
		if _sa_base(sa) == "profit" and st.space_state(s).count("syndicate", "casino", "open") < 1:
			continue
		if GameController.can_special(sid_id, _sa_params(sa, s)):
			out.append(s)
	return out


## Origini valide per Trasporto/Muscle (devono avere i pezzi da spostare).
func _sa_valid_origins(sa: String) -> Array:
	var out: Array = []
	var st_all: GameState = GameController.state
	for sid in _space_views.keys():
		var sd: SpaceDef = GameController.game_def.space(sid)
		var st: SpaceState = st_all.space_state(sid)
		if sa == "transport":
			var from_ok := (sd.type == CoinEnums.SpaceType.CITY or st.count("government", "base") > 0)
			if from_ok and st.count("government", "troops") > 0:
				out.append(sid)
		elif sa == "muscle":
			if st.count("government", "police") > 0 or st.count("government", "troops") > 0:
				out.append(sid)
	return out


## Destinazioni valide per Trasporto/Muscle data l'origine scelta.
func _sa_valid_dests(sa: String, from_id: String) -> Array:
	var out: Array = []
	var st_all: GameState = GameController.state
	var from_st: SpaceState = st_all.space_state(from_id)
	for sid in _space_views.keys():
		if sid == from_id:
			continue
		var sd: SpaceDef = GameController.game_def.space(sid)
		var st: SpaceState = st_all.space_state(sid)
		if sa == "transport":
			out.append(sid)   # qualsiasi spazio
		elif sa == "muscle":
			var dest_ok := sd.is_economic() or st.count("syndicate", "casino", "open") > 0
			if not dest_ok:
				continue
			var needed := "police" if sd.type == CoinEnums.SpaceType.CITY else "troops"
			if from_st.count("government", needed) > 0:
				out.append(sid)
	return out


## Esegue l'Att.Speciale su uno spazio (specials a bersaglio singolo).
func _run_sa(sa: String, space: String) -> void:
	GameController.run_special(_sa_target_id(sa), _sa_params(sa, space))


## Esegue Trasporto/Muscle come spostamento origine->destinazione del numero scelto di cubi.
func _run_sa_move(sa: String, from_id: String, to_id: String, count: int) -> void:
	var p := {"from": from_id, "to": to_id, "count": count}
	if sa == "muscle":
		var dest: SpaceDef = GameController.game_def.space(to_id)
		p["type"] = "police" if dest.type == CoinEnums.SpaceType.CITY else "troops"
	GameController.run_special(sa, p)


func _end_sa() -> void:
	_pending_sa = ""
	_sa_from = ""
	_sa_valid = []
	_sa_move_to = ""
	_sa_move_count = 0
	_sa_spaces = []
	_reprisal_from = ""
	_clear_highlights()
	# Se l'Operazione era in corso, riprendila (Att.Speciale fatta DURANTE l'operazione).
	if _resume_mode != "idle" and _cur_action != "":
		_mode = _resume_mode
		for sid in _valid_spaces(_cur_faction, _cur_action):
			_space_views[sid].set_highlight(true)
		for sid in _selected:
			_space_views[sid].set_highlight(true)
		_instr.text = "Continua l'Operazione (clicca/trascina), poi 'Esegui' o 'Concludi turno'"
	else:
		_mode = "idle"
	_resume_mode = "idle"
	_refresh_turn_banner()



func _build_params() -> Dictionary:
	match _cur_action:
		"sweep":
			var dests := {}
			for m in _pending_moves:
				dests[m["to"]] = true
			return {"spaces": dests.keys(), "moves": _pending_moves}
		"garrison":
			var gp := {"moves": _pending_moves}
			if _garrison_ec != "":
				gp["assault_ec"] = _garrison_ec
			return gp
		"march":
			return {"faction": _cur_faction, "moves": _pending_moves}
		"rally":
			return {"faction": _cur_faction, "spaces": _selected, "choices": _rally_choice.duplicate()}
		"attack":
			return {"faction": _cur_faction, "spaces": _selected, "targets": _attack_target.duplicate()}
		"terror":
			return {"faction": _cur_faction, "spaces": _selected}
		"assault":
			return {"spaces": _selected}
		"build":
			return {"spaces": _selected, "choices": _build_choice.duplicate()}
		"train":
			var place := {}
			var special := {}
			for sid in _selected:
				var p: Dictionary = _train_plan.get(sid, {"kind": "cubes", "n": 1})
				match String(p["kind"]):
					"base": special = {"type": "base", "space": sid}
					"civic": special = {"type": "civic", "space": sid, "steps": 1}
					_:
						var typ := "police" if GameController.game_def.space(sid).type == CoinEnums.SpaceType.CITY else "troops"
						place[sid] = {typ: int(p["n"])}
			var out := {"spaces": _selected, "place": place}
			if not special.is_empty():
				out["special"] = special
			return out
		_:
			return {"spaces": _selected, "faction": _cur_faction}


# Spazi validi (best-effort per evidenziazione; il motore valida comunque all'esecuzione).
func _valid_spaces(faction: String, op: String) -> Array:
	var s: GameState = GameController.state
	var out: Array = []
	for sid in _space_views.keys():
		var sd: SpaceDef = GameController.game_def.space(sid)
		var st: SpaceState = s.space_state(sid)
		var ok := false
		match op:
			"train":
				# Addestramento: Città oppure spazio con una Base del Governo.
				ok = sd.type == CoinEnums.SpaceType.CITY or st.count("government", "base") > 0
			"garrison", "march", "sweep":
				ok = true   # Operazioni a spostamento: libere (trascina i pezzi)
			"rally":
				ok = sd.has_population()
				if faction == "m26" and st.support > 0: ok = false
				if faction == "directorio" and abs(st.support) == 2: ok = false
			"attack":
				ok = st.count(faction, "guerrilla") > 0 and _enemy_present(faction, st)
			"terror":
				ok = st.count(faction, "guerrilla", "underground") > 0
			"build":
				ok = sd.has_population() and (st.control == "government" or st.control == "syndicate") \
					and GameController.module.can_place_base(s, sid, true)
			"assault":
				# Assalto efficace: Truppe del Governo e bersagli scoperti.
				var enemy := st.count("m26", "guerrilla", "active") + st.count("directorio", "guerrilla", "active") \
					+ st.count("m26", "base") + st.count("directorio", "base") + st.count("syndicate", "casino", "open")
				ok = st.count("government", "troops") > 0 and enemy > 0
		if ok:
			out.append(sid)
	return out


## Almeno un pezzo nemico presente nello spazio (per la Fazione data).
func _enemy_present(faction: String, st: SpaceState) -> bool:
	for e in ["government", "m26", "directorio", "syndicate"]:
		if e != faction and st.count(e) > 0:
			return true
	return false

