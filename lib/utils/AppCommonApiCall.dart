import 'dart:convert';
import 'dart:io';

import 'package:flutter_viz/local_storage/local_project_service.dart';
import 'package:flutter_viz/model/media_list_model.dart';
import 'package:flutter_viz/utils/AppFunctions.dart';
import 'package:flutter_viz/widgets/screen_json_parser_class.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../main.dart';
import 'AppConstant.dart';

/// Populates `appStore.mediaList` from the current project's local `media/`
/// folder — the local equivalent of the old `getMediaList()` REST call.
Future<void> allMediaListApi() async {
  final project = appStore.currentProject;
  appStore.mediaList.clear();
  if (project == null) return;
  appStore.mediaList.addAll(project.media.map((m) => MediaData(
        id: project.media.indexOf(m),
        userAttachment: '${project.directory.path}/${m.path}',
      )));
}

/// Copies picked image files into `<project>/media/` via [LocalProjectService]
/// instead of uploading them (local equivalent of the old `usermedia-save` call).
Future uploadMedia(BuildContext context, {required Function() onUpdate}) async {
  final project = appStore.currentProject;
  if (project == null) return;
  final ImagePicker picker = ImagePicker();
  final List<XFile> imageXFiles = await picker.pickMultiImage();
  if (imageXFiles.isEmpty) return;

  appStore.setLoading(true);
  for (final xFile in imageXFiles) {
    await locator<LocalProjectService>().importMedia(project, File(xFile.path));
  }
  appStore.setLoading(false);
  getToast("Media has been added successfully");
  onUpdate.call();
}

/// Local equivalent of the old addScreen() REST save — flushes the current
/// screen to project.json via LocalProjectService (Ctrl+S / header save button).
Future<void> saveScreenApi() async {
  trackUserEvent(SAVE_SCREEN);
  if (appStore.currentProject == null) return;
  Map<String, dynamic> rootScreenDataJson = await widgetClassToJsonData();
  screenshotController.capture(delay: Duration(milliseconds: 10)).then((capturedImage) async {
    String? screenImage;
    if (rootScreenDataJson['widgetsData'].isNotEmpty ||
        rootScreenDataJson['appBarData'].isNotEmpty ||
        rootScreenDataJson['bottomBarNavigationData'].isNotEmpty ||
        rootScreenDataJson['drawerData'].isNotEmpty) {
      screenImage = base64.encode(capturedImage!);
    }
    String screenJsonData = json.encode(rootScreenDataJson);

    await locator<LocalProjectService>().updateScreenData(
      appStore.currentProject!,
      appStore.selectedScreenId!,
      screenJsonData: screenJsonData,
      screenImage: screenImage,
    );
    appStore.updateScreenNewData(screenJsonData, appStore.selectedScreenId);
    appStore.updateScreenImage(screenImage, appStore.selectedScreenId);
    getToast(language!.save);
  }).catchError((onError) {
    print(onError);
  });
}
