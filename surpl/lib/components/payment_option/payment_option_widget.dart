import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'payment_option_model.dart';
export 'payment_option_model.dart';

class PaymentOptionWidget extends StatefulWidget {
  const PaymentOptionWidget({
    super.key,
    String? selected,
    String? tapAction,
    String? logo,
    String? name,
    String? subtitle,
  })  : this.selected = selected ?? '',
        this.tapAction = tapAction ?? 'form.set_payment_method(\'googlepay\')',
        this.logo = logo ?? 'https://cdn.simpleicons.org/googlepay/121212.svg',
        this.name = name ?? 'Google Pay',
        this.subtitle = subtitle ?? 'Fast & Secure UPI';

  final String selected;
  final String tapAction;
  final String logo;
  final String name;
  final String subtitle;

  @override
  State<PaymentOptionWidget> createState() => _PaymentOptionWidgetState();
}

class _PaymentOptionWidgetState extends State<PaymentOptionWidget> {
  late PaymentOptionModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => PaymentOptionModel());
  }

  @override
  void dispose() {
    _model.maybeDispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(0.0, 0.0, 0.0, 16.0),
      child: Container(
        child: Container(
          decoration: BoxDecoration(
            color: FlutterFlowTheme.of(context).secondaryBackground,
            borderRadius: BorderRadius.circular(16.0),
            shape: BoxShape.rectangle,
            border: Border.all(
              color: valueOrDefault<Color>(
                widget!.selected == 'true'
                    ? FlutterFlowTheme.of(context).primary
                    : FlutterFlowTheme.of(context).alternate,
                Color(0x00000000),
              ),
              width: valueOrDefault<double>(
                widget!.selected == 'true' ? 1.0 : 1.0,
                0.0,
              ),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.all(16.0),
            child: Container(
              child: Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 48.0,
                    height: 48.0,
                    decoration: BoxDecoration(
                      color: FlutterFlowTheme.of(context).primaryBackground,
                      borderRadius: BorderRadius.circular(12.0),
                      shape: BoxShape.rectangle,
                    ),
                    alignment: AlignmentDirectional(0.0, 0.0),
                    child: SvgPicture.network(
                      valueOrDefault<String>(
                        widget!.logo,
                        'https://cdn.simpleicons.org/googlepay/121212.svg',
                      ),
                      width: 24.0,
                      height: 24.0,
                      fit: BoxFit.contain,
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          valueOrDefault<String>(
                            widget!.name,
                            'Google Pay',
                          ),
                          style: FlutterFlowTheme.of(context)
                              .titleSmall
                              .override(
                                font: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.bold,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .titleSmall
                                      .fontStyle,
                                ),
                                color: FlutterFlowTheme.of(context).primaryText,
                                letterSpacing: 0.0,
                                fontWeight: FontWeight.bold,
                                fontStyle: FlutterFlowTheme.of(context)
                                    .titleSmall
                                    .fontStyle,
                                lineHeight: 1.4,
                              ),
                        ),
                        Text(
                          valueOrDefault<String>(
                            widget!.subtitle,
                            'Fast & Secure UPI',
                          ),
                          style: FlutterFlowTheme.of(context)
                              .labelSmall
                              .override(
                                font: GoogleFonts.plusJakartaSans(
                                  fontWeight: FlutterFlowTheme.of(context)
                                      .labelSmall
                                      .fontWeight,
                                  fontStyle: FlutterFlowTheme.of(context)
                                      .labelSmall
                                      .fontStyle,
                                ),
                                color:
                                    FlutterFlowTheme.of(context).secondaryText,
                                letterSpacing: 0.0,
                                fontWeight: FlutterFlowTheme.of(context)
                                    .labelSmall
                                    .fontWeight,
                                fontStyle: FlutterFlowTheme.of(context)
                                    .labelSmall
                                    .fontStyle,
                                lineHeight: 1.3,
                              ),
                        ),
                      ].divide(SizedBox(height: 4.0)),
                    ),
                  ),
                  Container(
                    width: 24.0,
                    height: 24.0,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(9999.0),
                      shape: BoxShape.rectangle,
                      border: Border.all(
                        color: valueOrDefault<Color>(
                          widget!.selected == 'false'
                              ? FlutterFlowTheme.of(context).alternate
                              : FlutterFlowTheme.of(context).primary,
                          Color(0x00000000),
                        ),
                        width: valueOrDefault<double>(
                          widget!.selected == 'false' ? 2.0 : 2.0,
                          0.0,
                        ),
                      ),
                    ),
                    alignment: AlignmentDirectional(0.0, 0.0),
                    child: Container(
                      width: 12.0,
                      height: 12.0,
                      decoration: BoxDecoration(
                        color: FlutterFlowTheme.of(context).primary,
                        borderRadius: BorderRadius.circular(9999.0),
                        shape: BoxShape.rectangle,
                      ),
                    ),
                  ),
                ].divide(SizedBox(width: 16.0)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
