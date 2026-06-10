class_name ABBCrisis
extends RefCounted

## Crisis Round All Bridges Burning (rulebook §6.0).

var state: GameState
var module: RulesModule

func _init(_state: GameState, _module: RulesModule) -> void:
	state = _state
	module = _module


func resolve() -> Dictionary:
	var out: Dictionary = {
		"politics": _politics_phase(),
		"earnings": _earnings_phase(),
	}
	# §6.5.3 Powers adjustment: solo in Phase II.
	if int(state.tracks.get("phase", 1)) >= 2:
		out["powers"] = _powers_adjustment()
	# §6.5.1 Prisoners of War — SOLO Phase II. Prima i NP Reds/Senate rilasciano
	# TUTTI i prigionieri nemici se Polarization ≥ 6, altrimenti nessuno (Solitaire
	# Play Aid §6.5.1). Poi, per ogni 2 Cellule rimaste in prigione, +1 Polarization.
	if int(state.tracks.get("phase", 1)) >= 2:
		var prisoners: Dictionary = state.tracks.get("prisoners", {"senate": 0, "reds": 0})
		if int(state.tracks.get("polarization", 0)) >= 6:
			state.tracks["prisoners"] = {"senate": 0, "reds": 0}
			out["prisoners_released"] = true
		else:
			var total_prisoners: int = int(prisoners.get("senate", 0)) + int(prisoners.get("reds", 0))
			if total_prisoners >= 2:
				var pol_bump := int(total_prisoners / 2)
				var prev_pol := int(state.tracks.get("polarization", 0))
				state.tracks["polarization"] = clampi(prev_pol + pol_bump, 0, 10)
				out["prisoners_polarization"] = pol_bump
	# §6.4.2 Agitation: gestione Supporto/Opposizione e clausole di
	# dis-azzeramento (Polarization vs Vassalaggio) — DEVE precedere il controllo
	# di vittoria, quindi sta qui prima del Reset.
	out["agitation"] = _agitation_phase()
	# §6.5.4 Old News: rimuovi tutti i Terror, Sabotage, News dalla mappa.
	out["reset"] = _reset_phase()
	# §6.5.5 Senate Conscription: alla PRIMA Propaganda (campaign_count ancora 0),
	# le 10 Cellule Senato Out of Play entrano nelle Forze Disponibili.
	if int(state.tracks.get("campaign_count", 0)) == 0:
		var oop := int(state.out_of_play.get("senate:cell", 0))
		if oop > 0:
			state.out_of_play["senate:cell"] = 0
			out["senate_conscription"] = oop
	# Conteggio Campaign per il bot (PAC2 last_campaign condition).
	state.tracks["campaign_count"] = int(state.tracks.get("campaign_count", 0)) + 1
	out["campaign"] = state.tracks["campaign_count"]
	return out


## §6.4.2 Agitation (Solitaire Play Aid). Ogni Fazione Non-player aggiusta
## Supporto/Opposizione nei propri spazi e, all'ULTIMA Propaganda, riduce la
## Polarization per non azzerare la propria vittoria (§7.2). Trascrizione fedele
## delle tre colonne del play-aid (Senate / Reds / Moderates).
func _agitation_phase() -> Dictionary:
	var log: Array = []
	# "final Propaganda" = l'ultima (4ª) Propaganda. campaign_count viene
	# incrementato a fine resolve(): qui vale 3 alla 4ª.
	var is_final := int(state.tracks.get("campaign_count", 0)) >= 3
	var vg := int(state.tracks.get("vassalage_german", 0))
	var vr := int(state.tracks.get("vassalage_russian", 0))

	# ---- SENATE: spazi con Controllo Senate e Cellula Senate Attiva ----
	# ❶ se Senate Town Pop 4+ e ultima Propaganda: riduci Polarization così che
	#    Vassalaggio Tedesco + Polarization = 5 (solo riduzione).
	if _senate_town_pop_ctrl() >= 4 and is_final:
		var tgt := maxi(0, 5 - vg)
		if int(state.tracks.get("polarization", 0)) > tgt:
			state.tracks["polarization"] = tgt
			log.append("Senate Agitation: Pol→%d" % tgt)
	# ❷ Agita al massimo: sposta verso Supporto dove controlla con Cellula Attiva.
	for sid in state.spaces.keys():
		var st: SpaceState = state.space_state(sid)
		if st.control == "senate" and st.count("senate", "cell", "active") > 0:
			_shift_support(sid, 1)

	# ---- REDS: spazi con Controllo Reds e Cellula Attiva o Admin ----
	# ❸ Alza l'Opposizione al massimo: (a) nelle Town, (b) a 1+ Pop. §6.4.2: con
	#    Admin Reds nello spazio fino a qualunque livello (Attiva −2), altrimenti
	#    solo fino a Opposizione PASSIVA (−1).
	for sid in _pop_spaces_towns_first():
		var st: SpaceState = state.space_state(sid)
		if st.control == "reds" and (st.count("reds", "cell", "active") > 0 or st.count("reds", "admin") > 0):
			var floor_opp := ACTIVE_OPP_INT if st.count("reds", "admin") > 0 else -1
			if int(st.support) > floor_opp:
				_shift_support(sid, -1)
	# ❹ se Oppose+Admins 12+ e ultima Propaganda: Polarization così che
	#    Vassalaggio Russo + Polarization = 5.
	if is_final and (state.total_opposition() + state.count_on_map("reds", "admin")) >= 12:
		var tgt2 := maxi(0, 5 - vr)
		if int(state.tracks.get("polarization", 0)) > tgt2:
			state.tracks["polarization"] = tgt2
			log.append("Reds Agitation: Pol→%d" % tgt2)

	# ---- MODERATES: spazi 1+ Pop senza Controllo con un pezzo Moderati ----
	# ❶ se ultima Propaganda e Risorse 15+: Polarization = Issues+Networks(+1).
	if is_final and int(state.get_resources("moderates")) >= 15:
		var tgt3 := clampi((module as ABBModule).issues_networks_expr(state), 0, 10)
		if int(state.tracks.get("polarization", 0)) > tgt3:
			state.tracks["polarization"] = tgt3
			log.append("Moderates Agitation: Pol→%d" % tgt3)
	# ❷ se Oppose+Admins 10+: sposta verso Neutrale finché Oppose+Admins ≤ 9.
	var guard := 0
	while (state.total_opposition() + state.count_on_map("reds", "admin")) >= 10 and guard < 30:
		guard += 1
		var shifted := false
		for sid in _pop_spaces_towns_first():
			var st: SpaceState = state.space_state(sid)
			if int(st.support) < 0 and st.count("moderates", "cell") > 0:
				_shift_support(sid, 1)
				shifted = true
				break
		if not shifted:
			break
	return {"log": log}


## Town Pop sotto Controllo Senate (per §6.4.2 ❶).
func _senate_town_pop_ctrl() -> int:
	var t := 0
	for sid in state.spaces.keys():
		var sd: SpaceDef = state.game_def.space(sid)
		if sd != null and sd.type == CoinEnums.SpaceType.CITY \
				and state.space_state(sid).control == "senate":
			t += sd.pop
	return t


## Spazi con 1+ Pop, Town prima delle Province (§8.1.7).
func _pop_spaces_towns_first() -> Array:
	var towns: Array = []
	var provs: Array = []
	for sid in state.spaces.keys():
		var sd: SpaceDef = state.game_def.space(sid)
		if sd == null or sd.pop <= 0:
			continue
		if sd.type == CoinEnums.SpaceType.CITY:
			towns.append(String(sid))
		else:
			provs.append(String(sid))
	return towns + provs


func _shift_support(sid: String, delta: int) -> void:
	var st: SpaceState = state.space_state(sid)
	var cur := int(st.support)
	st.support = clampi(cur + delta, ACTIVE_OPP_INT, ACTIVE_SUP_INT) as CoinEnums.Support


const ACTIVE_OPP_INT := -2
const ACTIVE_SUP_INT := 2


## §6.5.4 Old News: rimuove Terror, Sabotage, News markers dalla mappa
## (Personality e Prepared rimangono). Pulisce anche i Sabotage su bordo.
func _reset_phase() -> Dictionary:
	var removed: Dictionary = {"terror": 0, "sabotage": 0, "news": 0, "borders": 0}
	for sid in state.spaces.keys():
		var st: SpaceState = state.space_state(sid)
		for mk in ["terror", "sabotage", "news"]:
			var n := st.marker(mk)
			if n > 0:
				removed[mk] = int(removed[mk]) + n
				st.set_marker(mk, 0)
	# Pulisci anche i bordi sabotati.
	var borders: Array = state.tracks.get("sabotaged_borders", [])
	removed["borders"] = borders.size()
	state.tracks["sabotaged_borders"] = []
	return removed


## §6.5.3 — Numero di Truppe Tedesche/Russe sulla mappa allineato al marker Vassalage.
## Germans entrano/escono nella Available Forces (non sulla mappa direttamente).
## Russians entrano in un Town casuale con pezzi Reds (se nessuno disponibile, da nessuna parte).
func _powers_adjustment() -> Dictionary:
	var out := {"germans_placed": 0, "germans_removed": 0,
		"russians_placed": 0, "russians_removed": 0, "log": []}

	var vg: int = clampi(int(state.tracks.get("vassalage_german", 0)), 0, 6)
	var on_g: int = state.count_on_map("germans", "troops")
	var diff_g: int = vg - on_g
	if diff_g > 0:
		# Place: prendi dalla Available, ma per ABB Germans non hanno una "scatola"
		# distinta — li lasciamo nel pool (force_pool - on_map). Quindi non li metto
		# sulla mappa: aggiorno solo il counter logico via remove_to_available su
		# null (i.e. lascio invariato lo state-on-map). Da rifinire con un sotto-
		# pool "out_of_play" quando lo introduciamo.
		out["germans_placed"] = diff_g
		out["log"].append("Germans Available +%d (Vassalage %d)" % [diff_g, vg])
	elif diff_g < 0:
		# Remove dal mappa fino a -diff_g
		var to_remove_g: int = -diff_g
		for sid in state.spaces.keys():
			if to_remove_g <= 0:
				break
			var st: SpaceState = state.space_state(sid)
			var n: int = st.count("germans", "troops")
			if n > 0:
				var k: int = mini(n, to_remove_g)
				state.remove_to_available("germans", "troops", sid, k, "")
				to_remove_g -= k
				out["germans_removed"] += k
		out["log"].append("Germans -%d dalla mappa (Vassalage %d)" % [out["germans_removed"], vg])

	var vr: int = clampi(int(state.tracks.get("vassalage_russian", 0)), 0, 6)
	var on_r: int = state.count_on_map("russians", "troops")
	var diff_r: int = vr - on_r
	if diff_r > 0:
		# Piazza in un Town con pezzi Reds (se nessuno, nulla succede).
		var candidates: Array = []
		for sid in state.spaces.keys():
			var sd: SpaceDef = state.game_def.space(sid)
			if sd.type != CoinEnums.SpaceType.CITY:
				continue
			var st2: SpaceState = state.space_state(sid)
			if st2.count("reds", "cell") > 0 or st2.count("reds", "admin") > 0:
				candidates.append(sid)
		if not candidates.is_empty():
			var target: String = String(candidates[0])  # deterministico (no RNG nel modulo)
			var placed: int = state.place_from_available("russians", "troops", target, diff_r, "")
			out["russians_placed"] = placed
			out["log"].append("Russians +%d a %s (Vassalage %d)" % [placed, target, vr])
		else:
			out["log"].append("Russians: nessun Town con pezzi Reds, nulla piazzato (Vassalage %d)" % vr)
	elif diff_r < 0:
		var to_remove_r: int = -diff_r
		for sid in state.spaces.keys():
			if to_remove_r <= 0:
				break
			var st3: SpaceState = state.space_state(sid)
			var n: int = st3.count("russians", "troops")
			if n > 0:
				var k: int = mini(n, to_remove_r)
				state.remove_to_available("russians", "troops", sid, k, "")
				to_remove_r -= k
				out["russians_removed"] += k
		out["log"].append("Russians -%d dalla mappa (Vassalage %d)" % [out["russians_removed"], vr])

	return out


func _politics_phase() -> Dictionary:
	# §6.2 Politics Phase: usa ABBPoliticalDisplay per la risoluzione.
	# Personal Leadership check (§6.2.2): se Personality non sulla mappa,
	# Moderati -3 Risorse e cercano di rimetterla in una Town con Cell Moderati.
	var pd := ABBPoliticalDisplay.new(state)
	var result := pd.resolve_politics(-1)
	_personal_leadership_check(result)
	return result


func _personal_leadership_check(into: Dictionary) -> void:
	var on_map := false
	for sid in state.spaces.keys():
		if state.space_state(sid).marker("personality") > 0:
			on_map = true
			break
	if on_map:
		into["log"].append("Personal Leadership: Personality sulla mappa, niente penalità.")
		return
	# Penalità -3 Risorse Moderati
	state.resources["moderates"] = maxi(0, int(state.get_resources("moderates")) - 3)
	into["log"].append("Personal Leadership: Personality OFF map → Moderati Risorse -3.")
	# Cerca Town con Cellula Moderati per piazzare la Personality.
	for sid in state.spaces.keys():
		var sd: SpaceDef = state.game_def.space(sid)
		if sd.type != CoinEnums.SpaceType.CITY:
			continue
		var st: SpaceState = state.space_state(sid)
		if st.count("moderates", "cell") > 0:
			st.set_marker("personality", 1)
			into["log"].append("Personality piazzata a %s." % sid)
			return
	into["log"].append("Nessuna Town con Cellula Moderati: Personality fuori dal gioco.")


func _earnings_phase() -> Dictionary:
	var earnings := {}
	for f in state.game_def.factions:
		var fid: String = f.id
		var gain: int = _earnings_for(fid)
		earnings[fid] = gain
		state.resources[fid] = int(state.get_resources(fid)) + gain
	return earnings


func _earnings_for(fid: String) -> int:
	match fid:
		"reds":
			var gain_r: int = 0
			for sid in state.spaces.keys():
				var st: SpaceState = state.space_state(sid)
				if st.count("reds", "cell") > 0 or st.count("reds", "admin") > 0:
					gain_r += state.game_def.space(sid).pop
			return gain_r
		"senate":
			var gain_s: int = 0
			for sid in state.spaces.keys():
				var st: SpaceState = state.space_state(sid)
				if st.count("senate", "cell") > 0:
					gain_s += state.game_def.space(sid).pop
			return gain_s
		"moderates":
			return 1 + state.count_on_map("moderates", "network")
		"germans":
			return int(state.tracks.get("vassalage_german", 0)) / 2
		_:
			return 0
