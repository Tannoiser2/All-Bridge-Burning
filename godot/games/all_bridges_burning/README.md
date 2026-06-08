# All Bridges Burning — modulo di gioco

Modulo per il motore COIN generico (`coin_engine/`). Implementa la Serie COIN
Vol. IX (GMT 2020) — Finlandia 1917-18.

## Stato

Scheletro iniziale. La logica è ancora vuota; il modulo si registra come
`game_id = "all_bridges_burning"` e il `Manifest.gd` espone le factory dei
sottosistemi.

## Materiale sorgente

In `Materiale ABB/` alla radice del repo:

- `ABBLivingRules.pdf` — regolamento (versione "living").
- `ABBLivingPlaybook.pdf` — playbook con esempi.
- `ABBPAC2FlowchartsLivingOct-20.pdf` — diagrammi flusso Bot non-giocatore.
- `ABB_CardEdits-download.pdf` — carte evento aggiornate.
- `All Bridges Burning Tabelle.pdf` — tabelle Bot.
- `All Bridges Burning Carte Bot.pdf` — carte Bot.
- `All_Bridges_Burning_1.2.vmod.zip` — modulo Vassal (mappa + segnaposto).

## Roadmap (incrementale)

1. **Mappa + spazi + setup** — estrarre regions dal Vassal, popolare
   `data/spaces.json`, `data/regions.json`, `data/setup_standard.json`.
2. **Fazioni** — popolare `data/factions.json` (Reds, Whites, Moderates,
   Protesters — confermare dal rulebook).
3. **Operazioni** — implementare `rules/Operations.gd`.
4. **Attività Speciali** — `rules/SpecialActivities.gd`.
5. **Eventi** — popolare `data/cards.json` (76 carte) e `rules/Events.gd`.
6. **Round periodico (Crisis)** — `rules/Crisis.gd`.
7. **Bot NP** — `rules/Bot.gd` sulla base dei flowchart PAC2 e delle carte Bot.

A ogni passo: test in `tests/` come per Cuba Libre, e PR su `main`.

## Attivare ABB come gioco principale

Per ora il default è `cuba_libre` (modulo di riferimento, completo). Per girare
ABB:

- Da CLI: `godot --path godot -- --game=all_bridges_burning`
- Permanente: in `godot/project.godot` cambiare `application/config/game_id`
  da `"cuba_libre"` a `"all_bridges_burning"`.

Il motore non partirà finché ABB non avrà almeno spazi/fazioni minimi.
