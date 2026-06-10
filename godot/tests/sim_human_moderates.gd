extends SceneTree

## Esperimento: MODERATI giocati da una policy "umana" greedy (vittoria §7.2:
## Risorse >14 AND Issues+Networks+1 ≥ Polarization), con regole da GIOCATORE
## (pagano le Risorse). Le altre fazioni restano bot.
## Negotiate (§3.3.3) emulato coi primitivi: Cellula nemica Attiva→Underground,
## Polarization −1, costo 1 (il motore non ha ancora l'op player-side).

func _initialize() -> void:
	var mod := ABBModule.new(); var gd := mod.build_game_def()
	var N := 500
	var wins := {"reds":0,"senate":0,"moderates":0}
	var acc := {"mres":0.0,"inw":0.0,"pol":0.0,"mv":0.0,"rv":0.0,"sv":0.0,"act":0.0,"pass":0.0,"net":0.0}
	for gi in range(N):
		var state := GameState.new(gd); mod.apply_setup(state, "standard")
		for f in ["reds","senate","germans","russians"]: state.roles[f]="bot"
		state.roles["moderates"] = "player"
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
				if fid == "moderates":
					if _mod_human_turn(state, gd, ops, sp):
						acc.act += 1.0; seq.act(CoinEnums.ActionType.OPERATION)
					else:
						acc.pass += 1.0; seq.act_pass()
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
		acc.mres += state.get_resources("moderates")
		acc.inw += mod.issues_networks_expr(state)
		acc.pol += int(state.tracks.get("polarization", 0))
		acc.net += state.count_on_map("moderates", "network")
		acc.mv += vs["moderates"]["value"]; acc.rv += vs["reds"]["value"]; acc.sv += vs["senate"]["value"]
	var fn := float(N)
	print("== MODERATI UMANI (policy greedy) — %d partite ==" % N)
	print("VITTORIE: reds %.1f%%  senate %.1f%%  moderates %.1f%%" % [100.0*wins.reds/fn, 100.0*wins.senate/fn, 100.0*wins.moderates/fn])
	print("Moderati: Risorse=%.1f (>14)  Issues+Net=%.2f  Pol=%.2f  Networks=%.2f  azioni=%.1f pass=%.1f" % [acc.mres/fn, acc.inw/fn, acc.pol/fn, acc.net/fn, acc.act/fn, acc.pass/fn])
	print("Valori medi: Reds %.1f/11  Senate %.1f/3  Moder %.1f/14" % [acc.rv/fn, acc.sv/fn, acc.mv/fn])
	quit(0)


func _mod_human_turn(state: GameState, gd: GameDef, ops: ABBOperations, sp: ABBSpecialActivities) -> bool:
	var res := int(state.get_resources("moderates"))
	var pol := int(state.tracks.get("polarization", 0))
	# SA Dialogue SEMPRE (gratis): smorza il Supporto/Opposizione più estremo.
	var best_d0 := ""; var bd0 := 0
	for sid in state.spaces.keys():
		var st0: SpaceState = state.space_state(sid)
		if st0.count("moderates", "cell") > 0 and absi(int(st0.support)) > bd0:
			bd0 = absi(int(st0.support)); best_d0 = String(sid)
	if best_d0 != "":
		sp.dialogue(best_d0)
	# Senza risorse: Tax dove pop più alta con Cellula Moderati.
	if res <= 1:
		var best_tax := ""; var bp := 0
		for sid in state.spaces.keys():
			var sd: SpaceDef = gd.space(sid)
			if sd.pop > bp and state.space_state(sid).count("moderates", "cell") > 0:
				bp = sd.pop; best_tax = String(sid)
		if best_tax != "":
			sp.tax("moderates", best_tax)
			return true
		return false
	# ❶ Polarization alta = vittoria azzerata: Negotiate (§3.3.3, emulato).
	if pol >= 5:
		for sid in state.spaces.keys():
			var st: SpaceState = state.space_state(sid)
			if st.count("moderates", "cell") <= 0:
				continue
			for f in ["reds", "senate"]:
				if st.count(f, "cell", "active") > 0:
					st.remove_piece(f, "cell", 1, "active")
					st.add_piece(f, "cell", 1, "underground")
					state.tracks["polarization"] = maxi(0, pol - 1)
					state.resources["moderates"] = res - 1
					return true
	# ❷ Network disponibili: rally Network (rendita +1/Propaganda e conta per §7.2).
	if state.available("moderates", "network") > 0 and res >= 1:
		var best_net := ""; var bp2 := -1
		for sid in state.spaces.keys():
			var st: SpaceState = state.space_state(sid)
			var sd: SpaceDef = gd.space(sid)
			if st.count("moderates", "cell") > 0 and st.count("moderates", "network") == 0 and sd.pop > bp2:
				bp2 = sd.pop; best_net = String(sid)
		if best_net != "" and ops.rally("moderates", best_net, "network").get("ok", false):
			return true
	# ❸ Meno di 3 Cellule (minimo per Politics): rally Cellula.
	if state.count_on_map("moderates", "cell") < 3 and state.available("moderates", "cell") > 0:
		var tgt := ""
		for sid in state.spaces.keys():
			if state.space_state(sid).count("moderates", "cell") > 0:
				tgt = String(sid); break
		if tgt == "":
			tgt = "helsinki"
		if ops.rally("moderates", tgt, "cell").get("ok", false):
			return true
	# ❹ Politics: piazza un cubo per risolvere l'Issue corrente (costo 1+pol/2).
	var cost := 1 + int(pol / 2)
	if pol <= 5 and res >= cost:
		var color := "senate" if int(state.tracks.get("polarization", 0)) % 2 == 0 else "reds"
		if ops.politics("moderates", color).get("ok", false):
			# SA Dialogue: spazio col Supporto/Opposizione più estremo.
			var best_d := ""; var bd := 0
			for sid in state.spaces.keys():
				var st: SpaceState = state.space_state(sid)
				if st.count("moderates", "cell") > 0 and absi(int(st.support)) > bd:
					bd = absi(int(st.support)); best_d = String(sid)
			if best_d != "":
				sp.dialogue(best_d)
			return true
	# ❺ Accumula: Tax sulla pop più alta.
	var best2 := ""; var bp3 := 0
	for sid in state.spaces.keys():
		var sd: SpaceDef = gd.space(sid)
		if sd.pop > bp3 and state.space_state(sid).count("moderates", "cell") > 0:
			bp3 = sd.pop; best2 = String(sid)
	if best2 != "":
		sp.tax("moderates", best2)
		return true
	return false


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
