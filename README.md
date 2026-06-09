# All Bridges Burning — Digital Edition

Versione digitale di **All Bridges Burning** (Serie COIN Vol. IX, GMT 2020),
costruita riusando il motore COIN generico sviluppato per Cuba Libre.

🌐 **Sito live**: <https://tannoiser2.github.io/All-Bridge-Burning/>

📥 **Build desktop** (Windows / Linux / macOS): vedi
[Releases → `desktop-latest`](https://github.com/Tannoiser2/All-Bridge-Burning/releases/tag/desktop-latest).

## Stato

**Giocabile a livello di interazione**: la mappa Finlandia croppata dal Vassal,
i 13 spazi (8 province + 5 città) con popolazione e adiacenze, le 5 fazioni
(Reds, Senate, Moderates, Germans, Russians) con le loro forze e i marker dei
tracciati sono tutti renderizzati. Il setup standard viene applicato e i pezzi
del posizionamento iniziale compaiono sui poligoni della mappa.

I bottoni Operazione (Rally / Marcia / Attacco / Terrorismo / Messaggio /
Attivismo) e Attività Speciale (Agitazione / Imboscata / Sovversione /
Repressione / Coordinamento / Negoziato / Dialogo / Relazioni Estere /
Tassazione) sono cliccabili: aprono un flusso di selezione spazio e chiamano la
libreria di regole `ABBOperations` / `ABBSpecialActivities`. Il Bot priority
planner sceglie l'azione per le fazioni non-giocatore. Quando il mazzo pesca
una carta Propaganda, parte il Crisis Round (Politics + Earnings, in Phase II
anche l'aggiustamento delle Truppe di Germany/Russia in base alla Vassalage,
§6.5.3). La carta Pivotal **Red Revolt!** (#24) attiva la Phase II: i Germans
cominciano ad agire (per ora con un bot semplice, non ancora il flowchart
completo), e l'UI lo segnala con il tag *Phase II* sulla carta e con un badge
nel riquadro Sequence of Play. In SoP, i quattro cilindri (Reds/Senate/
Moderates/Germans) si spostano fra Pass / Eligible / Acted / Ineligible in
base allo stato attuale di idoneità + azione svolta sulla carta corrente.

Le province sono tinte col colore della fazione controllante usando le mask
PNG estratte direttamente dal modulo Vassal (pixel-perfect rispetto ai bordi
stampati). I pezzi disponibili nelle Available Forces compaiono nei riquadri
esatti del Vassal, e le Cell occupano i loro slot dedicati.

**286 test passati, 0 falliti** in headless (Cuba Libre + ABB combinati).

| Componente | Stato |
| --- | --- |
| Motore COIN multi-gioco | ✅ `GameRegistry` + `GameManifest` per swap dei moduli |
| Mappa Finlandia | ✅ JPG croppata 3000×2350 + 13 poligoni interattivi |
| 13 spazi (province + città) | ✅ pop, adiacenze (da poligoni), controllo iniziale |
| 5 fazioni | ✅ Reds, Senate, Moderates, Germans, Russians con `force_pool` |
| 4 tipi di pezzo | ✅ troops, cell (×stato), admin, network |
| Asset pezzi su mappa | ✅ texture dedicate, marker piazzati al setup |
| Setup standard | ✅ apply_setup runnable da `data/setup_standard.json` |
| 47 carte Evento | ✅ titoli dal playbook + immagini dal Vassal |
| Operazioni | ✅ Rally / March / Attack / Terror — logica core |
| Attività Speciali | ✅ Agitate, Ambush, Subvert, Crackdown, Coordinate, Dialogue, Foreign Relations, Tax, Negotiate |
| UI: click → ABBOperations / ABBSpecialActivities | ✅ dispatcher con highlight degli spazi candidati |
| Crisis Round (§6.0) | ✅ Politics + Earnings + §6.5.3 Powers adjustment in Phase II + campaign_count |
| Province highlighting | ✅ Mask Vassal pixel-perfect per il tint del Controllo |
| Bot non-giocatore | ✅ PAC2 framework (17 carte 49-65) + priority planner fallback |
| Vittoria (§7.2 / §7.3) | ✅ margine per fazione + tiebreak order |
| TrackOverlay sulla mappa | ✅ Resources, Polarization (tracciato dedicato), Vassalage, Town Pop, Cells on Map, Issues+Networks, Oppose+Admins |
| Box Available Forces | ✅ box dal Vassal, Cell sui 46 slot dedicati (senate/reds/moderates) |
| Marker Control / Support | ✅ posizioni `cbox`/`sbox` estratte dalla Zone Vassal Control |
| Sequence of Play | ✅ cilindri Eligibility (Pass/Eligible/Acted/Ineligible) per Reds/Senate/Moderates/Germans |
| Red Revolt! (Pivotal #24) | ✅ flip `tracks.phase` → II; Germans bot gated; badge UI |
| Activism (§3.2.2) | ✅ capovolge nemico Attivo o attiva Inattiva amica; Polarization -1 |
| Germans flowchart (§3.4) | ✅ Landing → Reinforce → Attack → March + 1d6 Eligibility roll + Coordinate hook |
| Capabilities Insorgenti | ✅ #1/#10/#14/#15/#16/#17/#26: Jaeger/Commander/Cannons/Trains markers on-map |
| Personality / News markers | ✅ asset Vassal + render sui poligoni; Personality a Helsinki al setup; transfer su rimozione; News piazzati da Landing/Terror Phase II/Attack-to-Prison |
| **Political Display §1.11** | ✅ 3 Issues × cubi per fazione; cubi colorati in UI |
| **Politics Command §3.3.4** | ✅ Moderati piazzano cubo; costo 1-3 da Polarization; gated Pol ≤ 5 |
| **Politics Phase §6.2** | ✅ 1d6 vs cubi; resolution majority (ties → Moderates); cubi azzerati |
| **Personal Leadership §6.2.2** | ✅ Personality OFF map → Moderati -3 + replacement |
| **Reset Phase §6.5.4** | ✅ Clear Terror/Sabotage/News/borders end-round |
| **Prisoners of War §6.5** | ✅ Track count via Attack-to-Prison; +1 Polarization per 2 prigionieri |
| **Sabotage su bordo §3.2.5** | ✅ Border markers bloccano March; Reset Phase pulisce |
| **Phase II gating §3.2.4/§3.2.5** | ✅ Attack/March solo in Phase II per player factions |
| **Polarization effects** | ✅ Moderati Rally cost 3 se Pol ≥ 6 (§3.3.1) |
| **Powers Germans/Russians** | ✅ sempre Bot, no UI toggle |
| **Capability +2 Attack Strength** | ✅ Jaeger/Commander/Cannons/Trains bonus on-space (§5.3) |
| **Sabotage border UI** | ✅ X rossa sul punto medio fra spazi sabotati |
| **Senato Coordinate UI** | ✅ pulsante "Coord. Germ." nella action bar (Phase II) |
| **Eventi semplici** | ✅ 12 carte con effetti atomici (Risorse/Polarization/Vassalage) |
| Testi carte | ✅ Unshaded/Shaded da OCR + cleanup; 47/47 traduzioni IT (Chiaro/Ombr.) |

## Cosa rimane da fare

- **PAC2 fidelity**: le sub-priorità interne alle carte sono ancora pick greedy
  semplificati. Framework + 10 handler concreti.
- **Eventi residui**: 12 carte ora hanno effetto atomico (Risorse/Polarization/
  Vassalage). Restano ~30 carte con effetti complessi non implementati che
  richiedono UI di scelta (sposta spazio, rimuovi cellula, ecc.).
- **Aspect ratio mappa**: ✅ fix in PR#76. Marker Control/Support ora
  allineati ai box stampati (era hardcoded a Cuba ratio).
- Crisis Round Phase II adjustment (Vassalage shift per i Powers).

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
      assets/                     # PNG/JPG mappa, pezzi, carte, VP markers
      rules/                      # Operations, SpecialActivities, Crisis, Bot, Events
  tests/                          # Test headless (40+ Cuba + 13 ABB)

sources/                          # Tool estrazione Vassal, OCR, rules
Materiale ABB/                    # Rulebook, playbook, .vmod, tabelle Bot
.github/workflows/                # CI: deploy-web (Pages) + build-desktop
```

## Multi-gioco

Il motore seleziona il modulo via `GameRegistry.game_id`. Ordine di risoluzione:

1. CLI: `godot --path godot -- --game=cuba_libre`
2. ProjectSettings: `application/config/game_id`
3. Default: `all_bridges_burning`

Ogni gioco espone un `games/<id>/Manifest.gd` che estende `GameManifest` e
fornisce le factory di `RulesModule`, Operazioni, Attività Speciali, Eventi,
round periodico, Bot e i ruoli default per fazione.

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

## Note tecniche

- **Godot 4.3 web export e `const`**: il parser GDScript del runtime web
  rifiuta `const X = [...]` o `const X := [...]` con array letterali
  ("Assigned value isn't a constant expression"). Usa `var X: Array = [...]`.
  Questo gotcha ha causato un crash WASM ricorrente prima di essere isolato.
- **Subsystem refs in `GameController.gd`**: i campi `ops`, `specials`,
  `propaganda`, `events`, `bot` sono Variant (perché ogni modulo gioco
  fornisce le proprie classi via `Manifest`). Per assegnamenti tipo
  `var res = subsystem.method()` usa `=` (non `:=`) o annota
  esplicitamente `var res: Dictionary = ...`.

## Crediti

- All Bridges Burning © 2020 GMT Games, LLC — design: VPJ Arponen.
- Engine COIN generico evoluto da `cuba-libre-gmt`.
- Materiale Vassal: ABB module 1.2.
