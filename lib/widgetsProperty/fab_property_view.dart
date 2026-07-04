import 'dart:convert';
import 'package:flutter_viz/main.dart';
import 'package:flutter_viz/utils/AppConstant.dart';
import 'package:flutter_viz/utils/AppWidget.dart';
import 'package:flutter_viz/widgetsClass/fab_class.dart';
import 'package:flutter_viz/widgetsProperty/comman_property_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:nb_utils/nb_utils.dart';

/// Property editor for the scaffold-slot Floating Action Button. Position is a
/// [FloatingActionButtonLocation] (referred to the page), not a parent-based
/// alignment.
class FabPropertyView extends StatefulWidget {
  @override
  FabPropertyViewState createState() => FabPropertyViewState();
}

class FabPropertyViewState extends State<FabPropertyView> {
  var fabModel;

  static const Map<String, String> _locationLabels = {
    kFabLocationStartTop: 'Alto · Sinistra',
    kFabLocationCenterTop: 'Alto · Centro',
    kFabLocationEndTop: 'Alto · Destra',
    kFabLocationStartFloat: 'Basso · Sinistra (float)',
    kFabLocationCenterFloat: 'Basso · Centro (float)',
    kFabLocationEndFloat: 'Basso · Destra (float)',
    kFabLocationStartDocked: 'Basso · Sinistra (docked)',
    kFabLocationCenterDocked: 'Basso · Centro (docked)',
    kFabLocationEndDocked: 'Basso · Destra (docked)',
  };

  init() async {
    fabModel = appStore.currentSelectedWidget!.widgetViewModel as FabClass?;
  }

  @override
  Widget build(BuildContext context) {
    init();
    return Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExpansionTileView(
          "Posizione",
          context,
          <Widget>[
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: DropdownButton<String>(
                isExpanded: true,
                value: fabModel.location ?? kFabLocationEndFloat,
                underline: SizedBox(),
                items: kFabLocations
                    .map((loc) => DropdownMenuItem<String>(
                          value: loc,
                          child: Text(_locationLabels[loc] ?? loc, style: primaryTextStyle(size: 13)),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    fabModel.location = value;
                    setState(() {});
                    appStore.updateData(fabModel);
                  }
                },
              ),
            ),
          ],
        ),
        ExpansionTileView(
          language!.icon,
          context,
          <Widget>[
            iconPickerView(
              iconDataJson: fabModel.iconDataJson ?? {'iconName': 'add', 'codePoint': 57415, 'fontFamily': 'MaterialIcons'},
              onChanged: (value) {
                var iconDataJson = jsonDecode(value);
                fabModel.iconDataJson = iconDataJson;
                setState(() {});
                appStore.updateData(fabModel);
              },
            ),
          ],
        ),
        ExpansionTileView(
          language!.iconColor,
          context,
          <Widget>[
            ColorView(
              color: fabModel.iconColor ?? Colors.white,
              applyColor: () {
                fabModel.iconColor = appStore.color;
                setState(() {});
                appStore.updateData(fabModel);
              },
              pickColor: () {
                showColorPicker(context, fabModel.iconColor ?? Colors.white, applyOnWidget: (color) {
                  fabModel.iconColor = color;
                  setState(() {});
                  appStore.updateData(fabModel);
                });
              },
            ),
          ],
        ),
        ExpansionTileView(
          language!.backgroundColor,
          context,
          <Widget>[
            ColorView(
              color: fabModel.backgroundColor ?? COMMON_BG_COLOR,
              applyColor: () {
                fabModel.backgroundColor = appStore.color;
                setState(() {});
                appStore.updateData(fabModel);
              },
              pickColor: () {
                showColorPicker(context, fabModel.backgroundColor ?? COMMON_BG_COLOR, applyOnWidget: (color) {
                  fabModel.backgroundColor = color;
                  setState(() {});
                  appStore.updateData(fabModel);
                });
              },
            ),
          ],
        ),
        ExpansionTileView(
          language!.iconSize,
          context,
          <Widget>[
            Container(
              width: widthPropertySize,
              child: getTextField(
                controller: TextEditingController(text: fabModel.iconSize != null ? fabModel.iconSize.toString() : DEFAULT_ICON_SIZE.toString()),
                textAlign: TextAlign.center,
                inputFormatter: <TextInputFormatter>[
                  FilteringTextInputFormatter.allow(RegExp('[0-9 .]')),
                ],
                onChanged: (s) {
                  fabModel.iconSize = s.toString().isNotEmpty ? double.parse(s) : DEFAULT_ICON_SIZE;
                  appStore.updateData(fabModel);
                },
                maxLength: commonMaxLength,
              ),
            ),
          ],
        ),
        ExpansionTileView(
          language!.elevation,
          context,
          <Widget>[
            Container(
              width: widthPropertySize,
              child: getTextField(
                controller: TextEditingController(text: fabModel.elevation != null ? fabModel.elevation.toString() : "6.0"),
                textAlign: TextAlign.center,
                inputFormatter: <TextInputFormatter>[
                  FilteringTextInputFormatter.allow(RegExp('[0-9 .]')),
                ],
                onChanged: (s) {
                  fabModel.elevation = s.toString().isNotEmpty ? double.parse(s) : 6.0;
                  appStore.updateData(fabModel);
                },
                maxLength: commonMaxLength,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
