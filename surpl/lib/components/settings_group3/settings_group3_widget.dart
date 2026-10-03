import '/components/settings_tile/settings_tile_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'settings_group3_model.dart';
export 'settings_group3_model.dart';

class SettingsGroup3Widget extends StatefulWidget {
  const SettingsGroup3Widget({
    super.key,
    String? title,
  }) : this.title = title ?? 'SUPPORT';

  final String title;

  @override
  State<SettingsGroup3Widget> createState() => _SettingsGroup3WidgetState();
}

class _SettingsGroup3WidgetState extends State<SettingsGroup3Widget> {
  late SettingsGroup3Model _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => SettingsGroup3Model());
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 24.0),
      child: Container(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 4.0),
              child: Container(
                child: Text(
                  valueOrDefault<String>(
                    widget!.title,
                    'SUPPORT',
                  ),
                  style: FlutterFlowTheme.of(context).labelLarge.override(
                        font: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.bold,
                          fontStyle:
                              FlutterFlowTheme.of(context).labelLarge.fontStyle,
                        ),
                        color: FlutterFlowTheme.of(context).primary,
                        letterSpacing: 0.0,
                        fontWeight: FontWeight.bold,
                        fontStyle:
                            FlutterFlowTheme.of(context).labelLarge.fontStyle,
                        lineHeight: 1.4,
                      ),
                ),
              ),
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(16.0),
              child: Container(
                decoration: BoxDecoration(
                  color: FlutterFlowTheme.of(context).secondaryBackground,
                  borderRadius: BorderRadius.circular(16.0),
                  shape: BoxShape.rectangle,
                  border: Border.all(
                    color: FlutterFlowTheme.of(context).alternate,
                    width: 1.0,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        wrapWithModel(
                          model: _model.settingsTileModel1,
                          updateCallback: () => safeSetState(() {}),
                          child: SettingsTileWidget(
                            tapAction: 'toast(\'Coming soon\')',
                            icon: Icon(
                              Icons.help_outline_rounded,
                              color: FlutterFlowTheme.of(context)
                                  .onPrimaryContainer,
                              size: 22.0,
                            ),
                            label: 'Help Center',
                            subtitle: '',
                            hasSubtitle: false,
                          ),
                        ),
                        Divider(
                          height: 16.0,
                          thickness: 1.0,
                          indent: 56.0,
                          endIndent: 0.0,
                          color: FlutterFlowTheme.of(context).alternate,
                        ),
                        wrapWithModel(
                          model: _model.settingsTileModel2,
                          updateCallback: () => safeSetState(() {}),
                          child: SettingsTileWidget(
                            tapAction: 'toast(\'Coming soon\')',
                            icon: Icon(
                              Icons.description_outlined,
                              color: FlutterFlowTheme.of(context)
                                  .onPrimaryContainer,
                              size: 22.0,
                            ),
                            label: 'Terms of Service',
                            subtitle: '',
                            hasSubtitle: false,
                          ),
                        ),
                        Divider(
                          height: 16.0,
                          thickness: 1.0,
                          indent: 56.0,
                          endIndent: 0.0,
                          color: FlutterFlowTheme.of(context).alternate,
                        ),
                        wrapWithModel(
                          model: _model.settingsTileModel3,
                          updateCallback: () => safeSetState(() {}),
                          child: SettingsTileWidget(
                            tapAction: 'toast(\'Coming soon\')',
                            icon: Icon(
                              Icons.shield_outlined,
                              color: FlutterFlowTheme.of(context)
                                  .onPrimaryContainer,
                              size: 22.0,
                            ),
                            label: 'Privacy Policy',
                            subtitle: '',
                            hasSubtitle: false,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ].divide(SizedBox(height: 8.0)),
        ),
      ),
    );
  }
}
