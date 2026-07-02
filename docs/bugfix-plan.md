# Piano di correzione bug — FlutterViz

> Documento generato da un'analisi statica + revisione mirata delle aree ad alto
> impatto (logica core di mutazione dell'albero in `AppStore`, persistenza locale,
> export/import, gestione tastiera). `flutter analyze` non riporta **errori di
> compilazione** (46 warning + 62 info, perlopiù deprecazioni); i bug elencati qui
> sono difetti **logici / funzionali** individuati leggendo il codice.

**Stato: tutti i punti eseguiti.** `flutter analyze` → 0 error (91 issue residue,
tutte deprecazioni minori/info, contro le 108 iniziali). `flutter test` → tutti
i test passano. `flutter build windows --debug` → build riuscita.

---

## 🔴 Critici (funzionalità rotte lato utente)

### [x] #1 — Undo/Redo completamente non funzionanti
**File:** `lib/store/AppStore.dart`

**Problema:** `addToChangeStack()` era un no-op (corpo commentato) nonostante
fosse chiamato in ~20 punti e Ctrl+Z/Ctrl+Y fossero cablati → undo/redo non
facevano nulla.

**Fatto:**
- `addToChangeStack()` ora salva uno snapshot profondo (`createCopyOfWidgets`)
  di `selectedWidgetList` in `undoWidgetsList` e svuota `redoWidgetList`.
- `undo()`/`redo()` riscritti in modo simmetrico: entrambi spostano uno snapshot
  profondo dello stato corrente sullo stack opposto prima di ripristinare lo
  stato salvato (il vecchio `redo()` spingeva erroneamente l'elemento appena
  estratto invece dello stato corrente).
- `selectedWidgetList` viene riassegnato con `ObservableList.of(...)` per
  restare coerente con il tipo osservabile MobX del campo.
- `currentSelectedWidget` viene riallineato alla nuova root dopo undo/redo per
  evitare riferimenti pendenti a nodi non più esistenti nell'albero.

---

### [x] #2 — Pulsante "Upload" nell'header: crash + stub non funzionante
**File:** `lib/components/header_component.dart`

**Fatto:** rimosso interamente il pulsante (era uno stub che non importava
nulla nel progetto e poteva sollevare NPE se l'utente annullava il dialog o su
desktop dove `bytes` è null senza `withData: true`). Rimosso anche l'import
`../model/models.dart`, rimasto inutilizzato dopo la rimozione.

---

### [x] #3 — Salvataggio schermata dipendente dallo screenshot (perdita dati silenziosa)
**File:** `lib/utils/AppCommonApiCall.dart`

**Fatto:** `updateScreenData` non dipende più dalla cattura dello screenshot.
La thumbnail viene tentata solo se c'è contenuto da mostrare, in un `try/catch`
separato che logga l'errore senza bloccare il salvataggio del JSON dello
schermo. Aggiunto `import 'dart:developer'` per `log(...)`.

---

## 🟠 Medi

### [x] #4 — Pulsante "My Projects" morto
**File:** `lib/components/header_component.dart`

**Fatto:** rimossa la guardia `getStringAsync(USER_TYPE) == USER` (retaggio
del backend, `USER_TYPE` non viene mai scritto nel fork locale) — il pulsante
ora lancia sempre `WelcomeScreen()`.

---

### [x] #5 — `getParentWidgetsClassChild`: ricerca interrotta prematuramente
**File:** `lib/store/AppStore.dart`

**Fatto:** sia `getParentWidgetsClass` che `getParentWidgetsClassChild` ora
salvano il risultato ricorsivo in una variabile e continuano il ciclo sui
fratelli se il risultato è `null`, invece di interrompere/ritornare `null`
prematuramente. Eliminata anche la doppia invocazione ridondante nel genitore.

---

### [x] #6 — `removeScreen`: riga morta
**File:** `lib/store/AppStore.dart`

**Fatto:** rimossa `screenList.remove(ScreenListData(id: id))` (no-op, nessun
`==`/`hashCode` su `ScreenListData`); la rimozione reale nel loop sottostante
resta invariata.

---

## 🟡 Minori / pulizia

### [x] #7 — Guardia tautologica sui tasti freccia
**File:** `lib/widgets/handle_keyboard_event.dart`

**Fatto:** `||` → `&&` nella condizione
`(previousKey != arrowUp && previousKey != arrowLeft)`. Ora la guardia filtra
davvero gli eventi di key-repeat mentre il tasto resta premuto, invece di
essere sempre vera.

### [x] #8 — Variabile morta `Expanded? expanded` → **era un bug funzionale reale**
**File:** `lib/widgets/widgets.dart`

**Scoperto durante l'intervento:** non era solo una variabile inutilizzata.
`subChildView()` assegnava `expanded = tempWidget` quando un Row/Column
annidato andava avvolto in `Expanded`, ma il `return` finale non controllava
mai `expanded` — quindi la funzione ricadeva sul contenitore vuoto
(`Column(children: [])`/`Row(children: [])`) inizializzato all'inizio della
funzione, invece di renderizzare il figlio realmente flessibile. Risultato
visibile: un Row/Column annidato che doveva occupare spazio flessibile dentro
il genitore veniva mostrato come vuoto nel canvas.

**Fatto:**
- Aggiunto `else if (expanded != null) return expanded;` nella catena di
  return finale.
- Nei due punti dove si rileva `tempWidget is Expanded` (rami Column e Row),
  azzerato il contenitore vuoto corrispondente (`columnView = null;` /
  `rowView = null;`) così non ha più priorità sul vero valore da restituire.

### [x] #9 — `clearData` reimposta `isDarkModeOn = false`
**File:** `lib/store/AppStore.dart`

**Verificato, nessuna modifica necessaria:** `isDarkModeOn` è stato morto —
nessun punto del codice lo *legge* per controllare qualcosa (il tema scuro
reale è pilotato da `isDarkMode`, non toccato da `clearData`). Il reset non ha
alcun effetto osservabile. Rimuovere il campo del tutto sarebbe un refactor più
ampio, fuori scope per questo intervento di bug-fix; lasciato inalterato.

### [x] #10 — Warning statici (batch)
**Fatto:** eseguito `dart fix --apply --code=deprecated_member_use`
(20 fix proposti, applicati escludendo `missing_dependency`/`unnecessary_import`
di `pubspec.yaml`/`third_party`), poi verificato e corretto manualmente ciò che
il fix automatico aveva rotto o reso rischioso:

- **`dart fix` aveva aggiunto `string_scanner: any` a `pubspec.yaml`** (side
  effect non richiesto, versione non pinnata) → **annullato** con
  `git checkout -- pubspec.yaml`.
- **`onAccept` → `onAcceptWithDetails` su 5 `DragTarget`** (`center_body_component.dart`,
  `dashboard-preview_component.dart` ×3, `widgets.dart`): il fix automatico
  aveva rinominato il parametro ma lasciato i corpi a usare l'oggetto trascinato
  direttamente, causando **8 errori di compilazione** (`DragTargetDetails<T>`
  non ha i getter di `T`). Corretto manualmente ogni callback per usare
  `details.data` al posto dell'item diretto.
- **`value:` → `initialValue:` su `DropdownButtonFormField`**
  (`right_screen_component.dart`): comportamento diverso da `value` — si
  applica solo al primo build del `FormField`, non si aggiorna sui rebuild
  MobX successivi. Dato che `AppStore.removeScreen`/`setScreenDetails`
  impostano `selectedDropdownScreen` a livello di store (fuori da `onChanged`),
  la dropdown sarebbe rimasta con un valore stantio dopo cancellazione/cambio
  schermata. **Fix:** aggiunta `key: ValueKey(appStore.selectedDropdownScreen?.id)`
  per forzare la ricreazione del `FormFieldState` (e quindi la rilettura di
  `initialValue`) ogni volta che cambia lo screen selezionato.
- **`dialogBackgroundColor` → `dialogTheme: DialogThemeData(...)`**
  (`AppTheme.dart`): verificato che non ci fossero `dialogTheme` duplicati
  nello stesso `ThemeData(...)`; riformattato per leggibilità (il fix
  automatico aveva accodato la proprietà su una riga esistente).
- Rimanenti fix automatici verificati come sicuri e lasciati: `Color.value` →
  `.toARGB32()`, `Color.opacity`/`.alpha` → `.a` (color picker esterno e
  `comman_property_view.dart`), `Switch.activeColor` → `activeThumbColor`
  (`switch_class.dart`, `switch_list_tile_class.dart`).
- I warning residui in `third_party/flutter_treeview/` sono codice **vendored**
  e sono stati lasciati intatti come da indicazione del piano.

---

## Note di verifica
- `flutter analyze`: 108 → **91 issue** (0 error sia prima che dopo).
  Le 2 warning aggiuntive rispetto al confronto grezzo provengono da
  `release/` (cartella di build generata, in `.gitignore`, irrilevante).
- `flutter test test/local_project_service_test.dart`: **6/6 test passati**.
- `flutter build windows --debug`: **build riuscita**.
- La persistenza su disco delle operazioni di cancellazione screen era già
  corretta prima di questo intervento (i vari `deleteScreenApi` chiamano
  `LocalProjectService.deleteScreen` prima di `appStore.removeScreen`).
- `lib/undoRedo/change_stack.dart` esiste ma resta **inutilizzato** (non è la
  struttura usata dall'undo/redo, ora implementato direttamente in `AppStore`).

## Test manuali consigliati (non eseguiti in questa sessione)
- `flutter run -d windows`: provare Ctrl+Z/Ctrl+Y su drag&drop, wrap, copy,
  move, delete, edit proprietà, in sequenze miste.
- Salvataggio schermata con/senza contenuto (verificare che il JSON venga
  scritto anche se la cattura della thumbnail fallisce).
- Cancellazione/cambio schermata dal pannello destro: verificare che la
  dropdown schermate mostri sempre il nome corretto dopo `removeScreen`.
- Un Row/Column annidato dentro un Row/Column padre che deve occupare spazio
  flessibile (`Expanded`): verificare che venga renderizzato correttamente nel
  canvas invece di apparire vuoto (bug #8).
- Pulsanti header "My Projects" (naviga sempre a `WelcomeScreen`) e conferma
  che "Upload" non sia più presente.
