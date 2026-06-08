extends GameManifest

## Manifest del gioco "Cuba Libre" (Serie COIN Vol. II) — factory dei sottosistemi.

func game_id() -> String:
	return "cuba_libre"

func game_title() -> String:
	return "Cuba Libre"

func create_module() -> RulesModule:
	return CubaLibreModule.new()

func create_operations(state, module):
	return CubaLibreOperations.new(state, module)

func create_specials(state, module):
	return CubaLibreSpecials.new(state, module)

func create_propaganda(state, module):
	return CubaLibrePropaganda.new(state, module)

func create_events(state, module):
	return CubaLibreEvents.new(state, module)

func create_bot(state, module):
	return CLCalixto.new(state, module)

func default_roles(_game_def: GameDef) -> Dictionary:
	# Solitario classico: l'umano gioca il Governo contro 3 NP.
	return {"government": "player", "m26": "bot", "directorio": "bot", "syndicate": "bot"}
