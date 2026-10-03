import '/components/button/button_widget.dart';
import '/components/text_field/text_field_widget.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'onboarding_login_widget.dart' show OnboardingLoginWidget;
import 'package:flutter/material.dart';

class OnboardingLoginModel extends FlutterFlowModel<OnboardingLoginWidget> {
  ///  Local state fields for this page.

  String? phone;

  String? otp;

  ///  State fields for stateful widgets in this page.

  // Model for TextField.
  late TextFieldModel textFieldModel;
  // Model for Button.
  late ButtonModel buttonModel;

  @override
  void initState(BuildContext context) {
    textFieldModel = createModel(context, () => TextFieldModel());
    buttonModel = createModel(context, () => ButtonModel());
  }

  @override
  void dispose() {
    textFieldModel.dispose();
    buttonModel.dispose();
  }
}
