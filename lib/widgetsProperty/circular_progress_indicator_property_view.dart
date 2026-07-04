import 'package:flutter_viz/main.dart';
import 'package:flutter_viz/utils/AppConstant.dart';
import 'package:flutter_viz/utils/AppFunctions.dart';
import 'package:flutter_viz/utils/AppWidget.dart';
import 'package:flutter_viz/widgetsClass/circular_progress_indicator_class.dart';
import 'package:flutter_viz/widgetsProperty/comman_property_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nb_utils/nb_utils.dart';

class CircularProgressIndicatorPropertyView extends StatefulWidget {
  static String tag = '/CircularProgressIndicatorPropertyView';

  @override
  CircularProgressIndicatorPropertyViewState createState() => CircularProgressIndicatorPropertyViewState();
}

class CircularProgressIndicatorPropertyViewState extends State<CircularProgressIndicatorPropertyView> {
  var circularProgressIndicatorClass;
  TextEditingController? strokeWidthController;

  init() async {
    circularProgressIndicatorClass = appStore.currentSelectedWidget!.widgetViewModel as CircularProgressIndicatorClass?;
    strokeWidthController = TextEditingController(text: circularProgressIndicatorClass.strokeWidth != null ? circularProgressIndicatorClass.strokeWidth.toString() : "");
  }

  @override
  Widget build(BuildContext context) {
    init();
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExpansionTileView(
          language!.padding,
          context,
          <Widget>[
            paddingView(
              padding: circularProgressIndicatorClass.padding,
              onPaddingChanged: (l, t, r, b) {
                circularProgressIndicatorClass.padding = EdgeInsets.fromLTRB(l, t, r, b);
                appStore.updateData(circularProgressIndicatorClass);
              },
            ),
          ],
        ),
        ExpansionTileView(
          language!.alignment,
          context,
          <Widget>[
            alignView(
              isAlignX: circularProgressIndicatorClass.isAlignX,
              isAlignY: circularProgressIndicatorClass.isAlignY,
              alignX: circularProgressIndicatorClass.horizontalAlignment ?? 0,
              alignY: circularProgressIndicatorClass.verticalAlignment ?? 0,
              onAlignChanged: (h, v) {
                circularProgressIndicatorClass.horizontalAlignment = h;
                circularProgressIndicatorClass.verticalAlignment = v;
                appStore.updateData(circularProgressIndicatorClass);
              },
              isAlignXChanged: (value) {
                circularProgressIndicatorClass.isAlignX = value;
                appStore.updateData(circularProgressIndicatorClass);
                appStore.setIsAlignX(value);
              },
              isAlignYChanged: (value) {
                circularProgressIndicatorClass.isAlignY = value;
                appStore.updateData(circularProgressIndicatorClass);
                appStore.setIsAlignY(value);
              },
            ),
          ],
        ),
        ExpansionTileView(
          language!.expandedAndFlex,
          context,
          <Widget>[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                checkBoxView(
                  circularProgressIndicatorClass.isExpanded ?? updateIsExpanded(),
                  language!.expanded,
                  onChanged: (value) {
                    if (getIsExpanded(value).isExpanded!) {
                      circularProgressIndicatorClass.isExpanded = value;
                      appStore.updateData(circularProgressIndicatorClass);
                      setState(() {});
                    } else {
                      getSnackBarWidget(getIsExpanded(value).message!);
                    }
                  },
                ),
                Container(
                  width: widthPropertySize,
                  child: getTextField(
                    controller: TextEditingController(text: circularProgressIndicatorClass.flex != null ? circularProgressIndicatorClass.flex.toString() : DEFAULT_FLEX.toString()),
                    textAlign: TextAlign.center,
                    inputFormatter: <TextInputFormatter>[
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    onChanged: (s) {
                      circularProgressIndicatorClass.flex = int.tryParse(s);
                      appStore.updateData(circularProgressIndicatorClass);
                    },
                    maxLength: commonMaxLength,
                  ),
                ).visible(circularProgressIndicatorClass.isExpanded ?? (appStore.currentSelectedWidget!.parentWidgetType == WidgetTypeColumn ? true : false)),
              ],
            ),
          ],
        ).visible(appStore.currentSelectedWidget!.parentWidgetType == WidgetTypeRow),
        ExpansionTileView(
          language!.value,
          context,
          <Widget>[
            Container(
              width: widthPropertySize,
              child: getTextField(
                  controller: TextEditingController(
                    text: circularProgressIndicatorClass.progressValue != null ? circularProgressIndicatorClass.progressValue.toString() : DEFAULT_PROGRESS_VALUE.toString(),
                  ),
                  textAlign: TextAlign.center,
                  inputFormatter: <TextInputFormatter>[
                    FilteringTextInputFormatter.allow(RegExp('[0-9 .]')),
                  ],
                  onChanged: (value) {
                    if (value.isEmpty) {
                      circularProgressIndicatorClass.progressValue = DEFAULT_PROGRESS_VALUE;
                      appStore.updateData(circularProgressIndicatorClass);
                    } else if (double.parse(value) >= 0.0 && double.parse(value) <= 1.0) {
                      circularProgressIndicatorClass.progressValue = double.parse(value);
                      appStore.updateData(circularProgressIndicatorClass);
                    } else {
                      getToast(language!.progressbarValueMsg);
                    }
                  }),
            ),
          ],
        ),
        ExpansionTileView(
          "Stroke Width",
          context,
          <Widget>[
            Container(
              width: widthPropertySize,
              child: getTextField(
                controller: strokeWidthController,
                textAlign: TextAlign.start,
                maxLength: commonMaxLength,
                inputFormatter: <TextInputFormatter>[
                  FilteringTextInputFormatter.allow(RegExp('[0-9 .]')),
                ],
                onChanged: (value) {
                  if (value.isEmpty) {
                    circularProgressIndicatorClass.strokeWidth = DEFAULT_PROGRESS_STROKE_WIDTH;
                    appStore.updateData(circularProgressIndicatorClass);
                  } else if (double.parse(value) > 0.0) {
                    circularProgressIndicatorClass.strokeWidth = double.parse(value);
                    appStore.updateData(circularProgressIndicatorClass);
                  } else {
                    getToast(language!.progressbarHeightMsg);
                  }
                },
              ),
            ),
          ],
        ),
        ExpansionTileView(
          language!.backgroundColor,
          context,
          <Widget>[
            ColorView(
              color: circularProgressIndicatorClass.backgroundColor ?? DEFAULT_PROGRESSBAR_BACKGROUND_COLOR,
              applyColor: () {
                circularProgressIndicatorClass.backgroundColor = appStore.color;
                setState(() {});
                appStore.updateData(circularProgressIndicatorClass);
              },
              pickColor: () {
                showColorPicker(context, circularProgressIndicatorClass.backgroundColor ?? DEFAULT_PROGRESSBAR_BACKGROUND_COLOR, applyOnWidget: (color) {
                  circularProgressIndicatorClass.backgroundColor = color;
                  setState(() {});
                  appStore.updateData(circularProgressIndicatorClass);
                });
              },
            ),
          ],
        ),
        ExpansionTileView(
          language!.valueColor,
          context,
          <Widget>[
            ColorView(
              color: circularProgressIndicatorClass.valueColor ?? COMMON_BG_COLOR,
              applyColor: () {
                circularProgressIndicatorClass.valueColor = appStore.color;
                setState(() {});
                appStore.updateData(circularProgressIndicatorClass);
              },
              pickColor: () {
                showColorPicker(context, circularProgressIndicatorClass.valueColor ?? COMMON_BG_COLOR, applyOnWidget: (color) {
                  circularProgressIndicatorClass.valueColor = color;
                  setState(() {});
                  appStore.updateData(circularProgressIndicatorClass);
                });
              },
            ),
          ],
        ),
      ],
    );
  }
}
