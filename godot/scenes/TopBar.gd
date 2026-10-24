class_name TopBar
extends PanelContainer

## Barra superiore comune ai giochi COIN: emblema e titolo, una tessera per ogni
## Fazione giocabile (ordine sulla carta, ruolo Giocatore/Bot, stato, Risorse, barra
## della Vittoria con la tacca della soglia), le Potenze non giocanti (All Bridges
## Burning: Vassallaggi tedesco e russo + Polarizzazione), carte rimaste e comandi.
##
## Non conosce la logica di gioco: legge lo stato dal controller in `refresh()` e
## notifica le richieste con i segnali; la scena decide cosa farne.

signal role_toggle_requested(fid: String)
signal undo_requested
signal auto_bot_toggled
signal bot_turn_requested
signal menu_id_pressed(id: int)

const HEIGHT := 72.0
## Fazioni Potenza (mai giocate da un umano): una sola tessera riassuntiva.
const POWERS := ["germans", "russians"]
## Nome della metrica di vittoria di ogni Fazione (suggerimento della tessera).
const VIC_LABEL := {
	"reds": "Opposizione + Amministrazioni (§7.2)",
	"senate": "Popolazione delle Città controllate (§7.2)",
	"moderates": "min(Risorse, Issues + Network + 1 − Polarizzazione + 14) (§7.3)",
	"government": "Supporto", "m26": "Opposizione + Basi",
	"directorio": "Pop DR + Basi", "syndicate": "Casinò aperti",
}

## Voci del menu di partita (gli id arrivano alla scena con `menu_id_pressed`).
enum MenuId { NEW_GAME, ALL_BOTS, FULL_GAME, SPEED_SLOW, SPEED_MED, SPEED_FAST, COORDINATE }

var _factions: Array = []          ## Fazioni con tessera propria (giocabili)
var _has_powers := false
var _tiles: Dictionary = {}        ## fid -> {panel, order, name, sub, res, bar, vval}
var _powers: Dictionary = {}       ## {panel, bar_g, bar_r, val_g, val_r, pol, order}
var _turn_lbl: Label
var _phase_lbl: Label
var _brand: PanelContainer
var _brand_title: Label
var _brand_sub: Label
var _btn_undo: Button
var _btn_auto: Button
var _btn_bot: Button
var _menu: MenuButton
var _cmds: Array = []


func _init() -> void:
	custom_minimum_size = Vector2(0, HEIGHT)
	var sb := CoinTheme.flat(CoinTheme.BAR)
	sb.border_width_bottom = 3
	sb.border_color = CoinTheme.BRASS
	add_theme_stylebox_override("panel", sb)


func _ready() -> void:
	var gc = GameController
	for f in gc.game_def.factions:
		if String(f.id) in POWERS:
			_has_powers = true
		else:
			_factions.append(String(f.id))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	add_child(row)
	row.add_child(_build_brand())

	var tiles := HBoxContainer.new()
	tiles.add_theme_constant_override("separation", 6)
	var tiles_m := MarginContainer.new()
	for side in ["left", "right"]:
		tiles_m.add_theme_constant_override("margin_" + side, 10)
	for side in ["top", "bottom"]:
		tiles_m.add_theme_constant_override("margin_" + side, 7)
	tiles_m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tiles_m.add_child(tiles)
	row.add_child(tiles_m)
	for fid in _factions:
		tiles.add_child(_build_tile(fid))
	if _has_powers:
		tiles.add_child(_build_powers_tile())

	row.add_child(_vline())
	var turn_box := VBoxContainer.new()
	turn_box.alignment = BoxContainer.ALIGNMENT_CENTER
	turn_box.add_theme_constant_override("separation", -3)
	turn_box.custom_minimum_size = Vector2(92, 0)
	var tl := CoinTheme.label("CARTE", CoinTheme.TEXT_DIM, 12, CoinTheme.ui_bold())
	tl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	turn_box.add_child(tl)
	_turn_lbl = CoinTheme.label("—", Color.WHITE, 26, CoinTheme.display())
	_turn_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_turn_lbl.tooltip_text = "Carte rimaste nel mazzo"
	_turn_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	turn_box.add_child(_turn_lbl)
	_phase_lbl = CoinTheme.label("", CoinTheme.BRASS, 12, CoinTheme.ui_bold())
	_phase_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_phase_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	turn_box.add_child(_phase_lbl)
	row.add_child(turn_box)

	row.add_child(_vline())
	_btn_undo = _cmd_button("Annulla", "Disfa l'ultima azione eseguita su questa carta (Ctrl+Z)")
	_btn_undo.pressed.connect(func(): undo_requested.emit())
	row.add_child(_btn_undo)
	row.add_child(_vline())
	_btn_auto = _cmd_button("Auto-Bot", "Se acceso, le Fazioni Bot giocano da sole quando tocca a loro")
	_btn_auto.toggle_mode = true
	_btn_auto.toggled.connect(func(_on): auto_bot_toggled.emit())
	row.add_child(_btn_auto)
	row.add_child(_vline())
	_btn_bot = _cmd_button("Gioca Bot", "Fai decidere al Bot l'azione della Fazione di turno")
	_btn_bot.pressed.connect(func(): bot_turn_requested.emit())
	row.add_child(_btn_bot)
	row.add_child(_vline())
	_menu = TipMenuButton.new()
	_menu.text = "Menu"
	_menu.tooltip_text = "Nuova partita, Bot, velocità e Coordinamento tedesco"
	_style_cmd(_menu)
	_cmds.append(_menu)
	var p := _menu.get_popup()
	p.add_separator("Bot")
	p.add_item("Tutti i Bot (questa carta)", MenuId.ALL_BOTS)
	p.add_item("Auto: tutta la partita", MenuId.FULL_GAME)
	p.add_separator("Velocità dei Bot")
	p.add_radio_check_item("Lenta", MenuId.SPEED_SLOW)
	p.add_radio_check_item("Media", MenuId.SPEED_MED)
	p.add_radio_check_item("Veloce", MenuId.SPEED_FAST)
	p.set_item_checked(p.get_item_index(MenuId.SPEED_MED), true)
	if GameRegistry.game_id == "all_bridges_burning":
		p.add_separator("Potenze")
		p.add_check_item("Coordinamento tedesco (§4.2.4)", MenuId.COORDINATE)
	p.add_separator()
	p.add_item("Nuova partita…", MenuId.NEW_GAME)
	p.id_pressed.connect(_on_menu)
	row.add_child(_menu)
	refresh()


func _build_brand() -> Control:
	_brand = PanelContainer.new()
	var bsb := CoinTheme.flat(CoinTheme.BRAND_BG, 0)
	bsb.border_width_right = 1
	bsb.border_color = CoinTheme.BRASS.darkened(0.3)
	_brand.add_theme_stylebox_override("panel", bsb)
	_brand.custom_minimum_size = Vector2(304, 0)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 12)
	m.add_theme_constant_override("margin_right", 10)
	m.add_child(h)
	_brand.add_child(m)
	var em := CoinTheme.Emblem.new()
	em.custom_minimum_size = Vector2(40, 40)
	em.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(em)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", -2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	# Il tema porta titolo e sottotitolo del gioco; un altro modulo dello stesso motore
	# (es. l'export Cuba Libre) mostra il titolo del proprio Manifest.
	var abb: bool = GameRegistry.game_id == "all_bridges_burning"
	var title: String = CoinTheme.TITLE if abb or GameRegistry.manifest == null else GameRegistry.manifest.game_title()
	_brand_title = CoinTheme.label(title, CoinTheme.TEXT, 21, CoinTheme.display())
	_brand_title.clip_text = true
	v.add_child(_brand_title)
	_brand_sub = CoinTheme.label(CoinTheme.SUBTITLE if abb else "Serie COIN · GMT", CoinTheme.FROST, 11, CoinTheme.typewriter())
	_brand_sub.clip_text = true
	v.add_child(_brand_sub)
	h.add_child(v)
	return _brand


func _token_box(tex: Texture2D) -> Array:
	var tok_box := Control.new()
	tok_box.custom_minimum_size = Vector2(30, 40)
	tok_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tok := TextureRect.new()
	tok.texture = tex
	tok.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tok.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tok.set_anchors_preset(Control.PRESET_FULL_RECT)
	tok.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tok_box.add_child(tok)
	var order := CoinTheme.label("", CoinTheme.INK, 12, CoinTheme.ui_heavy())
	order.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	order.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var ob := CoinTheme.box(CoinTheme.PAPER, CoinTheme.PAPER, 0, 9)
	ob.content_margin_left = 0
	ob.content_margin_right = 0
	ob.content_margin_top = 0
	ob.content_margin_bottom = 0
	order.add_theme_stylebox_override("normal", ob)
	order.position = Vector2(18, -4)
	order.size = Vector2(17, 17)
	tok_box.add_child(order)
	return [tok_box, order]


func _build_tile(fid: String) -> Control:
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(150, 0)
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pc.mouse_filter = Control.MOUSE_FILTER_STOP
	pc.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	pc.tooltip_text = "Clicca per passare da Giocatore a Bot e viceversa"
	pc.gui_input.connect(func(e):
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			role_toggle_requested.emit(fid))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(h)
	var tb := _token_box(CLAssets.res_token(fid))
	h.add_child(tb[0])
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", -2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_l := CoinTheme.label(CoinTheme.faction_label(fid), Color.WHITE, 17, CoinTheme.ui_heavy())
	name_l.clip_text = true
	v.add_child(name_l)
	var sub := CoinTheme.label("", CoinTheme.TEXT_DIM, 13)
	sub.clip_text = true
	v.add_child(sub)
	# Vittoria: barra con la tacca della soglia e valore/soglia accanto.
	var vrow := HBoxContainer.new()
	vrow.add_theme_constant_override("separation", 5)
	vrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bar := MeterBar.new()
	bar.bar_height = 6
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vrow.add_child(bar)
	var vval := CoinTheme.label("", CoinTheme.TEXT_DIM, 12, CoinTheme.ui_bold())
	vrow.add_child(vval)
	v.add_child(vrow)
	h.add_child(v)
	var res := CoinTheme.label("", Color.WHITE, 26, CoinTheme.display())
	res.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	res.tooltip_text = "Risorse"
	res.mouse_filter = Control.MOUSE_FILTER_PASS
	h.add_child(res)
	_tiles[fid] = {"panel": pc, "order": tb[1], "sub": sub, "res": res, "name": name_l,
		"bar": bar, "vval": vval}
	return pc


## Tessera delle Potenze (Germania e Russia, sempre gestite dal motore): Vassallaggio
## di ciascuna con la tacca "di pericolo" (Vassallaggio + Polarizzazione > 5 azzera la
## vittoria di Senato/Reds, §7.2) e la Polarizzazione in grande.
func _build_powers_tile() -> Control:
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(150, 0)
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pc.mouse_filter = Control.MOUSE_FILTER_STOP
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pc.add_child(h)
	var tb := _token_box(CLAssets.res_token("germans"))
	h.add_child(tb[0])
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", -3)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var name_l := CoinTheme.label("Potenze", Color.WHITE, 17, CoinTheme.ui_heavy())
	name_l.clip_text = true
	v.add_child(name_l)
	var rows: Dictionary = {}
	for pid in POWERS:
		var r := HBoxContainer.new()
		r.add_theme_constant_override("separation", 5)
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var lab := CoinTheme.label("Ted." if pid == "germans" else "Rus.", CoinTheme.TEXT_DIM, 12, CoinTheme.ui_bold())
		lab.custom_minimum_size = Vector2(26, 0)
		r.add_child(lab)
		var bar := MeterBar.new()
		bar.bar_height = 5
		bar.max_value = 6.0
		bar.color = CoinTheme.faction(pid).lightened(0.25)
		bar.track_color = Color("26323f")
		bar.tick_color = CoinTheme.WARN
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		r.add_child(bar)
		var val := CoinTheme.label("", CoinTheme.TEXT_DIM, 12, CoinTheme.ui_bold())
		r.add_child(val)
		v.add_child(r)
		rows[pid] = {"bar": bar, "val": val}
	h.add_child(v)
	var pol_box := VBoxContainer.new()
	pol_box.alignment = BoxContainer.ALIGNMENT_CENTER
	pol_box.add_theme_constant_override("separation", -6)
	pol_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var pol := CoinTheme.label("", Color.WHITE, 26, CoinTheme.display())
	pol.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pol.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pol_box.add_child(pol)
	var pl := CoinTheme.label("POL.", CoinTheme.TEXT_DIM, 10, CoinTheme.ui_bold())
	pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pol_box.add_child(pl)
	h.add_child(pol_box)
	var sb := CoinTheme.box(Color("18212a"), CoinTheme.faction("germans"), 0)
	sb.border_width_left = 5
	sb.content_margin_left = 6
	sb.content_margin_right = 10
	sb.content_margin_top = 3
	sb.content_margin_bottom = 3
	pc.add_theme_stylebox_override("panel", sb)
	_powers = {"panel": pc, "rows": rows, "pol": pol, "order": tb[1]}
	return pc


func _vline() -> Control:
	var c := ColorRect.new()
	c.color = CoinTheme.BAR_LINE
	c.custom_minimum_size = Vector2(1, 0)
	return c


func _cmd_button(text: String, tip: String) -> Button:
	var b := TipButton.new()
	b.text = text
	b.tooltip_text = tip
	_style_cmd(b)
	_cmds.append(b)
	return b


## Comandi della barra: piatti, alti quanto la barra, ottone al passaggio.
func _style_cmd(b: Button) -> void:
	CoinTheme.style_button(b)
	b.custom_minimum_size = Vector2(76, 0)
	var n := CoinTheme.flat(Color(0, 0, 0, 0), 8)
	var h := CoinTheme.flat(Color("223040"), 8)
	var on := CoinTheme.flat(Color("2c3a48"), 8)
	on.border_width_bottom = 3
	on.border_color = CoinTheme.BRASS_HI
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", on)
	b.add_theme_stylebox_override("hover_pressed", on)
	b.add_theme_stylebox_override("disabled", n)
	b.add_theme_color_override("font_color", Color("dfe3e6"))
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", CoinTheme.BRASS_HI)
	b.add_theme_color_override("font_hover_pressed_color", CoinTheme.BRASS_HI)
	b.add_theme_color_override("font_disabled_color", CoinTheme.BTN_DISABLED_TEXT)
	b.add_theme_font_override("font", CoinTheme.ui_bold())
	b.add_theme_font_size_override("font_size", 16)


## Barra stretta (finestre sotto ~1300 px): titolo e comandi più compatti.
func set_compact(on: bool) -> void:
	if _brand == null:
		return
	_brand.custom_minimum_size = Vector2(244 if on else 304, 0)
	_brand_title.add_theme_font_size_override("font_size", 16 if on else 21)
	_brand_sub.add_theme_font_size_override("font_size", 9 if on else 11)
	for b in _cmds:
		(b as Button).custom_minimum_size = Vector2(60 if on else 76, 0)
		(b as Button).add_theme_font_size_override("font_size", 14 if on else 16)
	for fid in _tiles:
		(_tiles[fid]["panel"] as Control).custom_minimum_size = Vector2(118 if on else 150, 0)
		(_tiles[fid]["res"] as Label).add_theme_font_size_override("font_size", 22 if on else 26)
	if not _powers.is_empty():
		(_powers["panel"] as Control).custom_minimum_size = Vector2(118 if on else 150, 0)


func _on_menu(id: int) -> void:
	var p := _menu.get_popup()
	if id in [MenuId.SPEED_SLOW, MenuId.SPEED_MED, MenuId.SPEED_FAST]:
		for sid in [MenuId.SPEED_SLOW, MenuId.SPEED_MED, MenuId.SPEED_FAST]:
			p.set_item_checked(p.get_item_index(sid), sid == id)
	menu_id_pressed.emit(id)


func set_auto_bot(on: bool) -> void:
	_btn_auto.set_pressed_no_signal(on)
	_btn_auto.text = "Auto-Bot ON" if on else "Auto-Bot"


## Abilita/disabilita "Annulla" e ne aggiorna il suggerimento.
func set_undo(depth: int, label: String) -> void:
	_btn_undo.disabled = depth <= 0
	_btn_undo.tooltip_text = "Disfa l'ultima azione eseguita su questa carta (Ctrl+Z)." if depth <= 0 \
		else "Disfa: %s (Ctrl+Z)" % label


## Aggiorna le tessere: ordine sulla carta, ruolo, stato nella sequenza, Risorse, Vittoria.
func refresh() -> void:
	var gc = GameController
	var s: GameState = gc.state
	if s == null or _turn_lbl == null:
		return
	var card: CardDef = gc.game_def.card(s.current_card) if s.current_card > 0 else null
	var st: Dictionary = gc.seq_status()
	var pending := String(st.get("pending", ""))
	var actors: PackedStringArray = gc.seq.actors() if gc.seq != null else PackedStringArray()
	var passers: PackedStringArray = gc.seq.passers() if gc.seq != null else PackedStringArray()
	_turn_lbl.text = str(gc.cards_left())
	var abb: bool = GameRegistry.game_id == "all_bridges_burning"
	var ph := int(s.tracks.get("phase", 1))
	_phase_lbl.text = ("Fase %s · Prop. %d/4" % ["II" if ph >= 2 else "I", gc.propaganda_played]) if abb \
		else "Prop. %d/4" % gc.propaganda_played
	_phase_lbl.tooltip_text = "Fase I fino a Red Revolt! (§2.4), poi Fase II · Carte Propaganda risolte"
	var vs: Dictionary = gc.victory()
	# Il Bot decide un turno intero: non a metà di un turno già iniziato a mano.
	_btn_bot.disabled = pending == "" or gc.turn_op() != "" or gc.turn_special_done()
	var pol := int(s.tracks.get("polarization", 0))
	for fid in _factions:
		var t: Dictionary = _tiles[fid]
		var col := CoinTheme.faction(fid)
		var active: bool = fid == pending
		var idx := card.faction_order.find(fid) if card != null else -1
		(t["order"] as Label).visible = idx >= 0
		(t["order"] as Label).text = str(idx + 1)
		var status := "disponibile"
		if active:
			status = "di turno"
		elif passers.has(fid):
			status = "ha passato"
		elif actors.has(fid):
			status = "ha agito"
		elif s.eligibility.get(fid, CoinEnums.Eligibility.ELIGIBLE) != CoinEnums.Eligibility.ELIGIBLE:
			status = "non disponibile"
		(t["sub"] as Label).text = "%s · %s" % ["Giocatore" if gc.is_player(fid) else "Bot", status]
		(t["res"] as Label).text = str(s.get_resources(fid)) if s.tracks_resources(fid) else "—"
		(t["res"] as Label).tooltip_text = "Risorse" if s.tracks_resources(fid) \
			else "Risorse non tracciate per le Fazioni Bot (§8.1.2)"
		var d: Dictionary = vs.get(fid, {})
		var val := int(d.get("value", 0))
		var thr := int(d.get("threshold", 0))
		var bar: MeterBar = t["bar"]
		bar.max_value = maxf(thr * 1.45, val + 2.0)
		bar.set_values(val, thr)
		var fg := CoinTheme.faction_fg(fid) if active else Color.WHITE
		var light := CoinTheme.LIGHT_FACTIONS.has(fid)
		bar.color = (CoinTheme.INK if light else Color.WHITE) if active else col.lightened(0.15)
		bar.track_color = col.darkened(0.3) if active else Color("26323f")
		bar.tick_color = CoinTheme.INK if active and light else CoinTheme.PAPER
		(t["vval"] as Label).text = "%d/%d" % [val, thr]
		(t["vval"] as Label).add_theme_color_override("font_color",
			CoinTheme.faction_fg_dim(fid) if active else CoinTheme.TEXT_DIM)
		var zeroed := ""
		if abb and fid == "reds" and int(s.tracks.get("vassalage_russian", 0)) + pol > 5:
			zeroed = "\nAttenzione: Vassallaggio russo + Polarizzazione > 5 azzera la vittoria dei Reds (§7.2)"
		elif abb and fid == "senate" and int(s.tracks.get("vassalage_german", 0)) + pol > 5:
			zeroed = "\nAttenzione: Vassallaggio tedesco + Polarizzazione > 5 azzera la vittoria del Senato (§7.2)"
		(t["panel"] as Control).tooltip_text = "%s · Vittoria (%s): %d, soglia %d, margine %+d%s\nClicca per passare da Giocatore a Bot e viceversa" % [
			gc.faction_name(fid), VIC_LABEL.get(fid, ""), val, thr, int(d.get("margin", 0)), zeroed]
		var sb := CoinTheme.box(col if active else Color("18212a"), col, 0)
		sb.border_width_left = 5
		if active:
			sb.set_border_width_all(1)
			sb.border_width_left = 5
			sb.border_color = CoinTheme.BRASS_HI
		sb.content_margin_left = 6
		sb.content_margin_right = 10
		sb.content_margin_top = 3
		sb.content_margin_bottom = 3
		(t["panel"] as PanelContainer).add_theme_stylebox_override("panel", sb)
		var dim: bool = not active and (status == "non disponibile" or status == "ha agito" or status == "ha passato")
		(t["panel"] as PanelContainer).modulate = Color(1, 1, 1, 0.6 if dim else 1.0)
		(t["name"] as Label).add_theme_color_override("font_color", fg)
		(t["res"] as Label).add_theme_color_override("font_color", fg)
		(t["sub"] as Label).add_theme_color_override("font_color",
			CoinTheme.faction_fg_dim(fid) if active else CoinTheme.TEXT_DIM)
	if not _powers.is_empty():
		var tip := "Potenze (sempre gestite dal motore)\n"
		for pid in POWERS:
			var key := "vassalage_german" if pid == "germans" else "vassalage_russian"
			var vv := int(s.tracks.get(key, 0))
			var r: Dictionary = _powers["rows"][pid]
			var b: MeterBar = r["bar"]
			# Tacca: oltre questo Vassallaggio (con la Polarizzazione attuale) la
			# vittoria di Senato (Germania) o Reds (Russia) si azzera.
			b.set_values(vv, clampf(5.0 - pol, 0.0, 6.0))
			var danger := vv + pol > 5
			(r["val"] as Label).text = str(vv)
			(r["val"] as Label).add_theme_color_override("font_color", CoinTheme.WARN if danger else CoinTheme.TEXT_DIM)
			tip += "Vassallaggio %s: %d%s\n" % ["tedesco" if pid == "germans" else "russo", vv,
				("  (con la Polarizzazione supera 5: vittoria %s azzerata)" % ("del Senato" if pid == "germans" else "dei Reds")) if danger else ""]
		(_powers["pol"] as Label).text = str(pol)
		var g_idx := card.faction_order.find("germans") if card != null else -1
		(_powers["order"] as Label).visible = g_idx >= 0
		(_powers["order"] as Label).text = str(g_idx + 1)
		tip += "Polarizzazione: %d\nLa tacca arancione indica il Vassallaggio oltre il quale Vass. + Pol. > 5." % pol
		(_powers["panel"] as Control).tooltip_text = tip
		var pop := _menu.get_popup()
		var ci := pop.get_item_index(MenuId.COORDINATE)
		if ci >= 0:
			pop.set_item_checked(ci, int(s.tracks.get("coordinate_marker", 0)) > 0)
			pop.set_item_disabled(ci, ph < 2)
