import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

const _green = Color(0xFF1A4731);
const _amber = Color(0xFFF5A623);
const _lightGreen = Color(0xFFE8F5EE);
const _bg = Color(0xFFF5F8F5);

class RescueFeedWidget extends StatefulWidget {
  const RescueFeedWidget({super.key});
  static String routeName = 'RescueFeed';
  static String routePath = '/rescueFeed';
  @override
  State<RescueFeedWidget> createState() => _RescueFeedWidgetState();
}

class _RescueFeedWidgetState extends State<RescueFeedWidget> {
  bool _uploading = false;
  String _userCity = 'Jagtial';

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    _loadUserCity();
  }

  Future<void> _loadUserCity() async {
    if (_uid == null) return;
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users').doc(_uid).get();
      final city = userDoc.data()?['city'] as String?;
      if (mounted && city != null) setState(() => _userCity = city);
    } catch (_) {
      // Keep default Jagtial if this fails - matches the same safe
      // fallback pattern used elsewhere in the app.
    }
  }

  Future<void> _postHaul() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 75,
      maxWidth: 1080,
    );
    if (picked == null || !mounted) return;

    setState(() => _uploading = true);
    try {
      // Upload image
      final file = File(picked.path);
      final ref = FirebaseStorage.instance
          .ref()
          .child('rescue_feed')
          .child('${_uid}_${DateTime.now().millisecondsSinceEpoch}.jpg');
      final snap = await ref.putFile(file,
          SettableMetadata(contentType: 'image/jpeg'));
      final url = await snap.ref.getDownloadURL();

      // Get user name
      final userDoc = await FirebaseFirestore.instance
          .collection('users').doc(_uid).get();
      final name = userDoc.data()?['name'] as String? ?? 'Surpl User';

      // Save to Firestore
      await FirebaseFirestore.instance.collection('rescue_feed').add({
        'userId': _uid,
        'userName': name,
        'imageUrl': url,
        'city': _userCity,
        'likes': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update city rescue counter
      await FirebaseFirestore.instance
          .collection('city_stats')
          .doc(_userCity.toLowerCase())
          .set({
        'mealsRescued': FieldValue.increment(0),
        'haulPosts': FieldValue.increment(1),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Your haul is posted! 🎉'),
          backgroundColor: _green,
        ));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not post. Try again.'),
          backgroundColor: Colors.red.shade700,
        ));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _likePost(String docId, int currentLikes) async {
    // FIX: previously computed and sent the new absolute value
    // client-side (currentLikes + 1) - vulnerable to a client sending
    // any number it wants, and to a lost-update race condition when two
    // people liked the same post at nearly the same time. An atomic
    // increment is both safe and race-free.
    await FirebaseFirestore.instance
        .collection('rescue_feed')
        .doc(docId)
        .update({'likes': FieldValue.increment(1)});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: Column(children: [
        // Header
        Container(
          color: _green,
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 12,
            left: 16, right: 16, bottom: 16),
          child: Column(children: [
            Row(children: [
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Rescue Feed 🌱',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 20, fontWeight: FontWeight.w800,
                      color: Colors.white)),
                  Text('See what $_userCity rescued today',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12, color: Colors.white.withValues(alpha: 0.7))),
                ])),
              GestureDetector(
                onTap: _uploading ? null : _postHaul,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: _amber,
                    borderRadius: BorderRadius.circular(10)),
                  child: _uploading
                    ? const SizedBox(width: 18, height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                    : Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.camera_alt_rounded,
                          color: Color(0xFF1A4731), size: 16),
                        const SizedBox(width: 6),
                        Text('Post my haul',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13, fontWeight: FontWeight.w700,
                            color: const Color(0xFF1A4731))),
                      ])),
              ),
            ]),
          ])),

        // Feed
        Expanded(child: StreamBuilder<QuerySnapshot>(
          // No .orderBy() here - combining .where() with .orderBy() on a
          // different field requires a Firestore composite index, which
          // if missing causes this entire feed to fail silently. Fetch
          // a larger batch and sort client-side instead, so this never
          // depends on that index existing.
          stream: FirebaseFirestore.instance
              .collection('rescue_feed')
              .where('city', isEqualTo: _userCity)
              .limit(100)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator(
                color: _green));
            }
            final docs = List<QueryDocumentSnapshot>.from(snapshot.data!.docs);
            docs.sort((a, b) {
              final tsA = (a.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
              final tsB = (b.data() as Map<String, dynamic>)['createdAt'] as Timestamp?;
              if (tsA == null || tsB == null) return 0;
              return tsB.compareTo(tsA);
            });
            final visibleDocs = docs.take(50).toList();
            if (visibleDocs.isEmpty) {
              return Center(child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('📷', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 16),
                  Text('No hauls yet — be the first!',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16, fontWeight: FontWeight.w700,
                      color: _green)),
                  const SizedBox(height: 8),
                  Text('After collecting your bag, tap\n"Post my haul" to share it',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13, color: Colors.grey.shade500)),
                ]));
            }
            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: visibleDocs.length,
              itemBuilder: (context, i) {
                final data = visibleDocs[i].data() as Map<String, dynamic>;
                final name = data['userName'] as String? ?? 'Surpl User';
                final imageUrl = data['imageUrl'] as String? ?? '';
                final likes = (data['likes'] as int?) ?? 0;
                final ts = data['createdAt'] as Timestamp?;
                final timeAgo = ts != null
                  ? _timeAgo(ts.toDate()) : '';
                final isMyPost = data['userId'] == _uid;

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.grey.shade100)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    // User row
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                      child: Row(children: [
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: _amber,
                            borderRadius: BorderRadius.circular(10)),
                          alignment: Alignment.center,
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'S',
                            style: const TextStyle(
                              color: _green, fontSize: 16,
                              fontWeight: FontWeight.w800))),
                        const SizedBox(width: 10),
                        Expanded(child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                          Text(isMyPost ? '$name (you)' : name,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13, fontWeight: FontWeight.w700,
                              color: const Color(0xFF0D1F12))),
                          Text('rescued a bag · $timeAgo',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: Colors.grey.shade500)),
                        ])),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: _lightGreen,
                            borderRadius: BorderRadius.circular(8)),
                          child: const Text('🌱 Rescued',
                            style: TextStyle(
                              color: _green, fontSize: 10,
                              fontWeight: FontWeight.w600))),
                      ])),
                    // Image
                    if (imageUrl.isNotEmpty)
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.zero),
                        child: CachedNetworkImage(
                          imageUrl: imageUrl,
                          width: double.infinity,
                          height: 240,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                            height: 100, color: _lightGreen,
                            alignment: Alignment.center,
                            child: const Icon(Icons.image_outlined,
                              color: _green, size: 32)))),
                    // Like row
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                      child: Row(children: [
                        GestureDetector(
                          onTap: () => _likePost(docs[i].id, likes),
                          child: Row(children: [
                            const Text('❤️', style: TextStyle(fontSize: 18)),
                            const SizedBox(width: 6),
                            Text('$likes',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13, fontWeight: FontWeight.w600,
                                color: Colors.grey.shade600)),
                          ])),
                        const SizedBox(width: 16),
                        Text('Tap to like this rescue!',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12, color: Colors.grey.shade400)),
                      ])),
                  ]));
              });
          })),
      ]),
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }
}
