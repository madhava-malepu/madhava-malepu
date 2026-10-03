import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:go_router/go_router.dart';
import '/pages/home_feed/home_feed_widget.dart';
import '/pages/onboarding_login/onboarding_login_widget.dart';

class SplashScreenWidget extends StatefulWidget {
  const SplashScreenWidget({Key? key}) : super(key: key);
  static String get routeName => 'SplashScreen';
  static String get routePath => '/';
  @override
  State<SplashScreenWidget> createState() => _SplashScreenWidgetState();
}

class _SplashScreenWidgetState extends State<SplashScreenWidget>
    with TickerProviderStateMixin {
  late AnimationController _logoCtrl;
  late AnimationController _textCtrl;
  late AnimationController _taglineCtrl;
  late Animation<double> _logoScale;
  late Animation<double> _logoFade;
  late Animation<double> _textFade;
  late Animation<Offset> _textSlide;
  late Animation<double> _taglineFade;

  @override
  void initState() {
    super.initState();

    _logoCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _textCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _taglineCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));

    _logoScale = Tween<double>(begin: 0.6, end: 1.0).animate(
        CurvedAnimation(parent: _logoCtrl, curve: Curves.elasticOut));
    _logoFade = CurvedAnimation(parent: _logoCtrl, curve: const Interval(0.0, 0.5));
    _textFade = CurvedAnimation(parent: _textCtrl, curve: Curves.easeOut);
    _textSlide = Tween<Offset>(begin: const Offset(0, 0.3), end: Offset.zero).animate(
        CurvedAnimation(parent: _textCtrl, curve: Curves.easeOutCubic));
    _taglineFade = CurvedAnimation(parent: _taglineCtrl, curve: Curves.easeOut);

    // Sequence: logo → text → tagline → navigate
    _logoCtrl.forward().then((_) {
      if (mounted) _textCtrl.forward();
    });
    _textCtrl.addListener(() {
      if (_textCtrl.value > 0.5 && !_taglineCtrl.isAnimating && !_taglineCtrl.isCompleted) {
        if (mounted) _taglineCtrl.forward();
      }
    });

    Future.delayed(const Duration(milliseconds: 2800), _navigate);
  }

  void _navigate() {
    if (!mounted) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      context.goNamed(HomeFeedWidget.routeName);
    } else {
      context.goNamed(OnboardingLoginWidget.routeName);
    }
  }

  @override
  void dispose() {
    _logoCtrl.dispose();
    _textCtrl.dispose();
    _taglineCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Logo with scale + fade
          ScaleTransition(
            scale: _logoScale,
            child: FadeTransition(
              opacity: _logoFade,
              child: Container(
                width: 100, height: 100,
                decoration: BoxDecoration(
                  color: const Color(0xFFF5A623),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFFF5A623).withValues(alpha: 0.4),
                      blurRadius: 24, offset: const Offset(0, 8)),
                  ]),
                child: CustomPaint(painter: _SurplIconPainter())),
            )),
          const SizedBox(height: 28),

          // Wordmark slide up + fade
          SlideTransition(
            position: _textSlide,
            child: FadeTransition(
              opacity: _textFade,
              child: const Text('surpl',
                style: TextStyle(
                  color: Color(0xFF1A4731),
                  fontSize: 52,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -2,
                  fontFamily: 'Georgia')))),
          const SizedBox(height: 10),

          // Tagline fade
          FadeTransition(
            opacity: _taglineFade,
            child: const Text('Sealed with care. Open to dare.',
              style: TextStyle(
                color: Color(0xFF4d6b57),
                fontSize: 15,
                fontStyle: FontStyle.italic,
                letterSpacing: 0.2,
                fontFamily: 'Georgia'))),

          const SizedBox(height: 60),

          // Subtle loading indicator
          FadeTransition(
            opacity: _taglineFade,
            child: SizedBox(
              width: 32, height: 3,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.0, end: 1.0),
                duration: const Duration(milliseconds: 2000),
                builder: (_, value, __) => LinearProgressIndicator(
                  value: value,
                  backgroundColor: const Color(0xFFE8F5EE),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1A4731)),
                  borderRadius: BorderRadius.circular(2))))),
        ]),
      ),
    );
  }
}

class _SurplIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const green = Color(0xFF1A4731);
    const amber = Color(0xFFF5A623);
    final p = Paint()..color = green..style = PaintingStyle.fill;
    final s = size.width / 110;

    canvas.drawRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(18*s, 58*s, 74*s, 42*s), Radius.circular(7*s)), p);

    canvas.drawPath(Path()
      ..moveTo(18*s, 58*s)..lineTo(55*s, 36*s)..lineTo(92*s, 58*s),
      Paint()..color = green..style = PaintingStyle.stroke
        ..strokeWidth = 7*s..strokeJoin = StrokeJoin.round..strokeCap = StrokeCap.round);

    canvas.drawCircle(Offset(55*s, 80*s), 18*s,
      Paint()..color = amber..style = PaintingStyle.fill);
    canvas.drawCircle(Offset(47*s, 75*s), 2.5*s, p);
    canvas.drawCircle(Offset(63*s, 75*s), 2.5*s, p);
    canvas.drawPath(Path()
      ..moveTo(46*s, 83*s)..quadraticBezierTo(55*s, 92*s, 64*s, 83*s),
      Paint()..color = green..style = PaintingStyle.stroke
        ..strokeWidth = 2.5*s..strokeCap = StrokeCap.round);

    void sparkle(double cx, double cy, double r, double len) {
      canvas.drawCircle(Offset(cx*s, cy*s), r*s, p);
      final lp = Paint()..color = green..strokeWidth = 2.2*s
        ..strokeCap = StrokeCap.round..style = PaintingStyle.stroke;
      canvas.drawLine(Offset(cx*s, cy*s), Offset(cx*s, (cy-len)*s), lp);
      canvas.drawLine(Offset(cx*s, cy*s), Offset((cx-len*0.7)*s, (cy+len*0.4)*s), lp);
      canvas.drawLine(Offset(cx*s, cy*s), Offset((cx+len*0.7)*s, (cy+len*0.4)*s), lp);
    }
    sparkle(55, 22, 3.5, 8);
    sparkle(30, 30, 2.5, 6);
    sparkle(80, 30, 2.5, 6);
  }

  @override
  bool shouldRepaint(_SurplIconPainter old) => false;
}