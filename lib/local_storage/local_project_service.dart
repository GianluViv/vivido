import 'dart:convert';
import 'dart:io';

import 'package:flutter_viz/local_storage/project.dart';
import 'package:flutter_viz/model/screen_list_response.dart';
import 'package:path_provider/path_provider.dart';

/// Lightweight entry in the "recent projects" index (`<AppData>/FlutterViz/recent.json`).
/// Kept separate from [Project] so listing recent projects never has to open
/// every project.json on disk.
class RecentProjectEntry {
  final String path;
  final String name;
  final DateTime lastOpenedAt;

  RecentProjectEntry({required this.path, required this.name, required this.lastOpenedAt});

  factory RecentProjectEntry.fromJson(Map<String, dynamic> json) {
    return RecentProjectEntry(
      path: json['path'] as String,
      name: json['name'] as String,
      lastOpenedAt: DateTime.tryParse(json['lastOpenedAt'] as String? ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'path': path,
        'name': name,
        'lastOpenedAt': lastOpenedAt.toIso8601String(),
      };
}

/// Replaces the REST-backed project/screen/media persistence
/// (`lib/network/rest_apis.dart`) with local folder storage. See
/// docs/local-desktop-plan.md §2.2 for the design.
class LocalProjectService {
  Directory? _appDataDirectoryOverride;

  /// Root folder for all FlutterViz local data (`<AppData>/FlutterViz`).
  Future<Directory> get appDataDirectory async {
    if (_appDataDirectoryOverride != null) return _appDataDirectoryOverride!;
    final supportDir = await getApplicationSupportDirectory();
    return Directory('${supportDir.path}/FlutterViz');
  }

  /// Redirects [appDataDirectory] to a test-controlled folder instead of the
  /// real OS app-data location (which needs platform channel mocking).
  void setAppDataDirectoryForTesting(Directory directory) {
    _appDataDirectoryOverride = directory;
  }

  Future<Directory> get defaultProjectsDirectory async {
    final root = await appDataDirectory;
    return Directory('${root.path}/projects');
  }

  Future<File> _recentIndexFile() async {
    final root = await appDataDirectory;
    return File('${root.path}/recent.json');
  }

  /// Creates `<location>/<name>/` with `project.json`, `media/` and `export/`.
  Future<Project> newProject(String name, {Directory? location}) async {
    final baseDir = location ?? await defaultProjectsDirectory;
    final projectDir = Directory('${baseDir.path}/${_sanitizeFolderName(name)}');
    if (await projectDir.exists()) {
      throw StateError('Esiste già un progetto in ${projectDir.path}');
    }
    final project = Project(name: name, directory: projectDir);
    await saveProject(project);
    return project;
  }

  Future<Project> openProject(Directory dir) async {
    final file = File('${dir.path}/project.json');
    if (!await file.exists()) {
      throw StateError('Nessun project.json trovato in ${dir.path}');
    }
    final json = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final project = Project.fromJson(json, dir);
    await _touchRecent(project);
    return project;
  }

  Future<Project> openFromPath(String path) => openProject(Directory(path));

  /// Writes `project.json` and ensures `media/`/`export/` exist.
  Future<void> saveProject(Project project) async {
    project.updatedAt = DateTime.now();
    await project.directory.create(recursive: true);
    await project.mediaDirectory.create(recursive: true);
    await project.exportDirectory.create(recursive: true);
    await project.projectFile.writeAsString(jsonEncode(project.toJson()));
    await _touchRecent(project);
  }

  Future<List<RecentProjectEntry>> listRecentProjects() async {
    final file = await _recentIndexFile();
    if (!await file.exists()) return [];
    final list = jsonDecode(await file.readAsString()) as List<dynamic>;
    final entries = list.map((e) => RecentProjectEntry.fromJson(e as Map<String, dynamic>)).toList();
    entries.sort((a, b) => b.lastOpenedAt.compareTo(a.lastOpenedAt));
    return entries;
  }

  Future<void> _touchRecent(Project project) async {
    final entries = await listRecentProjects();
    entries.removeWhere((e) => e.path == project.directory.path);
    entries.insert(0, RecentProjectEntry(path: project.directory.path, name: project.name, lastOpenedAt: DateTime.now()));
    final file = await _recentIndexFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(entries.map((e) => e.toJson()).toList()));
  }

  // ---------------------------------------------------------------------
  // Screen CRUD — mirrors the operations previously done via addScreen()/
  // deleteScreen()/getScreenList() in lib/network/rest_apis.dart.
  // ---------------------------------------------------------------------

  int _nextScreenId(Project project) {
    int maxId = 0;
    for (final screen in project.screens) {
      if ((screen.id ?? 0) > maxId) maxId = screen.id!;
    }
    return maxId + 1;
  }

  Future<ScreenListData> addScreen(Project project, {required String name, String? screenJsonData}) async {
    final now = DateTime.now().toIso8601String();
    final screen = ScreenListData(
      id: _nextScreenId(project),
      name: name,
      screenJsonData: screenJsonData,
      createdAt: now,
      updatedAt: now,
    );
    project.screens.add(screen);
    await saveProject(project);
    return screen;
  }

  Future<void> renameScreen(Project project, int screenId, String newName) async {
    final screen = project.screens.firstWhere((s) => s.id == screenId);
    screen.name = newName;
    await saveProject(project);
  }

  /// Persists new widget-tree JSON (and optionally a thumbnail) for a
  /// screen — the local equivalent of `saveScreenApi()`/`autoSaveData()`.
  Future<void> updateScreenData(Project project, int screenId, {String? screenJsonData, String? screenImage}) async {
    final screen = project.screens.firstWhere((s) => s.id == screenId);
    if (screenJsonData != null) screen.screenJsonData = screenJsonData;
    if (screenImage != null) screen.screenImage = screenImage;
    screen.updatedAt = DateTime.now().toIso8601String();
    await saveProject(project);
  }

  Future<void> deleteScreen(Project project, int screenId) async {
    project.screens.removeWhere((s) => s.id == screenId);
    await saveProject(project);
  }

  Future<ScreenListData> cloneScreen(Project project, int screenId, {String? newName}) async {
    final source = project.screens.firstWhere((s) => s.id == screenId);
    final now = DateTime.now().toIso8601String();
    final clone = ScreenListData(
      id: _nextScreenId(project),
      name: newName ?? '${source.name} copy',
      screenJsonData: source.screenJsonData,
      screenImage: source.screenImage,
      createdAt: now,
      updatedAt: now,
    );
    project.screens.add(clone);
    await saveProject(project);
    return clone;
  }

  // ---------------------------------------------------------------------
  // Media — replaces getMediaList()/usermedia-save (AppCommonApiCall.dart).
  // ---------------------------------------------------------------------

  /// Copies [source] into `<project>/media/` (renaming on collision) and
  /// returns the path relative to the project directory.
  Future<String> importMedia(Project project, File source) async {
    await project.mediaDirectory.create(recursive: true);
    final fileName = _uniqueFileName(project, source.uri.pathSegments.last);
    final destination = File('${project.mediaDirectory.path}/$fileName');
    await source.copy(destination.path);
    final relativePath = 'media/$fileName';
    project.media.add(ProjectMediaItem(name: fileName, path: relativePath));
    await saveProject(project);
    return relativePath;
  }

  String _uniqueFileName(Project project, String fileName) {
    if (!project.media.any((m) => m.name == fileName)) return fileName;
    final dotIndex = fileName.lastIndexOf('.');
    final base = dotIndex == -1 ? fileName : fileName.substring(0, dotIndex);
    final ext = dotIndex == -1 ? '' : fileName.substring(dotIndex);
    var index = 1;
    String candidate;
    do {
      candidate = '$base ($index)$ext';
      index++;
    } while (project.media.any((m) => m.name == candidate));
    return candidate;
  }

  String _sanitizeFolderName(String name) {
    return name.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
  }
}
