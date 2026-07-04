# FlutterViz UI Builder (Open Source)

> **Note:** This is a fork of FlutterViz targeting a **fully local desktop app** (Linux/Windows) —
> no login, no backend, no Firebase. Projects are stored as plain folders on disk. See
> [docs/local-desktop-plan.md](docs/local-desktop-plan.md) for the full migration write-up and
> [CLAUDE.md](CLAUDE.md) for codebase notes. The original web/backend-connected version this was
> forked from lives on the [`backend` branch](https://github.com/iqonic-design/flutter_viz/tree/backend)
> of the upstream repository.

**FlutterViz** is a visual UI builder built using Flutter. It lets you design Flutter UIs with a
drag-and-drop interface and export clean Dart code — running entirely as a **local desktop app**,
with no login, backend or cloud.

> 🚀 This open-source project aims to empower developers by providing a free and extensible visual Flutter UI builder.

---

## ✨ Features

- 🔧 **Drag-and-drop editor** to build Flutter UIs visually
- 📦 50+ Built-in Flutter widgets
- 🎨 Real-time property customization (padding, color, font, etc.)
- 💾 Export clean, readable, and production-ready Dart code (zipped)
- 🗂️ **Local, multi-page projects** saved as plain folders on disk — no login, no cloud
- 📄 **Page template library** — 10 built-in starter pages (Login, Register, Welcome, Profile,
  Settings, List, Detail, …), a theme/color picker to recolor them, and "save as template" for
  your own reusable pages
- 📦 **Single-file project export/import** via the `.fwz` format (share a whole project as one file)
- 🤖 **AI-assisted editing** — an embedded terminal panel runs [Claude Code](https://claude.com/claude-code)
  inside the project folder and can edit the current screen for you (see below)
- 🖥️ **Desktop-first** (Linux/Windows); web remains a secondary target

---

## 🤖 AI-assisted editing ("IA" panel)

The left-hand **IA** panel embeds a real terminal (via `xterm` + `flutter_pty`) that opens a shell
in the current project's folder, so you can run [Claude Code](https://claude.com/claude-code) —
or any CLI — without leaving the app. It also drives a file-based round-trip so the AI can edit the
screen you're looking at:

1. **Prepara** writes the current screen's widget tree to `<project>/ai/<screen>.json` (pretty-printed)
   plus a `CLAUDE.md` describing the JSON format.
2. You run `claude` in the embedded terminal and ask it to change that JSON file.
3. **Ricarica** reads the file back, applies it to the live preview and persists it.

Claude only ever edits the separate `ai/…json` file (never `project.json` directly), so the app's
30-second autosave never clobbers the AI's work. Using this panel requires the `claude` CLI to be
installed and available on your `PATH`.

---

## 🔧 Installation

### 🚀 Run Locally

1. **Clone the repository**

```bash
git clone https://github.com/GianluViv/flutter_viz.git
cd flutter_viz
```

2. **Install dependencies**

```bash
flutter pub get
```

3. **Run the desktop app** (no `.env`, no login, no backend needed — the app boots straight into
   project selection):

```bash
flutter run -d linux    # or: flutter run -d windows
```

No environment variables or `.env` file are required in this fork — the previous `BASE_URL`/
`CAPTACHA_*`/`INVITE_CODE` keys only existed to talk to the (now removed) backend.

### 📁 Project storage

Projects are plain folders on disk (no cloud account, no server) — see
[docs/local-desktop-plan.md](docs/local-desktop-plan.md#21-formato-progetto--cartella-per-progetto-deciso)
for the exact format:

```
<ProjectName>/
 ├─ project.json   # project metadata + all screens (widget-tree JSON)
 ├─ media/         # images imported into the project
 ├─ export/        # generated Dart source written by "Export Dart code"
 └─ ai/            # per-screen JSON handed to the AI panel (created on demand)
```

New projects are created under the OS-standard app-data directory by default (via
`path_provider`), or in any folder you pick with "Open Project".

### 📤 Exporting & sharing

- **Export Dart code** — generates the Flutter source for every screen and lets you save it as a
  `.zip` (via the `archive` package).
- **Export Project as `.fwz`** — packs the whole project folder (screens + media) into a single
  `.fwz` file you can share; import it back from the welcome screen with **Import `.fwz` Project**.

---

## 🤝 Contributing

We welcome contributions from everyone! Whether you're fixing bugs, improving documentation, or adding new features — your help is appreciated.

### 📌 Getting Started

1. **Fork the repository** to your GitHub account.

2. **Clone your forked repository**:

    ```bash
    git clone https://github.com/your-username/flutter_viz.git
    cd flutter_viz
    ```

3. **Create a new branch** with a descriptive name:

    ```bash
    git checkout -b feature/your-feature-name
    ```

4. **Make your changes**, then commit:

    ```bash
    git add .
    git commit -m "Add: Short description of your feature"
    ```

5. **Push to your forked repository**:

    ```bash
    git push origin feature/your-feature-name
    ```

> ✨ **Tip:** Keep your pull requests focused. Submit separate PRs for unrelated features or fixes.

### 🐛 Creating Issues

Found a bug? Have a feature request?

1. Go to the [Issues](https://github.com/GianluViv/flutter_viz/issues) tab.
2. Click **New Issue**.
3. Choose the relevant template (e.g., Bug Report, Feature Request).
4. Fill in the details clearly and concisely.

We use labels to organize and prioritize — be sure to use appropriate tags when possible.

### 📤 Submitting Pull Requests

Before submitting a pull request:

1. **Ensure your branch is up to date** with the latest `main`:

    ```bash
    git pull origin main
    ```

2. **Test your changes** and ensure they meet the project's coding standards.
3. **Create a pull request**:
   * Push your branch to GitHub
   * Navigate to the original repo
   * Click **Compare & pull request**
   * Add a **clear title and description** explaining your changes
4. **Reference related issues**, if any:

    ```
    Closes #issue-number
    ```

Our team will review your PR and provide feedback or suggestions. Please be responsive and respectful during the review process.

> ⭐ If you find this project useful, don't forget to **star** the repo and **share** it!
