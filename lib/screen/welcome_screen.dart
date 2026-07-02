import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_viz/components/create_project_dialog.dart';
import 'package:flutter_viz/components/welcome_screen_component.dart';
import 'package:flutter_viz/local_storage/local_project_service.dart';
import 'package:flutter_viz/main.dart';
import 'package:flutter_viz/screen/dashboard_screen.dart';
import 'package:flutter_viz/screen/mobile_view_screen.dart';
import 'package:flutter_viz/utils/AppColors.dart';
import 'package:flutter_viz/utils/AppConstant.dart';
import 'package:flutter_viz/utils/AppFunctions.dart';
import 'package:flutter_viz/utils/AppWidget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:nb_utils/nb_utils.dart';

class WelcomeScreen extends StatefulWidget {
  static String tag = '/WelcomeScreen';

  @override
  WelcomeScreenState createState() => WelcomeScreenState();
}

class WelcomeScreenState extends State<WelcomeScreen> {
  List<RecentProjectEntry> recentProjectList = [];

  @override
  void initState() {
    super.initState();
    init();
  }

  Future<void> init() async {
    await loadRecentProjects();
  }

  /// Reads the local "recent projects" index instead of calling getUserProjectList().
  Future<void> loadRecentProjects() async {
    appStore.setLoading(true);
    List<RecentProjectEntry> entries = await locator<LocalProjectService>().listRecentProjects();
    appStore.setLoading(false);
    recentProjectList.clear();
    recentProjectList.addAll(entries);
    setState(() {});
  }

  Future<void> openProjectFromFolder() async {
    String? path = await FilePicker.platform.getDirectoryPath(dialogTitle: "Select Project Folder");
    if (path == null) return;
    try {
      final project = await locator<LocalProjectService>().openFromPath(path);
      appStore.loadProject(project);
      appStore.selectedMenu = WIDGETS_INDEX;
      DashboardScreen().launch(context, isNewTask: true);
    } catch (e) {
      getToast(e.toString());
    }
  }

  /// Extracts a `.fwz` archive (see [LocalProjectService.importFwz]) into
  /// this machine's default projects folder and opens it.
  Future<void> importProjectFromFwz() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: "Select .fwz Project File",
      type: FileType.custom,
      allowedExtensions: ['fwz'],
    );
    final path = result?.files.single.path;
    if (path == null) return;
    try {
      appStore.setLoading(true);
      final service = locator<LocalProjectService>();
      final project = await service.importFwz(File(path), await service.defaultProjectsDirectory);
      appStore.setLoading(false);
      appStore.loadProject(project);
      appStore.selectedMenu = WIDGETS_INDEX;
      DashboardScreen().launch(context, isNewTask: true);
    } catch (e) {
      appStore.setLoading(false);
      getToast(e.toString());
    }
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    return Observer(builder: (_) {
      return Scaffold(
        backgroundColor: context.scaffoldBackgroundColor,
        body: Responsive(
          mobile: MobileViewScreen(),
          web: Stack(
            children: [
              Column(
                children: [
                  Container(
                    alignment: Alignment.center,
                    margin: EdgeInsets.all(16),
                    child: Row(
                      children: [
                        getHeaderLogoImage(),
                        darkModeSwitchWidget(),
                      ],
                    ),
                  ),
                  Container(
                    color: appStore.isDarkMode ? darkModeSecondaryBackgroundDark : centerBackgroundColor,
                    width: context.width(),
                    height: context.height() - 85,
                    padding: EdgeInsets.all(30),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Align(
                          alignment: Alignment.topRight,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              elevationButtonWithIcon(
                                toolTipMessage: "Open Project",
                                title: "Open Project",
                                icon: Icons.folder_open,
                                onPressed: openProjectFromFolder,
                              ),
                              16.width,
                              elevationButtonWithIcon(
                                toolTipMessage: "Import .fwz Project",
                                title: "Import .fwz",
                                icon: Icons.unarchive_outlined,
                                onPressed: importProjectFromFwz,
                              ),
                              16.width,
                              elevationButtonWithIcon(
                                toolTipMessage: language!.createNewProject,
                                title: language!.createNewProject,
                                icon: Icons.add,
                                onPressed: () async {
                                  await showInDialog(
                                    context,
                                    barrierDismissible: false,
                                    backgroundColor: context.scaffoldBackgroundColor,
                                    contentPadding: EdgeInsets.symmetric(vertical: 30),
                                    builder: (context) => CreateProjectDialog(),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                        30.height,
                        WelcomeScreenComponent(recentProjectList: recentProjectList, onUpdate: loadRecentProjects).expand(),
                      ],
                    ),
                  ),
                ],
              ),
              Align(
                child: noProjectFoundWidget(),
                alignment: Alignment.center,
              ).visible(recentProjectList.isEmpty && !appStore.isLoading),
              loadingAnimation().visible(appStore.isLoading).center(),
            ],
          ),
        ),
      );
    });
  }
}
