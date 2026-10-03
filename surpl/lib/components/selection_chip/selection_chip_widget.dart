import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'selection_chip_model.dart';
export 'selection_chip_model.dart';

class SelectionChipWidget extends StatefulWidget {
  const SelectionChipWidget({
    super.key,
    String? selected,
    String? label,
  })  : this.selected = selected ?? 'true',
        this.label = label ?? 'Freshly Baked';

  final String selected;
  final String label;

  @override
  State<SelectionChipWidget> createState() => _SelectionChipWidgetState();
}

class _SelectionChipWidgetState extends State<SelectionChipWidget> {
  late SelectionChipModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => SelectionChipModel());
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 8.0, 8.0),
      child: Container(
        child: Container(
          decoration: BoxDecoration(
            color: valueOrDefault<Color>(
              valueOrDefault<String>(
                        widget!.selected,
                        'true',
                      ) ==
                      'false'
                  ? FlutterFlowTheme.of(context).secondaryBackground
                  : FlutterFlowTheme.of(context).primary,
              FlutterFlowTheme.of(context).primary,
            ),
            borderRadius: BorderRadius.circular(12.0),
            shape: BoxShape.rectangle,
            border: Border.all(
              color: valueOrDefault<Color>(
                valueOrDefault<String>(
                          widget!.selected,
                          'true',
                        ) ==
                        'false'
                    ? FlutterFlowTheme.of(context).alternate
                    : FlutterFlowTheme.of(context).primary,
                FlutterFlowTheme.of(context).primary,
              ),
              width: valueOrDefault<double>(
                valueOrDefault<String>(
                          widget!.selected,
                          'true',
                        ) ==
                        'false'
                    ? 1.0
                    : 1.0,
                1.0,
              ),
            ),
          ),
          child: Padding(
            padding: EdgeInsetsDirectional.fromSTEB(24.0, 8.0, 24.0, 8.0),
            child: Container(
              child: Text(
                valueOrDefault<String>(
                  widget!.label,
                  'Freshly Baked',
                ),
                style: FlutterFlowTheme.of(context).labelMedium.override(
                      font: GoogleFonts.plusJakartaSans(
                        fontWeight:
                            FlutterFlowTheme.of(context).labelMedium.fontWeight,
                        fontStyle:
                            FlutterFlowTheme.of(context).labelMedium.fontStyle,
                      ),
                      color: valueOrDefault<Color>(
                        valueOrDefault<String>(
                                  widget!.selected,
                                  'true',
                                ) ==
                                'false'
                            ? FlutterFlowTheme.of(context).primaryText
                            : FlutterFlowTheme.of(context).onPrimary,
                        FlutterFlowTheme.of(context).onPrimary,
                      ),
                      letterSpacing: 0.0,
                      fontWeight:
                          FlutterFlowTheme.of(context).labelMedium.fontWeight,
                      fontStyle:
                          FlutterFlowTheme.of(context).labelMedium.fontStyle,
                      lineHeight: 1.4,
                    ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
