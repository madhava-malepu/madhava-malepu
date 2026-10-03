import '/components/switch_component/switch_component_widget.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'toggle_tile_widget.dart' show ToggleTileWidget;
import 'package:flutter/material.dart';

class ToggleTileModel extends FlutterFlowModel<ToggleTileWidget> {
  ///  State fields for stateful widgets in this component.

  // Model for Switch.
  late SwitchComponentModel switchModel;

  @override
  void initState(BuildContext context) {
    switchModel = createModel(context, () => SwitchComponentModel());
  }

  @override
  void dispose() {
    switchModel.dispose();
  }
}
