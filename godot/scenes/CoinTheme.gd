class_name CoinTheme
extends RefCounted

## Aspetto dell'interfaccia: tema "dispaccio di stato maggiore, inverno finlandese 1918".
##
## Unico posto dove vivono colori, caratteri, riquadri, nomi brevi delle Fazioni ed
## emblema. Lo schema della schermata (barra in alto, mappa, pannello azione a destra,
## striscia del registro in basso) è comune ai giochi COIN: per un altro titolo della
## serie basta sostituire QUESTO file (palette, caratteri, emblema, titolo).
##
## Due "superfici":
##  - scura (barra superiore, cornice della mappa, registro): notte d'inverno, testo chiaro;
##  - carta (pannello azione, finestre): carta da telegrafo fredda, inchiostro scuro.

# --- Titolo -------------------------------------------------------------------
const TITLE := "All Bridges Burning"
const SUBTITLE := "Guerra civile finlandese · 1917–18"

# --- Palette -----------------------------------------------------------------
const BG := Color("141b22")            ## sfondo della scena (notte d'inverno)
const BAR := Color("0d1217")           ## barra superiore
const BAR_LINE := Color("26323f")      ## divisori nella barra
const BRAND_BG := Color("1c2a37")      ## riquadro del titolo (ardesia)
const PAPER := Color("ece6d6")         ## carta da telegrafo
const PAPER_DARK := Color("ddd5c1")    ## carta in ombra (riquadri interni, hover)
const PAPER_EDGE := Color("b3aa94")    ## bordo tenue su carta / disattivato
const INK := Color("1f2328")           ## inchiostro
const INK_DIM := Color("4f5660")       ## inchiostro attenuato (etichette)
const INK_FAINT := Color("8a877c")     ## testo disattivato su carta
const WAX := Color("7a2a1c")           ## ceralacca: tasto principale, timbri (neutro, non il rosso dei Reds)
const WAX_DARK := Color("3d140d")      ## ombra del tasto principale
const BRASS := Color("b89a5a")         ## ottone: titoli sul buio, cornice mappa
const BRASS_HI := Color("e0b54a")      ## ottone acceso: spazio valido / selezionato
const FROST := Color("a9d6e5")         ## brina: emblema, accenti freddi
const LOG_BG := Color("10161c")        ## fondo del registro
const LOG_EDGE := Color("2a3642")

const TEXT := Color("e9e4d6")          ## testo chiaro sul buio
const TEXT_DIM := Color("9aa6b2")      ## testo attenuato sul buio (grigio-azzurro)
const ACCENT := BRASS_HI
const OK := Color("6fcf97")            ## esito positivo (sul buio)
const OK_INK := Color("2b6a3f")        ## esito positivo (su carta)
const ERR := Color("ff7b6b")           ## errori (sul buio)
const ERR_INK := WAX                   ## errori (su carta)
const WARN := Color("f0a868")
const WARN_INK := Color("8c4a12")

## Evidenziazione degli spazi validi sulla mappa innevata: ottone con filo scuro sotto.
const HILITE := BRASS_HI
const HILITE_UNDER := Color(0.05, 0.07, 0.09, 0.75)

# Tasti sul buio (barra superiore, menu, finestre di dialogo).
const BTN_BG := Color("18212a")
const BTN_BORDER := Color("394756")
const BTN_HOVER_BG := Color("223040")
const BTN_HOVER_BORDER := BRASS
const BTN_PRESSED_BG := Color("0d1217")
const BTN_DISABLED_BG := Color("131a21")
const BTN_DISABLED_BORDER := Color("26323f")
const BTN_DISABLED_TEXT := Color("5d6a76")
const FONT_SIZE := 15

## Colori delle Fazioni sul buio (dalla scatola: Reds rossi, Guardia Bianca, Moderati blu).
static var FACTION: Dictionary = {
	"reds": Color("b8322a"), "senate": Color("e9edf0"), "moderates": Color("2f78b7"),
	"germans": Color("6f7a80"), "russians": Color("8b4f2a"),
	# Cuba Libre (stesso motore, export alternativo)
	"government": Color("2f6db5"), "m26": Color("a8232b"),
	"directorio": Color("d9a91f"), "syndicate": Color("3f9a4a"),
}
## Variante leggibile su carta (il bianco del Senato diventa ardesia).
static var FACTION_INK: Dictionary = {
	"reds": Color("a8291f"), "senate": Color("3f5566"), "moderates": Color("255f95"),
	"germans": Color("555f66"), "russians": Color("7a4220"),
	"government": Color("2f6db5"), "m26": Color("a8232b"),
	"directorio": Color("b8901a"), "syndicate": Color("3f9a4a"),
}
## Fazioni chiare: sul loro colore serve testo scuro.
static var LIGHT_FACTIONS: Array = ["senate", "directorio"]
## Nomi brevi in italiano (tessere, intestazione del pannello, finestre).
static var FACTION_LABEL: Dictionary = {
	"reds": "Reds", "senate": "Senato", "moderates": "Moderati",
	"germans": "Germania", "russians": "Russia",
	"government": "Governo", "m26": "26 Luglio", "directorio": "Directorio", "syndicate": "Sindacato",
}

# --- Caratteri (OFL, in res://assets/fonts) ----------------------------------
const FONT_DIR := "res://assets/fonts/"
static var _fonts: Dictionary = {}


static func _font(file: String) -> Font:
	if not _fonts.has(file):
		var path := FONT_DIR + file
		_fonts[file] = load(path) if ResourceLoader.exists(path) else ThemeDB.fallback_font
	return _fonts[file]


## IM Fell English SC: titoli, tasto principale, numeri grandi (tipografia d'epoca).
static func display() -> Font: return _font("IMFellEnglishSC-Regular.ttf")
## Courier Prime: istruzioni, testi delle carte, registro (telegrafo / macchina da scrivere).
static func typewriter() -> Font: return _font("CourierPrime-Regular.ttf")
static func typewriter_bold() -> Font: return _font("CourierPrime-Bold.ttf")
## Barlow Condensed: testo dell'interfaccia.
static func ui() -> Font: return _font("BarlowCondensed-Regular.ttf")
static func ui_bold() -> Font: return _font("BarlowCondensed-SemiBold.ttf")
static func ui_heavy() -> Font: return _font("BarlowCondensed-Bold.ttf")


static func faction(fid: String) -> Color:
	return FACTION.get(fid, Color.WHITE)


static func faction_ink(fid: String) -> Color:
	return FACTION_INK.get(fid, INK)


## Colore del testo su un fondo pieno del colore della Fazione.
static func faction_fg(fid: String) -> Color:
	return INK if LIGHT_FACTIONS.has(fid) else Color.WHITE


## Colore del testo secondario su un fondo pieno del colore della Fazione.
static func faction_fg_dim(fid: String) -> Color:
	return INK_DIM if LIGHT_FACTIONS.has(fid) else Color(1, 1, 1, 0.8)


static func faction_label(fid: String) -> String:
	if FACTION_LABEL.has(fid):
		return String(FACTION_LABEL[fid])
	return fid


# --- Riquadri -------------------------------------------------------------------

## Riquadro con bordo, usato per tutti gli stati dei tasti.
static func box(bg: Color, border: Color, border_w: int = 1, radius: int = 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(radius)
	s.set_border_width_all(border_w)
	s.border_color = border
	s.content_margin_left = 10.0
	s.content_margin_right = 10.0
	s.content_margin_top = 4.0
	s.content_margin_bottom = 4.0
	return s


## Foglio di carta da telegrafo (pannelli informativi), con ombra.
static func paper_box(margin: float = 12.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = PAPER
	s.set_corner_radius_all(2)
	s.border_color = Color("cfc6ad")
	s.set_border_width_all(1)
	s.shadow_color = Color(0, 0, 0, 0.45)
	s.shadow_size = 6
	s.shadow_offset = Vector2(0, 3)
	s.content_margin_left = margin
	s.content_margin_right = margin
	s.content_margin_top = margin - 2.0
	s.content_margin_bottom = margin - 2.0
	return s


## Riquadro scuro semitrasparente (comandi sopra la mappa, registro).
static func dark_box(bg: Color = Color(0.05, 0.07, 0.09, 0.86), border: Color = BTN_BORDER) -> StyleBoxFlat:
	var s := box(bg, border)
	s.content_margin_left = 8.0
	s.content_margin_right = 8.0
	s.content_margin_top = 6.0
	s.content_margin_bottom = 6.0
	return s


static func flat(bg: Color, margin: float = 0.0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.content_margin_left = margin
	s.content_margin_right = margin
	s.content_margin_top = margin
	s.content_margin_bottom = margin
	return s


# --- Temi ----------------------------------------------------------------------

static var _dark_theme: Theme
static var _paper_theme: Theme


## Tema delle superfici scure: si applica alla radice della scena e alla finestra,
## così anche menu a tendina e finestre di dialogo prendono caratteri e colori.
static func dark_theme() -> Theme:
	if _dark_theme != null:
		return _dark_theme
	var t := Theme.new()
	t.default_font = ui()
	t.default_font_size = FONT_SIZE
	t.set_color("font_color", "Label", TEXT)
	for type in ["Button", "MenuButton", "OptionButton"]:
		_button_styles(t, type, BTN_BG, BTN_BORDER, BTN_HOVER_BG, BTN_HOVER_BORDER, BTN_PRESSED_BG,
			BTN_DISABLED_BG, BTN_DISABLED_BORDER, TEXT, Color.WHITE, BTN_DISABLED_TEXT, 1)
	var pm := box(Color("18212a"), BTN_BORDER)
	pm.content_margin_top = 6.0
	pm.content_margin_bottom = 6.0
	t.set_stylebox("panel", "PopupMenu", pm)
	t.set_stylebox("hover", "PopupMenu", box(Color("2c3a48"), BRASS))
	t.set_color("font_color", "PopupMenu", TEXT)
	t.set_color("font_hover_color", "PopupMenu", Color.WHITE)
	t.set_color("font_disabled_color", "PopupMenu", BTN_DISABLED_TEXT)
	t.set_color("font_separator_color", "PopupMenu", TEXT_DIM)
	t.set_font_size("font_size", "PopupMenu", FONT_SIZE)
	# Finestre di dialogo: foglio di carta da telegrafo.
	var dlg := paper_box(18.0)
	t.set_stylebox("panel", "AcceptDialog", dlg)
	t.set_color("font_color", "AcceptDialog", INK)
	t.set_stylebox("embedded_border", "Window", box(PAPER, Color("cfc6ad")))
	t.set_color("title_color", "Window", INK)
	t.set_font("title_font", "Window", display())
	t.set_font_size("title_font_size", "Window", 22)
	t.set_stylebox("panel", "TooltipPanel", box(BAR, BRASS))
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_font("normal_font", "RichTextLabel", ui())
	t.set_font("bold_font", "RichTextLabel", ui_bold())
	t.set_stylebox("panel", "PopupPanel", box(BAR, BRASS))
	# Barre di scorrimento sottili, color ottone.
	for sb_type in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("grabber", sb_type, box(Color("394756"), Color("394756"), 0, 4))
		t.set_stylebox("grabber_highlight", sb_type, box(BRASS, BRASS, 0, 4))
		t.set_stylebox("grabber_pressed", sb_type, box(BRASS_HI, BRASS_HI, 0, 4))
		var track := StyleBoxFlat.new()
		track.bg_color = Color(0, 0, 0, 0.0)
		track.content_margin_left = 3
		track.content_margin_right = 3
		track.content_margin_top = 3
		track.content_margin_bottom = 3
		t.set_stylebox("scroll", sb_type, track)
	_dark_theme = t
	return t


## Tema dei fogli di carta: inchiostro, tasti a contorno.
static func paper_theme() -> Theme:
	if _paper_theme != null:
		return _paper_theme
	var t := Theme.new()
	t.default_font = ui()
	t.default_font_size = FONT_SIZE
	t.set_color("font_color", "Label", INK)
	for type in ["Button", "MenuButton"]:
		_button_styles(t, type, Color(0, 0, 0, 0), INK, PAPER_DARK, INK, INK,
			Color(0, 0, 0, 0), PAPER_EDGE, INK, INK, INK_FAINT, 2)
		t.set_color("font_pressed_color", type, PAPER)
		t.set_font("font", type, ui_bold())
	t.set_color("default_color", "RichTextLabel", INK)
	t.set_font("normal_font", "RichTextLabel", typewriter())
	t.set_font("bold_font", "RichTextLabel", ui_heavy())
	t.set_stylebox("panel", "PopupMenu", box(PAPER, INK))
	t.set_stylebox("hover", "PopupMenu", box(INK, INK))
	t.set_color("font_color", "PopupMenu", INK)
	t.set_color("font_hover_color", "PopupMenu", PAPER)
	t.set_color("font_disabled_color", "PopupMenu", INK_FAINT)
	t.set_font("font", "PopupMenu", ui_bold())
	t.set_font_size("font_size", "PopupMenu", FONT_SIZE)
	t.set_stylebox("panel", "TooltipPanel", box(BAR, BRASS))
	t.set_color("font_color", "TooltipLabel", TEXT)
	for sb_type in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("grabber", sb_type, box(PAPER_EDGE, PAPER_EDGE, 0, 4))
		t.set_stylebox("grabber_highlight", sb_type, box(INK_DIM, INK_DIM, 0, 4))
		t.set_stylebox("grabber_pressed", sb_type, box(INK, INK, 0, 4))
		var track := StyleBoxFlat.new()
		track.bg_color = Color(0, 0, 0, 0.0)
		track.content_margin_left = 3
		track.content_margin_right = 3
		t.set_stylebox("scroll", sb_type, track)
	_paper_theme = t
	return t


static func _button_styles(t: Theme, type: String, bg: Color, border: Color, hover_bg: Color,
		hover_border: Color, pressed_bg: Color, dis_bg: Color, dis_border: Color,
		fg: Color, hover_fg: Color, dis_fg: Color, bw: int) -> void:
	t.set_stylebox("normal", type, box(bg, border, bw))
	t.set_stylebox("hover", type, box(hover_bg, hover_border, bw))
	t.set_stylebox("pressed", type, box(pressed_bg, border, bw))
	t.set_stylebox("hover_pressed", type, box(pressed_bg, hover_border, bw))
	t.set_stylebox("disabled", type, box(dis_bg, dis_border, bw))
	t.set_stylebox("focus", type, StyleBoxEmpty.new())
	t.set_color("font_color", type, fg)
	t.set_color("font_hover_color", type, hover_fg)
	t.set_color("font_focus_color", type, fg)
	t.set_color("font_pressed_color", type, hover_fg)
	t.set_color("font_hover_pressed_color", type, hover_fg)
	t.set_color("font_disabled_color", type, dis_fg)


# --- Tasti ---------------------------------------------------------------------

## Veste standard di un tasto: colori e riquadri arrivano dal tema della superficie.
static func style_button(b: Button) -> void:
	# Niente focus persistente: Invio/Spazio servono alle scorciatoie di turno.
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for st in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
		b.remove_theme_stylebox_override(st)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.remove_theme_color_override(c)


## Tasto in evidenza, con sfondo pieno (scelta attiva, Auto-Bot acceso).
static func accent_button(b: Button, bg: Color, border: Color, fg: Color = Color.WHITE) -> void:
	b.add_theme_stylebox_override("normal", box(bg, border, 2))
	b.add_theme_stylebox_override("hover", box(bg.lightened(0.12), border, 2))
	b.add_theme_stylebox_override("pressed", box(bg.darkened(0.18), border, 2))
	b.add_theme_stylebox_override("hover_pressed", box(bg.darkened(0.18), border, 2))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, fg)


## Tasto principale del pannello: ceralacca con "spessore" sotto, scritta d'epoca.
static func primary_button(b: Button, size: int = 24) -> void:
	style_button(b)
	var n := box(WAX, WAX, 0)
	n.border_width_bottom = 4
	n.border_color = WAX_DARK
	var h := n.duplicate() as StyleBoxFlat
	h.bg_color = WAX.lightened(0.1)
	var p := n.duplicate() as StyleBoxFlat
	p.bg_color = WAX.darkened(0.15)
	p.border_width_bottom = 1
	var d := box(Color("c4bcaa"), Color("aaa18c"), 0)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_stylebox_override("hover_pressed", p)
	b.add_theme_stylebox_override("disabled", d)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(c, Color("f6efe0"))
	b.add_theme_color_override("font_disabled_color", Color("efe9dc"))
	b.add_theme_font_override("font", display())
	b.add_theme_font_size_override("font_size", size)


# --- Etichette -----------------------------------------------------------------

## Titolo di sezione nel carattere d'epoca (es. "Comando").
static func section_title(text: String, color: Color = INK_DIM, size: int = 18) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", display())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


## Etichetta generica con carattere/colore/dimensione.
static func label(text: String, color: Color, size: int = FONT_SIZE, font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", size)
	if font != null:
		l.add_theme_font_override("font", font)
	return l


## Testo su fondino del colore della Fazione (registro).
static func faction_chip(text: String, faction_id: String) -> String:
	if faction_id == "":
		return text
	var hex := faction(faction_id).to_html(false)
	var fg := faction_fg(faction_id).to_html(false)
	return "[bgcolor=#%s][color=#%s] %s [/color][/bgcolor]" % [hex, fg, text]


# --- Emblema -------------------------------------------------------------------

## Emblema disegnato del riquadro del titolo: stella di brina a sei bracci su sigillo.
class Emblem:
	extends Control

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5
		# Sigillo: disco di ceralacca con anello d'ottone.
		draw_circle(c, r, CoinTheme.WAX)
		draw_arc(c, r - 1.5, 0, TAU, 40, CoinTheme.BRASS, 1.5, true)
		# Cristallo di neve: sei bracci con due coppie di rametti ciascuno.
		var col := CoinTheme.FROST
		var arm := r * 0.72
		for i in range(6):
			var a := -PI / 2.0 + i * PI / 3.0
			var d := Vector2(cos(a), sin(a))
			draw_line(c, c + d * arm, col, 2.0, true)
			for k in [0.45, 0.72]:
				var base: Vector2 = c + d * arm * k
				var len: float = arm * (0.30 if k < 0.6 else 0.22)
				for s in [-1.0, 1.0]:
					var b := d.rotated(s * PI / 3.0)
					draw_line(base, base + b * len, col, 1.5, true)
		draw_circle(c, r * 0.12, col)
