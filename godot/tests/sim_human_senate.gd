extends SceneTree

## Esperimento: Senato giocato da una policy "umana" greedy orientata alla
## vittoria (Town Control >3), con regole da GIOCATORE: paga le Risorse
## (NO §8.1.2) e forza d'Attack = pezzi (NO §8.1.3). Le altre fazioni restano bot.

func _initialize() -> void:
	var mod := ABBModule.new(); var gd := mod.build_game_def()
	var N := 500
	var wins := {"reds":0,"senate":0,"moderates":0}
	var acc := {"stp":0.0,"sres":0.0,"scell":0.0,"rv":0.0,"mv":0.0,"sv":0.0,"sact":0.0,"spass":0.0}
	for gi in range(N):
		var state := GameState.new(gd); mod.apply_setup(state, "standard")
		for f in ["reds","moderates","germans","russians"]: state.roles[f]="bot"
		state.roles["senate"] = "player"
		var bot := ABBBot.new(state, mod); bot._pac2_dice_seed = gi+1
		var events := ABBEvents.new(state, mod)
		var ops := ABBOperations.new(state, mod)
		var sp := ABBSpecialActivities.new(state, mod)
		var deck: Array = _deck(gd, gi); var props := 0
		for card in deck:
			if props >= 4: break
			if card.is_propaganda: props += 1; ABBCrisis.new(state, mod).resolve(); continue
			if card.number == 24 and int(state.tracks.get("phase",1))<2: events.apply(24,"unshaded","reds")
			var seq := SequenceOfPlay.new(state, mod, card); var g := 0
			while not seq.is_done() and g < 12:
				g += 1; var fid := seq.pending_faction()
				if fid == "": break
				if fid == "senate":
					if _senate_human_turn(state, gd, ops, sp):
						acc.sact += 1.0; seq.act(CoinEnums.ActionType.OPERATION)
					else:
						acc.spass += 1.0; seq.act_pass()
				else:
					var t: Dictionary = bot.take_turn(fid)
					if String(t.get("action","pass"))=="pass": seq.act_pass()
					else: seq.act(CoinEnums.ActionType.OPERATION)
			seq.finish()
			if int(state.tracks.get("phase",1))>=2: bot.take_turn("germans")
		var vs: Dictionary = mod.victory_status(state)
		var best := ""; var bm := -99999
		for f in ["reds","moderates","senate"]:
			if int(vs[f]["margin"]) > bm: bm = int(vs[f]["margin"]); best = f
		wins[best] += 1
		acc.stp += vs["senate"]["value"]; acc.sres += state.get_resources("senate")
		acc.scell += state.count_on_map("senate","cell")
		acc.rv += vs["reds"]["value"]; acc.mv += vs["moderates"]["value"]; acc.sv += vs["senate"]["value"]
	var fn := float(N)
	print("== SENATO UMANO (policy greedy) — %d partite ==" % N)
	print("VITTORIE: reds %.1f%%  senate %.1f%%  moderates %.1f%%" % [100.0*wins.reds/fn, 100.0*wins.senate/fn, 100.0*wins.moderates/fn])
	print("Senate: TownPop=%.2f (soglia 3)  Risorse=%.1f  Cellule=%.1f  azioni/partita=%.1f pass=%.1f" % [acc.stp/fn, acc.sres/fn, acc.scell/fn, acc.sact/fn, acc.spass/fn])
	print("Valori medi: Reds %.1f/11  Senate %.1f/3  Moder %.1f/14" % [acc.rv/fn, acc.sv/fn, acc.mv/fn])
	quit(0)


## Town per Pop decrescente.
func _towns(gd: GameDef, state: GameState) -> Array:
	var out: Array = []
	for sid in state.spaces.keys():
		var sd: SpaceDef = gd.space(sid)
		if sd != null and sd.type == CoinEnums.SpaceType.CITY:
			out.append(sid)
	out.sort_custom(func(a, b): return gd.space(a).pop > gd.space(b).pop)
	return out


## Pezzi che contano per il Controllo (§1.7: troops esclusi).
func _ctrl_pieces(st: SpaceState, fid: String) -> int:
	return st.count(fid, "cell") + st.count(fid, "admin") + st.count(fid, "network")


func _enemy_ctrl_pieces(st: SpaceState) -> int:
	var n := 0
	for f in ["reds", "moderates"]:
		n += _ctrl_pieces(st, f)
	return n


## Un turno "umano" del Senato: Op + eventuale SA. true = ha agito.
func _senate_human_turn(state: GameState, gd: GameDef, ops: ABBOperations, sp: ABBSpecialActivities) -> bool:
	var vg := int(state.tracks.get("vassalage_german", 0))
	var pol := int(state.tracks.get("polarization", 0))
	# SA difensiva: non farsi azzerare la vittoria (§7.2: vass+pol>5 → 0).
	if vg + pol >= 5 and vg > 0:
		sp.foreign_relations("germans", -1)
	var res := int(state.get_resources("senate"))
	# Senza risorse: Tax dove pop più alta con Cellula Senato (SA, gratis).
	if res <= 0:
		var best_tax := ""; var bp := 0
		for sid in state.spaces.keys():
			var sd: SpaceDef = gd.space(sid)
			if sd.pop > bp and state.space_state(sid).count("senate", "cell") > 0:
				bp = sd.pop; best_tax = String(sid)
		if best_tax != "":
			sp.tax("senate", best_tax)
			return true
		return false
	var phase := int(state.tracks.get("phase", 1))
	# ❶ Rally che CONQUISTA una Town (pop più alta prima).
	if state.available("senate", "cell") > 0:
		for sid in _towns(gd, state):
			var st: SpaceState = state.space_state(sid)
			if st.control == "senate":
				continue
			if _ctrl_pieces(st, "senate") + 1 > _enemy_ctrl_pieces(st):
				if ops.rally("senate", sid, "cell").get("ok", false):
					_try_crackdown(state, sp)
					return true
	# ❷ Phase II: Attack nella Town più ricca non controllata dove il Senato ha pezzi.
	if phase >= 2 and res >= 1:
		for sid in _towns(gd, state):
			var st: SpaceState = state.space_state(sid)
			if st.control != "senate" and st.count("senate", "cell") > 0 and _enemy_ctrl_pieces(st) > 0:
				if ops.attack("senate", sid).get("ok", false):
					_try_crackdown(state, sp)
					return true
	# ❸ Rally di avvicinamento: Town non controllata col divario minore.
	if state.available("senate", "cell") > 0 and res >= 1:
		var best := ""; var gap := 999
		for sid in _towns(gd, state):
			var st: SpaceState = state.space_state(sid)
			if st.control == "senate":
				continue
			var g := _enemy_ctrl_pieces(st) - _ctrl_pieces(st, "senate")
			if g < gap:
				gap = g; best = String(sid)
		if best != "" and ops.rally("senate", best, "cell").get("ok", false):
			_try_crackdown(state, sp)
			return true
	# ❹ March: porta una Cellula da una Provincia verso una Town adiacente non controllata.
	for sid in state.spaces.keys():
		var sd: SpaceDef = gd.space(sid)
		if sd == null or sd.type == CoinEnums.SpaceType.CITY:
			continue
		var st: SpaceState = state.space_state(sid)
		if st.count("senate", "cell") < 2:
			continue
		for adj in sd.adjacent:
			var ad: SpaceDef = gd.space(String(adj))
			if ad != null and ad.type == CoinEnums.SpaceType.CITY \
					and state.space_state(String(adj)).control != "senate":
				if ops.march("senate", sid, String(adj), "cell", 1).get("ok", false):
					return true
	return false


## Crackdown dove rimuove più Opposizione (richiede Cellula Attiva + Controllo).
func _try_crackdown(state: GameState, sp: ABBSpecialActivities) -> void:
	if int(state.get_resources("senate")) < 1:
		return
	var best := ""; var bo := 0
	for sid in state.spaces.keys():
		var st: SpaceState = state.space_state(sid)
		if st.count("senate", "cell", "active") > 0 and st.control == "senate" and int(st.support) < 0:
			if -int(st.support) > bo:
				bo = -int(st.support); best = String(sid)
	if best != "":
		sp.crackdown(best)


func _deck(gd: GameDef, gi: int) -> Array:
	var ev := []; var pr := []
	for c in gd.cards:
		if c.is_propaganda: pr.append(c)
		else: ev.append(c)
	var rng := RandomNumberGenerator.new(); rng.seed = gi*104729+1
	for i in range(ev.size()-1,0,-1):
		var j := rng.randi_range(0,i); var t = ev[i]; ev[i]=ev[j]; ev[j]=t
	var d := []; var pi := 0
	for i in range(ev.size()):
		d.append(ev[i])
		if (i+1)%11==0 and pi<pr.size(): d.append(pr[pi]); pi+=1
	while pi<pr.size(): d.append(pr[pi]); pi+=1
	return d
