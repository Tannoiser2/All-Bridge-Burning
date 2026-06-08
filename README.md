# All Bridges Burning — Digital Edition

Versione digitale di **All Bridges Burning** (Serie COIN Vol. IX, GMT 2020),
costruita riusando il motore COIN generico sviluppato per Cuba Libre.

Stato: **scheletro iniziale**. Il motore e il guscio UI sono importati e
funzionanti (modulo Cuba Libre come riferimento); il modulo ABB è registrato
nel `GameRegistry` e attende l'implementazione incrementale di mappa,
operazioni, attività speciali, eventi, round Crisis e Bot non-giocatore.

## Struttura

```
godot/
  coin_engine/                 # Motore COIN generico (game-agnostico)
    GameRegistry.gd            # Autoload: carica il modulo del game_id attivo
    GameManifest.gd            # Contratto factory per ogni gioco
    …
  scenes/                      # Guscio UI (mappa, pannelli, controlli)
  games/
    cuba_libre/                # Modulo Cuba Libre (riferimento + test)
    all_bridges_burning/       # Modulo ABB (scheletro, in costruzione)
  tests/                       # Test headless (GDScript nativo)

sources/                       # Tool di estrazione dal Vassal, OCR, rules
Materiale ABB/                 # Rulebook, playbook, .vmod, tabelle Bot
.github/workflows/             # CI: deploy-web (Pages) + build-desktop
```

## Multi-gioco

Il motore seleziona il modulo via `GameRegistry.game_id`. Ordine di risoluzione:

1. CLI: `godot --path godot -- --game=all_bridges_burning`
2. ProjectSettings: `application/config/game_id`
3. Default: `cuba_libre`

Ogni gioco espone un `games/<id>/Manifest.gd` che estende `GameManifest` e
fornisce le factory di `RulesModule`, Operazioni, Attività Speciali, Eventi,
round periodico e Bot.

## Sviluppo

```
# Test headless
godot --headless --path godot -s res://tests/test_runner.gd

# Run UI (default: cuba_libre)
godot --path godot

# Run UI con ABB
godot --path godot -- --game=all_bridges_burning
```

## Roadmap

1. Mappa + spazi + setup ABB
2. Operazioni
3. Attività Speciali
4. Eventi
5. Round periodico (Crisis)
6. Bot NP (PAC2 + carte Bot)

PR su `main` per ogni passo, con test che restano verdi.
