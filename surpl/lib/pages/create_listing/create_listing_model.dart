import '/components/button/button_widget.dart';
import '/components/form_section_header/form_section_header_widget.dart';
import '/components/selection_chip/selection_chip_widget.dart';
import '/components/text_field/text_field_widget.dart';
import '/components/upload_placeholder/upload_placeholder_widget.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/flutter_flow/form_field_controller.dart';
import 'create_listing_widget.dart' show CreateListingWidget;
import 'package:flutter/material.dart';

class CreateListingModel extends FlutterFlowModel<CreateListingWidget> {
  ///  Local state fields for this page.

  String? name;

  String? desc;

  double? price = 0.0;

  double? originalPrice = 0.0;

  String? startTime = '18:00';

  String? endTime = '20:00';

  int? quantity = 10;

  String? category = 'Bakery';

  String? error;

  ///  State fields for stateful widgets in this page.

  // Model for FormSectionHeader.
  late FormSectionHeaderModel formSectionHeaderModel1;
  // Model for TextField.
  late TextFieldModel textFieldModel1;
  // Model for TextField.
  late TextFieldModel textFieldModel2;
  // Model for UploadPlaceholder.
  late UploadPlaceholderModel uploadPlaceholderModel;
  // Model for FormSectionHeader.
  late FormSectionHeaderModel formSectionHeaderModel2;
  // Model for TextField.
  late TextFieldModel textFieldModel3;
  // Model for TextField.
  late TextFieldModel textFieldModel4;
  // Model for FormSectionHeader.
  late FormSectionHeaderModel formSectionHeaderModel3;
  // Model for TextField.
  late TextFieldModel textFieldModel5;
  // Model for TextField.
  late TextFieldModel textFieldModel6;
  // Model for Button.
  late ButtonModel buttonModel1;
  // Model for FormSectionHeader.
  late FormSectionHeaderModel formSectionHeaderModel4;
  // Model for TextField.
  late TextFieldModel textFieldModel7;
  // State field(s) for Dropdown widget.
  String? dropdownValue;
  FormFieldController<String>? dropdownValueController;
  // Model for SelectionChip.
  late SelectionChipModel selectionChipModel1;
  // Model for SelectionChip.
  late SelectionChipModel selectionChipModel2;
  // Model for SelectionChip.
  late SelectionChipModel selectionChipModel3;
  // Model for SelectionChip.
  late SelectionChipModel selectionChipModel4;
  // Model for Button.
  late ButtonModel buttonModel2;

  @override
  void initState(BuildContext context) {
    formSectionHeaderModel1 =
        createModel(context, () => FormSectionHeaderModel());
    textFieldModel1 = createModel(context, () => TextFieldModel());
    textFieldModel2 = createModel(context, () => TextFieldModel());
    uploadPlaceholderModel =
        createModel(context, () => UploadPlaceholderModel());
    formSectionHeaderModel2 =
        createModel(context, () => FormSectionHeaderModel());
    textFieldModel3 = createModel(context, () => TextFieldModel());
    textFieldModel4 = createModel(context, () => TextFieldModel());
    formSectionHeaderModel3 =
        createModel(context, () => FormSectionHeaderModel());
    textFieldModel5 = createModel(context, () => TextFieldModel());
    textFieldModel6 = createModel(context, () => TextFieldModel());
    buttonModel1 = createModel(context, () => ButtonModel());
    formSectionHeaderModel4 =
        createModel(context, () => FormSectionHeaderModel());
    textFieldModel7 = createModel(context, () => TextFieldModel());
    selectionChipModel1 = createModel(context, () => SelectionChipModel());
    selectionChipModel2 = createModel(context, () => SelectionChipModel());
    selectionChipModel3 = createModel(context, () => SelectionChipModel());
    selectionChipModel4 = createModel(context, () => SelectionChipModel());
    buttonModel2 = createModel(context, () => ButtonModel());
  }

  @override
  void dispose() {
    formSectionHeaderModel1.dispose();
    textFieldModel1.dispose();
    textFieldModel2.dispose();
    uploadPlaceholderModel.dispose();
    formSectionHeaderModel2.dispose();
    textFieldModel3.dispose();
    textFieldModel4.dispose();
    formSectionHeaderModel3.dispose();
    textFieldModel5.dispose();
    textFieldModel6.dispose();
    buttonModel1.dispose();
    formSectionHeaderModel4.dispose();
    textFieldModel7.dispose();
    selectionChipModel1.dispose();
    selectionChipModel2.dispose();
    selectionChipModel3.dispose();
    selectionChipModel4.dispose();
    buttonModel2.dispose();
  }
}
