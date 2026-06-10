extends SceneTree

## Simulazione headless ABB: N partite bot vs bot, report comportamento bot.
## Uso: godot --headless --path godot -s res://tests/sim_abb.gd -- 500

func _initialize() -> void:
	var n := 500
	var args := OS.get_cmdline_user_args()
	if args.size() > 0 and args[0].is_valid_int():
		n = int(args[0])
	print("== Simulazione ABB: %d partite ==" % n)

	var wins := {"reds": 0, "senate": 0, "moderates": 0, "none": 0}
	var act_counts := {}
	var sum_cards := 0
	var phase2_reached := 0
	var fp := {"reds_cell": 0, "senate_cell": 0, "moderates_cell": 0, "reds_admin": 0, "moderates_network": 0}
	var occ := {}
	var ev := {}  # eventi giocati dai bot (per carta) + _capabilities

	for gi in range(n):
		var r := _play_one(gi, act_counts, fp, occ, ev)
		wins[r["winner"]] = int(wins[r["winner"]]) + 1
		sum_cards += int(r["cards"])
		if r["phase2"]:
			phase2_reached += 1

	print("\n--- VINCITORI ---")
	for f in ["reds", "senate", "moderates", "none"]:
		print("  %-10s %5d  (%.1f%%)" % [f, int(wins[f]), 100.0 * int(wins[f]) / n])
	print("\n--- DURATA ---")
	print("  carte medie/partita: %.1f" % (float(sum_cards) / n))
	print("  Phase II: %d/%d (%.1f%%)" % [phase2_reached, n, 100.0 * phase2_reached / n])
	print("\n--- AZIONI BOT (totali) ---")
	var ks := act_counts.keys(); ks.sort()
	for k in ks:
		print("  %-16s %d" % [k, int(act_counts[k])])
	print("\n--- EVENTI GIOCATI DAI BOT (§8.1.4/§8.1.5) ---")
	var ev_total := 0
	var ev_pairs := []
	for k in ev:
		if String(k).begins_with("_"):
			continue
		ev_total += int(ev[k])
		ev_pairs.append({"k": k, "n": int(ev[k])})
	ev_pairs.sort_custom(func(a, b): return int(a["n"]) > int(b["n"]))
	print("  Eventi giocati TOTALI: %d  (%.2f/partita)" % [ev_total, float(ev_total) / n])
	print("  di cui Capability: %d  (%.2f/partita)" % [int(ev.get("_capabilities", 0)), float(int(ev.get("_capabilities", 0))) / n])
	print("  Pass-per-giocare-Capability: %d" % int(ev.get("_cap_pass", 0)))
	for p in ev_pairs:
		print("    %-22s %d" % [p["k"], p["n"]])
	print("\n--- PEZZI FINALI (media/partita) ---")
	for k in fp:
		print("  %-18s %.2f" % [k, float(fp[k]) / n])
	print("\n--- SPAZI: media pezzi/partita (piling check) ---")
	var pairs := []
	for sid in occ:
		pairs.append({"sid": sid, "avg": float(occ[sid]) / n})
	pairs.sort_custom(func(a, b): return float(a["avg"]) > float(b["avg"]))
	for p in pairs:
		print("  %-18s %.2f" % [p["sid"], p["avg"]])
	quit(0)


func _play_one(gi: int, act_counts: Dictionary, fp: Dictionary, occ: Dictionary, ev: Dictionary) -> Dictionary:
	var mod := ABBModule.new()
	var gd := mod.build_game_def()
	var state := GameState.new(gd)
	mod.apply_setup(state, "standard")
	var events := ABBEvents.new(state, mod)
	# Sim tutto-bot: per §8.1.2 le fazioni Non-player non tracciano/spendono
	# Risorse. Senza ruoli espliciti, tracks_resources() le tratterebbe da player.
	for f in ["reds", "senate", "moderates", "germans", "russians"]:
		state.roles[f] = "bot"
	var bot := ABBBot.new(state, mod)
	bot._pac2_dice_seed = gi + 1

	var deck := _build_deck(gd, gi)
	var cards := 0
	var props := 0
	var phase2 := false
	var rr_due := false   # §2.4: Red Revolt! sostituirà la prossima carta

	for card in deck:
		if props >= 4:
			break
		cards += 1
		if card.is_propaganda:
			props += 1
			ABBCrisis.new(state, mod).resolve()
			# §2.4: se Red Revolt! non è scattata entro la fine della 2ª
			# Propaganda, sostituisce la PROSSIMA carta (qui: flag → al
			# prossimo giro la carta viene rimpiazzata da #24).
			if props == 2 and int(state.tracks.get("phase", 1)) < 2:
				rr_due = true
			var vs := mod.victory_status(state)
			var w := _winner(vs)
			if w != "":
				return _finish(state, fp, occ, w, cards, phase2)
			continue
		# §2.4: Red Revolt! sostituisce questa carta (trigger 27+ Cellule o 2ª Propaganda).
		if rr_due and int(state.tracks.get("phase", 1)) < 2:
			rr_due = false
			events.apply(24, "unshaded", "reds")
			ev["#24 Red Revolt"] = int(ev.get("#24 Red Revolt", 0)) + 1
			continue  # la carta sostituita è scartata senza effetto
		var seq := SequenceOfPlay.new(state, mod, card)
		var guard := 0
		while not seq.is_done() and guard < 12:
			guard += 1
			var fid := seq.pending_faction()
			if fid == "":
				break
			# §8.1.4/§8.1.5: la fazione gioca l'EVENTO se è una carta che le giova
			# (Capability/critica) ed è legale; altrimenti fa un'Operazione.
			if seq.is_legal(CoinEnums.ActionType.EVENT) and fid in ["reds", "senate", "moderates"] \
					and bot.is_event_critical(fid, card.number) \
					and bot.event_choice(fid, card.number).get("play", false):
				var ec = bot.event_choice(fid, card.number)
				events.apply(card.number, String(ec.get("side", "unshaded")), fid)
				act_counts["EVENT"] = int(act_counts.get("EVENT", 0)) + 1
				ev["#%d" % card.number] = int(ev.get("#%d" % card.number, 0)) + 1
				if bot.capability_benefits(fid, card.number):
					ev["_capabilities"] = int(ev.get("_capabilities", 0)) + 1
				seq.act(CoinEnums.ActionType.EVENT)
				continue
			var turn := bot.take_turn(fid)
			var action := String(turn.get("action", "pass"))
			act_counts[action] = int(act_counts.get(action, 0)) + 1
			if action == "pass":
				seq.act_pass()
			else:
				seq.act(CoinEnums.ActionType.OPERATION)
		seq.finish()
		# §2.4: 27+ Cellule Reds+Senato a fine turno → Red Revolt! al posto
		# del prossimo Evento.
		if int(state.tracks.get("phase", 1)) < 2 and not rr_due \
				and state.count_on_map("reds", "cell") + state.count_on_map("senate", "cell") >= 27:
			rr_due = true
		if int(state.tracks.get("phase", 1)) >= 2:
			phase2 = true
			var gt := bot.take_turn("germans")
			var ga := String(gt.get("action", "pass"))
			if ga != "pass":
				act_counts["G:" + ga] = int(act_counts.get("G:" + ga, 0)) + 1

	var vs2 := mod.victory_status(state)
	# §7.3: a fine partita vince il margine più alto (tiebreak per ordine), MAI "none".
	return _finish(state, fp, occ, _tiebreak_winner(vs2), cards, phase2)


## §7.3 tiebreak finale: margine più alto; a parità, ordine reds < moderates < senate.
func _tiebreak_winner(vs: Dictionary) -> String:
	var best := ""
	var bm := -999999
	for f in ["reds", "moderates", "senate"]:
		var m := int(vs[f]["margin"])
		if m > bm:
			bm = m; best = f
	return best


## Mazzo FEDELE al Setup: 21 Eventi 1917 (#1-21) e 21 Eventi 1918 (#25-45)
## mescolati separatamente; Campaign Deck = (4 Eventi + 1 Propaganda) mescolati
## + 5 Eventi in cima; 2 Campaign 1917 sopra 2 Campaign 1918; 3 avanzi per anno
## fuori; #24 Red Revolt! NON nel mazzo (entra per trigger §2.4 nel loop).
func _build_deck(gd: GameDef, gi: int) -> Array:
	var y1917: Array = []
	var y1918: Array = []
	var props: Array = []
	for c in gd.cards:
		if c.is_propaganda:
			props.append(c)
		elif c.number == 24:
			continue
		elif c.number <= 21:
			y1917.append(c)
		else:
			y1918.append(c)
	var rng := RandomNumberGenerator.new()
	rng.seed = gi * 104729 + 1
	for arr in [y1917, y1918]:
		for i in range(arr.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var t = arr[i]; arr[i] = arr[j]; arr[j] = t
	var deck: Array = []
	var pi := 0
	for pool in [y1917, y1917, y1918, y1918]:
		var bottom: Array = []
		for _i in range(4):
			bottom.append(pool.pop_back())
		bottom.append(props[pi]); pi += 1
		for i in range(bottom.size() - 1, 0, -1):
			var j2 := rng.randi_range(0, i)
			var t2 = bottom[i]; bottom[i] = bottom[j2]; bottom[j2] = t2
		var top: Array = []
		for _i in range(5):
			top.append(pool.pop_back())
		deck.append_array(top + bottom)
	return deck


func _winner(vs: Dictionary) -> String:
	var w := []
	for f in ["reds", "senate", "moderates"]:
		if vs[f]["won"]:
			w.append(f)
	if w.is_empty():
		return ""
	return _best_margin(vs, w)


func _best_margin(vs: Dictionary, only: Array = []) -> String:
	var pool: Array = only if not only.is_empty() else ["reds", "senate", "moderates"]
	var best := ""
	var bm := -99999
	for f in pool:
		if int(vs[f]["margin"]) > bm:
			bm = int(vs[f]["margin"]); best = f
	if best == "" or bm < 0:
		return "none"
	return best


func _finish(state: GameState, fp: Dictionary, occ: Dictionary, winner: String, cards: int, phase2: bool) -> Dictionary:
	fp["reds_cell"] += state.count_on_map("reds", "cell")
	fp["senate_cell"] += state.count_on_map("senate", "cell")
	fp["moderates_cell"] += state.count_on_map("moderates", "cell")
	fp["reds_admin"] += state.count_on_map("reds", "admin")
	fp["moderates_network"] += state.count_on_map("moderates", "network")
	for sid in state.spaces.keys():
		var st: SpaceState = state.space_state(sid)
		var tot := 0
		for f in ["reds", "senate", "moderates", "germans", "russians"]:
			for pt in ["cell", "admin", "network", "troops"]:
				tot += st.count(f, pt)
		occ[sid] = int(occ.get(sid, 0)) + tot
	return {"winner": winner, "cards": cards, "phase2": phase2}
