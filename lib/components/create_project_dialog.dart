import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_viz/local_storage/local_project_service.dart';
import 'package:flutter_viz/main.dart';
import 'package:flutter_viz/screen/dashboard_screen.dart';
import 'package:flutter_viz/utils/AppConstant.dart';
import 'package:flutter_viz/utils/AppFunctions.dart';
import 'package:flutter_viz/utils/AppWidget.dart';
import 'package:flutter_viz/widgetsProperty/comman_property_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:nb_utils/nb_utils.dart';

class CreateProjectDialog extends StatefulWidget {
  static String tag = '/CreateProjectDialog';

  @override
  CreateProjectDialogState createState() => CreateProjectDialogState();
}

class CreateProjectDialogState extends State<CreateProjectDialog> {
  final formKey = GlobalKey<FormState>();

  TextEditingController projectNameController = TextEditingController();

  /// Default location proposed for the new project (`<user home>/FlutterViz`);
  /// overridden by [selectedLocation] if the user browses to a different folder.
  String defaultLocationPath = '';
  Directory? selectedLocation;

  @override
  void initState() {
    super.initState();
    locator<LocalProjectService>().defaultProjectsDirectory.then((dir) {
      if (mounted) setState(() => defaultLocationPath = dir.path);
    });
  }

  Future<void> pickLocation() async {
    String? path = await FilePicker.platform.getDirectoryPath(dialogTitle: "Select Project Location");
    if (path == null) return;
    setState(() => selectedLocation = Directory(path));
  }

  /// Creates a project folder on disk (project.json + media/ + export/), adds a
  /// default "Home Screen", and jumps straight into the editor.
  Future<void> createProject() async {
    if (!formKey.currentState!.validate()) return;
    hideKeyboard(context);
    formKey.currentState!.save();
    appStore.setLoading(true);

    try {
      final service = locator<LocalProjectService>();
      final project = await service.newProject(projectNameController.text.trim(), location: selectedLocation);
      await service.addScreen(project, name: "Home Screen");
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
    return SizedBox(
      width: 500,
      child: Stack(
        alignment: AlignmentDirectional.center,
        children: [
          Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(language!.createProject, style: boldTextStyle(size: 22)),
                    CloseButton(),
                  ],
                ).paddingSymmetric(horizontal: 30),
                8.height,
                Text(language!.enterProjectText, style: secondaryTextStyle()).paddingSymmetric(horizontal: 30),
                16.height,
                AppTextField(
                  controller: projectNameController,
                  textFieldType: TextFieldType.NAME,
                  decoration: commonInputDecoration(hintName: "Project Name"),
                  textStyle: primaryTextStyle(),
                  autoFocus: false,
                  maxLines: 1,
                  maxLength: 30,
                  validator: (String? value) {
                    if (value!.isEmpty) return errorThisFieldRequired;
                    return null;
                  },
                  inputFormatters: <TextInputFormatter>[
                    FilteringTextInputFormatter.allow(RegExp("[0-9a-zA-Z ]")),
                  ],
                ).paddingSymmetric(horizontal: 30),
                16.height,
                Text("Location", style: secondaryTextStyle()).paddingSymmetric(horizontal: 30),
                8.height,
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: COMMON_BORDER_COLOR, width: 1),
                          borderRadius: BorderRadius.circular(COMMON_BUTTON_BORDER_RADIUS),
                        ),
                        child: Text(
                          selectedLocation?.path ?? defaultLocationPath,
                          style: primaryTextStyle(size: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    8.width,
                    dialogGrayBorderButton(text: "Browse", onTap: pickLocation, width: 90, height: 45),
                  ],
                ).paddingSymmetric(horizontal: 30),
                30.height,
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    dialogGrayBorderButton(
                      text: language!.cancel,
                      onTap: () {
                        finish(context);
                      },
                    ),
                    16.width,
                    dialogPrimaryColorButton(
                      text: language!.createNew,
                      onTap: createProject,
                    ),
                  ],
                ).paddingSymmetric(horizontal: 30),
                16.height,
              ],
            ),
          ),
          Observer(builder: (context) => loadingAnimation().visible(appStore.isLoading)).center(),
        ],
      ),
    );
  }
}
