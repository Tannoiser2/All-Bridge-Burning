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


# ---------------------------------------------------------------------------
# Etichette UI (sposate da Main.gd const)
# ---------------------------------------------------------------------------

func op_names() -> Dictionary:
	return {
		"train": "Addestramento", "garrison": "Guarnigione", "sweep": "Perlustrazione",
		"assault": "Assalto", "rally": "Riorganizzazione", "march": "Marcia",
		"attack": "Attacco", "terror": "Terrorismo", "build": "Costruzione",
	}

func op_descriptions() -> Dictionary:
	return {
		"train": "Clicca uno spazio per piazzare cubi (riclicca per +1, fino a 4); un altro click cicla a Base (da 2 cubi) o Azione Civica (1 sola Att. speciale per Addestramento).",
		"garrison": "Sposta cubi verso Città/EC (trascina); attiva le Guerriglie negli EC. Clicca un EC per un Assalto gratuito lì.",
		"sweep": "Sposta Truppe negli spazi adiacenti e attiva 1 Guerriglia clandestina nemica per ogni Truppa/Polizia.",
		"assault": "Rimuovi pezzi nemici scoperti (1 per Truppa, o per Polizia in Città): prima le Guerriglie Attive, poi le Basi.",
		"rally": "Clicca uno spazio per piazzare Guerriglie; riclicca per cambiare azione (Base = sostituisci 2 Guerriglie con 1 Base; Clandestine = gira sotto, dove hai una Base).",
		"march": "Sposta Guerriglie/cubi in spazi adiacenti; chi entra dove ci sono nemici o Polizia diventa Attivo.",
		"attack": "Tira per rimuovere pezzi nemici (1 ogni 2 Guerriglie); con l'Imboscata colpisci senza tiro.",
		"terror": "Con una Guerriglia clandestina: poni Terrore e sposta il Supporto verso l'Opposizione (o Sabotaggio su LoC/EC).",
		"build": "Sindacato (5 Risorse/spazio): clicca per un nuovo Casinò chiuso; riclicca per aprirne uno già chiuso, dove possibile.",
	}

func op_kinds() -> Dictionary:
	return {
		"train": "space_list", "assault": "space_list", "rally": "space_list",
		"attack": "space_list", "terror": "space_list", "build": "space_list",
		"sweep": "moves", "garrison": "moves", "march": "moves",
	}

func sa_names() -> Dictionary:
	return {
		"transport": "Trasporto", "air_strike": "Attacco Aereo", "reprisal": "Rappresaglia",
		"infiltrate": "Infiltrazione", "ambush": "Imboscata", "kidnap": "Sequestro",
		"subvert": "Sovversione", "assassinate": "Assassinio",
		"profit": "Profitto", "muscle": "Muscle", "bribe": "Corruzione",
	}

func sa_descriptions() -> Dictionary:
	return {
		"transport": "Sposta fino a 3 Truppe da una Città o da una Base verso un qualsiasi spazio.",
		"air_strike": "Rimuovi 1 Guerriglia Attiva (o, se assente, 1 Base) in una Provincia/EC. Vietato durante l'Embargo.",
		"reprisal": "In uno spazio a Controllo Govt: poni Terrore, riduci l'Opposizione e sposta 1 Guerriglia in uno spazio adiacente.",
		"infiltrate": "Rimpiazza 1 cubo del Governo con una Guerriglia 26J in uno spazio senza Supporto (serve una clandestina 26J lì o adiacente).",
		"ambush": "In uno spazio scelto per l'Attacco: colpisci senza tiro rimuovendo 2 pezzi nemici (anche Basi).",
		"kidnap": "Trasferisci Risorse/Denaro dal Governo al 26J e chiudi 1 Casinò; servono più Guerriglie 26J che Polizia.",
		"subvert": "In una Provincia a Controllo DR: aggiungi Risorse pari alla Popolazione e rendi lo spazio Neutrale.",
		"assassinate": "Rimuovi 1 pezzo nemico (anche una Base) dove le Guerriglie DR superano la Polizia.",
		"profit": "Accumula 1 Denaro in 1-2 spazi con un Casinò aperto.",
		"muscle": "Sposta 1-2 Polizia (verso Città) o Truppe (verso Provincia/EC) in uno spazio con Casinò aperto o EC.",
		"bribe": "Spendi 3 Risorse del Sindacato per rimuovere fino a 2 cubi/Guerriglie nemici (o 1 Base) in uno spazio.",
	}

func sa_variants() -> Dictionary:
	return {
		"kidnap": [
			{"id": "kidnap:government", "label": "Sequestro (Governo)", "p": {"target": "government"}},
			{"id": "kidnap:syndicate", "label": "Sequestro (Sindacato)", "p": {"target": "syndicate"}},
		],
		"profit": [
			{"id": "profit:cash", "label": "Profitto (incassa Denaro)", "p": {"mode": "cash"}},
			{"id": "profit:convert", "label": "Profitto (converti in Risorse)", "p": {"mode": "convert"}},
		],
		"bribe": [
			{"id": "bribe:cubes", "label": "Corruzione (cubi)", "p": {"action": "cubes"}},
			{"id": "bribe:guerrillas_remove", "label": "Corruzione (rimuovi Guerriglie)", "p": {"action": "guerrillas_remove"}},
			{"id": "bribe:guerrillas_flip", "label": "Corruzione (gira Guerriglie)", "p": {"action": "guerrillas_flip"}},
			{"id": "bribe:base", "label": "Corruzione (rimuovi Base)", "p": {"action": "base"}},
		],
	}

func piece_names() -> Dictionary:
	return {
		"troops": "Truppa", "police": "Polizia", "guerrilla": "Guerriglia",
		"base": "Base", "casino": "Casinò",
	}
