# All Bridges Burning — Digital Edition

Versione digitale di **All Bridges Burning** (Serie COIN Vol. IX, GMT 2020),
costruita riusando il motore COIN generico sviluppato per Cuba Libre.

🌐 **Sito live**: <https://tannoiser2.github.io/All-Bridge-Burning/>

📥 **Build desktop** (Windows / Linux / macOS): vedi
[Releases → `desktop-latest`](https://github.com/Tannoiser2/All-Bridge-Burning/releases/tag/desktop-latest).

---

## Stato del progetto

Il motore di gioco e la struttura dati ABB sono **completi a livello di
scheletro funzionante**:

| Componente               | Stato                                                                |
| ------------------------ | -------------------------------------------------------------------- |
| Motore COIN multi-gioco  | ✅ `GameRegistry` + `GameManifest` per swap dei moduli                |
| Mappa Finlandia          | ✅ JPG croppata 3000×2350 + 13 poligoni interattivi                   |
| Spazi (province + città) | ✅ 8 + 5 con popolazione, adiacenze (da poligoni), controllo iniziale |
| Fazioni                  | ✅ Reds, Senate, Moderates, Germans, Russians (con `force_pool`)      |
| Pezzi (asset)            | ✅ Cell ×3 stati, Admin, Network, Troops ×2, Control ×2               |
| Setup standard           | ✅ Apply runnable da `data/setup_standard.json` + D6 deterministico   |
| 47 carte                 | ✅ Numerate + immagini estratte; titoli e factionOrder placeholder    |
| Operazioni base          | ✅ Rally, March, Attack, Terror — logica core                         |
| Attività Speciali        | ✅ 9 SA (Agitate, Ambush, Crackdown, Coord, Dialogue, FR, Tax, …)     |
| Crisis (round periodico) | ✅ Politics + Earnings (Phase II adjustment TODO)                     |
| Bot non-giocatore        | ✅ Scaffold random (full PAC2 + 17 Bot cards TODO)                    |
| Vittoria (§7.2/§7.3)     | ✅ Margine per fazione + tiebreak order                               |

**Cosa manca per essere "completo"**:

- UI di Main.gd è ancora cuba-style: i bottoni operazione/SA mostrano nomi
  Cuba Libre e le pipeline di click sono hardcoded. Per rendere giocabile la
  UI ABB serve un altro stadio di refactoring (lettura per-game di
  `OP_NAMES` / `SA_NAMES` / handlers dal Manifest).
- Carte Evento: solo placeholder. I 47 testi unshaded/shaded vanno
  trascritti dal regolamento + ABB_CardEdits, poi Events.gd va popolato.
- Bot PAC2: vanno implementati i 17 flussi della PAC2 e le 17 carte Bot.
- Tracciati overlay sulla mappa: solo Polarization Track stub; vassalage,
  scoring, town pop, oppose+admins, networks+issues mancano.

---

## Struttura

```
godot/
  coin_engine/                    # Motore COIN generico (game-agnostico)
    GameRegistry.gd               # Autoload: carica il modulo del game_id attivo
    GameManifest.gd               # Contratto factory per ogni gioco
    …
  scenes/                         # Guscio UI (mappa, pannelli, controlli)
  games/
    cuba_libre/                   # Modulo Cuba Libre (riferimento + test)
    all_bridges_burning/          # Modulo ABB
      Manifest.gd                 # Factory dei sottosistemi
      ABBModule.gd                # GameDef + apply_setup + victory_status
      data/                       # JSON: spaces, factions, cards, setup, regions, board_layout
      assets/                     # PNG/JPG mappa, pezzi, carte
      rules/                      # Operations, SpecialActivities, Crisis, Bot, Events
  tests/                          # Test headless GDScript (40+ Cuba + 8 ABB)

sources/                          # Tool estrazione Vassal, OCR, rules
Materiale ABB/                    # Rulebook, playbook, .vmod, tabelle/carte Bot
.github/workflows/                # CI: deploy-web (Pages) + build-desktop
```

## Multi-gioco

Il motore seleziona il modulo via `GameRegistry.game_id`. Ordine di risoluzione:

1. CLI: `godot --path godot -- --game=cuba_libre`
2. ProjectSettings: `application/config/game_id`
3. Default: `all_bridges_burning`

## Sviluppo

```bash
# Test headless
godot --headless --path godot -s res://tests/test_runner.gd

# Run UI ABB (default)
godot --path godot

# Run UI Cuba Libre
godot --path godot -- --game=cuba_libre
```

Per estrarre/aggiornare le mappe e i pezzi dal modulo Vassal:

```bash
mkdir -p tmp_vmod && cd tmp_vmod
unzip ../"Materiale ABB"/All_Bridges_Burning_1.2.vmod.zip
cd ..
python3 sources/vassal/estrai_zone_abb.py
python3 sources/vassal/calcola_adiacenze_abb.py --apply
```

## Crediti

- All Bridges Burning © 2020 GMT Games, LLC — design: VPJ Arponen.
- Engine COIN generico evoluto da `cuba-libre-gmt`.
- Materiale Vassal: ABB module 1.2.
