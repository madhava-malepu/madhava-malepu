import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:page_transition/page_transition.dart';
import 'package:provider/provider.dart';
import '/backend/backend.dart';

import '/auth/base_auth_user_provider.dart';

import '/main.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/lat_lng.dart';
import '/flutter_flow/place.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'serialization_util.dart';

import '/index.dart';

export 'package:go_router/go_router.dart';
export 'serialization_util.dart';

const kTransitionInfoKey = '__transition_info__';

GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class AppStateNotifier extends ChangeNotifier {
  AppStateNotifier._();

  static AppStateNotifier? _instance;
  static AppStateNotifier get instance => _instance ??= AppStateNotifier._();

  BaseAuthUser? initialUser;
  BaseAuthUser? user;
  bool showSplashImage = true;
  String? _redirectLocation;

  bool notifyOnAuthChange = true;

  bool get loading => user == null || showSplashImage;
  bool get loggedIn => user?.loggedIn ?? false;
  bool get initiallyLoggedIn => initialUser?.loggedIn ?? false;
  bool get shouldRedirect => loggedIn && _redirectLocation != null;

  String getRedirectLocation() => _redirectLocation!;
  bool hasRedirect() => _redirectLocation != null;
  void setRedirectLocationIfUnset(String loc) => _redirectLocation ??= loc;
  void clearRedirectLocation() => _redirectLocation = null;

  void updateNotifyOnAuthChange(bool notify) => notifyOnAuthChange = notify;

  void update(BaseAuthUser newUser) {
    final shouldUpdate =
        user?.uid == null || newUser.uid == null || user?.uid != newUser.uid;
    initialUser ??= newUser;
    user = newUser;
    if (notifyOnAuthChange && shouldUpdate) {
      notifyListeners();
    }
    updateNotifyOnAuthChange(true);
  }

  void stopShowingSplashImage() {
    showSplashImage = false;
    notifyListeners();
  }
}

GoRouter createRouter(AppStateNotifier appStateNotifier) => GoRouter(
      initialLocation: '/',
      debugLogDiagnostics: true,
      refreshListenable: appStateNotifier,
      navigatorKey: appNavigatorKey,
      errorBuilder: (context, state) => appStateNotifier.loggedIn
          ? HomeFeedWidget()
          : OnboardingLoginWidget(),
      routes: [
        FFRoute(
          name: '_initialize',
          path: '/',
          builder: (context, _) => SplashScreenWidget(),
        ),
        FFRoute(
          name: BagDetailWidget.routeName,
          path: BagDetailWidget.routePath,
          builder: (context, params) => BagDetailWidget(
            bagId: params.getParam('bagId', ParamType.String),
          ),
        ),
        FFRoute(
          name: VendorDetailWidget.routeName,
          path: VendorDetailWidget.routePath,
          builder: (context, params) => VendorDetailWidget(
            merchantId: params.getParam('merchantId', ParamType.String) ?? '',
          ),
        ),
        FFRoute(
          name: FavouritesWidget.routeName,
          path: FavouritesWidget.routePath,
          builder: (context, params) => const FavouritesWidget(),
        ),
        FFRoute(
          name: RestaurantRequestsWidget.routeName,
          path: RestaurantRequestsWidget.routePath,
          builder: (context, params) => const RestaurantRequestsWidget(),
        ),
        FFRoute(
          name: PartyModeWidget.routeName,
          path: PartyModeWidget.routePath,
          builder: (context, params) => const PartyModeWidget(),
        ),
        FFRoute(
          name: CheckoutWidget.routeName,
          path: CheckoutWidget.routePath,
          builder: (context, params) => CheckoutWidget(
            bagId: params.getParam('bagId', ParamType.String),
          ),
        ),
        FFRoute(
          name: CartWidget.routeName,
          path: CartWidget.routePath,
          builder: (context, params) => CartWidget(),
        ),
        FFRoute(
          name: ActivityFeedWidget.routeName,
          path: ActivityFeedWidget.routePath,
          builder: (context, params) => ActivityFeedWidget(),
        ),
        FFRoute(
          name: CityLeaderboardWidget.routeName,
          path: CityLeaderboardWidget.routePath,
          builder: (context, params) => CityLeaderboardWidget(),
        ),
        FFRoute(
          name: ExpiringSoonWidget.routeName,
          path: ExpiringSoonWidget.routePath,
          builder: (context, params) => ExpiringSoonWidget(),
        ),
        FFRoute(
          name: LocalKitchensWidget.routeName,
          path: LocalKitchensWidget.routePath,
          builder: (context, params) => LocalKitchensWidget(),
        ),
        FFRoute(
          name: CreateListingWidget.routeName,
          path: CreateListingWidget.routePath,
          builder: (context, params) => CreateListingWidget(),
        ),
        FFRoute(
          name: HomeFeedWidget.routeName,
          path: HomeFeedWidget.routePath,
          builder: (context, params) => HomeFeedWidget(),
        ),
        FFRoute(
          name: MyOrdersWidget.routeName,
          path: MyOrdersWidget.routePath,
          builder: (context, params) => MyOrdersWidget(),
        ),
        FFRoute(
          name: CustomerSupportWidget.routeName,
          path: CustomerSupportWidget.routePath,
          builder: (context, params) => CustomerSupportWidget(),
        ),
        FFRoute(
          name: OnboardingLoginWidget.routeName,
          path: OnboardingLoginWidget.routePath,
          builder: (context, params) => OnboardingLoginWidget(),
        ),
        FFRoute(
          name: OrderConfirmationWidget.routeName,
          path: OrderConfirmationWidget.routePath,
          builder: (context, params) => OrderConfirmationWidget(
            orderId: params.getParam('orderId', ParamType.String),
          ),
        ),
        FFRoute(
          name: VendorDashboardWidget.routeName,
          path: VendorDashboardWidget.routePath,
          builder: (context, params) => VendorDashboardWidget(),
        ),
        FFRoute(
          name: SavedBagsWidget.routeName,
          path: SavedBagsWidget.routePath,
          builder: (context, params) => SavedBagsWidget(),
        ),
        FFRoute(
          name: ProfileWidget.routeName,
          path: ProfileWidget.routePath,
          builder: (context, params) => ProfileWidget(),
        ),
        FFRoute(
          name: EditProfileWidget.routeName,
          path: EditProfileWidget.routePath,
          builder: (context, params) => EditProfileWidget(),
        ),
        FFRoute(
          name: TermsOfServiceWidget.routeName,
          path: TermsOfServiceWidget.routePath,
          builder: (context, params) => TermsOfServiceWidget(),
        ),
        FFRoute(
          name: PrivacyPolicyWidget.routeName,
          path: PrivacyPolicyWidget.routePath,
          builder: (context, params) => PrivacyPolicyWidget(),
        ),
      ].map((r) => r.toRoute(appStateNotifier)).toList(),
    );

extension NavParamExtensions on Map<String, String?> {
  Map<String, String> get withoutNulls => Map.fromEntries(
        entries
            .where((e) => e.value != null)
            .map((e) => MapEntry(e.key, e.value!)),
      );
}

extension NavigationExtensions on BuildContext {
  void goNamedAuth(
    String name,
    bool mounted, {
    Map<String, String> pathParameters = const <String, String>{},
    Map<String, String> queryParameters = const <String, String>{},
    Object? extra,
    bool ignoreRedirect = false,
  }) =>
      !mounted || GoRouter.of(this).shouldRedirect(ignoreRedirect)
          ? null
          : goNamed(
              name,
              pathParameters: pathParameters,
              queryParameters: queryParameters,
              extra: extra,
            );

  void pushNamedAuth(
    String name,
    bool mounted, {
    Map<String, String> pathParameters = const <String, String>{},
    Map<String, String> queryParameters = const <String, String>{},
    Object? extra,
    bool ignoreRedirect = false,
  }) =>
      !mounted || GoRouter.of(this).shouldRedirect(ignoreRedirect)
          ? null
          : pushNamed(
              name,
              pathParameters: pathParameters,
              queryParameters: queryParameters,
              extra: extra,
            );

  void safePop() {
    if (canPop()) {
      pop();
    } else {
      go('/');
    }
  }
}

extension GoRouterExtensions on GoRouter {
  AppStateNotifier get appState => AppStateNotifier.instance;
  void prepareAuthEvent([bool ignoreRedirect = false]) =>
      appState.hasRedirect() && !ignoreRedirect
          ? null
          : appState.updateNotifyOnAuthChange(false);
  bool shouldRedirect(bool ignoreRedirect) =>
      !ignoreRedirect && appState.hasRedirect();
  void clearRedirectLocation() => appState.clearRedirectLocation();
  void setRedirectLocationIfUnset(String location) =>
      appState.updateNotifyOnAuthChange(false);
}

extension _GoRouterStateExtensions on GoRouterState {
  Map<String, dynamic> get extraMap =>
      extra != null ? extra as Map<String, dynamic> : {};
  Map<String, dynamic> get allParams => <String, dynamic>{}
    ..addAll(pathParameters)
    ..addAll(uri.queryParameters)
    ..addAll(extraMap);
  TransitionInfo get transitionInfo => extraMap.containsKey(kTransitionInfoKey)
      ? extraMap[kTransitionInfoKey] as TransitionInfo
      : TransitionInfo.appDefault();
}

class FFParameters {
  FFParameters(this.state, [this.asyncParams = const {}]);

  final GoRouterState state;
  final Map<String, Future<dynamic> Function(String)> asyncParams;

  Map<String, dynamic> futureParamValues = {};

  bool get isEmpty =>
      state.allParams.isEmpty ||
      (state.allParams.length == 1 &&
          state.extraMap.containsKey(kTransitionInfoKey));
  bool isAsyncParam(MapEntry<String, dynamic> param) =>
      asyncParams.containsKey(param.key) && param.value is String;
  bool get hasFutures => state.allParams.entries.any(isAsyncParam);
  Future<bool> completeFutures() => Future.wait(
        state.allParams.entries.where(isAsyncParam).map(
          (param) async {
            final doc = await asyncParams[param.key]!(param.value)
                .onError((_, __) => null);
            if (doc != null) {
              futureParamValues[param.key] = doc;
              return true;
            }
            return false;
          },
        ),
      ).onError((_, __) => [false]).then((v) => v.every((e) => e));

  dynamic getParam<T>(
    String paramName,
    ParamType type, {
    bool isList = false,
    List<String>? collectionNamePath,
  }) {
    if (futureParamValues.containsKey(paramName)) {
      return futureParamValues[paramName];
    }
    if (!state.allParams.containsKey(paramName)) {
      return null;
    }
    final param = state.allParams[paramName];
    if (param is! String) {
      return param;
    }
    return deserializeParam<T>(
      param,
      type,
      isList,
      collectionNamePath: collectionNamePath,
    );
  }
}

class FFRoute {
  const FFRoute({
    required this.name,
    required this.path,
    required this.builder,
    this.requireAuth = false,
    this.asyncParams = const {},
    this.routes = const [],
  });

  final String name;
  final String path;
  final bool requireAuth;
  final Map<String, Future<dynamic> Function(String)> asyncParams;
  final Widget Function(BuildContext, FFParameters) builder;
  final List<GoRoute> routes;

  GoRoute toRoute(AppStateNotifier appStateNotifier) => GoRoute(
        name: name,
        path: path,
        redirect: (context, state) {
          if (appStateNotifier.shouldRedirect) {
            final redirectLocation = appStateNotifier.getRedirectLocation();
            appStateNotifier.clearRedirectLocation();
            return redirectLocation;
          }
          if (requireAuth && !appStateNotifier.loggedIn) {
            appStateNotifier.setRedirectLocationIfUnset(state.uri.toString());
            return '/onboardingLogin';
          }
          return null;
        },
        pageBuilder: (context, state) {
          fixStatusBarOniOS16AndBelow(context);
          final ffParams = FFParameters(state, asyncParams);
          final page = ffParams.hasFutures
              ? FutureBuilder(
                  future: ffParams.completeFutures(),
                  builder: (context, _) => builder(context, ffParams),
                )
              : builder(context, ffParams);

          final transitionInfo = state.transitionInfo;
          return transitionInfo.hasTransition
              ? CustomTransitionPage(
                  key: state.pageKey,
                  name: state.name,
                  child: page,
                  transitionDuration: transitionInfo.duration,
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) =>
                          PageTransition(
                    type: transitionInfo.transitionType,
                    duration: transitionInfo.duration,
                    reverseDuration: transitionInfo.duration,
                    alignment: transitionInfo.alignment,
                    child: child,
                  ).buildTransitions(
                    context,
                    animation,
                    secondaryAnimation,
                    child,
                  ),
                )
              : MaterialPage(
                  key: state.pageKey, name: state.name, child: page);
        },
        routes: routes,
      );
}

class TransitionInfo {
  const TransitionInfo({
    required this.hasTransition,
    this.transitionType = PageTransitionType.fade,
    this.duration = const Duration(milliseconds: 300),
    this.alignment,
  });

  final bool hasTransition;
  final PageTransitionType transitionType;
  final Duration duration;
  final Alignment? alignment;

  static TransitionInfo appDefault() => TransitionInfo(hasTransition: false);
}

class RootPageContext {
  const RootPageContext(this.isRootPage, [this.errorRoute]);
  final bool isRootPage;
  final String? errorRoute;

  static bool isInactiveRootPage(BuildContext context) {
    final rootPageContext = context.read<RootPageContext?>();
    final isRootPage = rootPageContext?.isRootPage ?? false;
    final location = GoRouterState.of(context).uri.toString();
    return isRootPage &&
        location != '/' &&
        location != rootPageContext?.errorRoute;
  }

  static Widget wrap(Widget child, {String? errorRoute}) => Provider.value(
        value: RootPageContext(true, errorRoute),
        child: child,
      );
}

extension GoRouterLocationExtension on GoRouter {
  String getCurrentLocation() {
    final RouteMatch lastMatch = routerDelegate.currentConfiguration.last;
    final RouteMatchList matchList = lastMatch is ImperativeRouteMatch
        ? lastMatch.matches
        : routerDelegate.currentConfiguration;
    return matchList.uri.toString();
  }
}