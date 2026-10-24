class_name BottomStrip
extends PanelContainer

## Striscia sotto la mappa: il registro delle azioni e, accanto, un riquadro compatto
## con il testo italiano della carta in gioco (Capacità/Momentum, Fase, carte rimaste).
## Risorse e Vittoria vivono nelle tessere della barra superiore, la carta (immagine e
## lati dell'Evento) nel pannello azione: qui resta spazio per leggere il registro.

const HEIGHT := 128.0
const CARD_W := 300.0

var log_view: LogView          ## esposto: la scena ci collega i segnali del controller
var _card_text: RichTextLabel
var _card_box: Control
var _ver_lbl: Label


func _init() -> void:
	custom_minimum_size = Vector2(0, HEIGHT)
	add_theme_stylebox_override("panel", CoinTheme.dark_box(CoinTheme.LOG_BG, CoinTheme.LOG_EDGE))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	add_child(h)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(v)
	var title_row := HBoxContainer.new()
	var reg := CoinTheme.section_title("Registro", CoinTheme.BRASS, 17)
	reg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(reg)
	_ver_lbl = CoinTheme.label("", CoinTheme.BRASS, 11, CoinTheme.typewriter())
	_ver_lbl.tooltip_text = "Numero di build: conferma quale versione è caricata (cache del browser)"
	_ver_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	_ver_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	title_row.add_child(_ver_lbl)
	v.add_child(title_row)
	log_view = LogView.new()
	log_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_view.custom_minimum_size = Vector2(0, 60)
	v.add_child(log_view)
	# Riquadro "Carta in gioco": divisorio sottile e testo dattiloscritto.
	var sep := ColorRect.new()
	sep.color = CoinTheme.LOG_EDGE
	sep.custom_minimum_size = Vector2(1, 0)
	h.add_child(sep)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 2)
	cv.custom_minimum_size = Vector2(CARD_W, 0)
	h.add_child(cv)
	_card_box = cv
	cv.add_child(CoinTheme.section_title("Carta in gioco", CoinTheme.BRASS, 17))
	_card_text = RichTextLabel.new()
	_card_text.bbcode_enabled = true
	_card_text.scroll_active = true
	_card_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for fs in ["normal_font_size", "bold_font_size"]:
		_card_text.add_theme_font_size_override(fs, 12)
	_card_text.add_theme_font_override("normal_font", CoinTheme.typewriter())
	_card_text.add_theme_font_override("bold_font", CoinTheme.typewriter_bold())
	_card_text.add_theme_color_override("default_color", Color("cfd6dc"))
	cv.add_child(_card_text)


## Numero di build, in piccolo accanto al titolo del registro (sempre visibile).
func set_version(v: String) -> void:
	_ver_lbl.text = "build " + v


## Testo della carta in gioco (BBCode del controller, già in italiano).
func refresh() -> void:
	if _card_text != null:
		_card_text.text = GameController.current_card_text()


## Finestre strette: il riquadro della carta si restringe per lasciare spazio al registro.
func set_compact(on: bool) -> void:
	if _card_box != null:
		_card_box.custom_minimum_size = Vector2(220.0 if on else CARD_W, 0)
