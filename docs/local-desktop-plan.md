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
  nascondeva 3 problemi preesistenti poi trovati e risolti in Fase 2. `flutter build linux` non
  ancora testato (nessun host Linux disponibile in questa sessione).

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

### Fase 3 — Collegare l'editor al servizio locale (progetti e pagine)
**Scopo:** creare/aprire progetti multi-pagina e gestire le pagine, tutto in locale.
- [ ] Sostituire nelle CRUD schermate le chiamate `addScreen/deleteScreen/getScreenList` con i
      metodi di `LocalProjectService` (file: `add_screen_dialog.dart`, `add_page_dialog.dart`,
      `screen_list_component.dart`, `screens_page_components.dart`, `screen_clone_dialog.dart`).
- [ ] Sostituire in `create_project_dialog.dart` e `welcome_screen.dart` la lista/creazione
      progetti con `listRecentProjects()` / `newProject()` / `openProject()`.
- [ ] Sostituire `saveScreenApi()` (`AppCommonApiCall.dart`) e `autoSaveData()`
      (`dashboard_screen.dart`) con `LocalProjectService.saveProject()` (autosave = flush su file,
      con debounce; il thumbnail via `screenshotController` resta locale).
- [ ] Sostituire `getAllScreenListApi()` con il caricamento da file → `appStore.addScreens()`.
- **Verifica:** creare un progetto, aggiungere/rinominare/eliminare/clonare pagine, chiudere e
      riaprire l'app: il progetto si ricarica con tutte le pagine.

### Fase 4 — Rimozione del gate di login/backend
**Scopo:** boot pulito senza autenticazione. **Decisione:** livello di rete **rimosso** del tutto.
- [ ] Sostituire il bypass temporaneo della Fase 0 con una vera schermata iniziale
      "Progetti recenti / Nuovo / Apri".
- [ ] Rimuovere `LoginScreen`, `RegisterScreen`, `ForgotPassword`, Firebase Auth (+
      `firebase_core`/`firebase_auth`/`firebase_analytics`), `google_sign_in`, e il
      caricamento `.env` non più necessario.
- [ ] Rimuovere la dipendenza `g_recaptcha_v3` (usata solo in `lib/screen/register_screen.dart`,
      verificato non bloccare la build nativa — rimandata qui dalla Fase 1 perché legata al
      login, non ai widget dell'editor).
- [ ] **Rimuovere** `lib/network/` (`rest_apis.dart`, `network_utils.dart`, `auth_service.dart`) e
      i modelli di risposta backend ora inutilizzati (`lib/model/*_response.dart`, ecc.).
- **Verifica:** l'app parte direttamente sulla schermata progetti; nessun riferimento a rete nel
      codebase (`grep` di `http`/`rest_apis` a zero).

### Fase 5 — Media ed export codice in locale
**Scopo:** eliminare gli ultimi due punti di dipendenza backend.
- [ ] **Media**: sostituire upload/lista media remoti con copia dei file immagine nella cartella
      del progetto (`media/`) e riferimenti relativi; adattare `media_component.dart`. Include la
      rimozione della dipendenza `image_picker_web` (rimandata qui dalla Fase 1, non bloccava la
      build nativa ma è comunque web-only) in favore di `image_picker`/`file_picker` (già dipendenze).
- [ ] **Export codice**: rimpiazzare `downloadProjectLatestApi()` (zip lato server) con
      generazione locale — riusare `viewFinalSourceData()` per il contenuto e creare lo zip in
      locale (aggiungere `archive`) salvandolo con `file_picker` (Salva con nome).
- **Verifica:** import di un'immagine e uso in un widget; export progetto produce uno zip Dart
      valido su disco senza rete.

### Fase 6 — Rifinitura, packaging, pulizia
- [ ] **Rimuovere l'area admin** `lib/adminDashboard/` e i suoi modelli/riferimenti (decisione presa).
- [ ] Rimuovere altro codice morto (analytics/`AnalyticsService`, modelli backend residui).
- [ ] Aggiornare `README.md`/`CLAUDE.md`: istruzioni build/run desktop, formato cartella-progetto.
- [ ] Packaging: eseguibili/installer Windows (`flutter build windows`) e Linux
      (`flutter build linux`, valutare AppImage/Flatpak).
- [ ] `flutter analyze` e `flutter test` puliti.

---

## 4. Decisioni prese
1. **Formato progetto → cartella per progetto** (`project.json` + `media/` + `export/`). Vedi §2.1.
2. **Area admin → rimossa** del tutto (Fase 6).
3. **Widget web-only → rimossi** (mappa/YouTube/video/audio), con appunto di reintroduzione in §6.
4. **Livello di rete → rimosso** del tutto (`lib/network/`, Firebase, auth). Nessun backend opzionale.

## 5. Rischi principali
- ~~Compilazione desktop bloccata dai plugin web-only~~ → **risolto in Fase 1** (`google_maps`,
  `youtube_player_iframe`, `just_audio`, `video_player`, `web` rimossi; `dart:html` isolato dietro
  import condizionale). `flutter build windows` verificato pulito.
- Coerenza del formato `screenJsonData` tra versioni: introdurre `formatVersion` da subito.
- La rimozione di rete/admin/widget tocca molti file: procedere per fasi con `flutter analyze` a
  ogni step per intercettare riferimenti pendenti.
- `flutter build linux` non ancora verificato in questa sessione (nessun host Linux disponibile) —
  da testare appena possibile, potrebbero emergere blocchi analoghi specifici di quel target.

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
