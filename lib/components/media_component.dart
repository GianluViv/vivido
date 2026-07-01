import 'dart:io';

import 'package:flutter_viz/local_storage/local_project_service.dart';
import 'package:flutter_viz/model/media_list_model.dart';
import 'package:flutter_viz/utils/AppColors.dart';
import 'package:flutter_viz/utils/AppCommonApiCall.dart';
import 'package:flutter_viz/utils/AppFunctions.dart';
import 'package:flutter_viz/utils/AppWidget.dart';
import 'package:flutter_viz/widgetsProperty/comman_property_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:nb_utils/nb_utils.dart';

import '../main.dart';

class MediaComponent extends StatefulWidget {
  static String tag = '/MediaComponent';

  @override
  MediaComponentState createState() => MediaComponentState();
}

class MediaComponentState extends State<MediaComponent> {
  List<MediaData> mediaList = [];

  @override
  void initState() {
    super.initState();
    init();
  }

  Future<void> init() async {
    await refreshMediaList();
  }

  /// Local equivalent of the old paginated `getMediaList()` REST call — the
  /// current project's `media/` folder is small enough not to need paging.
  Future<void> refreshMediaList() async {
    appStore.setLoading(true);
    await allMediaListApi();
    mediaList = List.of(appStore.mediaList);
    appStore.setLoading(false);
    setState(() {});
  }

  Future<void> deleteMediaApi(MediaData mediaData) async {
    final project = appStore.currentProject;
    if (project == null) return;
    appStore.setLoading(true);
    final relativePath = mediaData.userAttachment!.substring(project.directory.path.length + 1);
    await locator<LocalProjectService>().deleteMedia(project, relativePath);
    await refreshMediaList();
  }

  @override
  void setState(fn) {
    if (mounted) super.setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Stack(
                alignment: Alignment.topLeft,
                children: [
                  Image.asset(
                    'images/flutterviz_bg.jpg',
                    height: 140,
                    width: context.width(),
                    fit: BoxFit.cover,
                  ).cornerRadiusWithClipRRectOnly(bottomLeft: 16, bottomRight: 16),
                  Text("Project Media", style: primaryTextStyle(color: Colors.white, size: 34)).paddingAll(32),
                ],
              ),
              Container(
                transform: Matrix4.translationValues(0, -36, 0),
                width: context.width(),
                height: mediaList.isNotEmpty ? null : context.height() * 0.70,
                decoration: boxDecorationWithRoundedCorners(
                  backgroundColor: appStore.isDarkMode ? darkModePrimaryColorBackground : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: defaultBoxShadow(),
                ),
                margin: EdgeInsets.symmetric(horizontal: 32),
                padding: EdgeInsets.all(30),
                child: Stack(
                  children: [
                    Align(
                      alignment: Alignment.topRight,
                      child: Container(
                        height: 40,
                        width: 200,
                        decoration: boxDecorationWithRoundedCorners(
                          borderRadius: BorderRadius.circular(8),
                          backgroundColor: btnBackgroundColor,
                        ),
                        alignment: AlignmentDirectional.center,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.upload, color: Colors.white),
                            16.width,
                            Text(language!.uploadMedia, style: primaryTextStyle(color: Colors.white, size: 16)),
                          ],
                        ),
                      ).onTap(() async {
                        uploadMedia(
                          context,
                          onUpdate: () {
                            refreshMediaList();
                          },
                        );
                      }),
                    ),
                    mediaList.isNotEmpty
                        ? Wrap(
                            runSpacing: 24,
                            spacing: 24,
                            children: mediaList.map((MediaData mediaData) {
                              return Container(
                                width: context.width() * 0.15,
                                height: 250,
                                padding: EdgeInsets.all(16),
                                decoration: boxDecorationWithRoundedCorners(
                                  boxShadow: defaultBoxShadow(shadowColor: appStore.isDarkMode ? Colors.transparent : Colors.grey.withValues(alpha: 0.3)),
                                  backgroundColor: appStore.isDarkMode ? darkModeSecondaryBackgroundDark : Colors.white,
                                ),
                                child: Column(
                                  children: [
                                    Image.file(
                                      File(mediaData.userAttachment!),
                                      fit: BoxFit.cover,
                                      height: 150,
                                      width: context.width(),
                                    ).cornerRadiusWithClipRRect(COMMON_BUTTON_BORDER_RADIUS),
                                    16.height,
                                    Row(
                                      children: [
                                        Text(
                                          '${mediaData.userAttachment!.split('/').last}',
                                          style: primaryTextStyle(),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ).expand(),
                                        16.width,
                                        deleteIcon(context).onTap(() {
                                          deleteConfirmationDialog(
                                            context: context,
                                            messageText: "Are you sure you want to delete this asset ?",
                                            onAccept: () async {
                                              finish(context);
                                              await deleteMediaApi(mediaData);
                                            },
                                          );
                                        }),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ).paddingOnly(top: 70, bottom: 70)
                        : Text(language!.noDataFound, style: boldTextStyle()).visible(!appStore.isLoading).center(),
                  ],
                ),
              ),
            ],
          ),
        ),
        Observer(builder: (context) => loadingAnimation().visible(appStore.isLoading)).center(),
      ],
    );
  }
}
