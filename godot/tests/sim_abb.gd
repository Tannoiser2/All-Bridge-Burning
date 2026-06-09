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

	for gi in range(n):
		var r := _play_one(gi, act_counts, fp, occ)
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


func _play_one(gi: int, act_counts: Dictionary, fp: Dictionary, occ: Dictionary) -> Dictionary:
	var mod := ABBModule.new()
	var gd := mod.build_game_def()
	var state := GameState.new(gd)
	mod.apply_setup(state, "standard")
	var bot := ABBBot.new(state, mod)
	bot._pac2_dice_seed = gi + 1

	var deck := _build_deck(gd, gi)
	var cards := 0
	var props := 0
	var phase2 := false

	for card in deck:
		if props >= 4:
			break
		cards += 1
		if card.is_propaganda:
			props += 1
			ABBCrisis.new(state, mod).resolve()
			var vs := mod.victory_status(state)
			var w := _winner(vs)
			if w != "":
				return _finish(state, fp, occ, w, cards, phase2)
			continue
		# Red Revolt! → Phase II
		if card.number == 24:
			ABBEvents.new(state, mod).apply(24, "unshaded", "reds")
		var seq := SequenceOfPlay.new(state, mod, card)
		var guard := 0
		while not seq.is_done() and guard < 12:
			guard += 1
			var fid := seq.pending_faction()
			if fid == "":
				break
			var turn := bot.take_turn(fid)
			var action := String(turn.get("action", "pass"))
			act_counts[action] = int(act_counts.get(action, 0)) + 1
			if action == "pass":
				seq.act_pass()
			else:
				seq.act(CoinEnums.ActionType.OPERATION)
		seq.finish()
		if int(state.tracks.get("phase", 1)) >= 2:
			phase2 = true
			var gt := bot.take_turn("germans")
			var ga := String(gt.get("action", "pass"))
			if ga != "pass":
				act_counts["G:" + ga] = int(act_counts.get("G:" + ga, 0)) + 1

	var vs2 := mod.victory_status(state)
	return _finish(state, fp, occ, _best_margin(vs2), cards, phase2)


func _build_deck(gd: GameDef, gi: int) -> Array:
	var events := []
	var props := []
	for c in gd.cards:
		if c.is_propaganda:
			props.append(c)
		else:
			events.append(c)
	var rng := RandomNumberGenerator.new()
	rng.seed = gi * 104729 + 1
	for i in range(events.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = events[i]; events[i] = events[j]; events[j] = t
	var deck := []
	var pi := 0
	for i in range(events.size()):
		deck.append(events[i])
		if (i + 1) % 11 == 0 and pi < props.size():
			deck.append(props[pi]); pi += 1
	while pi < props.size():
		deck.append(props[pi]); pi += 1
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
