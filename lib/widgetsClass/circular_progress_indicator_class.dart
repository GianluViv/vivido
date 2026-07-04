import 'package:flutter_viz/model/widget_model.dart';
import 'package:flutter_viz/utils/AppCommon.dart';
import 'package:flutter_viz/utils/AppFunctions.dart';
import 'package:flutter_viz/widgets/widgets.dart';
import 'package:flutter_viz/widgetsProperty/comman_property_view.dart';
import 'package:flutter/material.dart';

/// Live-render + Dart code-gen for a Material [CircularProgressIndicator].
/// Modeled on [LinearProgressIndicatorClass]; unlike the linear bar this widget
/// has an intrinsic size, so it needs no full-width / forced-expand handling
/// and uses [strokeWidth] instead of a height.
class CircularProgressIndicatorClass {
  /// Padding
  EdgeInsets? padding;

  ///Horizontal Alignment
  double? horizontalAlignment;

  ///Vertical Alignment
  double? verticalAlignment;

  /// Is AlignX
  bool? isAlignX;

  /// Is AlignY
  bool? isAlignY;

  ///Background Color
  Color? backgroundColor;

  ///Value Color
  Color? valueColor;

  ///Progress Value
  double? progressValue;

  ///Stroke Width
  double? strokeWidth;

  ///Is Expanded
  bool? isExpanded;

  ///Flex
  int? flex;

  CircularProgressIndicatorClass({
    this.padding,
    this.horizontalAlignment,
    this.verticalAlignment,
    this.isAlignX = false,
    this.isAlignY = false,
    this.backgroundColor,
    this.valueColor,
    this.progressValue,
    this.strokeWidth,
    this.isExpanded = false,
    this.flex = 1,
  });

  CircularProgressIndicatorClass.fromJson(Map<String, dynamic> json) {
    padding = json['padding'] != null ? fromJsonPadding(json['padding']) : EdgeInsets.zero;
    horizontalAlignment = json['horizontalAlignment'] != null ? json['horizontalAlignment'] : DEFAULT_HORIZONTAL_ALIGNMENT;
    verticalAlignment = json['verticalAlignment'] != null ? json['verticalAlignment'] : DEFAULT_VERTICAL_ALIGNMENT;
    isAlignX = json['isAlignX'] != null ? json['isAlignX'] : false;
    isAlignY = json['isAlignY'] != null ? json['isAlignY'] : false;
    backgroundColor = json['backgroundColor'] != null ? fromJsonColor(json['backgroundColor']) : DEFAULT_PROGRESSBAR_BACKGROUND_COLOR;
    valueColor = json['valueColor'] != null ? fromJsonColor(json['valueColor']) : COMMON_BG_COLOR;
    progressValue = json['progressValue'] != null ? json['progressValue'] : DEFAULT_PROGRESS_VALUE;
    strokeWidth = json['strokeWidth'] != null ? json['strokeWidth'] : DEFAULT_PROGRESS_STROKE_WIDTH;
    isExpanded = json['isExpanded'] != null ? json['isExpanded'] : false;
    flex = json['flex'] != null ? json['flex'] : DEFAULT_FLEX;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    if (this.padding != null) {
      data['padding'] = toJsonPadding(this.padding!);
    }
    if (this.horizontalAlignment != null && this.verticalAlignment != null) {
      data['horizontalAlignment'] = this.horizontalAlignment;
      data['verticalAlignment'] = this.verticalAlignment;
    } else if (this.horizontalAlignment != null) {
      data['horizontalAlignment'] = this.horizontalAlignment;
    } else if (this.verticalAlignment != null) {
      data['verticalAlignment'] = this.verticalAlignment;
    }
    if (this.isAlignX != null) {
      data['isAlignX'] = this.isAlignX;
    }
    if (this.isAlignY != null) {
      data['isAlignY'] = this.isAlignY;
    }
    if (this.valueColor != null) {
      data['valueColor'] = toJsonColor(this.valueColor!);
    }
    if (this.backgroundColor != null) {
      data['backgroundColor'] = toJsonColor(this.backgroundColor!);
    }
    if (this.progressValue != null) {
      data['progressValue'] = this.progressValue;
    }
    if (this.strokeWidth != null) {
      data['strokeWidth'] = this.strokeWidth;
    }
    if (this.isExpanded != null) {
      data['isExpanded'] = this.isExpanded;
    }
    if (this.flex != null) {
      data['flex'] = this.flex;
    }
    return data;
  }

  Widget getCircularProgressIndicatorDefaultWidget(WidgetModel widgetModel) {
    Widget childData = AbsorbPointer(
      absorbing: absorbPointer(),
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth ?? DEFAULT_PROGRESS_STROKE_WIDTH,
        backgroundColor: backgroundColor ?? DEFAULT_PROGRESSBAR_BACKGROUND_COLOR,
        valueColor: new AlwaysStoppedAnimation<Color>(valueColor ?? COMMON_BG_COLOR),
        value: progressValue ?? DEFAULT_PROGRESS_VALUE,
      ),
    );
    return getGestureDetector(widgetModel, childData);
  }

  _getExpanded(Widget _child) {
    return Expanded(child: _child, flex: flex ?? 1);
  }

  _getPadding(Widget _child) {
    return Padding(padding: padding!, child: _child);
  }

  _getAlign(Widget _child) {
    return Align(
      alignment: Alignment(horizontalAlignment ?? DEFAULT_HORIZONTAL_ALIGNMENT, verticalAlignment ?? DEFAULT_VERTICAL_ALIGNMENT),
      child: _child,
    );
  }

  Widget getCircularProgressIndicatorWidget(WidgetModel widgetModel) {
    if (getExpanded(widgetModel, isExpanded) && getPadding(padding) && getHorizontalOrVerticalAlignment(horizontalAlignment, verticalAlignment, isAlignX, isAlignY)) {
      return _getExpanded(_getPadding(_getAlign(getCircularProgressIndicatorDefaultWidget(widgetModel))));
    } else if (getExpanded(widgetModel, isExpanded) && getPadding(padding)) {
      return _getExpanded(_getPadding(getCircularProgressIndicatorDefaultWidget(widgetModel)));
    } else if (getExpanded(widgetModel, isExpanded) && getHorizontalOrVerticalAlignment(horizontalAlignment, verticalAlignment, isAlignX, isAlignY)) {
      return _getExpanded(_getAlign(getCircularProgressIndicatorDefaultWidget(widgetModel)));
    } else if (getPadding(padding) && getHorizontalOrVerticalAlignment(horizontalAlignment, verticalAlignment, isAlignX, isAlignY)) {
      return _getPadding(_getAlign((getCircularProgressIndicatorDefaultWidget(widgetModel))));
    } else if (getPadding(padding)) {
      return _getPadding(getCircularProgressIndicatorDefaultWidget(widgetModel));
    } else if (getHorizontalOrVerticalAlignment(horizontalAlignment, verticalAlignment, isAlignX, isAlignY)) {
      return _getAlign(getCircularProgressIndicatorDefaultWidget(widgetModel));
    } else if (getExpanded(widgetModel, isExpanded)) {
      return _getExpanded(getCircularProgressIndicatorDefaultWidget(widgetModel));
    } else {
      return getCircularProgressIndicatorDefaultWidget(widgetModel);
    }
  }

  getCircularProgressIndicatorString() {
    return "CircularProgressIndicator(\n"
        "backgroundColor: ${backgroundColor ?? DEFAULT_PROGRESSBAR_BACKGROUND_COLOR},\n"
        "valueColor: new AlwaysStoppedAnimation<Color>(${valueColor ?? COMMON_BG_COLOR}),\n"
        "value: ${progressValue ?? DEFAULT_PROGRESS_VALUE},\n"
        "strokeWidth: ${strokeWidth ?? DEFAULT_PROGRESS_STROKE_WIDTH}\n"
        ")";
  }

  _getStringExpanded(String _child) {
    return "Expanded(\n"
        "flex: ${flex ?? 1},\n"
        "child: $_child,\n"
        ")";
  }

  _getStringAlign() {
    return "Align(\n"
        "alignment:${Alignment(horizontalAlignment ?? DEFAULT_HORIZONTAL_ALIGNMENT, verticalAlignment ?? DEFAULT_VERTICAL_ALIGNMENT)},\n"
        "child:${getCircularProgressIndicatorString()},\n"
        ")";
  }

  _getStringPadding(String child) {
    return "Padding(\n"
        "padding:${getPaddingString(padding)},\n"
        "child:$child,\n"
        ")";
  }

  /// For view code
  getCodeAsString(WidgetModel widgetModel) {
    if (getExpanded(widgetModel, isExpanded) && getPadding(padding) && getHorizontalOrVerticalAlignment(horizontalAlignment, verticalAlignment, isAlignX, isAlignY)) {
      return _getStringExpanded(_getStringPadding(_getStringAlign()));
    } else if (getExpanded(widgetModel, isExpanded) && getPadding(padding)) {
      return _getStringExpanded(_getStringPadding(getCircularProgressIndicatorString()));
    } else if (getExpanded(widgetModel, isExpanded) && getHorizontalOrVerticalAlignment(horizontalAlignment, verticalAlignment, isAlignX, isAlignY)) {
      return _getStringExpanded(_getStringAlign());
    } else if (getPadding(padding) && getHorizontalOrVerticalAlignment(horizontalAlignment, verticalAlignment, isAlignX, isAlignY)) {
      return _getStringPadding(_getStringAlign());
    } else if (getPadding(padding)) {
      return _getStringPadding(getCircularProgressIndicatorString());
    } else if (getHorizontalOrVerticalAlignment(horizontalAlignment, verticalAlignment, isAlignX, isAlignY)) {
      return _getStringAlign();
    } else if (getExpanded(widgetModel, isExpanded)) {
      return _getStringExpanded(getCircularProgressIndicatorString());
    } else {
      return getCircularProgressIndicatorString();
    }
  }
}
