// ════════════════════════════════════════════════════════
//  lib/services/location_service.dart
//  Handles: customer location, distance to vendor,
//           opening Google Maps for navigation
// ════════════════════════════════════════════════════════

import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

class LocationService {
  static Position? _lastPosition;
  static const cacheMaxAge = Duration(minutes: 5);

  static bool validCoordinates(double? lat, double? lng) =>
      lat != null && lng != null && lat.isFinite && lng.isFinite &&
      lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180 &&
      !(lat == 0 && lng == 0);

  static (double, double)? vendorCoordinates(Map<String, dynamic> data) {
    for (final fields in [('shopLat', 'shopLng'), ('vendorLat', 'vendorLng')]) {
      final a = data[fields.$1];
      final b = data[fields.$2];
      final lat = a is num ? a.toDouble() : null;
      final lng = b is num ? b.toDouble() : null;
      if (validCoordinates(lat, lng)) return (lat!, lng!);
    }
    return null;
  }

  static bool freshPosition(Position? position, {DateTime? now}) {
    if (position == null || !validCoordinates(position.latitude, position.longitude)) return false;
    final age = (now ?? DateTime.now()).difference(position.timestamp);
    return !age.isNegative && age <= cacheMaxAge;
  }

  // ── Get current customer location ──────────────────────
  static Future<Position?> getCurrentLocation() async {
    try {
      // Check permission
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
        if (perm == LocationPermission.denied) return null;
      }
      if (perm == LocationPermission.deniedForever) return null;

      // Check if location service is enabled
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return null;

      // Get position
      _lastPosition = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );
      return freshPosition(_lastPosition) ? _lastPosition : null;
    } catch (_) {
      return freshPosition(_lastPosition) ? _lastPosition : null;
    }
  }

  // ── Calculate distance in km ────────────────────────────
  static double? distanceKm(
    double? customerLat, double? customerLng,
    double? vendorLat, double? vendorLng,
  ) {
    if (!validCoordinates(customerLat, customerLng) ||
        !validCoordinates(vendorLat, vendorLng)) return null;
    const R = 6371.0; // Earth radius in km
    final dLat = _toRad(vendorLat! - customerLat!);
    final dLng = _toRad(vendorLng! - customerLng!);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(customerLat)) *
            cos(_toRad(vendorLat)) *
            sin(dLng / 2) * sin(dLng / 2);
    final stable = a.clamp(0.0, 1.0);
    final c = 2 * atan2(sqrt(stable), sqrt(1 - stable));
    return R * c;
  }

  static double _toRad(double deg) => deg * pi / 180;

  // ── Format distance nicely ──────────────────────────────
  static String formatDistance(double? km) {
    if (km == null || !km.isFinite || km < 0) return '';
    if (km < 1) return '${(km * 1000).round()}m away';
    if (km < 10) return '${km.toStringAsFixed(1)}km away';
    return '${km.round()}km away';
  }

  // ── Open Google Maps for navigation ────────────────────
  // Opens turn-by-turn directions to vendor location
  static Future<void> navigateToVendor({
    required double vendorLat,
    required double vendorLng,
    required String vendorName,
  }) async {
    if (!validCoordinates(vendorLat, vendorLng)) {
      await navigateToAddress(vendorName);
      return;
    }
    // Try Google Maps app first
    final googleMapsUrl = Uri.parse(
      'google.navigation:q=$vendorLat,$vendorLng&mode=d'
    );
    // Fallback to browser Google Maps
    final googleMapsBrowser = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=$vendorLat,$vendorLng'
      '&destination_place_name=${Uri.encodeComponent(vendorName)}'
      '&travelmode=driving'
    );

    // Try Google Maps app first, fall back to browser if it's not available
    // or not handled. canLaunchUrl() can false-negative on Android 11+
    // without a matching <queries> manifest entry, so we don't gate on it —
    // we just try the app scheme and fall back on failure.
    try {
      if (await launchUrl(googleMapsUrl)) return;
    } catch (_) {}
    await launchUrl(googleMapsBrowser, mode: LaunchMode.externalApplication);
  }

  // ── Open Google Maps with just an address ──────────────
  // Fallback when lat/lng not available — use shop address
  static Future<void> navigateToAddress(String address) async {
    final encoded = Uri.encodeComponent(address);
    final url = Uri.parse(
        'https://www.google.com/maps/search/?api=1&query=$encoded');
    await launchUrl(url, mode: LaunchMode.externalApplication);
  }
}
