import '/components/switch_component/switch_component_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'toggle_tile_model.dart';
export 'toggle_tile_model.dart';

class ToggleTileWidget extends StatefulWidget {
  const ToggleTileWidget({
    super.key,
    String? tapAction,
    this.icon,
    String? label,
    bool? active,
  })  : this.tapAction = tapAction ?? 'toast(\'Toggle coming soon\')',
        this.label = label ?? 'Push Notifications',
        this.active = active ?? true;

  final String tapAction;
  final Widget? icon;
  final String label;
  final bool active;

  @override
  State<ToggleTileWidget> createState() => _ToggleTileWidgetState();
}

class _ToggleTileWidgetState extends State<ToggleTileWidget> {
  late ToggleTileModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => ToggleTileModel());
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(24.0, 16.0, 24.0, 16.0),
        child: Container(
          child: Row(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 40.0,
                height: 40.0,
                decoration: BoxDecoration(
                  color: FlutterFlowTheme.of(context).primaryContainer,
                  borderRadius: BorderRadius.circular(12.0),
                  shape: BoxShape.rectangle,
                ),
                alignment: AlignmentDirectional(0.0, 0.0),
                child: widget!.icon!,
              ),
              Expanded(
                flex: 1,
                child: Text(
                  valueOrDefault<String>(
                    widget!.label,
                    'Push Notifications',
                  ),
                  style: FlutterFlowTheme.of(context).bodyLarge.override(
                        font: GoogleFonts.inter(
                          fontWeight: FontWeight.w500,
                          fontStyle:
                              FlutterFlowTheme.of(context).bodyLarge.fontStyle,
                        ),
                        color: FlutterFlowTheme.of(context).primaryText,
                        letterSpacing: 0.0,
                        fontWeight: FontWeight.w500,
                        fontStyle:
                            FlutterFlowTheme.of(context).bodyLarge.fontStyle,
                        lineHeight: 1.5,
                      ),
                ),
              ),
              wrapWithModel(
                model: _model.switchModel,
                updateCallback: () => safeSetState(() {}),
                child: SwitchComponentWidget(
                  label: '',
                  labelPresent: false,
                  variant: 'iOS',
                  active: valueOrDefault<bool>(
                    widget!.active,
                    true,
                  ),
                ),
              ),
            ].divide(SizedBox(width: 16.0)),
          ),
        ),
      ),
    );
  }
}
