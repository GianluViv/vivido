# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project overview

FlutterViz is a visual, drag-and-drop Flutter UI builder built as a Flutter app itself. Users compose screens from a palette of 50+ built-in widgets, tweak properties in a right-hand panel, and export clean, formatted Dart code for the resulting layout.

The upstream (non-fork) backend API for this project lives on a separate `backend` git branch, not in `main`. **This fork no longer uses it at all** — see below.

## Fork goal: local desktop app (no backend) — largely complete

This fork's target direction is to turn FlutterViz into a **fully local desktop app for Linux/Windows** — no login, no remote backend, no Firebase. Multi-page projects are created, saved, and loaded from local disk instead of via REST calls. **Fases 0–5 of this migration are done** (only Fase 6 — packaging/installers and minor residual cleanup — remains); see [docs/local-desktop-plan.md](docs/local-desktop-plan.md) for the full phase-by-phase history and what's left.

What changed from upstream:
- `lib/network/` (REST client), `lib/adminDashboard/`, `LoginScreen`/`RegisterScreen`/`ForgotPasswordScreen`, and Firebase (Auth/Core/Analytics) + `google_sign_in` + `g_recaptcha_v3` + `flutter_dotenv`/`.env` have all been **removed**. The app boots straight into `WelcomeScreen()` (`lib/screen/welcome_screen.dart`) — a local "recent projects / new / open" picker.
- Project/screen persistence is handled by `lib/local_storage/local_project_service.dart` (`LocalProjectService`, registered in `get_it`), which reads/writes a `Project` (`lib/local_storage/project.dart`) as a folder on disk: `<name>/project.json` + `<name>/media/` + `<name>/export/`. `project.json`'s `screens` list reuses the existing `ScreenListData` model — its `screenJsonData` field is exactly the string produced by `widgetClassToJsonData()`/consumed by `applyScreenJsonToView()`, so the widget-tree JSON format itself was never touched by this migration.
- Media (image import) and code export are also fully local: `media_component.dart` copies picked files into `<project>/media/` via `LocalProjectService.importMedia`/`deleteMedia`; `header_component.dart`'s "Download" button zips the generated Dart source (via the `archive` package) and lets you pick a save location with `file_picker`.
- Widgets with no viable desktop-native plugin (Google Map, YouTube/Video/Audio player) were removed entirely rather than stubbed — see §6 of the plan doc for how to reintroduce them.

By contrast, the actual widget-tree editing (drag&drop, property editing, undo/redo, Dart code generation — see the "Widget tree model" and "Per-widget Class pattern" sections below) was already fully client-side and needed no changes to work offline.

## Setup

No `.env` file, Firebase config, or login is needed — the app has no network dependency at all.

## Common commands

```bash
flutter pub get                                                   # install dependencies
flutter run -d linux                                               # run the app on Linux
flutter run -d windows                                             # run the app on Windows
flutter run -d chrome --web-port 5000                              # run the app on web (secondary target in this fork)
flutter packages pub run build_runner build --delete-conflicting-outputs
                                                                    # regenerate MobX code (*.g.dart) after editing any @observable/@action store
flutter analyze                                                    # static analysis (flutter_lints) — use `grep "error •"` (not `grep "^error"`) to check for real errors, see docs/local-desktop-plan.md
flutter test                                                       # run tests (test/local_project_service_test.dart; test/widget_test.dart is a stale default-template test, ignore it)
flutter build linux                                                # Linux desktop build
flutter build windows                                              # Windows desktop build
flutter build web                                                  # web build (secondary target in this fork)
```

Run `build_runner` any time `lib/store/AppStore.dart` (or any other MobX `Store` class) changes — `AppStore.g.dart` is generated and must stay in sync, otherwise the app won't compile.

## Architecture

### Widget tree model (the core data structure)

The screen being edited is represented as a recursive tree of `WidgetModel` (`lib/model/widget_model.dart`). Each node has:
- `widgetType` / `widgetSubType` — tag identifying what kind of widget it is (e.g. `WidgetTypeRow`, `WidgetTypeContainer`, constants defined in `lib/utils/AppConstant.dart`); `widgetType == WidgetTypeNormal` marks leaf/non-container widgets, anything else can have children.
- `subWidgetsList` — child `WidgetModel`s (containers like Row/Column/Stack/ListView/Grid/TabView nest children here).
- `widgetViewModel` — a `dynamic` holding the widget-specific config object (e.g. a `ContainerClass`, `RowClass`, `ColumnClass` instance from `lib/widgetsClass/`).
- `parentWidgetId` / `parentWidgetType` — back-references used for layout decisions (e.g. deciding whether a child should be `Expanded` inside a Row/Column).

This tree round-trips to/from JSON (`toJson`/`fromJson`) for persistence, and is reconstructed via `lib/widgets/screen_json_parser_class.dart`.

### Per-widget "Class" pattern

Every built-in widget type has a matching pair of files:
- `lib/widgetsClass/<widget>_class.dart` — holds the widget's editable properties, JSON (de)serialization, a method that renders the *actual* Flutter `Widget` for live preview (e.g. `getContainerWidget`), and a parallel method that generates the equivalent Dart **source code as a string** for export (e.g. `getCodeAsString` / `getEndCodeAsString`, formatted later with `dart_style`). Keeping the live-render path and the code-generation path in sync inside the same class is the central convention of this codebase — when adding/editing a widget, both must be updated together.
- `lib/widgetsProperty/<widget>_property_view.dart` — the right-side panel UI for editing that widget's properties, which calls into `AppStore.updateData()` to push changes back into the tree.

`lib/widgets/widgets.dart` is the central dispatcher that maps a `WidgetModel`'s `widgetSubType` to the right class for rendering/casting (see `getWidgetCasting` and the large `if/else` chains keyed on `WidgetType*` constants).

### State management (MobX)

A single global `AppStore` instance (`appStore` in `lib/main.dart`, class defined in `lib/store/AppStore.dart` with generated `AppStore.g.dart`) holds all editor state: the current screen's widget tree (`selectedWidgetList`, always a 1-element list wrapping the root), `currentSelectedWidget`, `parentWidgetsList` (breadcrumb of ancestors for the selected node), app bar/bottom nav/drawer widgets, screen list, undo/redo stacks (`undoWidgetsList`/`redoWidgetList`, plain `List<List<WidgetModel>>` snapshots — not the class in `lib/undoRedo/`, which is currently unused), and UI flags (dark mode, selected menu/property tab, etc.).

Most tree mutations (`addChildWidget`, `wrapWidget`, `copyWidget`, `moveWidget`, `removeSelectedWidget`, `updateData`, ...) walk the tree recursively from `selectedWidgetList[0]` to find the node matching `currentSelectedWidget.id`, mutate it in place, then call `refreshMainViewData()` to force MobX to re-emit (it re-inserts the root at index 0) and emits a `LiveStream().emit("updateTreeViewComponents")` event to refresh the tree-view UI.

### Editor UI layout

- `lib/components/leftView/` — widget palette and component/screen tree list.
- `lib/components/centerView/` — canvas/preview area where the widget tree is rendered and drag targets live (drop handling in `lib/widgets/on_accept_widgets.dart`).
- `lib/components/rightView/` — property editor panel (dispatches to the appropriate `widgetsProperty` view for `currentSelectedWidget`).
- `lib/components/code_view.dart` / `lib/screen/code_view_screen.dart` — generated Dart code preview, built by walking the tree and concatenating each node's `getCodeAsString`/`getEndCodeAsString`.
- `lib/components/tree_view_components.dart` — the layer/outline tree (built on `flutter_treeview`), kept in sync via the `LiveStream` events above.

### Other areas

- `lib/local_storage/` — `LocalProjectService` (project/screen/media CRUD on disk) and the `Project`/`ProjectMediaItem` models; this is the local replacement for the old `lib/network/` REST client (removed).
- `lib/local/` — localization (`app_localizations.dart`, `languages.dart`); `AppStore.setLanguage` drives the active locale.
- `lib/utils/` — shared helpers: `AppConstant.dart` (widget type/string constants), `AppFunctions.dart` (JSON<->Flutter value conversions like `fromJsonPadding`/`fromJsonColor`), `AppColors.dart`, `AppTheme.dart`, `AppCommon.dart`/`AppCommonApiCall.dart` (now local-only, no REST calls), `syntax_highlighter.dart` (for the code view).
