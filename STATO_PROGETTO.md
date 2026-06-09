# Stato del progetto — All Bridges Burning (Digital Edition)

**Data:** 2026-06-10
**Ultima build web:** `b104` (vedi etichetta gialla in alto a sinistra nel gioco)
**PR mergiate su main:** 105
**Sito live:** <https://tannoiser2.github.io/All-Bridge-Burning/>
**Repo:** `Tannoiser2/All-Bridge-Burning` — locale: `~/Desktop/all-bridges-burning/`

---

## 1. Cosa funziona ora

Il gioco è **completo e giocabile a livello di interazione**, fedele al modulo Vassal.

### Sulla mappa si vede:
- Mappa Finlandia (3000×2350) con 13 spazi (8 province + 5 città) interattivi
- **Pedine** delle 5 fazioni sui poligoni (Reds, Senate, Moderates + Powers Germans/Russians)
- **Marker Control / Support** nelle caselle stampate "Uncontrol"/"Neutral" (disegnati a
  dimensione 0.019, affiancati orizzontalmente, niente sovrapposizione)
- **Tint province** col colore della fazione controllante (mask Vassal pixel-perfect)
- **Marker Personality / News** (Moderates) sui poligoni
- **Capability markers** on-map (Jaeger/Commander/Cannons/Trains) in Phase II

### Pannelli e tracce (TrackOverlay):
- Traccia punteggio 0-30 con i marker VP/Resources delle fazioni
- **Box Available Forces** (Senate/Reds/Moderates/German/Russian) con le pedine nei loro slot esatti
- **Political Display** con cubi colorati + 3 badge Issue (Working/Reform/Social)
- **Polarization Track** (0-10) con marker dedicato
- **Sequence of Play** con cilindri Eligibility (R/S/M/G) nei box giusti
- **Prisoners of War** box, **Capabilities** panel
- Tag "Phase I/II" sulla card label + badge "PHASE II" nel SoP

### Regole implementate (fedeli al regolamento):
- **Operazioni**: Rally, March, Attack, Terror, Activism (March/Attack gated a Phase II per le fazioni-giocatore)
- **9 Attività Speciali**: Agitate, Ambush, Subvert, Crackdown, Coordinate, Dialogue, Foreign Relations, Tax, Negotiate
- **Crisis Round (§6.0)**: Politics Phase §6.2 + Earnings + Powers §6.5.3 + Reset §6.5.4 + Personal Leadership §6.2.2
- **Political Display §1.11**: 3 Issues × cubi per fazione, risoluzione con 1d6
- **Politics Command §3.3.4** (Moderati), **Prisoners of War §6.5**, **Sabotage borders §3.2.5**
- **Phase I/II**: Red Revolt! (#24) attiva la Phase II; Germans flowchart §3.4 (Landing/Reinforce/Attack/March + 1d6 roll)
- **Capabilities +2 Attack Strength**, **News/Personality transfer §4.3.1**, **Polarization effects**
- **Powers (Germans/Russians) sempre Bot**, no toggle UI
- **Vittoria §7.2/§7.3** con tiebreak
- **47/47 carte** con testo Unshaded/Shaded (OCR) + traduzione IT (Chiaro/Ombr.)
- **PAC2 Bot**: 17 carte solitaire (49-65) + priority planner di fallback

---

## 2. Cosa abbiamo fatto in questa sessione (PR 75-105)

### Bug critico risolto — l'overlay che spariva
Per ore il gioco mostrava la mappa e le pedine ma **mancavano risorse, forze disponibili,
VP markers e tutto l'overlay**. Sembrava un problema di cache ma era un **bug vero**.

La diagnosi (con un'etichetta diagnostica temporanea sullo schermo) ha rivelato:
- `ovl:NULL` → il nodo `TrackOverlay` era **null**
- `mapChildren:15` → mancava un figlio (il track overlay non era stato creato)
- `mapPieces:18` → le pedine c'erano (RegionView funzionava)

**Causa radice:** in `TrackOverlay.gd` avevo scritto
`var pass_slot := ["pass_a","pass_b","pass_c"][min(i,2)]`. Indicizzare un array literal
inline ritorna `Variant`, e il parser stretto (load progetto + export web) lo rifiuta con
**"Cannot infer the type of pass_slot"** → lo script non si caricava → `TrackOverlay.new()`
ritornava null → tutto l'overlay spariva. Le forme disegnate senza texture (cubi Political
Display) restavano, le texture no → per questo "sparivano solo alcune cose".

**Fix:** tipo esplicito `var pass_slot: String = [...][mini(...)]`. Verificato con `godot --import`.

### Altri fix di questa sessione
- **Marker Control/Support**: erano sovrapposti e troppo grandi. Ora disegnati con
  `draw_texture_rect` a dimensione esplicita 0.019 (i TextureRect non rispettavano la size).
  Posizioni misurate al pixel: le due caselle sono affiancate orizzontalmente.
- **Aspect ratio mappa**: era hardcoded su Cuba Libre (0.7727) → marker disallineati.
  Ora 0.7833 per ABB.
- **Texture null-cache** in CLAssets: non cacha più i null (riprova finché GameRegistry è pronto).
- **Available Forces**: estratti dal Vassal i 46 slot Cell + slot Admin/Network/Troops.
- **SoP cylinders**: 21 slot esatti dal Vassal, allineati ai cerchi stampati.
- **Bot**: rispetta le priorità PAC2 invece di uno scoring inventato; Germans flowchart §3.4.
- **Eventi**: 47/47 carte con effetto programmato; traduzioni IT.
- **Regole politiche complete**: Political Display, Politics Phase, Personal Leadership,
  Prisoners, Sabotage, Capabilities +2 Attack.
- **Pulizia repo**: committati i .import dei nuovi asset, ignorati i *.uid (Godot locale 4.6).

---

## 3. Cosa resta da fare (priorità)

### PRIORITÀ 1 — FIX DEI BOT (problema vero aperto)
La simulazione (`sim_abb.gd`, 200 partite) mostra bot **rotti**:
- **100% "none"**: nessuna fazione raggiunge mai la soglia di vittoria
- **Admin/Network MAI costruiti** (`reds_admin: 0.00`, `moderates_network: 0.00`) → Reds
  (serve Opposition+Admin≥11) e Moderates (serve Network) **non possono vincere**
- **Dialogue (156/partita) e Crackdown (85/partita) SPAMMATI** — sono Attività Speciali,
  non l'azione principale da ripetere all'infinito
- **Terror quasi mai** (0.26/partita) → Reds non costruiscono Opposition
- **Senato inonda la board** (18.7 Cell su 20) senza convertire in vittoria; piling su
  Pohjanmaa (7.6) e Tampere (5.3)

**Piano di fix in ordine:**
1. `BotPAC2`: smettere di spammare Dialogue/Crackdown (sono SA che accompagnano un Comando)
2. Reds: costruire Admin (rally mode "admin" con 2 Cell in spazio controllato) + usare Terror
3. Moderates: costruire Network (Message/Rally)
4. Senato: Rally mirato a controllare Town invece di spargere Cellule
5. Rilanciare `sim_abb.gd` dopo ogni fix per misurare il miglioramento

### PRIORITÀ 2 — Rifiniture
- PAC2: implementare le sub-priorità fini dentro le carte (ora pick greedy)
- News markers piazzati da più eventi; cleanup OCR residuo su pochi titoli carta

---

## 4. Note tecniche per ripartire

### File chiave
| File | Cosa contiene |
| --- | --- |
| `godot/scenes/Main.gd` | UI principale, `BUILD_VERSION` (etichetta build), layout, dispatcher click |
| `godot/scenes/TrackOverlay.gd` | Disegna tracce/forze/Political Display/SoP/Prisoners |
| `godot/scenes/RegionView.gd` | Poligono spazio, pedine, marker Control/Support (`_draw_abb_markers`) |
| `godot/scenes/CLAssets.gd` | Caricamento texture (cache, no null-cache) |
| `godot/games/all_bridges_burning/rules/Bot.gd` | Priority planner fallback + Germans flowchart |
| `godot/games/all_bridges_burning/rules/BotPAC2.gd` | **Bot PAC2 — qui i fix bot** |
| `godot/games/all_bridges_burning/rules/Operations.gd` | Rally/March/Attack/Terror/Activism/Politics |
| `godot/games/all_bridges_burning/rules/Crisis.gd` | Crisis Round (Politics/Earnings/Powers/Reset) |
| `godot/games/all_bridges_burning/data/board_layout.json` | track, box, cell_slots, sop_slots |
| `godot/games/all_bridges_burning/data/cards.json` | 47 carte + testi + traduzioni |
| `godot/games/all_bridges_burning/data/pac2_deck.json` | 17 carte Bot PAC2 |
| `godot/tests/sim_abb.gd` | **Simulazione bot — per misurare i fix** |
| `godot/tests/test_runner.gd` | Test headless (Cuba + ABB) |

### Comandi
```bash
# Import (SEMPRE prima di assumere che un problema sia cache — rivela i parse error)
godot --headless --path godot --import

# Test headless
godot --headless --path godot -s res://tests/test_runner.gd

# Simulazione bot (N partite)
godot --headless --path godot -s res://tests/sim_abb.gd -- 500

# Run UI locale
godot --path godot
```
(Su questo Mac: `/Applications/Godot.app/Contents/MacOS/Godot`. Nota: il Godot locale è
4.6, la CI usa 4.3 — il 4.6 genera file `.uid` che NON vanno committati, sono gitignorati.)

### Trappole da ricordare (GOTCHA)
1. **Type-inference (web export)**: MAI `var x := array_literal[index]` o assegnazioni `:=`
   il cui valore è `Variant` → "Cannot infer type" → lo script NON si carica → cascata di
   fallimenti a runtime (`Classe.new()` ritorna null). USA SEMPRE tipo esplicito:
   `var x: String = [...][i]`. La CI "passa" lo stesso (l'export include script rotti), il
   fallimento è solo a runtime. Diagnosi: `godot --import` mostra file:riga.
2. **Const con array/dict literal**: il parser web rifiuta `const X = [...]`. Usa `var X: Array = [...]`.
3. **Cache `.pck`**: `index.pck` ha nome fisso, GitHub Pages lo cachea → a volte "non vedi i
   fix" dopo un deploy. L'etichetta build `bNNN` in alto a sinistra conferma la versione.
   Per forzare: **finestra incognito**. Bumpare `BUILD_VERSION` in Main.gd a ogni fix UI.
4. **Aspect ratio mappa**: ABB = 2350/3000; Cuba = 2040/2640. È selezionato su `game_id`.
5. **Workflow PR**: ogni feature su branch → PR → squash merge → il deploy parte sul push a main.

---

🤖 Generato con [Claude Code](https://claude.com/claude-code)
