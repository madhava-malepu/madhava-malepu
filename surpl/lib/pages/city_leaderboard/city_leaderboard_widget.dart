import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'city_leaderboard_model.dart';
export 'city_leaderboard_model.dart';

const _kGreen = Color(0xFF1A4731);
const _kAmber = Color(0xFFF5A623);
const _kBgLight = Color(0xFFF4F7F4);
const _kBorder = Color(0xFFD4E8D4);
const _kTextDark = Color(0xFF0D1F12);
const _kTextSecondary = Color(0xFF4D6B57);

/// Reads the existing city_stats collection (already populated by the
/// city rescue counter) sorted by mealsRescued. Works fine with a single
/// city today and needs zero changes when Surpl expands to more cities —
/// each new city_stats doc just appears in the ranking automatically.
class CityLeaderboardWidget extends StatefulWidget {
  const CityLeaderboardWidget({super.key});
  static String routeName = 'CityLeaderboard';
  static String routePath = '/cityLeaderboard';
  @override
  State<CityLeaderboardWidget> createState() => _CityLeaderboardWidgetState();
}

class _CityLeaderboardWidgetState extends State<CityLeaderboardWidget> {
  late CityLeaderboardModel _model;

  @override
  void initState() {
    super.initState();
    _model = createModel(context, () => CityLeaderboardModel());
  }

  @override
  void dispose() {
    _model.dispose();
    super.dispose();
  }

  static const _medals = ['🥇', '🥈', '🥉'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBgLight,
      appBar: AppBar(
        backgroundColor: _kGreen,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        title: Text('City Leaderboard 🏆',
            style: GoogleFonts.plusJakartaSans(
                color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('city_stats')
            .orderBy('mealsRescued', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(_kGreen)));
          }
          final docs = snapshot.data!.docs;
          if (docs.isEmpty) {
            return Center(child: Text('No rescues yet',
                style: GoogleFonts.plusJakartaSans(color: _kTextSecondary)));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (docs.length == 1)
                Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _kAmber.withValues(alpha: 0.3))),
                  child: Row(children: [
                    const Text('🎉', style: TextStyle(fontSize: 20)),
                    const SizedBox(width: 10),
                    Expanded(child: Text(
                        'More cities join soon — right now you\'re #1 by default, but every rescue still counts!',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 12, color: const Color(0xFF7B4F00)))),
                  ]),
                ),
              ...docs.asMap().entries.map((e) {
                final rank = e.key;
                final data = e.value.data() as Map<String, dynamic>;
                final cityId = e.value.id;
                final cityName = data['cityName'] as String? ??
                    (cityId.isNotEmpty
                        ? '${cityId[0].toUpperCase()}${cityId.substring(1)}'
                        : 'Unknown');
                final meals = (data['mealsRescued'] as num?)?.toInt() ?? 0;

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: rank == 0 ? _kAmber : _kBorder,
                          width: rank == 0 ? 1.5 : 1)),
                  child: Row(children: [
                    SizedBox(
                      width: 32,
                      child: Text(
                        rank < 3 ? _medals[rank] : '#${rank + 1}',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: rank < 3 ? 20 : 14,
                            fontWeight: FontWeight.w700,
                            color: _kTextDark),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(cityName,
                          style: GoogleFonts.plusJakartaSans(
                              fontSize: 14, fontWeight: FontWeight.w700, color: _kTextDark)),
                    ),
                    Text('$meals meals',
                        style: GoogleFonts.plusJakartaSans(
                            fontSize: 13, fontWeight: FontWeight.w700, color: _kGreen)),
                  ]),
                );
              }),
            ],
          );
        },
      ),
    );
  }
}
