import 'package:flutter_viz/widgetsProperty/comman_property_view.dart';
import 'package:flutter/material.dart';

import '../utils/AppCommon.dart';

/// Scaffold-slot model for a Material [FloatingActionButton].
///
/// Unlike a normal tree widget, a FAB belongs to the [Scaffold] and its
/// position is expressed through [FloatingActionButtonLocation] ([location]),
/// referred to the page — not to a parent's layout. Stored on
/// `appStore.fabClass` and rendered in the scaffold's `floatingActionButton`
/// slot, alongside AppBar / BottomNavigationBar / Drawer.
class FabClass {
  /// Icon
  dynamic iconDataJson;

  /// Icon Color
  Color? iconColor;

  /// Size of icon
  double? iconSize;

  /// Background Color
  Color? backgroundColor;

  /// Elevation
  double? elevation;

  /// FloatingActionButtonLocation key (see [kFabLocations]).
  String? location;

  FabClass({
    this.iconColor,
    this.iconSize,
    this.iconDataJson,
    this.backgroundColor,
    this.elevation,
    this.location,
  });

  FabClass.fromJson(Map<String, dynamic> json) {
    iconDataJson = json['iconDataJson'] != null ? json['iconDataJson'] : {'iconName': 'add', 'codePoint': 57415, 'fontFamily': 'MaterialIcons'};
    iconColor = json['iconColor'] != null ? fromJsonColor(json['iconColor']) : Colors.white;
    iconSize = json['iconSize'] != null ? json['iconSize'] : DEFAULT_ICON_SIZE;
    backgroundColor = json['backgroundColor'] != null ? fromJsonColor(json['backgroundColor']) : COMMON_BG_COLOR;
    elevation = json['elevation'] != null ? json['elevation'] : 6.0;
    location = json['location'] != null ? json['location'] : kFabLocationEndFloat;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    if (this.iconDataJson != null) {
      data['iconDataJson'] = this.iconDataJson;
    }
    if (this.iconColor != null) {
      data['iconColor'] = toJsonColor(this.iconColor!);
    }
    if (this.iconSize != null) {
      data['iconSize'] = this.iconSize;
    }
    if (this.backgroundColor != null) {
      data['backgroundColor'] = toJsonColor(this.backgroundColor!);
    }
    if (this.elevation != null) {
      data['elevation'] = this.elevation;
    }
    if (this.location != null) {
      data['location'] = this.location;
    }
    return data;
  }

  /// Live-preview widget for the scaffold's `floatingActionButton` slot.
  Widget getFabWidget() {
    return FloatingActionButton(
      onPressed: () {},
      backgroundColor: backgroundColor ?? COMMON_BG_COLOR,
      elevation: elevation ?? 6.0,
      child: Icon(
        iconDataJson != null ? IconData(iconDataJson['codePoint'], fontFamily: iconDataJson['fontFamily']) : Icons.add,
        color: iconColor ?? Colors.white,
        size: iconSize ?? DEFAULT_ICON_SIZE,
      ),
    );
  }

  /// Maps [location] to the actual Flutter [FloatingActionButtonLocation].
  FloatingActionButtonLocation getFabLocation() {
    return fabLocationFromKey(location ?? kFabLocationEndFloat);
  }

  /// Dart source for the scaffold's `floatingActionButton:`.
  getCodeAsString() {
    return "FloatingActionButton(\n"
        "onPressed:(){},\n"
        "backgroundColor:${backgroundColor ?? COMMON_BG_COLOR},\n"
        "elevation:${elevation ?? 6.0},\n"
        "child:Icon(\n"
        "${iconDataJson != null ? 'Icons.${iconDataJson['iconName']}' : 'Icons.add'},\n"
        "color:${iconColor ?? Colors.white},\n"
        "size:${iconSize ?? DEFAULT_ICON_SIZE},\n"
        "),\n"
        ")";
  }

  /// Dart source for the scaffold's `floatingActionButtonLocation:`.
  getLocationCodeString() {
    return "FloatingActionButtonLocation.${location ?? kFabLocationEndFloat}";
  }
}

// ---------------------------------------------------------------------------
// FloatingActionButtonLocation options
// ---------------------------------------------------------------------------

const String kFabLocationStartTop = 'startTop';
const String kFabLocationCenterTop = 'centerTop';
const String kFabLocationEndTop = 'endTop';
const String kFabLocationStartFloat = 'startFloat';
const String kFabLocationCenterFloat = 'centerFloat';
const String kFabLocationEndFloat = 'endFloat';
const String kFabLocationStartDocked = 'startDocked';
const String kFabLocationCenterDocked = 'centerDocked';
const String kFabLocationEndDocked = 'endDocked';

/// Ordered list shown in the position dropdown.
const List<String> kFabLocations = [
  kFabLocationStartTop,
  kFabLocationCenterTop,
  kFabLocationEndTop,
  kFabLocationStartFloat,
  kFabLocationCenterFloat,
  kFabLocationEndFloat,
  kFabLocationStartDocked,
  kFabLocationCenterDocked,
  kFabLocationEndDocked,
];

FloatingActionButtonLocation fabLocationFromKey(String key) {
  switch (key) {
    case kFabLocationStartTop:
      return FloatingActionButtonLocation.startTop;
    case kFabLocationCenterTop:
      return FloatingActionButtonLocation.centerTop;
    case kFabLocationEndTop:
      return FloatingActionButtonLocation.endTop;
    case kFabLocationStartFloat:
      return FloatingActionButtonLocation.startFloat;
    case kFabLocationCenterFloat:
      return FloatingActionButtonLocation.centerFloat;
    case kFabLocationStartDocked:
      return FloatingActionButtonLocation.startDocked;
    case kFabLocationCenterDocked:
      return FloatingActionButtonLocation.centerDocked;
    case kFabLocationEndDocked:
      return FloatingActionButtonLocation.endDocked;
    case kFabLocationEndFloat:
    default:
      return FloatingActionButtonLocation.endFloat;
  }
}
