import 'dart:convert';
import 'dart:io';

import 'package:flutter_viz/components/add_page_dialog.dart';
import 'package:flutter_viz/externalClasses/on_hover.dart';
import 'package:flutter_viz/local_storage/local_project_service.dart';
import 'package:flutter_viz/main.dart';
import 'package:flutter_viz/model/download_model.dart';
import 'package:flutter_viz/model/screen_list_response.dart';
import 'package:flutter_viz/screen/preview_screen.dart';
import 'package:flutter_viz/screen/welcome_screen.dart';
import 'package:flutter_viz/utils/AppColors.dart';
import 'package:flutter_viz/utils/AppCommon.dart';
import 'package:flutter_viz/utils/AppCommonApiCall.dart';
import 'package:flutter_viz/utils/AppConstant.dart';
import 'package:flutter_viz/utils/AppFunctions.dart';
import 'package:flutter_viz/utils/AppWidget.dart';
import 'package:flutter_viz/widgets/screen_json_parser_class.dart';
import 'package:flutter_viz/widgets/widgets.dart';
import 'package:flutter_viz/widgetsProperty/comman_property_view.dart';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_svg/svg.dart';
import 'package:lottie/lottie.dart';
import 'package:nb_utils/nb_utils.dart';

class HeaderComponent extends StatefulWidget {
  @override
  _HeaderComponentState createState() => _HeaderComponentState();
}

class _HeaderComponentState extends State<HeaderComponent> {
  TextEditingController screenController = TextEditingController();
  bool isDarkMode = appStore.isDarkMode;

  /// Generates the Dart source for every screen, zips it and lets the user
  /// save the archive wherever they like — local equivalent of the old
  /// server-side `downloadProjectLatestApi()` zip download.
  Future<void> downloadProjectLatest() async {
    final project = appStore.currentProject;
    if (project == null) return;
    appStore.setProjectDownloading(true);
    List<Map> contents = [];

    await Future.forEach<ScreenListData>(appStore.screenList, (element) async {
      appStore.codeViewData.clear();
      appStore.headerImport.clear();
      appStore.yamlImportLib.clear();

      DownloadModel aDownloadModel = await applyScreenJsonToView(element.screenJsonData, isForDownload: true);
      aDownloadModel.fileName = element.name;
      List<String> filesContent = await viewFinalSourceData(aDownloadModel.selectedWidgetList, downloadModel: aDownloadModel);

      String codeContent = "";

      for (int i = 0; i < filesContent.length; i++) {
        codeContent = codeContent + filesContent[i];
      }

      contents.add({
        'file_name': "${getFileName(projectFileName: aDownloadModel.fileName)}.dart",
        'file_content': codeContent,
      });
    });

    /// Other Files
    if (appStore.headerImport.length > 0) {
      await Future.forEach<String>(appStore.headerImport, (element) async {
        String fileName = element.replaceAll("import ", "").replaceAll("'", "").replaceAll(";", "");
        String fileContent = await loadFileContent(fileName);

        fileContent = fileContent.replaceAll("package:flutter_viz/externalClasses/", '');

        contents.add({
          'file_name': fileName,
          'file_content': fileContent,
        });
      });
    }

    try {
      final archive = Archive();
      for (final file in contents) {
        final bytes = utf8.encode(file['file_content'] as String);
        archive.addFile(ArchiveFile(file['file_name'] as String, bytes.length, bytes));
      }
      final zipBytes = ZipEncoder().encode(archive);

      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: language!.downloadProject,
        fileName: "${getFileName(projectFileName: project.name)}.zip",
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );
      appStore.setProjectDownloading(false);
      if (savePath == null) return;

      final outputPath = savePath.endsWith('.zip') ? savePath : '$savePath.zip';
      await File(outputPath).writeAsBytes(zipBytes);
      trackUserEvent(DOWNLOAD_PROJECT_CODE);
      getToast("Exported to $outputPath");
    } catch (e) {
      appStore.setProjectDownloading(false);
      log("project export failed: $e");
      getToast(e.toString());
    }
  }

  /// Zips the whole project folder (project.json, media/, export/) into a
  /// single `.fwz` file wherever the user picks — the local counterpart to
  /// [downloadProjectLatest], which only zips the generated Dart source.
  Future<void> exportProjectAsFwz() async {
    final project = appStore.currentProject;
    if (project == null) return;
    try {
      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: "Export Project",
        fileName: "${getFileName(projectFileName: project.name)}.fwz",
        type: FileType.custom,
        allowedExtensions: ['fwz'],
      );
      if (savePath == null) return;

      final outputPath = savePath.endsWith('.fwz') ? savePath : '$savePath.fwz';
      await locator<LocalProjectService>().exportToFwz(project, File(outputPath));
      getToast("Exported to $outputPath");
    } catch (e) {
      log("project .fwz export failed: $e");
      getToast(e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Observer(builder: (_) {
      return Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(color: context.scaffoldBackgroundColor),
        child: (appStore.selectedMenu == SCREEN_LIST_INDEX || appStore.selectedMenu == WIDGETS_INDEX || appStore.selectedMenu == TREE_INDEX || appStore.selectedMenu == PRE_COMPONENTS_INDEX)
            ? Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  getHeaderLogoImage(),
                  16.width,
                  Row(
                          children: [
                            OnHover(builder: (isHovered) {
                              return elevationButtonHighLightColor(
                                isHovered: isHovered,
                                child: highLightIcon(isHovered, icon: Icons.add),
                                toolTipMessage: language!.createPage,
                                onPressed: () async {
                                  trackUserEvent(VIEW_TEMPLATES);
                                  await showInDialog(
                                    context,
                                    contentPadding: EdgeInsets.all(30),
                                    backgroundColor: context.scaffoldBackgroundColor,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(COMMON_CARD_BORDER_RADIUS),
                                    ),
                                    builder: (context) => AddPageDialog(),
                                  );
                                },
                              );
                            }),
                            16.width,
                            OnHover(builder: (isHovered) {
                              return Observer(
                                builder: (_) => elevationButtonHighLightColor(
                                  isHovered: isHovered,
                                  child: (appStore.isProjectDownloading)
                                      ? Container(
                                          width: 25,
                                          height: 25,
                                          child: Lottie.asset('images/loader.json').center(),
                                        ).visible(appStore.isProjectDownloading)
                                      : highLightIcon(isHovered, icon: Icons.download),
                                  toolTipMessage: (appStore.isProjectDownloading) ? language!.downloadingInProgress : language!.downloadProject,
                                  onPressed: () async {
                                    if (appStore.isProjectDownloading) {
                                      getToast(language!.downloadingInProgress);
                                    } else {
                                      downloadProjectLatest();
                                    }
                                  },
                                ),
                              );
                            }),
                            16.width,
                            OnHover(builder: (isHovered) {
                              return elevationButtonHighLightColor(
                                isHovered: isHovered,
                                child: highLightIcon(isHovered, icon: Icons.archive_outlined),
                                toolTipMessage: "Export Project as .fwz",
                                onPressed: exportProjectAsFwz,
                              );
                            }),
                            16.width,
                          ],
                        ),
                  OnHover(
                    builder: (isHovered) {
                      return elevationButtonWithText(
                        isHovered: isHovered,
                        toolTipMessage: "My Projects",
                        image: 'project_white.svg',
                        title: "My Projects",
                        onPressed: () {
                          appStore.isProjectDownloading = false;
                          WelcomeScreen().launch(getContext, isNewTask: true);
                        },
                      );
                    },
                  ),
                  16.width,
                  OnHover(builder: (isHovered) {
                    return elevationButtonWithIcon(
                      isHovered: isHovered,
                      toolTipMessage: language!.save,
                      icon: Icons.save,
                      title: language!.save,
                      onPressed: () async {
                        if (appStore.isProjectDownloading) {
                          getToast(language!.downloadingInProgress);
                        } else if (appStore.selectedScreenId! > 0) {
                          saveScreenApi();
                        }
                      },
                    );
                  }),
                  16.width,
                  OnHover(builder: (isHovered) {
                    return elevationButtonHighLightColor(
                      isHovered: isHovered,
                      child: SvgPicture.asset(
                        "${WidgetIconPath}preview.svg",
                        color: isHovered
                            ? btnBackgroundColor
                            : appStore.isDarkMode
                                ? Colors.white
                                : btnBackgroundColor,
                        height: btnIconSize,
                        width: btnIconSize,
                      ),
                      toolTipMessage: language!.preview,
                      onPressed: () async {
                        appStore.setPreviewCode(true);
                        PreviewScreen().launch(context);
                      },
                    );
                  }),
                  16.width,
                  darkModeSwitchWidget(),
                ],
              )
            : Row(
                children: [
                  getHeaderLogoImage(),
                  16.width,
                  darkModeSwitchWidget(),
                ],
              ),
      );
    });
  }
}
