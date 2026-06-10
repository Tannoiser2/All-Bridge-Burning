# Stato del progetto — All Bridges Burning (Digital Edition)

**Data:** 2026-06-10 (sessione "bot fedeli §8 + bilanciamento + UI")
**Ultima build web:** `b152` (etichetta gialla in alto a sinistra nel gioco)
**Sito live:** <https://tannoiser2.github.io/All-Bridge-Burning/>
**Repo:** `Tannoiser2/All-Bridge-Burning` — locale: `~/Desktop/all-bridges-burning/`
**Test:** 353/353 verdi (`tests/test_runner.gd`)

---

## 1. Cosa funziona ora

Il gioco è **completo e giocabile**, fedele al modulo Vassal e al regolamento
(Living Rules 2023 + Solitaire Play Aid). Tutte le fazioni possono vincere.

### Sistema Non-player COMPLETO (§8.0 — riscrittura fedele)
- **Mini-deck per fazione** (§8.2): Reds #48-53, Senato #54-59, Moderati #60-64,
  Condition box (§8.2.1), esecuzione top-to-bottom (§8.2.3), pesca casuale.
- **§8.1.2** No Resource Tracking (i bot non pagano; offsetting automatico §8.1.3).
- **§8.1.3** Attack Strength fissa per i bot: Senato 7, Reds 5 (+modificatori).
- **§8.1.4 COMPLETO**: ❶ marker "NP to play" → ❷ simbolo P = passa-per-giocare-il-
  prossimo-Evento → ❸ procedura Capability (Treni sempre per il Senato; 1d6 vs
  2×capability, Reds +2) → ❹ Evento con simbolo (i = tabella istruzioni, pieno =
  priorità generali §8.1.7) → ❺ Cmd+SA / Lim Cmd → Pass.
- **Tabella "Non-player Event Instructions" COMPLETA** (play-aid pag. 2): tutte le
  righe #4-#45 — condizioni di gioco per fazione + esecuzione fedele ("per la
  carta NP Terror/Rally/Attack/Politics", shift, Cellule per il Controllo, ecc.)
  in `Events._np_instruction_effect`.
- **Simboli P/i/pieni** estratti visivamente dalle 47 carte del Vassal →
  `cards.json` campo `np` (33 carte), parsati in `CardDef.np_has()`.
- **Germans flowchart §3.4** in Phase II; §6.5.2 Red Revolt! forzata alla 2ª
  Propaganda se non ancora avvenuta.

### Regole base corrette in questa sessione (erano bug)
- **Terror §3.2.3**: rimuove pezzi (1, o 2 se Pol≥6) + Prigionieri — NON sposta
  più il Supporto (era la causa principale dello squilibrio).
- **Controllo §1.7**: Truppe dei Powers escluse (`counts_for_control=false`);
  solo Reds/Senato controllano (`can_control`).
- **Rally §3.2.1+§8.1.3**: 1 + modificatori positivi (Senato +1/Supporto, Reds
  +1/Opposizione); sottrazioni auto-offsettate per i bot.
- **Vittoria Moderati §7.2**: i Network su mappa ora contano (Issues risolte +
  Network + 1, derivato dai primitivi in `ABBModule.issues_networks_expr`).
- **Vittoria §6.1**: check all'INIZIO di ogni Propaganda (la partita può finire
  alla 1ª-3ª, non solo alla 4ª). Log del Crisis Round leggibile fase per fase.
- **§6.5.5 Senate Conscription**: 10 Cellule Senato Out of Play al setup, entrano
  alla 1ª Propaganda (nuovo `GameState.out_of_play`).
- **Capabilities**: i pending Jaeger/Commander si piazzano all'arrivo della
  Phase II (prima restavano nel limbo); Prepared difensore = −2 all'Attack.
- **«Concludi»** riconosce l'azione umana già eseguita (`mark_human_action`).

### UI (tutte coordinate esatte dal Vassal)
- Marker Control (0.030) e Support/Oppose (0.024) — scale in cima a
  `RegionView.gd` (`ABB_CTRL_SCALE`/`ABB_SUP_SCALE`), regolabili DAL VIVO coi
  pulsanti `Control −/+ / Support −/+` nel pannello laterale.
- Cubi del Political Display sulle posizioni Vassal esatte (arco della camera);
  Issues sulle caselle stampate; Log compatto; art carte Propaganda.

### Bilanciamento (sim 300-500 partite, tutti bot, margini §7.3 a fine partita)
- **Reds ~62-66% / Moderati ~28-31% / Senato ~5-7%** — il sistema NP è progettato
  per il solitario (1 umano), non per 3 bot. Esperimenti (`sim_human_senate.gd`,
  `sim_human_moderates.gd`): un Senato "umano" triplica le vittorie (15.6%,
  TownPop 5.2 > soglia 3); i Moderati si vincono frenando i Reds, non accumulando.
- NB: la sim NON applica il check §6.1 (vittoria anticipata) — nel gioco reale
  molte vittorie arrivano prima.

---

## 2. Cosa resta (priorità basse / rifiniture)

1. **Agitation §6.4 interattiva per la fazione umana** durante la Propaganda
   (oggi auto-risolta con le regole del play-aid NP anche per l'umano).
2. **Simboli NP — verifiche puntuali**: #41 sulla carta appare rosso (Reds) ma la
   riga della tabella è del Senato (tenuti entrambi); #7 Reds / #34 / #45 hanno la
   "i" integrata dalla tabella (non rilevata sulla carta). Se un bot gioca/passa
   in modo strano su una carta, ricontrollare quella.
3. **Negotiate player-side** (§3.3.3): manca l'operazione per il giocatore umano
   (il bot ce l'ha via carta #61). Emulata solo nella sim dei Moderati umani.
4. LIMITI MODELLO dichiarati nei commenti: reachability #27/#29 approssimata,
   #42 modellata come guadagno di Town Pop Control, Random Spaces Map = uniforme.
5. Workflow deploy: warning Node.js 20 deprecato (azioni GitHub da aggiornare
   entro giugno 2026 — non blocca).

---

## 3. Note tecniche per ripartire

### File chiave
| File | Cosa contiene |
| --- | --- |
| `godot/scenes/Main.gd` | UI, `BUILD_VERSION`, layout, dispatcher click, pulsanti tuning marker |
| `godot/scenes/GameController.gd` | Flusso turni, bot dispatch, Propaganda+§6.1, P-pass §8.1.4 ❷ |
| `godot/scenes/TrackOverlay.gd` | Tracce/forze/Political Display/SoP/Prisoners |
| `godot/scenes/RegionView.gd` | Poligono spazio, pedine, marker (ABB_CTRL_SCALE/ABB_SUP_SCALE) |
| `godot/games/all_bridges_burning/rules/Bot.gd` | §8.1.4/§8.1.5: event_choice, tabella istruzioni, P-pass, Germans |
| `godot/games/all_bridges_burning/rules/NonPlayer{Reds,Senate,Moderates}.gd` | Carte NP §8.3/8.4/8.5 (FEDELI) |
| `godot/games/all_bridges_burning/rules/Events.gd` | Effetti carte + `_np_instruction_effect` (tabella) |
| `godot/games/all_bridges_burning/rules/Operations.gd` | Rally/March/Attack/Terror/Activism/Politics |
| `godot/games/all_bridges_burning/rules/Crisis.gd` | Crisis Round §6.0 completo |
| `godot/games/all_bridges_burning/ABBModule.gd` | Vittoria §7.2/§7.3, issues_networks_expr, setup, Out of Play |
| `godot/games/all_bridges_burning/data/cards.json` | 47 carte + testi + traduzioni + simboli `np` |
| `godot/tests/sim_abb.gd` | Sim bot-vs-bot con statistiche complete |
| `godot/tests/sim_human_{senate,moderates}.gd` | Esperimenti fazione "umana" |

### Comandi
```bash
# Import (SEMPRE prima di assumere che un problema sia cache — rivela i parse error)
/Applications/Godot.app/Contents/MacOS/Godot --headless --path godot --import
# Test headless
/Applications/Godot.app/Contents/MacOS/Godot --headless --path godot -s res://tests/test_runner.gd
# Simulazione (N partite)
/Applications/Godot.app/Contents/MacOS/Godot --headless --path godot -s res://tests/sim_abb.gd -- 500
```
(Godot locale 4.6, CI 4.3 — i file `.uid` non vanno committati, sono gitignorati.)

### Trappole da ricordare (GOTCHA)
1. **Type-inference (parser strict/web)**: MAI `var x := espressione_Variant`
   (es. array literal indicizzato, concat con var di loop non tipata) → "Cannot
   infer type" → lo script NON si carica → cascata di null a runtime. Tipo
   esplicito sempre. Diagnosi: `godot --import` mostra file:riga.
2. **Const con array/dict literal**: il parser web rifiuta `const X = [...]`.
   Usa `var X: Array = [...]`.
3. **custom_minimum_size CLAMPA size**: un Control non scende mai sotto la sua
   min-size — assegnare `size` più piccola viene silenziosamente ignorato.
   (Causa storica dei marker "che non cambiavano mai", b144.)
4. **Cache web RISOLTA (b145)**: il deploy rinomina `index.{js,wasm,pck}` in
   `index.<sha8>.*` → ogni build si vede con refresh normale. L'etichetta `bNNN`
   conferma la versione. Bumpare `BUILD_VERSION` a ogni modifica visibile.
5. **Permessi Claude Code**: `.claude/settings.local.json` ha `defaultMode:
   dontAsk` (gitignorato).

---

🤖 Generato con [Claude Code](https://claude.com/claude-code)
