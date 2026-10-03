import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'info_tile_model.dart';
export 'info_tile_model.dart';

class InfoTileWidget extends StatefulWidget {
  const InfoTileWidget({
    super.key,
    this.icon,
    String? label,
    String? value,
  })  : this.label = label ?? 'Location',
        this.value = value ?? '';

  final Widget? icon;
  final String label;
  final String value;

  @override
  State<InfoTileWidget> createState() => _InfoTileWidgetState();
}

class _InfoTileWidgetState extends State<InfoTileWidget> {
  late InfoTileModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => InfoTileModel());
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        widget!.icon!,
        Expanded(
          flex: 1,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                valueOrDefault<String>(
                  widget!.label,
                  'Location',
                ),
                style: FlutterFlowTheme.of(context).labelSmall.override(
                      font: GoogleFonts.plusJakartaSans(
                        fontWeight:
                            FlutterFlowTheme.of(context).labelSmall.fontWeight,
                        fontStyle:
                            FlutterFlowTheme.of(context).labelSmall.fontStyle,
                      ),
                      color: FlutterFlowTheme.of(context).secondaryText,
                      letterSpacing: 0.0,
                      fontWeight:
                          FlutterFlowTheme.of(context).labelSmall.fontWeight,
                      fontStyle:
                          FlutterFlowTheme.of(context).labelSmall.fontStyle,
                      lineHeight: 1.3,
                    ),
              ),
              Text(
                widget!.value,
                style: FlutterFlowTheme.of(context).bodyMedium.override(
                      font: GoogleFonts.inter(
                        fontWeight: FontWeight.w500,
                        fontStyle:
                            FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                      ),
                      color: FlutterFlowTheme.of(context).primaryText,
                      letterSpacing: 0.0,
                      fontWeight: FontWeight.w500,
                      fontStyle:
                          FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                      lineHeight: 1.5,
                    ),
              ),
            ].divide(SizedBox(height: 4.0)),
          ),
        ),
      ].divide(SizedBox(width: 16.0)),
    );
  }
}
