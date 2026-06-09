extends GameManifest

## Manifest del gioco "All Bridges Burning" (Serie COIN Vol. IX, GMT 2020) —
## scheletro iniziale. I sottosistemi sono stub: verranno implementati in modo
## incrementale (mappa+spazi → operazioni → att.speciali → eventi → round → bot).

func game_id() -> String:
	return "all_bridges_burning"

func game_title() -> String:
	return "All Bridges Burning"

func create_module() -> RulesModule:
	return ABBModule.new()

func create_operations(state, module):
	return ABBOperations.new(state, module)

func create_specials(state, module):
	return ABBSpecialActivities.new(state, module)

func create_propaganda(state, module):
	return ABBCrisis.new(state, module)

func create_events(state, module):
	return ABBEvents.new(state, module)

func create_bot(state, module):
	return ABBBot.new(state, module)

func op_names() -> Dictionary:
	return {
		"rally": "Rally", "march": "March", "attack": "Attack", "terror": "Terror",
		"message": "Message", "activism": "Activism",
	}

func op_descriptions() -> Dictionary:
	return {
		"rally": "Piazza Cellule (o Admin/Network) in uno spazio. Costo: 1 Risorsa per spazio.",
		"march": "Sposta Cellule/Truppe verso uno spazio adiacente. Le Cellule entrate in spazio nemico diventano Active.",
		"attack": "Tira 1d6 vs Attack Strength (cellule + truppe). Su successo rimuovi 1 pezzo nemico.",
		"terror": "Reds/Senate: poni marker Terror in uno spazio con tua Cellula e sposta Supporto/Opposizione.",
		"message": "Moderates: sposta News markers, gira Cellule clandestine/attive.",
		"activism": "Moderates: sposta Supporto/Opposizione verso Neutral; aumenta Polarization.",
	}

func op_kinds() -> Dictionary:
	return {
		"rally": "space_list", "attack": "space_list", "terror": "space_list",
		"activism": "space_list", "march": "moves", "message": "moves",
	}

func sa_names() -> Dictionary:
	return {
		"agitate": "Agitazione", "ambush": "Imboscata", "subvert": "Sovversione",
		"crackdown": "Repressione", "coordinate": "Coordinamento", "negotiate": "Negoziato",
		"dialogue": "Dialogo", "foreign_relations": "Relazioni Estere", "tax": "Tassazione",
	}

func sa_descriptions() -> Dictionary:
	return {
		"agitate": "Reds: spendi 1 Risorsa per spostare il Supporto di 1 step verso Opposition in uno spazio con tua Cellula.",
		"ambush": "Reds: in uno spazio per Attack, rimuovi 2 pezzi nemici senza tirare. Attiva la tua Cellula clandestina.",
		"subvert": "Reds: rimuovi 1 Cellula avversaria in uno spazio dove hai una Cellula clandestina.",
		"crackdown": "Senate: rimuovi 1 marker Terror; sposta Supporto verso Senate. Costa 1 Risorsa.",
		"coordinate": "Senate: muovi 1 Truppa Russa/Tedesca verso uno spazio adiacente.",
		"negotiate": "Senate/Moderates: aumenta +1 la Vassalage Tedesca.",
		"dialogue": "Moderates: sposta Supporto/Opposizione verso Neutral in uno spazio con tua Cellula.",
		"foreign_relations": "Moderates: cambia la Vassalage Tedesca o Russa.",
		"tax": "Incassa Risorse pari alla Popolazione di uno spazio dove hai una tua Cellula.",
	}

func sa_variants() -> Dictionary:
	return {}

func piece_names() -> Dictionary:
	return {
		"troops": "Truppa", "cell": "Cellula", "admin": "Amministrazione", "network": "Network",
	}


func default_roles(_game_def: GameDef) -> Dictionary:
	# Solitario classico: l'umano gioca il Senate contro Reds e Moderates NP.
	# Germans e Russians sono Powers gestite dal motore (mai "player").
	return {
		"senate": "player",
		"reds": "bot",
		"moderates": "bot",
		"germans": "bot",
		"russians": "bot",
	}
