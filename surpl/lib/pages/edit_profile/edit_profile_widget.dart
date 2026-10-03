import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '/auth/firebase_auth/auth_util.dart';
import '/flutter_flow/flutter_flow_util.dart';

const _kGreen = Color(0xFF1A4731);
const _kAmber = Color(0xFFF5A623);
const _kBgLight = Color(0xFFF4F7F4);
const _kBorder = Color(0xFFD4E8D4);
const _kTextDark = Color(0xFF0D1F12);
const _kTextSecondary = Color(0xFF4D6B57);
const _kMintBg = Color(0xFFE6F4ED);

class EditProfileWidget extends StatefulWidget {
  const EditProfileWidget({super.key});
  static String routeName = 'EditProfile';
  static String routePath = '/editProfile';
  @override
  State<EditProfileWidget> createState() => _EditProfileWidgetState();
}

class _EditProfileWidgetState extends State<EditProfileWidget> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  bool _saving = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    // FIX: the avatar initial read the controller's text directly in
    // build() with no listener, so it never actually updated while
    // typing - only appeared to update coincidentally when some other
    // setState fired (e.g. after the initial load).
    _nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users').doc(currentUserUid).get();
      final data = doc.data();
      if (mounted) {
        _nameController.text = data?['name'] as String? ?? '';
        _emailController.text = data?['email'] as String? ?? currentUserEmail;
        setState(() => _loaded = true);
      }
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name'), backgroundColor: Colors.red));
      return;
    }
    if (name.length > 50) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Name is too long - please keep it under 50 characters.'), backgroundColor: Colors.red));
      return;
    }
    final email = _emailController.text.trim();
    // FIX: this field previously accepted any text as a valid email -
    // only checked when non-empty, since the field is explicitly
    // optional.
    if (email.isNotEmpty && !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('That doesn\'t look like a valid email address.'), backgroundColor: Colors.red));
      return;
    }

    setState(() => _saving = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(currentUserUid).set({
        'name': name,
        'email': _emailController.text.trim(),
        'phoneNumber': currentPhoneNumber,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated ✅'), backgroundColor: _kGreen));
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Couldn\'t save your changes — please try again.'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBgLight,
      body: Column(children: [
        Container(
          color: _kGreen,
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 12, left: 16, right: 16, bottom: 16),
          child: Row(children: [
            GestureDetector(
              onTap: () => context.pop(),
              child: Container(width: 36, height: 36,
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.arrow_back_rounded, color: Colors.white, size: 20))),
            const SizedBox(width: 12),
            Text('Edit Profile', style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: -0.3)),
          ]),
        ),
        Expanded(child: !_loaded
          ? const Center(child: CircularProgressIndicator(color: _kGreen))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                const SizedBox(height: 8),
                // Avatar
                Center(child: Container(
                  width: 88, height: 88,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: _kGreen, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.14),
                        blurRadius: 14, offset: const Offset(0, 5)),
                      BoxShadow(
                        color: _kGreen.withValues(alpha: 0.20),
                        blurRadius: 8, offset: const Offset(0, 2)),
                    ]),
                  child: Container(
                    width: 88, height: 88,
                    decoration: const BoxDecoration(color: _kAmber, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Text(
                      _nameController.text.isNotEmpty ? _nameController.text[0].toUpperCase() : 'S',
                      style: GoogleFonts.plusJakartaSans(fontSize: 32, fontWeight: FontWeight.w800, color: _kGreen))))),
                const SizedBox(height: 8),
                Center(child: Text(currentPhoneNumber.isNotEmpty ? currentPhoneNumber : 'No phone',
                  style: GoogleFonts.plusJakartaSans(fontSize: 13, color: _kTextSecondary))),
                const SizedBox(height: 28),

                _label('Full Name'),
                _field(_nameController, 'e.g. Ravi Kumar', TextInputType.name, maxLength: 50),
                const SizedBox(height: 16),

                _label('Email Address (optional)'),
                _field(_emailController, 'e.g. ravi@email.com', TextInputType.emailAddress, maxLength: 100),
                const SizedBox(height: 8),

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: _kMintBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: _kBorder)),
                  child: Row(children: [
                    const Icon(Icons.phone_rounded, color: _kGreen, size: 16),
                    const SizedBox(width: 8),
                    Expanded(child: Text('Phone number cannot be changed. Contact support to update.',
                      style: GoogleFonts.plusJakartaSans(fontSize: 11, color: _kTextSecondary, height: 1.4))),
                  ])),
                const SizedBox(height: 32),

                DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: _saving ? [] : [
                      BoxShadow(
                        color: _kGreen.withValues(alpha: 0.35),
                        blurRadius: 14, offset: const Offset(0, 5)),
                      BoxShadow(
                        color: _kGreen.withValues(alpha: 0.12),
                        blurRadius: 6, offset: const Offset(0, 2)),
                    ]),
                  child: Material(
                    color: _saving ? _kGreen.withValues(alpha: 0.6) : _kGreen,
                    borderRadius: BorderRadius.circular(14),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: _saving ? null : _save,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        alignment: Alignment.center,
                        child: _saving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text('Save Changes', style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFFFBF3E4), letterSpacing: -0.3))),
                    ),
                  ),
                ),
              ]),
            )),
      ]),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: _kTextDark)));

  Widget _field(TextEditingController ctrl, String hint, TextInputType type, {int? maxLength}) =>
    TextField(
      controller: ctrl,
      keyboardType: type,
      maxLength: maxLength,
      style: GoogleFonts.plusJakartaSans(fontSize: 15, color: _kTextDark),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.plusJakartaSans(fontSize: 14, color: _kTextSecondary.withValues(alpha: 0.5)),
        filled: true, fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: _kGreen, width: 1.5)),
      ));
}