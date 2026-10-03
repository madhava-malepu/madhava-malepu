import '/components/settings_tile/settings_tile_widget.dart';
import '/components/toggle_tile/toggle_tile_widget.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'settings_group2_widget.dart' show SettingsGroup2Widget;
import 'package:flutter/material.dart';

class SettingsGroup2Model extends FlutterFlowModel<SettingsGroup2Widget> {
  ///  State fields for stateful widgets in this component.

  // Model for ToggleTile.
  late ToggleTileModel toggleTileModel1;
  // Model for ToggleTile.
  late ToggleTileModel toggleTileModel2;
  // Model for ToggleTile.
  late ToggleTileModel toggleTileModel3;
  // Model for SettingsTile.
  late SettingsTileModel settingsTileModel;

  @override
  void initState(BuildContext context) {
    toggleTileModel1 = createModel(context, () => ToggleTileModel());
    toggleTileModel2 = createModel(context, () => ToggleTileModel());
    toggleTileModel3 = createModel(context, () => ToggleTileModel());
    settingsTileModel = createModel(context, () => SettingsTileModel());
  }

  @override
  void dispose() {
    toggleTileModel1.dispose();
    toggleTileModel2.dispose();
    toggleTileModel3.dispose();
    settingsTileModel.dispose();
  }
}
