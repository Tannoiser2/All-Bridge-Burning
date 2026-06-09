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
