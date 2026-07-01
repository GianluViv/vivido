# Piano di lavoro — FlutterViz come app desktop locale (Linux/Windows)

> Documento di progettazione. Obiettivo: trasformare FlutterViz da web-app client/server a
> **applicazione desktop autonoma per Linux e Windows**, senza login né backend remoto, con
> progetti multi-pagina **salvati e caricati da file locali**.
>
> Questo file descrive *cosa* va fatto e *perché*, con i dettagli tecnici. Va aggiornato man mano
> che le fasi vengono completate. Vedi anche la sezione "Fork goal" in [CLAUDE.md](../CLAUDE.md).

---

## 1. Situazione attuale (analisi)

### 1.1 Cosa è già locale (nessuna modifica necessaria)
L'editor vero e proprio è interamente client-side e non tocca la rete:
- Costruzione/modifica dell'albero di widget (`AppStore`: `addChildWidget`, `wrapWidget`,
  `copyWidget`, `moveWidget`, `removeSelectedWidget`, `updateData`, undo/redo).
- Pannello proprietà (`lib/widgetsProperty/`), palette (`lib/components/leftView/`), canvas
  (`lib/components/centerView/`), tree view (`lib/components/tree_view_components.dart`).
- **Serializzazione già pronta**: ogni schermata viene serializzata/deserializzata come stringa
  JSON autosufficiente tramite `widgetClassToJsonData()` e `applyScreenJsonToView()`
  (`lib/widgets/screen_json_parser_class.dart`). Questo è il pilastro su cui costruire la
  persistenza locale — **il formato dati non va reinventato**.
- **Generazione del codice Dart**: `viewFinalSourceData()` produce il sorgente dei file in locale
  (usato da `header_component.dart`); solo lo *zip finale* passa dal server.

### 1.2 Cosa dipende dal backend (da sostituire)
| Area | File / funzione | Chiamata backend |
|------|-----------------|------------------|
| Autenticazione | `lib/screen/login_screen.dart` `signIn()` | `login()` |
| Firebase init | `lib/main.dart` | `Firebase.initializeApp` + `google_sign_in` |
| Progetti (crea/lista) | `lib/components/create_project_dialog.dart`, `lib/screen/welcome_screen.dart` | `addUserProject()`, `getUserProjectList()`, `getProjectList()`, `addTemplateSaveAsProject()` |
| Schermate/pagine (CRUD) | `add_screen_dialog.dart`, `add_page_dialog.dart`, `screen_list_component.dart`, `screens_page_components.dart`, `screen_clone_dialog.dart` | `addScreen()`, `deleteScreen()`, `getScreenList()` |
| Salvataggio schermata | `lib/utils/AppCommonApiCall.dart` `saveScreenApi()` | `addScreen()` |
| Autosave (timer 30s) | `lib/screen/dashboard_screen.dart` `autoSaveData()` | `addScreen()` |
| Caricamento schermate | `AppCommonApiCall.dart` `getAllScreenListApi()` | `getScreenList()` → `appStore.addScreens()` |
| Media/immagini | `AppCommonApiCall.dart` `allMediaListApi()`, `addMediaApi()` | `getMediaList()`, `usermedia-save` (multipart) |
| Export codice (zip) | `lib/components/header_component.dart` `downloadProjectLatest()` | `downloadProjectLatestApi()` |
| Template/categorie | `add_page_dialog.dart` | `getCategoryTemplateList()` |

### 1.3 Modello dati chiave
- `ScreenListData` (`lib/model/screen_list_response.dart`): `id` (int), `userId`, `name`,
  `screenJsonData` (stringa JSON della schermata), `screenImage` (PNG base64), timestamp.
  Attualmente gli `id` sono assegnati dal backend.
- Un **progetto** = insieme di schermate con `project_id` + `name` (`UserProjectData`).
- `AppStore` tiene già in memoria: `screenList` (`List<ScreenListData>`), `projectId`,
  `projectName`, `selectedScreenId`, e i metodi `addScreens()`, `setScreenDetails()`,
  `updateScreenNewData()` funzionano già offline. **La persistenza locale deve solo alimentare e
  leggere queste strutture.**

### 1.4 Target di build
- Esistono solo `web/` + `.metadata` (piattaforme root+web). **Non esistono** le cartelle
  `windows/` e `linux/`.
- `lib/firebase_options.dart` oggi lancia `UnsupportedError` per tutte le piattaforme non-web.

### 1.5 Rischio tecnico: plugin web-only
Diverse dipendenze in `pubspec.yaml` sono **solo web** e impediranno la compilazione desktop finché
non isolate dietro compilazione condizionale o rimosse:
`google_maps`, `youtube_player_iframe`, `g_recaptcha_v3`, `image_picker_web`, `web`
(dart:js interop, usato in `main.dart` per lo script di Google Maps). Anche `video_player` non ha
supporto desktop ufficiale. I widget corrispondenti (mappa, YouTube, audio/video) andranno resi
condizionali o disabilitati su desktop.

---

## 2. Architettura target

```
┌──────────────────────────────────────────────────────────────┐
│  UI (invariata: editor, palette, proprietà, tree, code view)  │
├──────────────────────────────────────────────────────────────┤
│  AppStore (invariato nella logica dell'albero)                │
├──────────────────────────────────────────────────────────────┤
│  NUOVO: LocalProjectService  ← rimpiazza rest_apis per        │
│         progetti/schermate/media                              │
│    · load/save progetto (cartella con project.json)           │
│    · CRUD schermate in memoria + flush su disco               │
│    · media come file reali copiati in <progetto>/media/       │
├──────────────────────────────────────────────────────────────┤
│  File system (path_provider + file_picker)                    │
│    <AppData>/FlutterViz/projects/<NomeProgetto>/              │
│    oppure cartella scelta dall'utente                         │
└──────────────────────────────────────────────────────────────┘
```

### 2.1 Formato progetto — **cartella per progetto** *(deciso)*
Ogni progetto è una **directory** (non un file singolo): più comoda per media ed export, si
condivide zippandola.
```
<NomeProgetto>/
 ├─ project.json          # metadati + schermate (vedi sotto)
 ├─ media/                # immagini importate dall'utente (file reali)
 │    ├─ logo.png
 │    └─ bg.jpg
 └─ export/               # codice Dart generato (output export)
```
`project.json` — JSON versionato:
```jsonc
{
  "formatVersion": 1,
  "projectName": "MyApp",
  "createdAt": "2026-07-01T...",
  "updatedAt": "2026-07-01T...",
  "screens": [
    {
      "id": 1,                 // int locale, progressivo
      "name": "Home Screen",
      "screenJsonData": "…",   // identico all'output di widgetClassToJsonData()
      "screenImage": "…"       // PNG base64 (thumbnail), opzionale
    }
  ],
  "media": [ { "name": "logo.png", "path": "media/logo.png" } ]  // riferimenti relativi
}
```
Il campo `screenJsonData` riusa **così com'è** il formato già prodotto/consumato dal parser
esistente: nessuna migrazione del formato widget. I media sono referenziati con **path relativi**
alla cartella del progetto.

### 2.2 Nuovo servizio: `LocalProjectService`
`lib/local_storage/local_project_service.dart` (nuovo). Responsabilità:
- `Future<Project> newProject(String name, {Directory? location})` (crea la cartella + `project.json` + `media/`)
- `Future<Project> openProject(Directory dir)` / `openFromPath(String)`
- `Future<void> saveProject(Project)` (serializza `appStore.screenList` → `project.json`)
- `List<Project> listRecentProjects()` (indice in `<AppData>/FlutterViz/recent.json`)
- CRUD schermate: `addScreen`, `renameScreen`, `deleteScreen`, `cloneScreen` — operano sulla
  lista in memoria e poi invocano `saveProject`.
- Media: `importMedia(File src)` copia il file in `<progetto>/media/` e restituisce il path relativo.
- Assegnazione `id` progressivi locali (rimpiazza gli id del backend).

`get_it` è già usato (`locator` in `main.dart`): registrare qui il servizio come singleton.

---

## 3. Fasi di lavoro

Ogni fase è indipendente e verificabile; l'ordine è pensato per avere presto qualcosa di
eseguibile. Ogni fase termina con `flutter analyze` pulito e app avviabile.

### Fase 0 — Preparazione e sblocco esecuzione *(rapida, sblocca lo sviluppo)* ✅ COMPLETATA
**Scopo:** poter avviare ed esplorare l'editor subito, prima ancora della persistenza.
- [x] Abilitare i target desktop: `flutter create --platforms=windows,linux .`
- [x] Rendere Firebase opzionale/no-op fuori dal web (guardia `kIsWeb` attorno a
      `Firebase.initializeApp` in `main.dart`; evitare `UnsupportedError`).
- [x] Bypass boot: `main.dart` avvia direttamente `DashboardScreen()` (invece di `LoginScreen()`),
      che già creava da sola una `ScreenListData` fittizia + `appStore.addRootView()` in `init()` —
      non è stato necessario toccare `dashboard_screen.dart`.
- [x] Creato un `.env` placeholder (vuoto, gitignored) — necessario perché è un asset dichiarato
      in `pubspec.yaml`; senza, `flutter run`/`build` falliscono a monte.
- [x] Rimosso lo script di injection Google Maps da `main.dart` (diventato dead code, vedi Fase 1).
- **Verifica:** `flutter run -d windows` apre l'editor e mostra palette/canvas/proprietà
      correttamente (screenshot confermato). Non ancora testato `-d linux` (nessun host Linux
      disponibile in questa sessione, ma i file di piattaforma sono stati generati).
- **Nota:** questa fase produce un bypass temporaneo che verrà sostituito dal flusso reale in Fase 3.

### Fase 1 — Compilabilità desktop (rimuovere i plugin web-only) ✅ COMPLETATA
**Scopo:** build desktop che compila davvero.
**Decisione:** i widget web-only vengono **rimossi**, non stubbati — vedi §6 per l'appunto di
reintroduzione futura.
- [x] **Google Map — rimosso completamente** (era l'unico blocco *hard* per la build nativa: il
      package `google_maps` usa `dart:js_interop` non compilabile fuori dal target web/wasm).
      Toccati: `lib/widgetsClass/google_map_class.dart` e `lib/widgetsProperty/google_map_property_view.dart`
      (eliminati), `lib/widgets/widgets.dart` (4 punti di dispatch), `lib/utils/AppFunctions.dart`,
      `lib/utils/AppCommon.dart`, `lib/model/screen_json_data.dart`,
      `lib/components/rightView/selected_widget_property.dart`, `pubspec.yaml`. La costante
      `WidgetTypeGoogleMap` e le stringhe di traduzione `titleGoogleMap` sono rimaste (innocue,
      non referenziate) — pulizia rimandata a un passaggio di rifinitura.
- [x] **YouTube / Video / Audio player — rimossi completamente.** Non bloccavano la compilazione
      nativa (a differenza di `google_maps`), ma sono stati rimossi comunque per coerenza con la
      decisione presa. Toccati: `lib/widgetsClass/{video_player,audio_player,youtube_player}_class.dart`
      e i relativi `lib/widgetsProperty/*_property_view.dart` (eliminati), i 3 wrapper
      `lib/externalClasses/flutterViz_{video,audio,youtube}_player.dart` (eliminati, erano usati solo
      da queste classi), tutte le voci in `baseWidgetsList` e i ~10 punti di dispatch per tipo in
      `lib/widgets/widgets.dart`, `lib/utils/AppFunctions.dart` (incl. 2 liste generiche di
      comportamento layout — `getExpanded`/`getExpandedModel` — dove compariva solo
      `WidgetTypeVideoPlayer` tra vari altri tipi non toccati), `lib/utils/AppCommon.dart` (icone +
      `fullWidthWidgetTypeList`), `lib/model/screen_json_data.dart`,
      `lib/components/rightView/selected_widget_property.dart`, e le 3 voci nel pannello "info
      widget" (`lib/utils/DataProvider.dart`).
      **Effetto collaterale positivo trovato durante la pulizia**: in `screen_json_data.dart` il
      `toJson()` di `VideoPlayerClass` aveva un bug preesistente (scriveva
      `youtubePlayerClass!.toJson()` invece di `videoPlayerClass!.toJson()`) — sparito con la rimozione.
      **Eccezione gestita a parte**: `lib/components/tutorials_component.dart` (schermata "Tutorials"
      dell'app, raggiungibile dal menu principale) usava `FlutterVizYoutubePlayer` per riprodurre in
      un dialog i video tutorial. Sostituito con `launchUrl(...)` (`url_launcher`, già dipendenza) che
      apre il link del tutorial nel browser di sistema — più adatto a un'app desktop di un iframe
      embedded, e non richiede più `youtube_player_iframe`. Nota: questa schermata resta comunque
      legata al backend (`getTutorialsList()`), quindi tornerà in discussione in Fase 4.
- [x] Isolato **tutto** l'uso diretto di `dart:html`/`package:web` (non solo Google Maps) dietro un
      modulo a import condizionale `lib/utils/web_interop/` (`web_interop.dart` esporta
      `web_interop_stub.dart` di default o `web_interop_web.dart` se `dart.library.html` è
      disponibile). Questo era un blocco di compilazione nativa **generale**, non solo della mappa:
      riguardava anche `lib/components/centerView/dashboard-preview_component.dart` (context menu),
      `lib/components/code_view_header_component.dart`, `lib/components/pubSpec_file_details.dart`,
      `lib/components/header_component.dart` (download codice/progetto via `Blob`/`AnchorElement`),
      e `lib/widgets/handle_keyboard_event.dart` (tab key listener). Le funzioni di download
      restano no-op su desktop: l'implementazione locale reale è compito della Fase 5.
- [x] Aggiunto `path_provider: ^2.1.5` a `pubspec.yaml` (servirà in Fase 2 per la cartella dati).
- [x] Rimosse le dipendenze `youtube_player_iframe`, `just_audio`, `video_player`, `rxdart`
      (verificato non usato altrove) e `web` da `pubspec.yaml`; `google_maps` già rimosso in
      precedenza nella stessa fase.
- **Scope rivisto rispetto alla stesura iniziale del piano:** `image_picker_web` (usato dal media
  picker per il web) e `g_recaptcha_v3` (usato solo in `register_screen.dart`, parte del flusso di
  login) **non sono stati rimossi qui** — non bloccano la build nativa (la Fase 0 aveva già
  compilato con entrambi presenti) e appartengono logicamente ad altre fasi già pianificate:
  `image_picker_web` alla gestione media locale (Fase 5), `g_recaptcha_v3` alla rimozione del
  login/backend (Fase 4). Spostati lì per evitare di anticipare lavoro fuori ambito.
- **Scoperte impreviste, non legate ai widget web-only, che bloccavano comunque la build nativa
  con il Flutter/Dart SDK attualmente installato (3.44.4 / Dart 3.12) — probabilmente avrebbero
  bloccato anche il target web con questo stesso SDK:**
  - `flutter_treeview` 1.0.7+1 (ultima versione pubblicata, pacchetto non manutenuto) chiama le API
    rimosse `hashValues`/`hashList`. Soluzione applicata: vendorizzata una copia locale in
    `third_party/flutter_treeview/` con le 3 occorrenze sostituite da `Object.hash(...)`, agganciata
    via `dependency_overrides` in `pubspec.yaml`. Da valutare in futuro: sostituire del tutto con
    `animated_tree_view` (già in `pubspec.yaml`) per eliminare questa dipendenza vendorizzata.
  - `lib/utils/AppTheme.dart` usa `CupertinoPageTransitionsBuilder` avendo importato solo
    `package:flutter/material.dart` (che non ri-esporta `cupertino.dart`). Fix: aggiunto
    `import 'package:flutter/cupertino.dart';`.
  - **Bug di classe generale, potenzialmente presente altrove:** diverse funzioni helper senza tipo
    di ritorno esplicito (`getMenuWidth`, `getChildWidgetsWidth`, `getLeftWidgetsWidth`,
    `getRightPropertyViewWidth`, `getCenterScreenWidth` in `lib/utils/AppCommon.dart`) restituivano
    letterali `int` (es. `200`, `70`) usati come `double` (es. `Container.width`). Su Flutter Web
    (dart2js) `int`/`double` sono unificati a runtime e l'errore non si manifesta; sulla VM nativa
    (Windows/Linux/desktop) lancia `type 'int' is not a subtype of type 'double?'` a runtime. Fix
    applicato aggiungendo tipo di ritorno esplicito `double` a queste 5 funzioni. **Altre funzioni
    `dynamic`/non tipizzate nel codebase potrebbero avere lo stesso problema silente**: se durante
    le prossime fasi compare lo stesso errore runtime, cercare funzioni helper senza tipo di ritorno
    che restituiscono letterali interi usati in contesti `double`.
  - `fluttertoast` non ha un'implementazione per Windows/Linux: le chiamate `getToast(...)` lanciano
    `MissingPluginException` (non fatale, solo loggata) su desktop. Da sistemare quando si rimuove
    la dipendenza dal backend (i toast di errore di rete spariranno comunque in Fase 3/4), ma se
    restano notifiche locali da mostrare andrà sostituito con un meccanismo desktop-friendly.
- **Verifica:** `flutter build windows` completa senza errori (**confermato**, palette senza
  mappa/video/audio/youtube); `flutter analyze` a 0 errori — **nota**: questo conteggio era in
  realtà basato su un grep sbagliato (vedi la correzione nella verifica di Fase 2 più sotto) e
  nascondeva 3 problemi preesistenti poi trovati e risolti in Fase 2. `flutter build linux --debug`
  **ora testato e verde** (host Linux disponibile in una sessione successiva) — vedi nota sotto.
- **Aggiornamento (verifica `flutter build linux`, sessione successiva):** due problemi bloccavano
  la prima build su host Linux, entrambi risolti:
  1. `.env` assente in questo host (è gitignored, va ricreato per-macchina come già notato in Fase 0)
     — ricreato con le stesse chiavi placeholder.
  2. **Bug reale trovato**, non legato all'ambiente: `lib/widgets/on_accept_widgets.dart:116` aveva
     `if (!isExpanded)` invece di `if (!isExpanded!)`, con `isExpanded` tipizzato `bool?` — errore di
     null-safety che blocca la compilazione su qualunque target (non solo Linux). Era una modifica
     presente nel working tree ma non ancora committata al momento del test; non chiaro in quale
     sessione precedente fosse stata introdotta né perché non fosse emersa nella verifica
     `flutter build windows` di questa fase (il file compare come modificato anche in quella sessione).
     **Ripristinato il `!`**. Dopo questo fix, `flutter build linux --debug` produce
     `build/linux/x64/debug/bundle/flutter_viz` senza errori.

### Fase 2 — `LocalProjectService` (persistenza su file) ✅ COMPLETATA
**Scopo:** salvare/caricare un progetto su disco.
- [x] Definito il modello `Project` (+ `ProjectMediaItem`) in `lib/local_storage/project.dart`:
      cartella con `project.json` (`formatVersion`, `projectName`, `createdAt`, `updatedAt`,
      `screens`, `media`) + `media/` + `export/`, secondo il formato deciso in §2.1. `screens` riusa
      **direttamente** il modello esistente `ScreenListData` (`lib/model/screen_list_response.dart`)
      invece di introdurne uno nuovo — il suo campo `screenJsonData` è già lo stesso formato
      prodotto/consumato da `widgetClassToJsonData()`/`applyScreenJsonToView()`.
- [x] Implementato `LocalProjectService` in `lib/local_storage/local_project_service.dart`
      (§2.2): `newProject`, `openProject`/`openFromPath`, `saveProject`, `listRecentProjects`
      (indice leggero `RecentProjectEntry` in `<AppData>/FlutterViz/recent.json`, per non dover
      aprire ogni `project.json` solo per elencare i progetti recenti), CRUD schermate
      (`addScreen`/`renameScreen`/`updateScreenData`/`deleteScreen`/`cloneScreen`, con id
      progressivi locali), e `importMedia` (copia il file in `<progetto>/media/`, rinominando in
      caso di collisione). Registrato come singleton in `get_it` (`main.dart` → `setupServiceLocator()`).
- [x] Aggiunto un metodo `setAppDataDirectoryForTesting()` per reindirizzare la cartella dati verso
      una directory temporanea nei test, evitando di dover mockare i platform channel di
      `path_provider`. Il dialogo `file_picker` per Apri/Salva-con-nome resta da collegare in Fase 3
      (qui era fuori scopo: questa fase riguarda il servizio, non ancora la UI che lo userà).
- [x] **Test unitari** in `test/local_project_service_test.dart` (5 test, tutti verdi):
      creazione cartella progetto; round-trip completo widget-tree → `widgetClassToJsonData()` →
      scrittura su disco → riapertura → `applyScreenJsonToView()` → albero ricostruito verificato
      identico (stesso `widgetSubType`, stessa gerarchia, stesso testo nel `TextClass`); ordine di
      `listRecentProjects()`; CRUD schermate persistito su `project.json`; `importMedia`.
- **Scoperta importante durante la verifica — errore nel mio metodo di controllo, non nel codice:**
  nelle Fasi 0/1 avevo verificato "0 errori" con `grep -c "^error"`, ma l'output di `flutter analyze`
  allinea la colonna di severità con spazi iniziali (`"  error - ..."`), quindi quel grep non
  avrebbe **mai** trovato un vero errore — il conteggio "0" era falso positivo strutturale, non una
  verifica reale. Con il pattern corretto (`grep "error -"`) sono emersi 2 problemi preesistenti,
  scoperti solo ora:
  1. Due file bundlati come asset per l'export (`images/files/FlutterViz{Audio,Video,Youtube}Player.dart`)
     erano diventati orfani dopo la rimozione dei relativi widget in Fase 1 (referenziavano i
     package rimossi `just_audio`/`video_player`/`youtube_player_iframe`) — **eliminati**.
  2. `analysis_options.yaml` non escludeva `build/**` dall'analisi (gap preesistente, non
     collegato a questa migrazione): gli asset `.dart` copiati in `build/flutter_assets/` venivano
     analizzati come se fossero codice sorgente. **Aggiunto un blocco `analyzer: exclude:`** per
     `build/**` e per `images/files/**` (i template restanti in quella cartella — drawer, credit
     card, bottom nav — sono snippet da copiare nel progetto esportato dall'utente, non codice
     compilato di quest'app, quindi non hanno senso da analizzare qui).
  3. Un file strano e mai referenziato, `lib/AppTheme.dart` (alla radice di `lib/`, diverso da
     `lib/utils/AppTheme.dart` che è quello realmente usato dall'app) conteneva lo stesso bug
     dell'import mancante di `cupertino.dart` già risolto in Fase 0 — ma sull'originale, non su
     questo doppione. Verificato non referenziato da nessuna parte insieme a un secondo file simile,
     `lib/ZoomViewExample.dart` (scarto/esempio del template originale) — **entrambi eliminati**.
  **Da fare ora in poi**: usare sempre `grep "error -"` (non `grep "^error"`) per verificare
  `flutter analyze` in questo progetto.
- **Verifica:** `flutter test test/local_project_service_test.dart` → 5/5 verdi;
  `flutter analyze` → 0 errori (verificato con il pattern corretto); `flutter build windows` pulita.
  (Nota: `test/widget_test.dart`, il test "Counter increments smoke test" generato di default da
  `flutter create` e mai aggiornato per questa app, fallisce già da prima — non collegato a questa
  fase, ignorato.)

### Fase 3 — Collegare l'editor al servizio locale (progetti e pagine) ✅ COMPLETATA
**Scopo:** creare/aprire progetti multi-pagina e gestire le pagine, tutto in locale.
- [x] Aggiunto `Project? currentProject` e `AppStore.loadProject(Project)` (`lib/store/AppStore.dart`):
      popola `screenList`/`projectName`/`fileName` da un `Project` aperto/creato e riusa
      `addScreens()` esistente (che già gestiva il placeholder "New Screen" id -1 e la selezione
      della prima schermata).
- [x] **`WelcomeScreen` riscritta** (`lib/screen/welcome_screen.dart`) come vero picker locale:
      elenca i progetti recenti via `LocalProjectService.listRecentProjects()`, bottone "Create New
      Project" (dialog semplificato) e bottone "Open Project" che usa `file_picker` per aprire una
      cartella progetto arbitraria via `openFromPath()`. **`main.dart`** ora punta `home:` a
      `WelcomeScreen()` invece del bypass diretto a `DashboardScreen()` introdotto in Fase 0.
- [x] **`WelcomeScreenComponent` riscritta** (`lib/components/welcome_screen_component.dart`) per
      mostrare `List<RecentProjectEntry>` invece di `List<UserProjectData>` (rimosso il backend
      `getUserProjectList()`); click per aprire, icona cestino per rimuovere dall'indice recenti
      (`LocalProjectService.removeRecent()`, nuovo metodo — non tocca i file su disco). Le
      funzionalità di rinomina/clona-progetto (`AddCloneProjectDialog`) sono state **rimosse dalla UI**
      (fuori scopo per questa fase, che copre solo list/create/open come da piano) — il file
      `add_clone_project_dialog.dart` resta ma è ora non referenziato (pulizia rimandata a Fase 6).
- [x] **`CreateProjectDialog` semplificata** (`lib/components/create_project_dialog.dart`): rimossa
      tutta la galleria "template di progetto" lato server (`getProjectList`/`addTemplateSaveAsProject`,
      backend-only e senza senso offline), resta solo nome progetto → `LocalProjectService.newProject()`
      + una schermata "Home Screen" di default → `appStore.loadProject()` → `DashboardScreen`.
- [x] Sostituite le chiamate `addScreen/deleteScreen/getScreenList` con i metodi di
      `LocalProjectService` in: `add_screen_dialog.dart` (rinomina schermata → `renameScreen`),
      `add_page_dialog.dart` (`addScreenApi`/`updateScreenImageApi` → `addScreen`/`updateScreenData`),
      `screen_list_component.dart` (`deleteScreenApi` → `deleteScreen`), `screens_page_components.dart`
      (`getScreenListApi` → riapre `project.json` via `openProject()`, `deleteScreenApi` →
      `deleteScreen`), `screen_clone_dialog.dart` (rinomina o "Save As" → `renameScreen`/`addScreen`+
      `updateScreenData`).
- [x] Sostituito `saveScreenApi()` (`AppCommonApiCall.dart`, usato da Ctrl+S e dal bottone salva
      dell'header) e `autoSaveData()`/`init()` (`dashboard_screen.dart`, timer ogni 30s) con
      `LocalProjectService.updateScreenData()`; rimossa `getAllScreenListApi()` (dead code —
      `DashboardScreen` ora riceve le schermate già caricate da `WelcomeScreen` via
      `appStore.loadProject()`, non le rifetcha più).
- **Bug preesistente scoperto e corretto in corso d'opera**: `autoSaveData()` e il bottone "create
  project" erano avvolti in `ifNotTester(...)`, un guard pensato per il concetto di utente
  demo/tester del backend (`appStore.userEmail`/`USER_TYPE` da SharedPreferences). Con il login
  bypassato dalla Fase 0, `USER_TYPE` non viene mai impostato → la condizione falliva sempre →
  `ifNotTester` **non eseguiva mai il callback**, disabilitando silenziosamente l'autosave (e in
  origine anche la creazione progetto) senza errori visibili. Rimosso l'uso di `ifNotTester` da
  questi due punti, dato che il concetto di utente "tester" non ha senso in un'app desktop locale
  senza licenze/backend.
- **Verifica:** `flutter analyze` → 0 errori reali (verificato con `grep "error -"`); `flutter test
  test/local_project_service_test.dart` → 5/5 verdi (invariati); `flutter build windows` → pulita.
- **Nota sulla cattura schermo (falso allarme)**: un primo tentativo di verifica visiva tramite
  screenshot GDI (`CopyFromScreen`/`PrintWindow`) mostrava un rettangolo bianco anche con un
  `Container(color: Colors.red)` di debug al posto del `body`. Confrontando con un'app Flutter
  Windows vanilla nello stesso ambiente (cattura riuscita al primo colpo), si è visto che
  `CopyFromScreen` funziona normalmente — il rettangolo bianco iniziale era un artefatto di timing
  della cattura, non un bug. Ripetendo la cattura, la `WelcomeScreen` **si vede correttamente**:
  logo/versione, switch dark mode, bottoni "Open Project"/"Create New Project", messaggio "No
  Project found".
- **Verifica end-to-end confermata dall'utente in sessione live**: creato un progetto reale
  ("prova") dalla `WelcomeScreen`; `project.json` scritto correttamente su disco con
  `formatVersion`/`projectName`/`screens[]`; `recent.json` aggiornato; **autosave confermato
  funzionante** (`updatedAt` successivo a `createdAt` nel `project.json` dopo ~1 minuto di editing,
  segno che il timer da 30s ha effettivamente chiamato `updateScreenData()`).
- **Bug reale trovato durante il test live e corretto**: il log di `flutter run -d windows` mostrava
  `[ERROR] Unhandled Exception: MissingPluginException(No implementation found for method showToast
  on channel PonnamKarthik/fluttertoast)` — `getToast()` (`lib/utils/AppFunctions.dart`) chiama
  `Fluttertoast.showToast(...)` senza mai gestirne l'esito, e il pacchetto `fluttertoast` non ha
  **nessuna** implementazione nativa per Windows/Linux, quindi ogni singola chiamata a `getToast()`
  in tutta l'app (centinaia di call site, non solo quelli toccati in questa fase) lanciava
  un'eccezione non gestita su desktop. Era già segnalato come rischio noto nelle note della Fase 1
  ("da sistemare quando si rimuove la dipendenza dal backend... Fase 3/4"). **Fix minimo applicato**:
  aggiunto un `.catchError((e) => false)` al `Future` restituito da `Fluttertoast.showToast(...)`,
  per evitare l'eccezione non gestita senza introdurre un nuovo sistema di notifiche desktop (quello
  resta un miglioramento più ampio, rimandato a una fase successiva di rifinitura UX). Verificato con
  `flutter analyze` (0 errori) e `flutter test` (5/5 ancora verdi).
- **Osservazione fuori scopo, non toccata**: lo switch dark mode (`darkModeSwitchWidget()` in
  `lib/utils/AppWidget.dart`) chiama ancora `editProfileApi()` → `updateProfile()` REST per
  persistere la preferenza tema lato server; fallisce silenziosamente con "No host specified in URI"
  (già gestito da un `catchError` esistente, solo loggato — nessun crash). Rientra nella rimozione
  del livello di rete pianificata per la Fase 4, non toccato qui per restare nello scopo di questa
  fase.

### Fase 4 — Rimozione del gate di login/backend ✅ COMPLETATA
**Scopo:** boot pulito senza autenticazione. **Decisione:** livello di rete **rimosso** del tutto.
- [x] Il bypass temporaneo della Fase 0 era già stato sostituito da `WelcomeScreen` come
      "Progetti recenti / Nuovo / Apri" in Fase 3 — nessun lavoro aggiuntivo qui.
- [x] Rimossi `LoginScreen`, `RegisterScreen`, `ForgotPasswordScreen` e `SplashScreen` (quest'ultima
      era già dead code: nessuna rotta ci arrivava più, `main.dart` avvia `WelcomeScreen` da Fase 3).
      Rimossi Firebase Auth/Core/Analytics (+ `AnalyticsService`), `google_sign_in`, e il caricamento
      `.env`/`flutter_dotenv` — non più necessari (le costanti `baseURl`/`CAPTACHA_*`/`INVITE_CODE`
      lette da `.env` in `AppConstant.dart` servivano solo al layer di rete rimosso).
      `trackScreenView`/`trackUserEvent` (`AppFunctions.dart`) sono stati resi no-op invece di
      rimossi, per non dover toccare i loro ~19 call site sparsi nell'app.
- [x] Rimossa la dipendenza `g_recaptcha_v3` (era solo in `register_screen.dart`, eliminato).
- [x] **Rimosso** `lib/network/` (`rest_apis.dart`, `network_utils.dart`, `auth_service.dart`) e 12
      modelli di risposta backend ora orfani in `lib/model/` (`base_response`, `login_response`,
      `user_project_list_model`, `profile_info_model`, `profile_photo_model`, `city_model`,
      `country_model`, `state_model`, `add_screen_model`, `class_widget_model`,
      `feedback_status_model`, `verify_recaptcha_model` — verificati non referenziati altrove per
      nome di classe, non solo per import diretto).
- **Decisione presa in sessione (non nella stesura originale del piano) — area admin anticipata da
  Fase 6**: `lib/network/` era importato da tutti i 14 file di `lib/adminDashboard/`, non solo dal
  flusso di login. Tenerlo in vita con uno stub avrebbe contraddetto la Decisione #4 ("rete rimossa
  del tutto") e lasciato per un'intera fase codice che non compila con uno stub finto; l'area admin
  era comunque già irraggiungibile dal boot bypassato in Fase 0. **Rimossa qui `lib/adminDashboard/`
  per intero** (component/model/screen), insieme a `lib/screen/admin_project_template_screen.dart`.
  La parte restante di Fase 6 ("altro codice morto: AnalyticsService, modelli backend residui") è
  quindi già in gran parte assorbita da questa fase.
- **Funzionalità rimosse per mancanza di equivalente locale** (dipendevano dal backend/account utente
  e non hanno senso in un'app desktop senza login):
  - **Profile / Change password / Edit profile** (`profile_component.dart`,
    `change_password_dialog.dart`, `edit_profile_dialog.dart`) — eliminati, insieme a
    `getProfileWidget()`/`profileImage()` (`AppWidget.dart`/`AppCommon.dart`) e alla voce "Profile"
    nel menu laterale (`menu_component.dart`) e in `center_child_view_screen.dart`.
  - **Feedback** (`feedback_dialog.dart`) — eliminato, insieme all'icona nell'header.
  - **Tutorials** (`tutorials_component.dart`) — eliminato, insieme alla voce di menu; la lista video
    veniva da `getTutorialsList()` (backend), senza equivalente locale bundlabile.
  - **Galleria "componenti" da backend** (`left_component_list_component.dart`,
    `categoryComponentListApi`) — rimossa la chiamata di rete, il pannello ora mostra sempre "nessun
    dato" (nessun archivio locale di componenti salvati esiste ancora).
  - **Galleria "template pagina" da backend** in `add_page_dialog.dart`
    (`categoryTemplateListApi`/tab bar) — rimossa, stesso pattern già usato in `create_project_dialog.dart`
    in Fase 3: resta solo la creazione di una pagina vuota.
  - **Duplicato morto** `lib/components/addpagedialog.dart` (senza underscore, mai referenziato) e
    `lib/components/add_clone_project_dialog.dart` (già segnalato non referenziato in Fase 3) —
    eliminati.
- **Funzionalità riportate in locale invece che rimosse**, dove esisteva già l'infrastruttura:
  - **Media** (`media_component.dart`, `AppCommonApiCall.dart`): la libreria immagini di progetto ora
    legge/scrive `<project>/media/` via `LocalProjectService` (`importMedia`, nuovo `deleteMedia`)
    invece di `getMediaList()`/upload multipart; le thumbnail nel pannello e nel picker della
    proprietà "Asset Image" (`comman_property_view.dart`) usano `Image.file` invece di
    `commonCachedNetworkImage`. **Non toccato**: la resa live dei widget Image/CircleImage/ImageIcon
    già trascinati sul canvas (`Image_class.dart` e affini) usa ancora sempre `NetworkImage(path)` per
    il path selezionato — bug preesistente non legato a questa fase, la vera integrazione
    locale-end-to-end resta il compito di Fase 5 ("adattare media_component.dart").
  - **Export codice** (`header_component.dart`, `downloadProjectLatest()`): scrive ora i file `.dart`
    generati direttamente in `<project>/export/` su disco invece di chiamare
    `downloadProjectLatestApi()` (zip lato server). Non è ancora uno zip/installer — resta compito di
    Fase 5 ("generazione locale... creare lo zip in locale").
  - Rimossa anche la funzionalità morta "Save as Template/Component" nell'header (backend catalog
    condiviso, `addTemplateApi`/`addComponentApi`/`addProjectTemplateApi`): dipendeva da
    `appStore.screenTemplateData`, mai assegnato in nessun punto raggiungibile del codice (verificato
    con grep) — cioè era già dead code prima ancora della rimozione della rete. Rimosso anche il
    campo `screenTemplateData`/tipo `TemplateData` da `AppStore.dart` (rigenerato `AppStore.g.dart`
    con `build_runner`) e le relative diramazioni sempre-false in `header_component.dart`,
    `menu_component.dart`, `right_screen_component.dart`.
  - `deleteScreenApi()` in `right_screen_component.dart` e `preview_screen.dart` (non toccati in Fase
    3, che aveva convertito solo `screen_list_component.dart`/`screens_page_components.dart`) ora
    usano `LocalProjectService.deleteScreen()`.
- **Verifica:** `flutter pub get` rimuove 16 pacchetti (Firebase ×4, `google_sign_in` ×5,
  `g_recaptcha_v3`, `flutter_dotenv`, `image_picker_web`, ecc.); `flutter analyze` → 0 errori;
  `flutter test test/local_project_service_test.dart` → 5/5 verdi; `flutter build linux --debug` →
  pulita; **eseguito il binario risultante** (`build/linux/x64/debug/bundle/flutter_viz`) su display
  reale: resta in esecuzione senza eccezioni, log di boot regolare (`IS_LOGGED_IN=false`,
  lingua caricata). Non verificato in questa sessione: `flutter build windows` (nessun host Windows
  disponibile qui, simmetrico al limite opposto delle sessioni precedenti).
- **Nota per Fase 5/6**: `image_picker_web` era stato lasciato in Fase 1 perché non bloccava la build
  nativa; è stato rimosso qui perché è risultato non più referenziato da nessun file (il media
  picker locale usa solo `image_picker`).

### Fase 5 — Media ed export codice in locale ✅ COMPLETATA
**Scopo:** completare l'integrazione locale end-to-end di media ed export (la Fase 4 aveva già
coperto la parte "senza rete" di entrambi come effetto collaterale della rimozione di
`lib/network/`; questa fase copre la parte di *qualità/completezza* del risultato).
- [x] Media: sostituire upload/lista media remoti con copia dei file nella cartella del
      progetto → **fatto in Fase 4** (`media_component.dart` + `LocalProjectService.importMedia`/
      `deleteMedia`, rimossa `image_picker_web`).
- [x] **Resa locale dei media nei widget**: `lib/widgetsClass/Image_class.dart`,
      `circle_image_class.dart`, `image_icon_class.dart`, `left_drawer_class.dart` e
      `page_view_class.dart` usavano tutti `NetworkImage`/`Image.network` anche per il tipo "Asset"
      (bug preesistente, "accidentalmente funzionante" quando `path` era un URL del vecchio backend —
      vedi rischio segnalato a fine Fase 4). Ora, quando `imageType == ImageTypeAsset`: se `path` è
      valorizzato (path locale assoluto scelto dal picker media) si usa `FileImage`/`Image.file`;
      altrimenti si usa `AssetImage`/`Image.asset` sul placeholder bundlato in *questa* app
      (`images/placeIndex.png` e affini, già dichiarati come asset in `pubspec.yaml`). **Non
      toccata** la generazione del codice esportato (`getCodeAsString`/stringhe `AssetImage(...)`):
      era già corretta di suo — assume che l'utente copi le immagini in `assets/images/`
      nel progetto esportato, un passaggio manuale preesistente e non legato alla rete.
- [x] Export codice: rimpiazzare `downloadProjectLatestApi()` con generazione locale → **fatto**.
      `downloadProjectLatest()` in `header_component.dart` genera i sorgenti via
      `viewFinalSourceData()` (invariato, già locale), li impacchetta in uno zip vero con il pacchetto
      `archive` (`Archive`/`ArchiveFile`/`ZipEncoder`), e lascia scegliere dove salvarlo con
      `FilePicker.platform.saveFile()` ("Salva con nome"). Se l'utente annulla il dialogo, l'export
      si interrompe senza errori.
- **Verifica:** `flutter analyze` → 0 errori; `flutter test test/local_project_service_test.dart` →
  5/5 verdi (invariati); `flutter build linux --debug` → pulita dopo l'aggiunta di `archive` a
  `pubspec.yaml`. Verifica manuale interattiva (drag di un'immagine nel canvas, click su "Download")
  non eseguita in questa sessione — nessuno strumento di cattura schermo funzionante disponibile per
  questo host Linux (vedi nota sotto); il codice è stato verificato per compilazione/tipi e per
  coerenza logica con `LocalProjectService`/`Project.exportDirectory` già testati in Fase 2.
- **Nota**: un tentativo di screenshot con `import` (ImageMagick) su questo host è fallito
  (`missing an image filename` nonostante il path fosse passato correttamente — presumibilmente una
  policy di sicurezza di ImageMagick che blocca la cattura di `-window root`). L'avvio del binario
  Linux è comunque stato verificato in Fase 4 (processo stabile, nessuna eccezione nei log).

### Fase 6 — Rifinitura, packaging, pulizia 🟡 QUASI COMPLETATA (packaging installer non fatto)
- [x] ~~Rimuovere l'area admin `lib/adminDashboard/`~~ → **fatto in Fase 4** (anticipata per necessità:
      dipendeva interamente da `lib/network/`, rimosso nella stessa fase).
- [x] Rimosso codice morto residuo: campi `isComponent`/`isProjectTemplate` in `AppStore.dart` (mai
      assegnati, stesso pattern del già rimosso `screenTemplateData`; rigenerato `AppStore.g.dart`);
      l'intero blocco "Admin Screen Index" in `AppConstant.dart` (`ADMIN_DASHBOARD_INDEX` e altri 6,
      tutti orfani); `PROFILE_INDEX`/`TUTORIALS_INDEX`; `WidgetTypeGoogleMap`/`WidgetTypeVideoPlayer`/
      `WidgetTypeAudioPlayer`/`WidgetTypeYoutubePlayer` (residui della rimozione widget di Fase 1); le
      14 occorrenze di `titleGoogleMap` nei file di traduzione (`lib/local/language_*.dart` +
      `languages.dart`).
- [x] **Bug critico trovato e corretto**: `ifNotTester()` (`lib/utils/AppCommon.dart`) è rimasta la
      guardia originale del concetto di utente "tester" del backend — condizionava l'esecuzione della
      callback a `getStringAsync(USER_TYPE) == USER`. Con il login rimosso, `USER_TYPE` non viene
      **mai** scritto, quindi la condizione è sempre falsa e la callback **non veniva mai eseguita**.
      La Fase 3 aveva già trovato e corretto questo stesso bug per due call site (autosave, create
      project), ma **altri 8 call site erano rimasti**, tutti azioni chiave dell'editor silenziosamente
      disabilitate: bottone **Save** e **Download/Export** dell'header, **Create Page**,
      **rinomina/clona schermata**, **view source code**, **clear screen data** e **delete screen**
      nel pannello destro, **delete screen** nella preview. Rimossa la guardia da tutti gli 8 call
      site (`header_component.dart`, `right_screen_component.dart`, `preview_screen.dart`) ed
      eliminata la funzione `ifNotTester` stessa, ora completamente inutilizzata.
- [x] Aggiornato `README.md` (rimossa la sezione `.env`/variabili d'ambiente non più necessaria,
      aggiunte istruzioni `flutter run -d linux`/`-d windows` e formato cartella-progetto) e
      `CLAUDE.md` (sezioni "Fork goal"/"Setup"/"Common commands"/"Other areas" aggiornate per
      riflettere lo stato attuale: nessun `.env`, `lib/network/`/`lib/adminDashboard/` rimossi,
      `lib/local_storage/` come nuovo layer di persistenza).
- [ ] **Packaging (non fatto in questa sessione)**: `flutter build linux` (debug e `--release`)
      verificati puliti ed eseguiti su display reale senza eccezioni; **non** prodotto un pacchetto
      installabile (AppImage/Flatpak) — gli strumenti necessari (`appimagetool`, `flatpak-builder`)
      non sono installati su questo host e richiederebbero un'installazione a livello di sistema non
      eseguita senza conferma esplicita. `flutter build windows` resta non verificabile da un host
      Linux (serve una macchina/CI Windows). Questo rimane l'unico punto aperto del piano.
- [x] `flutter analyze` e `flutter test` puliti (verificato a ogni step di Fase 4/5/6).

---

## 4. Decisioni prese
1. **Formato progetto → cartella per progetto** (`project.json` + `media/` + `export/`). Vedi §2.1.
2. **Area admin → rimossa** del tutto → **fatto in Fase 4** (anticipata da Fase 6: dipendeva
   interamente da `lib/network/`, rimosso nella stessa fase).
3. **Widget web-only → rimossi** (mappa/YouTube/video/audio), con appunto di reintroduzione in §6.
4. **Livello di rete → rimosso** del tutto (`lib/network/`, Firebase, auth) → **fatto in Fase 4**.
   Nessun backend opzionale. Rimosse anche le feature senza equivalente locale (Profile, Feedback,
   Tutorials, gallerie template/componenti da backend) — vedi Fase 4 per l'elenco completo.

## 5. Rischi principali
- ~~Compilazione desktop bloccata dai plugin web-only~~ → **risolto in Fase 1** (`google_maps`,
  `youtube_player_iframe`, `just_audio`, `video_player`, `web` rimossi; `dart:html` isolato dietro
  import condizionale). `flutter build windows` verificato pulito.
- Coerenza del formato `screenJsonData` tra versioni: introdurre `formatVersion` da subito.
- ~~La rimozione di rete/admin/widget tocca molti file~~ → **fatto in Fase 4**, proceduto con
  `flutter analyze` a ogni step come previsto; nessun riferimento a rete rimasto (verificato a grep).
- ~~`flutter build linux` non ancora verificato~~ → **risolto**: testato su host Linux,
  `flutter build linux --debug` verde dopo il fix di `on_accept_widgets.dart` descritto in Fase 1;
  il binario risultante è stato anche eseguito su display reale in Fase 4 (nessun crash).
  Non ancora testato `--release`, né il packaging (AppImage/Flatpak, previsto in Fase 6); non ancora
  testato `flutter build windows` dopo le rimozioni di Fase 4 (nessun host Windows in questa sessione).
- **Nuovo — resa locale dei media incompleta**: dopo la Fase 4 i path immagine importati sono locali,
  ma `Image_class.dart` (e affini) li passano ancora sempre a `NetworkImage`. Finché non si risolve
  in Fase 5, un'immagine importata da `media_component.dart` non si vede nell'anteprima live del
  widget sul canvas anche se il file esiste su disco.

---

## 6. Appunto: reintroduzione futura dei widget web-only *(rimossi in Fase 1)*
I seguenti widget sono stati **rimossi** per sbloccare la build desktop. Per reintrodurli in futuro
con supporto desktop nativo:

| Widget | Plugin attuale (web-only) | Alternativa desktop suggerita |
|--------|---------------------------|-------------------------------|
| Google Map | `google_maps` + `web`/`dart:js` | `flutter_map` (OpenStreetMap, cross-platform) o Google Maps SDK desktop |
| Video Player | `video_player` (no desktop) | `media_kit` (Windows/Linux/macOS) |
| Audio Player | `just_audio` + `rxdart` | `media_kit` o `audioplayers` (supporto desktop) |
| YouTube Player | `youtube_player_iframe` | `media_kit` con URL stream, o webview desktop |

Passi per la reintroduzione:
1. Ripristinare le classi `*_class.dart` + `*_property_view.dart` (recuperabili dalla history git
   pre-rimozione) e le costanti `WidgetType*` in `AppConstant.dart`.
2. Rimappare la generazione del codice Dart (`getCodeAsString`) sul nuovo plugin.
3. Riaggiungere le voci in `lib/widgets/widgets.dart` (dispatcher) e nella palette.
4. Considerare la compilazione condizionale (`kIsWeb`) se si vuole mantenere anche il target web.

**Importante:** la generazione del *codice esportato* per questi widget produce codice Flutter
standard e non dipende dai plugin dell'editor — la rimozione riguarda solo l'anteprima live
nell'editor, non la validità del codice che l'utente esporterebbe.
```
