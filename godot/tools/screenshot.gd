extends SceneTree

## Cattura uno screenshot della scena di partita (serve un display: xvfb-run).
##   xvfb-run -a -s "-screen 0 1600x950x24" godot --path godot --rendering-method gl_compatibility \
##       --resolution 1500x820 -s res://tools/screenshot.gd -- out.png [modo]
## Modi:
##   (nessuno)   la partita dopo che i Bot hanno giocato fino al turno del Senato umano;
##   rally       il Senato prepara un Rally su due spazi (pannello azione con Comando scelto);
##   eseguito    come "rally", poi preme "Esegui" e prepara un'Attività speciale (Tassazione);
##   moderati    i Moderati sono il giocatore umano (più tasti di Attività speciale);
##   fase2       Fase II forzata (Marcia/Attacco/Coordinamento attivi), Reds umani con Attacco scelto.

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var out := args[0] if args.size() > 0 else "user://screenshot.png"
	var mode := args[1] if args.size() > 1 else ""
	var human := "senate"
	if mode == "moderati":
		human = "moderates"
	elif mode == "fase2":
		human = "reds"
	# Gli autoload (GameRegistry, GameController) completano _ready al primo frame.
	await process_frame
	var gc = root.get_node("GameController")
	seed(1918)
	gc.new_game()
	for f in ["reds", "senate", "moderates"]:
		gc.set_role(f, "player" if f == human else "bot")
	if mode == "fase2":
		gc.state.tracks["phase"] = 2
	var main = load("res://scenes/Main.tscn").instantiate()
	root.add_child(main)
	for i in range(10):
		await process_frame
	# Fa giocare i Bot finché non tocca alla Fazione umana (massimo qualche carta),
	# preferendo il 1° posto della sequenza (Comando + Attività speciale ammessi).
	for i in range(60):
		var st: Dictionary = gc.seq_status()
		var p := String(st.get("pending", ""))
		if p == human and (bool(st.get("first_slot", false)) or i > 40):
			break
		if p != "" and gc.is_bot(p):
			gc.bot_act_pending()
		else:
			gc.advance_card()
		await process_frame
	for i in range(5):
		await process_frame
	if mode in ["rally", "moderati", "eseguito"]:
		main._start_op("rally")
		await process_frame
		var picked := 0
		for sid in main._abb_op_valid("rally"):
			main._on_space_clicked(sid)
			picked += 1
			if picked >= 2:
				break
	if mode == "eseguito":
		await process_frame
		print("esegui: ", main._on_execute(), " comando del turno: ", gc.turn_op())
		await process_frame
		main._do_special("tax")
		await process_frame
		var tv: Array = main._abb_sa_valid("tax")
		if not tv.is_empty():
			main._on_space_clicked(tv[0])
	elif mode == "fase2":
		main._start_op("attack")
		await process_frame
		var targets: Array = main._abb_op_valid("attack")
		if not targets.is_empty():
			main._on_space_clicked(targets[0])
	for i in range(30):
		await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	img.save_png(out)
	print("salvato ", out, " ", img.get_size())
	quit(0)
