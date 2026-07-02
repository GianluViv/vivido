import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter_viz/local_storage/project.dart';
import 'package:flutter_viz/model/screen_list_response.dart';
import 'package:path/path.dart' as p;
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

  /// Root folder for app-level data — the recent-projects index
  /// (`<AppData>/FlutterViz`). Kept separate from [defaultProjectsDirectory]:
  /// this is internal bookkeeping, not something the user browses to.
  Future<Directory> get appDataDirectory async {
    if (_appDataDirectoryOverride != null) return _appDataDirectoryOverride!;
    final supportDir = await getApplicationSupportDirectory();
    return Directory(p.join(supportDir.path, 'FlutterViz'));
  }

  /// Redirects [appDataDirectory] and [defaultProjectsDirectory] to a
  /// test-controlled folder instead of the real OS locations (which need
  /// platform channel mocking).
  void setAppDataDirectoryForTesting(Directory directory) {
    _appDataDirectoryOverride = directory;
  }

  Directory get _userHomeDirectory {
    final home = Platform.isWindows ? Platform.environment['USERPROFILE'] : Platform.environment['HOME'];
    return Directory(home ?? Directory.current.path);
  }

  /// Folder proposed when creating a new project — `<user home>/FlutterViz`,
  /// so it's easy for the user to find rather than buried under AppData.
  /// Always overridable per-project via [newProject]'s `location` parameter.
  Future<Directory> get defaultProjectsDirectory async {
    if (_appDataDirectoryOverride != null) return Directory(p.join(_appDataDirectoryOverride!.path, 'projects'));
    return Directory(p.join(_userHomeDirectory.path, 'FlutterViz'));
  }

  Future<File> _recentIndexFile() async {
    final root = await appDataDirectory;
    return File(p.join(root.path, 'recent.json'));
  }

  /// Creates `<location>/<name>/` with `project.json`, `media/` and `export/`.
  Future<Project> newProject(String name, {Directory? location}) async {
    final baseDir = location ?? await defaultProjectsDirectory;
    final projectDir = Directory(p.join(baseDir.path, _sanitizeFolderName(name)));
    if (await projectDir.exists()) {
      throw StateError('Esiste già un progetto in ${projectDir.path}');
    }
    final project = Project(name: name, directory: projectDir);
    await saveProject(project);
    return project;
  }

  Future<Project> openProject(Directory dir) async {
    final file = File(p.join(dir.path, 'project.json'));
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

  /// Removes a project from the recent-projects index without touching its files on disk.
  Future<void> removeRecent(String path) async {
    final entries = await listRecentProjects();
    entries.removeWhere((e) => e.path == path);
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
    final destination = File(p.join(project.mediaDirectory.path, fileName));
    await source.copy(destination.path);
    final relativePath = 'media/$fileName';
    project.media.add(ProjectMediaItem(name: fileName, path: relativePath));
    await saveProject(project);
    return relativePath;
  }

  /// Removes a media file from `<project>/media/` and its `project.json` entry.
  Future<void> deleteMedia(Project project, String relativePath) async {
    final file = File(p.normalize(p.join(project.directory.path, relativePath)));
    if (await file.exists()) await file.delete();
    project.media.removeWhere((m) => m.path == relativePath);
    await saveProject(project);
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

  // ---------------------------------------------------------------------
  // .fwz archive — single-file export/import of a project folder, layered
  // on top of the folder-based storage above.
  // ---------------------------------------------------------------------

  /// Zips [project]'s folder (project.json, media/, export/) into a single
  /// `.fwz` file at [destination].
  Future<void> exportToFwz(Project project, File destination) async {
    final archive = Archive();
    await for (final entity in project.directory.list(recursive: true)) {
      if (entity is! File) continue;
      final relativePath = p.relative(entity.path, from: project.directory.path);
      final entryName = p.split(relativePath).join('/');
      final bytes = await entity.readAsBytes();
      archive.addFile(ArchiveFile(entryName, bytes.length, bytes));
    }
    final zipBytes = ZipEncoder().encode(archive);
    await destination.parent.create(recursive: true);
    await destination.writeAsBytes(zipBytes);
  }

  /// Extracts a `.fwz` archive into a new folder under [parentDir] (named
  /// after the archive file, deduplicated if that name is already taken)
  /// and opens the resulting project.
  Future<Project> importFwz(File fwzFile, Directory parentDir) async {
    final archive = ZipDecoder().decodeBytes(await fwzFile.readAsBytes());

    final baseName = _sanitizeFolderName(p.basenameWithoutExtension(fwzFile.path));
    var targetDir = Directory(p.join(parentDir.path, baseName));
    var index = 1;
    while (await targetDir.exists()) {
      targetDir = Directory(p.join(parentDir.path, '$baseName ($index)'));
      index++;
    }
    await targetDir.create(recursive: true);

    for (final entry in archive.files) {
      if (!entry.isFile) continue;
      final outputFile = File(p.joinAll([targetDir.path, ...p.posix.split(entry.name)]));
      await outputFile.parent.create(recursive: true);
      await outputFile.writeAsBytes(entry.content as List<int>);
    }

    return openProject(targetDir);
  }
}
