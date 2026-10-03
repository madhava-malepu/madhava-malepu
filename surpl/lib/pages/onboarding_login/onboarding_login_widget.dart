import 'package:cloud_functions/cloud_functions.dart';
import 'dart:async';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import '/utils/input_sanitizer.dart';
import '/pages/legal/legal_widget.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/index.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'onboarding_login_model.dart';
export 'onboarding_login_model.dart';

// ══════════════════════════════════════════════════
// CUSTOMER LOGIN — clean, simple
// ══════════════════════════════════════════════════
// Converts Firebase Auth's raw technical error messages (like the E.164
// format message, which no ordinary user would understand) into plain,
// friendly language. Shared by both customer and vendor login flows.
String _friendlyAuthError(FirebaseAuthException e) {
  switch (e.code) {
    case 'invalid-phone-number':
      return 'That phone number doesn\'t look right — please check and try again.';
    case 'too-many-requests':
      return 'Too many attempts. Please wait a bit before trying again.';
    case 'network-request-failed':
      return 'Network issue — check your connection and try again.';
    case 'invalid-verification-code':
      return 'Incorrect code. Try again.';
    case 'session-expired':
      return 'That code expired — please request a new one.';
    default:
      // Never show Firebase's raw technical message (e.g. the E.164
      // format wording) directly to a user.
      return 'Something went wrong. Please try again.';
  }
}

class OnboardingLoginWidget extends StatefulWidget {
  const OnboardingLoginWidget({super.key});
  static String routeName = 'OnboardingLogin';
  static String routePath = '/onboardingLogin';
  @override
  State<OnboardingLoginWidget> createState() => _OnboardingLoginWidgetState();
}

class _CountryCode {
  final String flag, code, name;
  const _CountryCode(this.flag, this.code, this.name);
}

const _countryCodes = [
  _CountryCode('🇮🇳', '+91', 'India'),
  _CountryCode('🇬🇧', '+44', 'United Kingdom'),
  _CountryCode('🇺🇸', '+1', 'United States'),
  _CountryCode('🇦🇪', '+971', 'UAE'),
  _CountryCode('🇸🇬', '+65', 'Singapore'),
  _CountryCode('🇦🇺', '+61', 'Australia'),
  _CountryCode('🇨🇦', '+1', 'Canada'),
];

class _OnboardingLoginWidgetState extends State<OnboardingLoginWidget> {
  late OnboardingLoginModel _model;
  final _phoneCtrl = TextEditingController();
  final _otpCtrls = List.generate(6, (_) => TextEditingController());
  final _otpNodes = List.generate(6, (_) => FocusNode());

  bool _otpSent = false, _sending = false, _verifying = false;
  bool _agreedToTerms = false;
  String? _verificationId, _error;
  _CountryCode _country = _countryCodes[0];
  Timer? _timer;
  int _timerSec = 0;

  static const _green = Color(0xFF1A4731);
  static const _amber = Color(0xFFF5A623);
  static const _border = Color(0xFFD4E8D4);
  static const _bg = Color(0xFFF4F7F4);
  static const _textDark = Color(0xFF0D1F12);
  static const _textSec = Color(0xFF4D6B57);

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => OnboardingLoginModel());
  }

  @override
  void dispose() {
    _model.dispose();
    _phoneCtrl.dispose();
    for (final c in _otpCtrls) c.dispose();
    for (final f in _otpNodes) f.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _timerSec = 45);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      if (_timerSec <= 1) { t.cancel(); setState(() => _timerSec = 0); }
      else setState(() => _timerSec--);
    });
  }

  Future<void> _showCountryPicker() async {
    final sel = await showModalBottomSheet<_CountryCode>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 12),
        Container(width: 40, height: 4, decoration: BoxDecoration(
          color: _border, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 12),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Align(alignment: Alignment.centerLeft,
            child: Text('Select country', style: GoogleFonts.plusJakartaSans(
              fontSize: 16, fontWeight: FontWeight.w700)))),
        const SizedBox(height: 8),
        ..._countryCodes.map((c) => ListTile(
          leading: Text(c.flag, style: const TextStyle(fontSize: 22)),
          title: Text(c.name, style: GoogleFonts.plusJakartaSans(
            fontSize: 14, fontWeight: FontWeight.w600)),
          trailing: Text(c.code, style: GoogleFonts.plusJakartaSans(
            fontSize: 14, color: _textSec)),
          onTap: () => Navigator.pop(context, c))),
        const SizedBox(height: 12),
      ])));
    if (sel != null) setState(() => _country = sel);
  }

  Future<void> _ensureUserDoc(User user) async {
    try {
      final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final doc = await ref.get();
      if (!doc.exists) {
        final myCode = user.uid.substring(0, 8).toUpperCase();
        await ref.set({
          'uid': user.uid,
          'phoneNumber': user.phoneNumber ?? '',
          'name': '', 'email': '',
          'isVendor': false, 'vendorStatus': '',
          'savedBags': [], 'walletBalance': 0.0,
          'referralCode': myCode,
          'referralCount': 0,
          'referredBy': '',
          'firstOrderDiscountPct': 0,
          'createdAt': FieldValue.serverTimestamp(),
        });
        // Small, safe lookup-only record — lets another user's referral
        // code be found without exposing this user's phone/wallet/etc.
        // (querying `users` directly by code is blocked by security rules
        // on purpose, since that collection holds private fields).
        await FirebaseFirestore.instance
            .collection('referralCodes').doc(myCode)
            .set({'uid': user.uid});
      } else {
        await ref.update({
          'phoneNumber': user.phoneNumber ?? '',
          'lastLogin': FieldValue.serverTimestamp(),
        });
        // Backfill: users who registered before the referralCodes lookup
        // table existed won't have an entry yet — create it now so their
        // existing (already-shared) code starts working.
        final existingCode = doc.data()?['referralCode'] as String?;
        if (existingCode != null && existingCode.isNotEmpty) {
          final lookup = await FirebaseFirestore.instance
              .collection('referralCodes').doc(existingCode).get();
          if (!lookup.exists) {
            await FirebaseFirestore.instance
                .collection('referralCodes').doc(existingCode)
                .set({'uid': user.uid});
          }
        }
      }
    } catch (_) {}
  }

  Future<void> _sendOtp() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.length < 6) {
      setState(() => _error = 'Enter a valid phone number');
      return;
    }
    if (!_agreedToTerms) {
      setState(() => _error = 'Please agree to the Terms & Privacy Policy to continue');
      return;
    }
    setState(() { _sending = true; _error = null; });
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: '${_country.code}$phone',
        timeout: const Duration(seconds: 60),
        verificationCompleted: (cred) async {
          final r = await FirebaseAuth.instance.signInWithCredential(cred);
          if (r.user != null) await _ensureUserDoc(r.user!);
          if (mounted) context.goNamed(HomeFeedWidget.routeName);
        },
        verificationFailed: (e) {
          if (mounted) setState(() {
            _sending = false;
            _error = _friendlyAuthError(e);
          });
        },
        codeSent: (id, _) {
          if (mounted) setState(() {
            _sending = false; _otpSent = true; _verificationId = id;
          });
          _startTimer();
        },
        codeAutoRetrievalTimeout: (id) => _verificationId = id,
      );
    } catch (e) {
      if (mounted) setState(() { _sending = false; _error = 'Could not send OTP: $e'; });
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpCtrls.map((c) => c.text).join();
    if (otp.length != 6 || _verificationId == null) {
      setState(() => _error = 'Enter the complete 6-digit code');
      return;
    }
    setState(() { _verifying = true; _error = null; });
    try {
      final cred = PhoneAuthProvider.credential(
        verificationId: _verificationId!, smsCode: otp);
      final r = await FirebaseAuth.instance.signInWithCredential(cred);
      if (r.user != null) {
        final isNew = r.additionalUserInfo?.isNewUser ?? false;
        await _ensureUserDoc(r.user!);
        if (mounted) {
          if (isNew) {
            // Show referral code dialog for new users
            _showReferralCodeDialog(r.user!.uid);
          } else {
            context.goNamed(HomeFeedWidget.routeName);
          }
        }
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() {
        _verifying = false;
        _error = e.code == 'invalid-verification-code'
            ? 'Incorrect code. Try again.' : _friendlyAuthError(e);
      });
    } catch (e) {
      if (mounted) setState(() { _verifying = false; _error = 'Verification failed: $e'; });
    }
  }

  void _showReferralCodeDialog(String newUserUid) {
    final codeCtrl = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('🎁', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 12),
          const Text('Have a referral code?',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
              color: Color(0xFF0D1F12))),
          const SizedBox(height: 6),
          const Text('Enter a friend\'s code to get 10% off your first order!',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: Color(0xFF4D6B57), height: 1.4)),
          const SizedBox(height: 16),
          TextField(
            controller: codeCtrl,
            textCapitalization: TextCapitalization.characters,
            maxLength: 8,
            textAlign: TextAlign.center,
            decoration: InputDecoration(
              counterText: '',
              hintText: 'Enter code (optional)',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF1A4731), width: 2))),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
              letterSpacing: 4, color: Color(0xFF1A4731))),
        ]),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.goNamed(HomeFeedWidget.routeName);
            },
            child: const Text('Skip',
              style: TextStyle(color: Color(0xFF4D6B57)))),
          ElevatedButton(
            onPressed: () async {
              final code = codeCtrl.text.trim().toUpperCase();
              Navigator.pop(context);
              if (code.isNotEmpty) await _applyReferral(newUserUid, code);
              if (mounted) context.goNamed(HomeFeedWidget.routeName);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1A4731),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text('Apply', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700))),
        ]));
  }

  Future<void> _applyReferral(String newUserUid, String referralCode) async {
    try {
      await FirebaseFunctions.instanceFor(region: 'asia-south1')
          .httpsCallable('applyReferral').call({'code': referralCode});
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _green,
      body: SafeArea(child: SingleChildScrollView(child: Column(children: [
        // Logo
        Padding(padding: const EdgeInsets.fromLTRB(0, 48, 0, 32),
          child: Column(children: [
            Container(width: 80, height: 80,
              decoration: BoxDecoration(color: _amber, borderRadius: BorderRadius.circular(20)),
              child: ClipRRect(borderRadius: BorderRadius.circular(20),
                child: Image.asset('assets/images/surpl_logo.png', fit: BoxFit.cover))),
            const SizedBox(height: 14),
            Text('surpl', style: GoogleFonts.plusJakartaSans(
              fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -1.5)),
            const SizedBox(height: 4),
            Text('Sealed with care. Open to dare.', style: GoogleFonts.plusJakartaSans(
              fontSize: 13, fontStyle: FontStyle.italic, color: Colors.white54)),
          ])),

        // Card
        Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Welcome back 👋', style: GoogleFonts.plusJakartaSans(
                fontSize: 20, fontWeight: FontWeight.w800, color: _textDark)),
              const SizedBox(height: 4),
              Text('Enter your number to find great deals near you',
                style: GoogleFonts.plusJakartaSans(fontSize: 13, color: _textSec)),
              const SizedBox(height: 20),

              // Phone field — rebuilt using TextField's own prefixIcon
              // system instead of a manual Row, same fix pattern as the
              // home feed search bar. The isDense+zero-padding combo was
              // fighting Flutter's text layout, causing exactly the kind
              // of cramped/clipped look reported.
              Container(
                height: 54,
                decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _border)),
                child: TextField(
                  controller: _phoneCtrl,
                  enabled: !_otpSent,
                  keyboardType: TextInputType.phone,
                  maxLength: 12,
                  textAlignVertical: TextAlignVertical.center,
                  style: GoogleFonts.plusJakartaSans(fontSize: 15, color: _textDark),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    counterText: '',
                    hintText: 'Phone number',
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    hintStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 15, color: const Color(0xFFBBBBBB)),
                    prefixIcon: GestureDetector(
                      onTap: _otpSent ? null : _showCountryPicker,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text('${_country.flag} ${_country.code}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14, fontWeight: FontWeight.w600, color: _textDark)),
                          if (!_otpSent) const Icon(Icons.keyboard_arrow_down_rounded,
                            size: 16, color: _textSec),
                          const SizedBox(width: 10),
                          Container(width: 1, height: 20, color: _border),
                        ]),
                      ),
                    ),
                    prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              if (!_otpSent) _btn('Send OTP', _sending, _sendOtp),

              if (_error != null) ...[
                const SizedBox(height: 10),
                Container(padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    Icon(Icons.error_outline, color: Colors.red.shade600, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!, style: GoogleFonts.plusJakartaSans(
                      fontSize: 12, color: Colors.red.shade700))),
                  ])),
              ],

              if (_otpSent) ...[
                const SizedBox(height: 20),
                const Divider(color: _border),
                const SizedBox(height: 16),
                Text('Enter OTP', style: GoogleFonts.plusJakartaSans(
                  fontSize: 16, fontWeight: FontWeight.w700, color: _textDark)),
                const SizedBox(height: 4),
                Text('Sent to ${_country.code} ${_phoneCtrl.text}',
                  style: GoogleFonts.plusJakartaSans(fontSize: 12, color: _textSec)),
                const SizedBox(height: 14),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(6, (i) => _otpBox(i))),
                const SizedBox(height: 12),
                Center(child: _timerSec > 0
                  ? Text('Resend in 0:${_timerSec.toString().padLeft(2,'0')}',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, color: _textSec))
                  : GestureDetector(onTap: _sending ? null : _sendOtp,
                      child: Text('Resend OTP', style: GoogleFonts.plusJakartaSans(
                        fontSize: 12, color: _green, fontWeight: FontWeight.w700)))),
                const SizedBox(height: 6),
                Center(child: GestureDetector(
                  onTap: () {
                    _timer?.cancel();
                    setState(() {
                      _otpSent = false; _error = null; _timerSec = 0;
                      for (final c in _otpCtrls) c.clear();
                    });
                  },
                  child: Text('Change number', style: GoogleFonts.plusJakartaSans(
                    fontSize: 12, color: _textSec, fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline)))),
                const SizedBox(height: 16),
                _btn('Verify & Continue', _verifying, _verifyOtp),
              ],
            ])),
        ),

        const SizedBox(height: 28),

        // Terms — real checkbox, not passive text. DPDP Act requires
        // consent via clear affirmative action, not implied-by-continuing.
        GestureDetector(
          onTap: () => setState(() => _agreedToTerms = !_agreedToTerms),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            SizedBox(width: 20, height: 20, child: Checkbox(
              value: _agreedToTerms,
              activeColor: Colors.white24,
              checkColor: Colors.white,
              side: const BorderSide(color: Colors.white38),
              onChanged: (v) => setState(() => _agreedToTerms = v ?? false))),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: () => _showLegalPicker(context),
              child: Text('I agree to the Terms & Privacy Policy',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11, color: Colors.white38,
                  decoration: TextDecoration.underline,
                  decorationColor: Colors.white24))),
          ])),

        const SizedBox(height: 20),

        // Vendor login link — subtle, at bottom
        GestureDetector(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const VendorLoginScreen())),
          child: Padding(padding: const EdgeInsets.only(bottom: 32),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              const Icon(Icons.storefront_outlined, color: Colors.white30, size: 14),
              const SizedBox(width: 6),
              Text('Vendor Login', style: GoogleFonts.plusJakartaSans(
                fontSize: 12, color: Colors.white38,
                decoration: TextDecoration.underline,
                decorationColor: Colors.white24)),
            ]))),
      ]))),
    );
  }

  void _showLegalPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(child: Column(
        mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 12),
        Container(width: 40, height: 4, decoration: BoxDecoration(
          color: _border, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 12),
        ListTile(
          leading: const Icon(Icons.description_outlined, color: _green),
          title: Text('Terms of Service', style: GoogleFonts.plusJakartaSans(
            fontSize: 14, fontWeight: FontWeight.w600)),
          onTap: () {
            Navigator.pop(context);
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const TermsOfServiceWidget()));
          }),
        ListTile(
          leading: const Icon(Icons.privacy_tip_outlined, color: _green),
          title: Text('Privacy Policy', style: GoogleFonts.plusJakartaSans(
            fontSize: 14, fontWeight: FontWeight.w600)),
          onTap: () {
            Navigator.pop(context);
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const PrivacyPolicyWidget()));
          }),
        const SizedBox(height: 12),
      ])));
  }

  Widget _btn(String label, bool loading, VoidCallback onTap) =>
    SizedBox(width: double.infinity, child: ElevatedButton(
      onPressed: loading ? null : onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF1A4731),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0),
      child: loading
        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(
            strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
        : Text(label, style: GoogleFonts.plusJakartaSans(
            fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white))));

  Widget _otpBox(int i) => Container(
    width: 44, height: 52,
    decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _border)),
    child: TextField(
      controller: _otpCtrls[i], focusNode: _otpNodes[i],
      textAlign: TextAlign.center,
      keyboardType: TextInputType.number, maxLength: 1,
      decoration: const InputDecoration(border: InputBorder.none, counterText: ''),
      style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w800,
        color: const Color(0xFF1A4731)),
      onChanged: (v) {
        if (v.isNotEmpty && i < 5) _otpNodes[i + 1].requestFocus();
        else if (v.isEmpty && i > 0) _otpNodes[i - 1].requestFocus();
      }));
}

// ══════════════════════════════════════════════════
// VENDOR LOGIN — completely separate screen
// ══════════════════════════════════════════════════
class VendorLoginScreen extends StatefulWidget {
  const VendorLoginScreen({super.key});
  @override
  State<VendorLoginScreen> createState() => _VendorLoginScreenState();
}

class _VendorLoginScreenState extends State<VendorLoginScreen> {
  final _phoneCtrl = TextEditingController();
  final _otpCtrls = List.generate(6, (_) => TextEditingController());
  final _otpNodes = List.generate(6, (_) => FocusNode());

  bool _otpSent = false, _sending = false, _verifying = false;
  String? _verificationId, _error;
  _CountryCode _country = _countryCodes[0];
  Timer? _timer;
  int _timerSec = 0;

  static const _green = Color(0xFF1A4731);
  static const _amber = Color(0xFFF5A623);
  static const _border = Color(0xFFD4E8D4);
  static const _bg = Color(0xFFF4F7F4);
  static const _textDark = Color(0xFF0D1F12);
  static const _textSec = Color(0xFF4D6B57);
  static const _mintBg = Color(0xFFE6F4ED);

  @override
  void dispose() {
    _phoneCtrl.dispose();
    for (final c in _otpCtrls) c.dispose();
    for (final f in _otpNodes) f.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _timerSec = 45);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      if (_timerSec <= 1) { t.cancel(); setState(() => _timerSec = 0); }
      else setState(() => _timerSec--);
    });
  }

  Future<void> _showCountryPicker() async {
    final sel = await showModalBottomSheet<_CountryCode>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
        const SizedBox(height: 12),
        Container(width: 40, height: 4, decoration: BoxDecoration(
          color: _border, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 12),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Align(alignment: Alignment.centerLeft,
            child: Text('Select country', style: GoogleFonts.plusJakartaSans(
              fontSize: 16, fontWeight: FontWeight.w700)))),
        const SizedBox(height: 8),
        ..._countryCodes.map((c) => ListTile(
          leading: Text(c.flag, style: const TextStyle(fontSize: 22)),
          title: Text(c.name, style: GoogleFonts.plusJakartaSans(
            fontSize: 14, fontWeight: FontWeight.w600)),
          trailing: Text(c.code, style: GoogleFonts.plusJakartaSans(
            fontSize: 14, color: _textSec)),
          onTap: () => Navigator.pop(context, c))),
        const SizedBox(height: 12),
      ])));
    if (sel != null) setState(() => _country = sel);
  }

  Future<void> _sendOtp() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.length < 6) {
      setState(() => _error = 'Enter your registered vendor phone number');
      return;
    }
    setState(() { _sending = true; _error = null; });
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: '${_country.code}$phone',
        timeout: const Duration(seconds: 60),
        verificationCompleted: (cred) async {
          final r = await FirebaseAuth.instance.signInWithCredential(cred);
          if (r.user != null) await _routeVendor(r.user!);
        },
        verificationFailed: (e) {
          if (mounted) setState(() {
            _sending = false;
            _error = _friendlyAuthError(e);
          });
        },
        codeSent: (id, _) {
          if (mounted) setState(() {
            _sending = false; _otpSent = true; _verificationId = id;
          });
          _startTimer();
        },
        codeAutoRetrievalTimeout: (id) => _verificationId = id,
      );
    } catch (e) {
      if (mounted) setState(() { _sending = false; _error = 'Could not send OTP: $e'; });
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpCtrls.map((c) => c.text).join();
    if (otp.length != 6 || _verificationId == null) {
      setState(() => _error = 'Enter the complete 6-digit code');
      return;
    }
    setState(() { _verifying = true; _error = null; });
    try {
      final cred = PhoneAuthProvider.credential(
        verificationId: _verificationId!, smsCode: otp);
      final r = await FirebaseAuth.instance.signInWithCredential(cred);
      if (r.user != null) await _routeVendor(r.user!);
    } on FirebaseAuthException catch (e) {
      if (mounted) setState(() {
        _verifying = false;
        _error = e.code == 'invalid-verification-code'
            ? 'Incorrect code. Try again.' : _friendlyAuthError(e);
      });
    } catch (e) {
      if (mounted) setState(() { _verifying = false; _error = 'Verification failed: $e'; });
    }
  }

  Future<void> _routeVendor(User user) async {
    if (!mounted) return;
    try {
      // Ensure user doc exists
      final ref = FirebaseFirestore.instance.collection('users').doc(user.uid);
      final doc = await ref.get();
      if (!doc.exists) {
        await ref.set({
          'uid': user.uid, 'phoneNumber': user.phoneNumber ?? '',
          'name': '', 'email': '', 'isVendor': false, 'vendorStatus': '',
          'savedBags': [], 'walletBalance': 0.0,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        await ref.update({'lastLogin': FieldValue.serverTimestamp()});
      }

      final data = (await ref.get()).data();
      final isVendor = data?['isVendor'] as bool? ?? false;
      final vendorStatus = data?['vendorStatus'] as String? ?? '';

      if (!mounted) return;

      if (isVendor && vendorStatus == 'approved') {
        context.goNamed(VendorDashboardWidget.routeName);
      } else if (vendorStatus == 'pending') {
        _showPending();
      } else if (vendorStatus == 'rejected') {
        _showRejected(data?['rejectionReason'] as String? ?? '', user.uid);
      } else {
        // Not registered — go to registration
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => _VendorRegistrationScreen(uid: user.uid)));
      }
    } catch (_) {
      if (mounted) setState(() {
        _verifying = false;
        _error = 'Failed to check vendor status. Try again.';
      });
    }
  }

  void _showPending() => showDialog(
    context: context, barrierDismissible: false,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 72, height: 72,
          decoration: BoxDecoration(color: const Color(0xFFFFF3E0), shape: BoxShape.circle),
          child: const Icon(Icons.hourglass_empty_rounded,
            color: Color(0xFFE65100), size: 36)),
        const SizedBox(height: 16),
        Text('Application Under Review', textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18, fontWeight: FontWeight.w800, color: _textDark)),
        const SizedBox(height: 10),
        Text('Surpl is reviewing your FSSAI certificate and application. You will be approved within 24 hours.',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(fontSize: 13, color: _textSec, height: 1.5)),
      ]),
      actions: [TextButton(
        onPressed: () {
          Navigator.pop(context);
          context.goNamed(HomeFeedWidget.routeName);
        },
        child: Text('Browse as Customer',
          style: GoogleFonts.plusJakartaSans(color: _green, fontWeight: FontWeight.w700)))],
    ));

  void _showRejected(String reason, String uid) => showDialog(
    context: context, barrierDismissible: false,
    builder: (_) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 72, height: 72,
          decoration: BoxDecoration(color: Colors.red.shade50, shape: BoxShape.circle),
          child: Icon(Icons.cancel_rounded, color: Colors.red.shade600, size: 36)),
        const SizedBox(height: 16),
        Text('Application Rejected', textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18, fontWeight: FontWeight.w800, color: _textDark)),
        const SizedBox(height: 10),
        if (reason.isNotEmpty) Text('Reason: $reason',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(fontSize: 13, color: _textSec, height: 1.5)),
        const SizedBox(height: 6),
        Text('Fixed the issue above? You can apply again below.',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(fontSize: 12, color: _textSec)),
      ]),
      actions: [
        TextButton(
          onPressed: () async {
            // The actual fix: previously rejection left vendorStatus
            // stuck at 'pending' forever, with genuinely no path back to
            // a fresh application anywhere in the app - a vendor who
            // fixed the issue they were rejected for had no way to try
            // again except contacting support directly. This resets the
            // field only when the vendor explicitly taps to re-apply,
            // so the rejection reason above is still shown once, not
            // silently skipped.
            try {
              await FirebaseFirestore.instance.collection('users').doc(uid)
                  .update({'vendorStatus': ''});
            } catch (_) {}
            if (context.mounted) {
              Navigator.pop(context); // close this dialog
              Navigator.pop(context); // close the loading/verify screen beneath it
              Navigator.of(context).pushReplacement(MaterialPageRoute(
                  builder: (_) => _VendorRegistrationScreen(uid: uid)));
            }
          },
          child: Text('Apply Again', style: GoogleFonts.plusJakartaSans(
            color: _green, fontWeight: FontWeight.w700)),
        ),
        TextButton(
          onPressed: () { Navigator.pop(context); Navigator.pop(context); },
          child: Text('Not Now', style: GoogleFonts.plusJakartaSans(
            color: _textSec, fontWeight: FontWeight.w600)),
        ),
      ],
    ));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0D1F12), // darker green for vendor
      body: SafeArea(child: SingleChildScrollView(child: Column(children: [
        // Back button
        Padding(padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: Align(alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(width: 36, height: 36,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1),
                  shape: BoxShape.circle),
                child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 18))))),

        // Vendor logo section
        Padding(padding: const EdgeInsets.fromLTRB(0, 24, 0, 28),
          child: Column(children: [
            Container(width: 80, height: 80,
              decoration: BoxDecoration(color: _amber, borderRadius: BorderRadius.circular(20)),
              child: const Center(child: Icon(Icons.storefront_rounded,
                color: _green, size: 40))),
            const SizedBox(height: 14),
            Text('Vendor Portal', style: GoogleFonts.plusJakartaSans(
              fontSize: 28, fontWeight: FontWeight.w800, color: Colors.white,
              letterSpacing: -1)),
            const SizedBox(height: 4),
            Text('surpl for businesses', style: GoogleFonts.plusJakartaSans(
              fontSize: 13, color: Colors.white38)),
          ])),

        // Login card
        Padding(padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Vendor Login', style: GoogleFonts.plusJakartaSans(
                fontSize: 20, fontWeight: FontWeight.w800, color: _textDark)),
              const SizedBox(height: 4),
              Text('Enter your registered vendor phone number',
                style: GoogleFonts.plusJakartaSans(fontSize: 13, color: _textSec)),
              const SizedBox(height: 20),

              // Phone field — same robust prefixIcon-based fix as customer login
              Container(
                height: 54,
                decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _border)),
                child: TextField(
                  controller: _phoneCtrl,
                  enabled: !_otpSent,
                  keyboardType: TextInputType.phone,
                  maxLength: 12,
                  textAlignVertical: TextAlignVertical.center,
                  style: GoogleFonts.plusJakartaSans(fontSize: 15, color: _textDark),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    counterText: '',
                    hintText: 'Phone number',
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    hintStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 15, color: const Color(0xFFBBBBBB)),
                    prefixIcon: GestureDetector(
                      onTap: _otpSent ? null : _showCountryPicker,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Text('${_country.flag} ${_country.code}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14, fontWeight: FontWeight.w600, color: _textDark)),
                          if (!_otpSent) const Icon(Icons.keyboard_arrow_down_rounded,
                            size: 16, color: _textSec),
                          const SizedBox(width: 10),
                          Container(width: 1, height: 20, color: _border),
                        ]),
                      ),
                    ),
                    prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              if (!_otpSent) _amberBtn('Send OTP', _sending, _sendOtp),

              if (_error != null) ...[
                const SizedBox(height: 10),
                Container(padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8)),
                  child: Row(children: [
                    Icon(Icons.error_outline, color: Colors.red.shade600, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!, style: GoogleFonts.plusJakartaSans(
                      fontSize: 12, color: Colors.red.shade700))),
                  ])),
              ],

              if (_otpSent) ...[
                const SizedBox(height: 20),
                const Divider(color: _border),
                const SizedBox(height: 16),
                Text('Enter OTP', style: GoogleFonts.plusJakartaSans(
                  fontSize: 16, fontWeight: FontWeight.w700, color: _textDark)),
                const SizedBox(height: 4),
                Text('Sent to ${_country.code} ${_phoneCtrl.text}',
                  style: GoogleFonts.plusJakartaSans(fontSize: 12, color: _textSec)),
                const SizedBox(height: 14),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: List.generate(6, (i) => Container(
                    width: 44, height: 52,
                    decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _border)),
                    child: TextField(
                      controller: _otpCtrls[i], focusNode: _otpNodes[i],
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number, maxLength: 1,
                      decoration: const InputDecoration(border: InputBorder.none, counterText: ''),
                      style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w800,
                        color: _green),
                      onChanged: (v) {
                        if (v.isNotEmpty && i < 5) _otpNodes[i + 1].requestFocus();
                        else if (v.isEmpty && i > 0) _otpNodes[i - 1].requestFocus();
                      })))),
                const SizedBox(height: 12),
                Center(child: _timerSec > 0
                  ? Text('Resend in 0:${_timerSec.toString().padLeft(2,'0')}',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, color: _textSec))
                  : GestureDetector(onTap: _sending ? null : _sendOtp,
                      child: Text('Resend OTP', style: GoogleFonts.plusJakartaSans(
                        fontSize: 12, color: _green, fontWeight: FontWeight.w700)))),
                const SizedBox(height: 6),
                Center(child: GestureDetector(
                  onTap: () {
                    _timer?.cancel();
                    setState(() {
                      _otpSent = false; _error = null; _timerSec = 0;
                      for (final c in _otpCtrls) c.clear();
                    });
                  },
                  child: Text('Change number', style: GoogleFonts.plusJakartaSans(
                    fontSize: 12, color: _textSec, fontWeight: FontWeight.w600,
                    decoration: TextDecoration.underline)))),
                const SizedBox(height: 16),
                _amberBtn('Verify & Enter Dashboard', _verifying, _verifyOtp),
              ],
            ])),
        ),

        const SizedBox(height: 24),

        // Register link
        GestureDetector(
          onTap: () {
            final user = FirebaseAuth.instance.currentUser;
            if (user != null) {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => _VendorRegistrationScreen(uid: user.uid)));
            } else {
              setState(() => _error = 'Please verify your number first to register.');
            }
          },
          child: Padding(padding: const EdgeInsets.only(bottom: 32),
            child: Text('New vendor? Apply here →', style: GoogleFonts.plusJakartaSans(
              fontSize: 13, color: _amber, fontWeight: FontWeight.w600,
              decoration: TextDecoration.underline, decorationColor: _amber)))),
      ]))),
    );
  }

  Widget _amberBtn(String label, bool loading, VoidCallback onTap) =>
    SizedBox(width: double.infinity, child: ElevatedButton(
      onPressed: loading ? null : onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: _amber,
        foregroundColor: _green,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 0),
      child: loading
        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(
            strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1A4731))))
        : Text(label, style: GoogleFonts.plusJakartaSans(
            fontSize: 15, fontWeight: FontWeight.w800))));
}

// ══════════════════════════════════════════════════
// VENDOR REGISTRATION SCREEN
// ══════════════════════════════════════════════════
class _VendorRegistrationScreen extends StatefulWidget {
  final String uid;
  const _VendorRegistrationScreen({required this.uid});
  @override
  State<_VendorRegistrationScreen> createState() =>
      _VendorRegistrationScreenState();
}

class _VendorRegistrationScreenState extends State<_VendorRegistrationScreen> {
  static const _green = Color(0xFF1A4731);
  static const _amber = Color(0xFFF5A623);
  static const _border = Color(0xFFD4E8D4);
  static const _bg = Color(0xFFF4F7F4);
  static const _textDark = Color(0xFF0D1F12);
  static const _textSec = Color(0xFF4D6B57);
  static const _mintBg = Color(0xFFE6F4ED);

  final _shopCtrl = TextEditingController();
  final _ownerCtrl = TextEditingController();
  final _fssaiCtrl = TextEditingController();
  final _gstinCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _storyCtrl = TextEditingController();

  bool _submitting = false;
  String? _error;
  bool _submitted = false;
  bool _locating = false;
  double? _shopLat;
  double? _shopLng;
  String _shopArea = 'Angadi Bazar';
  String _city = 'Jagtial';

  // Same fix as the customer-facing home feed - this was hardcoded to
  // Jagtial's own localities regardless of which city a vendor actually
  // selected. Jagtial's list is the original, established one -
  // unchanged. The other 3 cities use an honest, generic starting list
  // rather than inventing specific-sounding but unverified neighborhood
  // names - these need real local knowledge to refine properly.
  static const Map<String, List<String>> _areasByCity = {
    'Jagtial': [
      'Angadi Bazar', 'New Bus Stand', 'Old Bus Stand', 'Yawar Road',
      'Collectorate Road', 'Gandhi Chowk', 'Jagitial Fort Area',
      'RTC Colony', 'Bypass Road', 'Korutla Road', 'Other Area',
    ],
    'Korutla': [
      'Sairampura Colony', 'Hajipura', 'Kumariwada', 'Korutla Main Road',
      'Jagtial Road', 'Jhansi Road', 'Kallur Road', 'Raheempura', 'Other Area',
    ],
    'Karimnagar': [
      'Mukarampura', 'Vavilalapally', 'Jagtial Road', 'Ganesh Nagar',
      'Jyothinagar', 'Sai Nagar', 'Court Chowrastha', 'Kothirampur',
      'Christian Colony', 'Kothapalli', 'Other Area',
    ],
    'Warangal': [
      'Bus Stand Area', 'Railway Station Area', 'Main Market', 'Other Area',
    ],
  };
  List<String> get _areasForSelectedCity => _areasByCity[_city] ?? _areasByCity['Jagtial']!;
  bool _agreedToVendorTerms = false;
  XFile? _fssaiCertFile;
  bool _uploadingCert = false;

  @override
  void dispose() {
    _shopCtrl.dispose();
    _ownerCtrl.dispose();
    _fssaiCtrl.dispose();
    _gstinCtrl.dispose();
    _addressCtrl.dispose();
    _storyCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickFssaiCert() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
          source: ImageSource.gallery, imageQuality: 80, maxWidth: 1400);
      if (picked != null && mounted) {
        setState(() => _fssaiCertFile = picked);
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not pick image. Please try again.');
    }
  }

  Future<String?> _uploadFssaiCert(String uid) async {
    if (_fssaiCertFile == null) return null;
    setState(() => _uploadingCert = true);
    try {
      final file = File(_fssaiCertFile!.path);
      final ref = FirebaseStorage.instance
          .ref().child('vendor_fssai_certs').child('$uid.jpg');
      final task = ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
      final snap = await task;
      return await snap.ref.getDownloadURL();
    } catch (e) {
      return null;
    } finally {
      if (mounted) setState(() => _uploadingCert = false);
    }
  }

  Future<void> _captureLocation() async {
    setState(() { _locating = true; _error = null; });
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        setState(() {
          _locating = false;
          _error = 'Location permission denied. Enable it in app settings to capture your shop location.';
        });
        return;
      }

      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _locating = false;
          _error = 'Please turn on Location/GPS on your phone.';
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      );

      setState(() {
        _shopLat = position.latitude;
        _shopLng = position.longitude;
        _locating = false;
      });
    } catch (e) {
      setState(() {
        _locating = false;
        _error = 'Could not get location. Make sure GPS is on and try again.';
      });
    }
  }

  Future<void> _submit() async {
    if (_shopCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Enter shop name'); return;
    }
    if (_ownerCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Enter owner name'); return;
    }
    if (!InputSanitizer.isValidFssai(_fssaiCtrl.text)) {
      setState(() => _error = 'Enter valid 14-digit FSSAI number'); return;
    }
    if (_fssaiCertFile == null) {
      setState(() => _error = 'Please upload a photo of your FSSAI certificate'); return;
    }
    // GST made optional per business decision - only validate format if
    // the vendor chose to provide one; an empty field is now allowed
    // through, rather than blocking submission entirely.
    if (_gstinCtrl.text.trim().isNotEmpty && !InputSanitizer.isValidGstin(_gstinCtrl.text)) {
      setState(() => _error = 'GSTIN entered doesn\'t look valid — check it or leave it blank'); return;
    }
    if (_addressCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Enter shop address'); return;
    }
    if (_shopLat == null || _shopLng == null) {
      setState(() => _error = 'Please capture your shop location using the location button'); return;
    }
    if (!_agreedToVendorTerms) {
      setState(() => _error = 'Please confirm you agree to the vendor terms below'); return;
    }

    setState(() { _submitting = true; _error = null; });
    try {
      final certUrl = await _uploadFssaiCert(widget.uid);
      if (certUrl == null) {
        setState(() {
          _submitting = false;
          _error = 'Could not upload your FSSAI certificate. Please try again.';
        });
        return;
      }
      await FirebaseFirestore.instance
          .collection('vendorApplications').doc(widget.uid).set({
        'uid': widget.uid,
        'shopName': InputSanitizer.sanitizeName(_shopCtrl.text),
        'ownerName': InputSanitizer.sanitizeName(_ownerCtrl.text),
        'fssaiNumber': InputSanitizer.sanitizeFssai(_fssaiCtrl.text),
        'fssaiCertUrl': certUrl,
        'gstin': InputSanitizer.sanitizeGstin(_gstinCtrl.text),
        'address': InputSanitizer.sanitizeAddress(_addressCtrl.text),
        'vendorStory': _storyCtrl.text.trim(),
        'shopArea': _shopArea,
        'city': _city,
        'shopLat': _shopLat,
        'shopLng': _shopLng,
        'agreedToVendorTerms': true,
        'agreedToVendorTermsAt': FieldValue.serverTimestamp(),
        'status': 'pending',
        'submittedAt': FieldValue.serverTimestamp(),
        'rejectionReason': '',
      });
      await FirebaseFirestore.instance.collection('users').doc(widget.uid).update({
        'vendorStatus': 'pending',
        'shopName': InputSanitizer.sanitizeName(_shopCtrl.text),
        'ownerName': InputSanitizer.sanitizeName(_ownerCtrl.text),
        'city': _city,
      });
      if (mounted) setState(() { _submitting = false; _submitted = true; });
    } catch (e) {
      if (mounted) setState(() {
        _submitting = false;
        _error = 'Submission failed. Please try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_submitted) return _successScreen();
    return Scaffold(
      backgroundColor: _bg,
      body: Column(children: [
        // Header
        Container(color: _green, padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 12,
          left: 16, right: 16, bottom: 20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(width: 32, height: 32,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.12),
                  shape: BoxShape.circle),
                child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 16))),
            const SizedBox(height: 16),
            Text('Vendor Registration', style: GoogleFonts.plusJakartaSans(
              fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white)),
            const SizedBox(height: 4),
            Text('Apply to sell surprise bags on Surpl',
              style: GoogleFonts.plusJakartaSans(fontSize: 13, color: Colors.white60)),
          ])),

        Expanded(child: SingleChildScrollView(padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          _field('Shop / Restaurant Name *', _shopCtrl, Icons.storefront_rounded,
            'e.g. Sharma Bakery, Hotel Sai'),
          _field('Owner Full Name *', _ownerCtrl, Icons.person_rounded,
            'e.g. Rajesh Kumar Sharma'),
          _field('FSSAI License Number *', _fssaiCtrl, Icons.verified_rounded,
            '14-digit FSSAI number',
            keyboardType: TextInputType.number, maxLength: 14),
          _field('GSTIN (optional)', _gstinCtrl, Icons.receipt_long_rounded,
            '15-character GST number, if you have one',
            keyboardType: TextInputType.text, maxLength: 15),

          // FSSAI certificate photo — required, not just the number, since
          // a self-typed number alone can't be verified as genuine.
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('FSSAI Certificate Photo *', style: GoogleFonts.plusJakartaSans(
                fontSize: 12, fontWeight: FontWeight.w700, color: _textSec)),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: _pickFssaiCert,
                child: Container(
                  height: _fssaiCertFile != null ? 160 : 90,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _fssaiCertFile != null ? _green : _border,
                      width: _fssaiCertFile != null ? 2 : 1)),
                  child: _fssaiCertFile != null
                    ? Stack(fit: StackFit.expand, children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(11),
                          child: Image.file(File(_fssaiCertFile!.path), fit: BoxFit.cover)),
                        Positioned(top: 6, right: 6,
                          child: GestureDetector(
                            onTap: () => setState(() => _fssaiCertFile = null),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                              child: const Icon(Icons.close, color: Colors.white, size: 16)))),
                      ])
                    : Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.camera_alt_outlined, color: _textSec, size: 24),
                        const SizedBox(height: 6),
                        Text('Tap to upload a photo of your certificate',
                          style: GoogleFonts.plusJakartaSans(fontSize: 12, color: _textSec)),
                      ])),
                ),
              ),
            ]),
          ),

          _field('Shop Address *', _addressCtrl, Icons.location_on_rounded,
            'Full shop address', maxLines: 3),

          const SizedBox(height: 4),

          _field('Your Story (optional)', _storyCtrl, Icons.auto_stories_rounded,
            'How long have you run this shop? What are you known for? Customers see this on your listings.',
            maxLines: 3),

          const SizedBox(height: 4),

          // City picker
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border)),
            child: Row(children: [
              const Icon(Icons.location_city_rounded, color: _textSec, size: 18),
              const SizedBox(width: 10),
              Expanded(child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _city,
                  isExpanded: true,
                  style: const TextStyle(
                    fontSize: 14, color: _textDark,
                    fontWeight: FontWeight.w500),
                  items: const [
                    'Jagtial',
                    'Korutla',
                    'Karimnagar',
                    'Warangal',
                  ].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setState(() {
                    _city = v ?? _city;
                    // FIX: prevents a genuine crash - DropdownButton
                    // requires its value to exactly match an item in its
                    // own list. Without this reset, switching to a city
                    // whose area list doesn't contain the previously
                    // selected area (e.g. Jagtial's "Angadi Bazar" isn't
                    // valid for Korutla) throws a real assertion error.
                    if (!_areasForSelectedCity.contains(_shopArea)) {
                      _shopArea = _areasForSelectedCity.first;
                    }
                  }),
                ))),
            ])),

          const SizedBox(height: 4),

          // Area picker
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border)),
            child: Row(children: [
              const Icon(Icons.map_outlined, color: _textSec, size: 18),
              const SizedBox(width: 10),
              Expanded(child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _shopArea,
                  isExpanded: true,
                  style: const TextStyle(
                    fontSize: 14, color: _textDark,
                    fontWeight: FontWeight.w500),
                  items: _areasForSelectedCity
                      .map((a) => DropdownMenuItem(value: a, child: Text(a))).toList(),
                  onChanged: (v) => setState(() => _shopArea = v ?? _shopArea),
                ))),
            ])),

          const SizedBox(height: 4),

          // GPS location capture
          GestureDetector(
            onTap: _locating ? null : _captureLocation,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _shopLat != null ? _mintBg : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _shopLat != null ? _green : _border)),
              child: Row(children: [
                Container(width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: _shopLat != null ? _green : _bg,
                    shape: BoxShape.circle),
                  child: Icon(
                    _shopLat != null ? Icons.check_rounded : Icons.my_location_rounded,
                    color: _shopLat != null ? Colors.white : _textSec,
                    size: 18)),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  Text(
                    _shopLat != null
                        ? 'Location captured ✓'
                        : 'Capture shop location *',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13, fontWeight: FontWeight.w700,
                      color: _shopLat != null ? _green : _textDark)),
                  Text(
                    _shopLat != null
                        ? '${_shopLat!.toStringAsFixed(5)}, ${_shopLng!.toStringAsFixed(5)}'
                        : 'Stand at your shop and tap to capture GPS location',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11, color: _textSec)),
                ])),
                if (_locating) const SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _green)),
              ]))),

          const SizedBox(height: 4),

          // FSSAI warning
          Container(padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: const Color(0xFFFFF8E1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFFFE082))),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.info_outline_rounded, color: Color(0xFFE65100), size: 18),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('FSSAI Certificate Required', style: GoogleFonts.plusJakartaSans(
                  fontSize: 12, fontWeight: FontWeight.w700,
                  color: const Color(0xFFE65100))),
                const SizedBox(height: 4),
                Text('After submitting, the Surpl team will verify your FSSAI certificate manually before approving your account. This may take up to 24 hours.',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11, color: const Color(0xFF7A4F00), height: 1.4)),
              ])),
            ])),
          const SizedBox(height: 12),

          // No registration fee info
          Container(padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: _mintBg, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border)),
            child: Row(children: [
              const Icon(Icons.check_circle_outline, color: _green, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text(
                'No registration fee! Join Surpl free. We only charge 10% commission on completed orders. First 30 days: 0% commission.',
                style: GoogleFonts.plusJakartaSans(fontSize: 12, color: _green, height: 1.4))),
            ])),

          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                Icon(Icons.error_outline, color: Colors.red.shade700, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(_error!, style: GoogleFonts.plusJakartaSans(
                  fontSize: 12, color: Colors.red.shade700))),
              ])),
          ],

          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => setState(() => _agreedToVendorTerms = !_agreedToVendorTerms),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Checkbox(
                value: _agreedToVendorTerms,
                activeColor: _green,
                onChanged: (v) => setState(() => _agreedToVendorTerms = v ?? false)),
              Expanded(child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  'I\'ll keep my food fresh, safe, and hygienically prepared \u2014 same as I would for any customer walking into my shop.',
                  style: GoogleFonts.plusJakartaSans(fontSize: 12.5, color: Colors.black54)))),
            ]),
          ),

          const SizedBox(height: 24),

          SizedBox(width: double.infinity, child: ElevatedButton(
            onPressed: _submitting ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: _green,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0),
            child: _submitting
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
              : Text('Submit Application', style: GoogleFonts.plusJakartaSans(
                  fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)))),

          const SizedBox(height: 32),
        ]))),
      ]),
    );
  }

  Widget _successScreen() => Scaffold(
    backgroundColor: _bg,
    body: SafeArea(child: Center(child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 96, height: 96,
          decoration: BoxDecoration(color: _mintBg, shape: BoxShape.circle),
          child: const Icon(Icons.check_circle_rounded, color: _green, size: 56)),
        const SizedBox(height: 24),
        Text('Application Submitted! 🎉', textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 22, fontWeight: FontWeight.w800, color: _textDark)),
        const SizedBox(height: 12),
        Text('Your application is under review. Surpl will verify your FSSAI certificate and approve your account within 24 hours.',
          textAlign: TextAlign.center,
          style: GoogleFonts.plusJakartaSans(fontSize: 14, color: _textSec, height: 1.6)),
        const SizedBox(height: 32),
        SizedBox(width: double.infinity, child: ElevatedButton(
          onPressed: () => context.goNamed(HomeFeedWidget.routeName),
          style: ElevatedButton.styleFrom(
            backgroundColor: _green,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            elevation: 0),
          child: Text('Continue to Home', style: GoogleFonts.plusJakartaSans(
            fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)))),
      ])))));

  Widget _field(String label, TextEditingController ctrl, IconData icon, String hint,
      {TextInputType keyboardType = TextInputType.text,
       int maxLines = 1, int? maxLength}) =>
    Padding(padding: const EdgeInsets.only(bottom: 14), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: GoogleFonts.plusJakartaSans(
        fontSize: 12, fontWeight: FontWeight.w700, color: _textSec)),
      const SizedBox(height: 6),
      Container(
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _border)),
        child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Padding(padding: const EdgeInsets.only(left: 12),
            child: Icon(icon, size: 18, color: _textSec)),
          Expanded(child: TextField(
            controller: ctrl, keyboardType: keyboardType,
            maxLines: maxLines, maxLength: maxLength,
            decoration: InputDecoration(
              border: InputBorder.none, counterText: '',
              hintText: hint,
              hintStyle: GoogleFonts.plusJakartaSans(
                fontSize: 13, color: const Color(0xFFBBBBBB)),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 12),
              isDense: true),
            style: GoogleFonts.plusJakartaSans(fontSize: 14, color: _textDark))),
        ])),
    ]));
}