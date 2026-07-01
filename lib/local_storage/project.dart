import 'dart:io';

import 'package:flutter_viz/model/screen_list_response.dart';

/// Bumped whenever the on-disk `project.json` shape changes in a
/// backwards-incompatible way. See docs/local-desktop-plan.md §2.1.
const int projectFormatVersion = 1;

/// A single media file (image) imported into a project, referenced by a
/// path relative to the project directory (e.g. `media/logo.png`).
class ProjectMediaItem {
  String name;
  String path;

  ProjectMediaItem({required this.name, required this.path});

  factory ProjectMediaItem.fromJson(Map<String, dynamic> json) {
    return ProjectMediaItem(
      name: json['name'] as String,
      path: json['path'] as String,
    );
  }

  Map<String, dynamic> toJson() => {'name': name, 'path': path};
}

/// A FlutterViz project stored as a folder on disk:
/// ```
/// <directory>/
///  ├─ project.json
///  ├─ media/
///  └─ export/
/// ```
/// `screens` reuses the existing [ScreenListData] model — its
/// `screenJsonData` field already holds the exact string produced by
/// `widgetClassToJsonData()` / consumed by `applyScreenJsonToView()`.
class Project {
  int formatVersion;
  String name;
  DateTime createdAt;
  DateTime updatedAt;
  List<ScreenListData> screens;
  List<ProjectMediaItem> media;

  /// Folder this project lives in. Not persisted inside project.json itself
  /// (it's implied by where the file was opened from).
  final Directory directory;

  Project({
    required this.name,
    required this.directory,
    this.formatVersion = projectFormatVersion,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<ScreenListData>? screens,
    List<ProjectMediaItem>? media,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now(),
        screens = screens ?? <ScreenListData>[],
        media = media ?? <ProjectMediaItem>[];

  File get projectFile => File('${directory.path}/project.json');
  Directory get mediaDirectory => Directory('${directory.path}/media');
  Directory get exportDirectory => Directory('${directory.path}/export');

  factory Project.fromJson(Map<String, dynamic> json, Directory directory) {
    return Project(
      name: json['projectName'] as String,
      directory: directory,
      formatVersion: json['formatVersion'] as int? ?? 1,
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] as String? ?? '') ?? DateTime.now(),
      screens: (json['screens'] as List<dynamic>? ?? [])
          .map((e) => ScreenListData.fromJson(e as Map<String, dynamic>))
          .toList(),
      media: (json['media'] as List<dynamic>? ?? [])
          .map((e) => ProjectMediaItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'formatVersion': formatVersion,
        'projectName': name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
        'screens': screens.map((s) => s.toJson()).toList(),
        'media': media.map((m) => m.toJson()).toList(),
      };
}
