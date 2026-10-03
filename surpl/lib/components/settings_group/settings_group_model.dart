import '/components/settings_tile/settings_tile_widget.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'settings_group_widget.dart' show SettingsGroupWidget;
import 'package:flutter/material.dart';

class SettingsGroupModel extends FlutterFlowModel<SettingsGroupWidget> {
  ///  State fields for stateful widgets in this component.

  // Model for SettingsTile.
  late SettingsTileModel settingsTileModel1;
  // Model for SettingsTile.
  late SettingsTileModel settingsTileModel2;
  // Model for SettingsTile.
  late SettingsTileModel settingsTileModel3;

  @override
  void initState(BuildContext context) {
    settingsTileModel1 = createModel(context, () => SettingsTileModel());
    settingsTileModel2 = createModel(context, () => SettingsTileModel());
    settingsTileModel3 = createModel(context, () => SettingsTileModel());
  }

  @override
  void dispose() {
    settingsTileModel1.dispose();
    settingsTileModel2.dispose();
    settingsTileModel3.dispose();
  }
}
