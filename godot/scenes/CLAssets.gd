class_name CLAssets
extends RefCounted

## Caricamento/cache delle texture (mappa, pezzi, marcatori) di Cuba Libre.

## Path degli asset risolto a runtime tramite l'autoload GameRegistry.
## Fallback hardcoded a Cuba Libre se il GameRegistry non è raggiungibile (test).
const FALLBACK_DIR := "res://games/cuba_libre/assets/"
static var _cache: Dictionary = {}


static func _assets_dir() -> String:
	# L'autoload "GameRegistry" è accessibile come singleton globale: lo cerchiamo
	# via path nel SceneTree per evitare di hardcodare il nome in static context.
	var loop = Engine.get_main_loop()
	if loop == null or not (loop is SceneTree):
		return FALLBACK_DIR
	var tree: SceneTree = loop
	var reg = tree.root.get_node_or_null("GameRegistry")
	if reg != null and reg.has_method("assets_dir"):
		return String(reg.call("assets_dir"))
	return FALLBACK_DIR


static func tex(file: String) -> Texture2D:
	if not _cache.has(file):
		var path: String = _assets_dir() + file
		_cache[file] = load(path) if ResourceLoader.exists(path) else null
	return _cache[file]


static func map() -> Texture2D:
	return tex("map.jpg")


## Texture del pezzo (faction, type, state).
##
## Convenzione di naming sugli asset:
##   troops      → troops.png (Cuba) o troops_<faction>.png (ABB: germans/russians)
##   police      → police.png (Cuba)
##   base        → base_<faction>.png (Cuba)
##   casino      → casino_<open|closed>.png (Cuba, Syndicate)
##   guerrilla   → guerrilla_<faction>_<state>.png (Cuba)
##   cell        → cell_<faction>_<state>.png (ABB: reds/senate/moderates, active/underground)
##   admin       → admin_<faction>.png (ABB Reds disc)
##   network     → network_<faction>.png (ABB Moderates disc)
static func piece(faction: String, type: String, state: String) -> Texture2D:
	match type:
		"troops":
			# Prima prova faction-aware (ABB), poi cade su nome generico (Cuba).
			var faction_tex: Texture2D = tex("troops_%s.png" % faction)
			return faction_tex if faction_tex != null else tex("troops.png")
		"police": return tex("police.png")
		"base": return tex("base_%s.png" % faction)
		"casino": return tex("casino_%s.png" % ("open" if state == "open" else "closed"))
		"guerrilla":
			var gs: String = state if state != "" else "underground"
			return tex("guerrilla_%s_%s.png" % [faction, gs])
		"cell":
			var cs: String = state if state != "" else "underground"
			return tex("cell_%s_%s.png" % [faction, cs])
		"admin": return tex("admin_%s.png" % faction)
		"network": return tex("network_%s.png" % faction)
	return null


static func control(faction: String) -> Texture2D:
	# Per ABB: control_reds.png / control_senate.png. Per Cuba: control_government.png ecc.
	# Senza fazione (controllo "none"), si può ritornare una "Uncontrol" — TODO.
	if faction == "":
		return null
	return tex("control_%s.png" % faction)


static func support(level: int) -> Texture2D:
	match level:
		2: return tex("support_active.png")
		1: return tex("support_passive.png")
		-1: return tex("opposition_passive.png")
		-2: return tex("opposition_active.png")
	return null


## Immagine della carta: number 1..N, oppure 0 = Propaganda.
## Prova prima JPG (ABB), poi PNG (Cuba Libre) come fallback.
static func card(number: int) -> Texture2D:
	var name_base: String = "prop" if number <= 0 else "%02d" % number
	var jpg: Texture2D = tex("cards/%s.jpg" % name_base)
	return jpg if jpg != null else tex("cards/%s.png" % name_base)


static func cash() -> Texture2D: return tex("cash.png")
static func terror() -> Texture2D: return tex("terror.png")
static func sabotage() -> Texture2D: return tex("sabotage.png")

# Token/segnalini dei tracciati (immagini originali)
static func res_token(faction: String) -> Texture2D: return tex("token_%s.png" % faction)
static func aid_marker() -> Texture2D: return tex("aid.png")
static func alliance_marker() -> Texture2D: return tex("us_alliance.png")
static func vic_support() -> Texture2D: return tex("vic_support.png")
static func vic_opp_bases() -> Texture2D: return tex("vic_opp_bases.png")
static func vic_dr() -> Texture2D: return tex("vic_dr.png")
static func vic_casinos() -> Texture2D: return tex("vic_casinos.png")
