import '/components/nav_item/nav_item_widget.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'bottom_nav_model.dart';
export 'bottom_nav_model.dart';

class BottomNavWidget extends StatefulWidget {
  const BottomNavWidget({super.key});

  @override
  State<BottomNavWidget> createState() => _BottomNavWidgetState();
}

class _BottomNavWidgetState extends State<BottomNavWidget> {
  late BottomNavModel _model;

  @override
  void setState(VoidCallback callback) {
    super.setState(callback);
    _model.onUpdate();
  }

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => BottomNavModel());
  }

  @override
  void dispose() {
    _model.maybeDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: FlutterFlowTheme.of(context).secondaryBackground,
        shape: BoxShape.rectangle,
        border: Border.all(
          color: FlutterFlowTheme.of(context).alternate,
          width: 1.0,
        ),
      ),
      child: Padding(
        padding: EdgeInsetsDirectional.fromSTEB(8.0, 8.0, 8.0, 8.0),
        child: Row(
          mainAxisSize: MainAxisSize.max,
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Home
            wrapWithModel(
              model: _model.navItemModel1,
              updateCallback: () => safeSetState(() {}),
              child: NavItemWidget(
                label: 'Home',
                icon: Icon(
                  Icons.home_rounded,
                  color: FlutterFlowTheme.of(context).primaryText,
                  size: 24.0,
                ),
                target: 'home_feed',
                selected: true,
              ),
            ),
            // Cart
            GestureDetector(
              onTap: () => context.pushNamed('Cart'),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.shopping_bag_outlined,
                    color: FlutterFlowTheme.of(context).primaryText,
                    size: 24.0),
                  const SizedBox(height: 2),
                  Text('Cart',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10,
                      color: FlutterFlowTheme.of(context).primaryText)),
                ]),
            ),
            // Orders
            wrapWithModel(
              model: _model.navItemModel2,
              updateCallback: () => safeSetState(() {}),
              child: NavItemWidget(
                label: 'Orders',
                icon: Icon(
                  Icons.shopping_bag_rounded,
                  color: FlutterFlowTheme.of(context).primaryText,
                  size: 24.0,
                ),
                target: 'my_orders',
                selected: false,
              ),
            ),
            // Profile
            wrapWithModel(
              model: _model.navItemModel5,
              updateCallback: () => safeSetState(() {}),
              child: NavItemWidget(
                label: 'Profile',
                icon: Icon(
                  Icons.person_rounded,
                  color: FlutterFlowTheme.of(context).primaryText,
                  size: 24.0,
                ),
                target: 'profile',
                selected: false,
              ),
            ),
          ],
        ),
      ),
    );
  }
}