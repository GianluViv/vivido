import 'dart:convert';

import 'package:flutter_viz/local_storage/local_project_service.dart';
import 'package:flutter_viz/model/screen_list_response.dart';
import 'package:flutter_viz/utils/AppConstant.dart';
import 'package:flutter_viz/utils/AppFunctions.dart';
import 'package:flutter_viz/utils/AppWidget.dart';
import 'package:flutter_viz/widgets/screen_json_parser_class.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:nb_utils/nb_utils.dart';

import '../main.dart';

class AddPageDialog extends StatefulWidget {
  static String tag = '/AddTemplateDialog';

  @override
  AddPageDialogState createState() => AddPageDialogState();
}

class AddPageDialogState extends State<AddPageDialog> {
  final formKey = GlobalKey<FormState>();

  TextEditingController pageNameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    trackScreenView(PRE_BUILD_SCREEN);
  }

  /// Creates a new page in the current local project via LocalProjectService,
  /// replacing the old addScreen() REST call.
  Future<void> addScreenApi({String? rootScreenData}) async {
    if (formKey.currentState!.validate()) {
      hideKeyboard(context);
      formKey.currentState!.save();
      appStore.setLoading(true);

      try {
        final screen = await locator<LocalProjectService>().addScreen(
          appStore.currentProject!,
          name: pageNameController.text,
          screenJsonData: rootScreenData,
        );
        appStore.screenList.add(screen);

        /// Showing added screen data
        appStore.selectedDropdownScreen = appStore.screenList[appStore.screenList.length - 1];
        appStore.setScreenDetails(appStore.screenList[appStore.screenList.length - 1]);
        applyScreenJsonToView(appStore.screenList[appStore.screenList.length - 1].screenJsonData);
        LiveStream().emit(updateScreenList);
        if (rootScreenData != null) {
          Future.delayed(Duration(seconds: 1), () async {
            await updateScreenImageApi(screen);
          });
        } else {
          appStore.setLoading(false);
          finish(context);
        }
      } catch (e) {
        appStore.setLoading(false);
        finish(context);
        getToast(e.toString());
      }
    }
  }

  Future<void> updateScreenImageApi(ScreenListData screen) async {
    screenshotController.capture(delay: Duration(milliseconds: 10)).then((capturedImage) async {
      String screenImage = base64.encode(capturedImage!);
      await locator<LocalProjectService>().updateScreenData(appStore.currentProject!, screen.id!, screenImage: screenImage);
      appStore.setLoading(false);
      finish(context);
      appStore.updateScreenImage(screenImage, appStore.selectedScreenId);
    }).catchError((onError) {
      print(onError);
    });
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
                if (!appStore.isLoading)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(language!.createScreen, style: boldTextStyle(size: 22)),
                          CloseButton(),
                        ],
                      ),
                      8.height,
                      Text(language!.enterScreenText, style: secondaryTextStyle()),
                      16.height,
                      AppTextField(
                        controller: pageNameController,
                        textFieldType: TextFieldType.NAME,
                        decoration: commonInputDecoration(hintName: "Screen Name"),
                        textStyle: primaryTextStyle(),
                        autoFocus: false,
                        maxLines: 1,
                        maxLength: 15,
                        validator: (String? value) {
                          if (value!.isEmpty) return errorThisFieldRequired;
                          return null;
                        },
                        inputFormatters: <TextInputFormatter>[
                          FilteringTextInputFormatter.allow(RegExp("[0-9a-zA-Z]")),
                        ],
                      ),
                      16.height,
                      dialogPrimaryColorButton(
                        text: language!.createNew,
                        onTap: () async {
                          addScreenApi();
                        },
                      ),
                    ],
                  ),
              ],
            ),
          ),
          Observer(builder: (context) => loadingAnimation().visible(appStore.isLoading).center()),
        ],
      ),
    );
  }
}
