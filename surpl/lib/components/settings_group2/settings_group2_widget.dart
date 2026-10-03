import '/components/settings_tile/settings_tile_widget.dart';
import '/components/toggle_tile/toggle_tile_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'settings_group2_model.dart';
export 'settings_group2_model.dart';

class SettingsGroup2Widget extends StatefulWidget {
  const SettingsGroup2Widget({
    super.key,
    String? title,
  }) : this.title = title ?? 'PREFERENCES';

  final String title;

  @override
  State<SettingsGroup2Widget> createState() => _SettingsGroup2WidgetState();
}

class _SettingsGroup2WidgetState extends State<SettingsGroup2Widget> {
  late SettingsGroup2Model _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => SettingsGroup2Model());
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    context.watch<FFAppState>();

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
                    'PREFERENCES',
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
                          model: _model.toggleTileModel1,
                          updateCallback: () => safeSetState(() {}),
                          child: ToggleTileWidget(
                            tapAction: 'toast(\'Toggle coming soon\')',
                            icon: Icon(
                              Icons.notifications_none_rounded,
                              color: FlutterFlowTheme.of(context)
                                  .onPrimaryContainer,
                              size: 22.0,
                            ),
                            label: 'Push Notifications',
                            active: true,
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
                          model: _model.toggleTileModel2,
                          updateCallback: () => safeSetState(() {}),
                          child: ToggleTileWidget(
                            tapAction: 'toast(\'Toggle coming soon\')',
                            icon: Icon(
                              Icons.mail_outline_rounded,
                              color: FlutterFlowTheme.of(context)
                                  .onPrimaryContainer,
                              size: 22.0,
                            ),
                            label: 'Email Updates',
                            active: false,
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
                          model: _model.toggleTileModel3,
                          updateCallback: () => safeSetState(() {}),
                          child: ToggleTileWidget(
                            tapAction: 'app.toggle_vendor_mode()',
                            icon: Icon(
                              Icons.storefront_rounded,
                              color: FlutterFlowTheme.of(context)
                                  .onPrimaryContainer,
                              size: 22.0,
                            ),
                            label: 'Vendor Mode',
                            active: FFAppState().isVendorMode,
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
                          model: _model.settingsTileModel,
                          updateCallback: () => safeSetState(() {}),
                          child: SettingsTileWidget(
                            tapAction: 'toast(\'Coming soon\')',
                            icon: Icon(
                              Icons.language_rounded,
                              color: FlutterFlowTheme.of(context)
                                  .onPrimaryContainer,
                              size: 22.0,
                            ),
                            label: 'Language',
                            subtitle: 'English (India)',
                            hasSubtitle: true,
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
