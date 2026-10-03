import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'transaction_item_model.dart';
export 'transaction_item_model.dart';

class TransactionItemWidget extends StatefulWidget {
  const TransactionItemWidget({
    super.key,
    String? type,
    String? title,
    String? subtitle,
    String? status,
  })  : this.type = type ?? 'sale',
        this.title = title ?? 'Order #SUR-992',
        this.subtitle = subtitle ?? '2x Premium Veg Thali',
        this.status = status ?? 'Completed';

  final String type;
  final String title;
  final String subtitle;
  final String status;

  @override
  State<TransactionItemWidget> createState() => _TransactionItemWidgetState();
}

class _TransactionItemWidgetState extends State<TransactionItemWidget> {
  late TransactionItemModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => TransactionItemModel());
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
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 40.0,
          height: 40.0,
          decoration: BoxDecoration(
            color: valueOrDefault<Color>(
              valueOrDefault<String>(
                        widget!.type,
                        'sale',
                      ) ==
                      'sale'
                  ? FlutterFlowTheme.of(context).success10
                  : FlutterFlowTheme.of(context).primary10,
              FlutterFlowTheme.of(context).success10,
            ),
            borderRadius: BorderRadius.circular(9999.0),
            shape: BoxShape.rectangle,
          ),
          alignment: AlignmentDirectional(0.0, 0.0),
          child: Container(
            width: 20.0,
            height: 20.0,
            child: Stack(
              alignment: AlignmentDirectional(0.0, 0.0),
              children: [
                if (valueOrDefault<bool>(
                  valueOrDefault<String>(
                            widget!.type,
                            'sale',
                          ) ==
                          'sale'
                      ? true
                      : false,
                  true,
                ))
                  Icon(
                    Icons.shopping_bag_rounded,
                    color: valueOrDefault<Color>(
                      valueOrDefault<String>(
                                widget!.type,
                                'sale',
                              ) ==
                              'sale'
                          ? FlutterFlowTheme.of(context).success
                          : FlutterFlowTheme.of(context).primary,
                      FlutterFlowTheme.of(context).success,
                    ),
                    size: 20.0,
                  ),
                if (valueOrDefault<bool>(
                  valueOrDefault<String>(
                            widget!.type,
                            'sale',
                          ) ==
                          'sale'
                      ? false
                      : true,
                  false,
                ))
                  Icon(
                    Icons.account_balance_wallet_rounded,
                    color: valueOrDefault<Color>(
                      valueOrDefault<String>(
                                widget!.type,
                                'sale',
                              ) ==
                              'sale'
                          ? FlutterFlowTheme.of(context).success
                          : FlutterFlowTheme.of(context).primary,
                      FlutterFlowTheme.of(context).success,
                    ),
                    size: 20.0,
                  ),
              ],
            ),
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
                  widget!.title,
                  'Order #SUR-992',
                ),
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
              Text(
                valueOrDefault<String>(
                  widget!.subtitle,
                  '2x Premium Veg Thali',
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
            ].divide(SizedBox(height: 4.0)),
          ),
        ),
        Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              valueOrDefault<String>(
                '{${widget!.type} == ',
                '{sale == ',
              ),
              style: FlutterFlowTheme.of(context).bodyMedium.override(
                    font: GoogleFonts.inter(
                      fontWeight:
                          FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                      fontStyle:
                          FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                    ),
                    letterSpacing: 0.0,
                    fontWeight:
                        FlutterFlowTheme.of(context).bodyMedium.fontWeight,
                    fontStyle:
                        FlutterFlowTheme.of(context).bodyMedium.fontStyle,
                    lineHeight: 1.5,
                  ),
            ),
            Text(
              valueOrDefault<String>(
                widget!.status,
                'Completed',
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
          ].divide(SizedBox(height: 4.0)),
        ),
      ].divide(SizedBox(width: 16.0)),
    );
  }
}
