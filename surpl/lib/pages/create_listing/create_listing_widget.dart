import 'dart:async';
import 'dart:io';
import 'dart:io';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import '/auth/firebase_auth/auth_util.dart';
import '/utils/input_sanitizer.dart';
import '/flutter_flow/flutter_flow_util.dart';
import '/services/location_service.dart';
import '/services/ecosystem_service.dart';
import '/components/listing_type_selector.dart';

class CreateListingWidget extends StatefulWidget {
  final String? editBagId;
  const CreateListingWidget({Key? key, this.editBagId}) : super(key: key);
  static String get routeName => 'CreateListing';
  static String get routePath => '/createListing';
  @override
  State<CreateListingWidget> createState() => _CreateListingWidgetState();
}

const int kMinBagPrice = 29;

class _CreateListingWidgetState extends State<CreateListingWidget> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _originalPriceController = TextEditingController();
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');
  final _addressController = TextEditingController(); // NEW

  String _selectedCategory = 'Bakery';
  String _foodType = 'veg'; // 'veg' or 'nonveg' — separate from category,
  // matches the Zomato/Swiggy pattern of a distinct veg/non-veg indicator
  // rather than folding it into the cuisine category list.
  XFile? _imageFile;
  bool _isSubmitting = false;
  bool _uploadingImage = false;
  double _uploadProgress = 0; // 0..1, shown on the button while a photo uploads
  String? _lastUploadErrorDetail; // the REAL cause, for diagnosis - never shown raw to the vendor
  String? _errorMessage;
  bool _isEditMode = false;
  String? _existingImageUrl;

  TimeOfDay? _pickupFrom;
  TimeOfDay? _pickupTo;
  DateTime _pickupDate = DateTime.now();

  // NEW — location
  Position? _vendorPosition;
  (double, double)? _savedVendorCoordinates;
  String _failureStage = 'local_file';
  bool _loadingLocation = false;

  final List<String> _categories = ['Bakery', 'Restaurant', 'Cafe', 'Grocery', 'Sweets', 'Other'];

  // ── Local Kitchens (fresh food) — snack stalls only: chaat, samosa,
  // bajji, and similar. Not restaurants/tiffin/dhabas.
  String _listingType = 'surplus'; // 'surplus' or 'freshFood'
  String _snackType = 'chaat';
  bool _isFreshFoodApproved = false;
  String _registeredShopName = '';
  static const _snackTypes = [
    ('chaat', '🍛 Chaat'),
    ('samosa', '🥟 Samosa / Kachori'),
    ('bajji', '🍤 Bajji / Fritters'),
    ('other_snack', '🥘 Other Snacks'),
  ];

  static const _green = Color(0xFF1A4731);
  static const _amber = Color(0xFFF5A623);
  static const _lightGreen = Color(0xFFE8F5EE);

  // Live clock — shown next to the pickup-window pickers so a vendor can
  // see the actual current time while choosing a window, instead of
  // guessing whether "7 PM" is even still ahead of them right now.
  Timer? _clockTimer;
  DateTime _now = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30));

  @override
  void initState() {
    super.initState();
    if (widget.editBagId != null) {
      _isEditMode = true;
      _loadExistingBag(widget.editBagId!);
    }
    _loadFreshFoodApproval();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now().toUtc().add(const Duration(hours: 5, minutes: 30)));
    });
  }

  Future<void> _loadFreshFoodApproval() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users').doc(currentUserUid).get();
      final approved = doc.data()?['isFreshFoodApproved'] as bool? ?? false;
      final name = doc.data()?['shopName'] as String? ?? '';
      if (mounted) setState(() {
        _isFreshFoodApproved = approved;
        _registeredShopName = name;
      });
    } catch (_) {}
  }

  Future<void> _loadExistingBag(String bagId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('bags').doc(bagId).get();
      if (!doc.exists || !mounted) return;
      final d = doc.data()!;
      setState(() {
        _titleController.text = d['title'] as String? ?? '';
        _descController.text = d['description'] as String? ?? '';
        _originalPriceController.text =
            (d['originalPrice'] as num?)?.toStringAsFixed(0) ?? '';
        _priceController.text =
            (d['price'] as num?)?.toStringAsFixed(0) ?? '';
        _quantityController.text =
            (d['availableQuantity'] as num?)?.toInt().toString() ?? '1';
        _selectedCategory = d['category'] as String? ?? 'Bakery';
        _foodType = d['foodType'] as String? ?? 'veg';
        _listingType = d['listingType'] as String? ?? 'surplus';
        // Migrate old-style data: a freshFood listing that was NOT
        // full-price under the old toggle was genuinely a discounted
        // listing - that's now the separate 'happyHour' type, not a
        // sub-choice within freshFood.
        if (_listingType == 'freshFood' &&
            (d['isSkipQueueFullPrice'] as bool? ?? true) == false) {
          _listingType = 'happyHour';
        }
        _snackType = d['snackType'] as String? ?? 'chaat';
        _existingImageUrl = d['image'] as String?;
        _addressController.text = d['vendorAddress'] as String? ?? '';
        final pickupStart = d['pickupStart'] as String? ?? '';
        final pickupEnd = d['pickupEnd'] as String? ?? '';
        if (pickupStart.isNotEmpty) _pickupFrom = _parseTime(pickupStart);
        if (pickupEnd.isNotEmpty) _pickupTo = _parseTime(pickupEnd);
        _savedVendorCoordinates = LocationService.vendorCoordinates(d);
      });
    } catch (_) {}
  }

  TimeOfDay? _parseTime(String timeStr) {
    try {
      final parts = timeStr.trim().split(' ');
      final timeParts = parts[0].split(':');
      int hour = int.parse(timeParts[0]);
      final minute = int.parse(timeParts[1]);
      final isPm = parts.length > 1 && parts[1].toUpperCase() == 'PM';
      if (isPm && hour != 12) hour += 12;
      if (!isPm && hour == 12) hour = 0;
      return TimeOfDay(hour: hour, minute: minute);
    } catch (_) { return null; }
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    _titleController.dispose();
    _descController.dispose();
    _originalPriceController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    _addressController.dispose(); // NEW
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
          source: ImageSource.gallery, imageQuality: 75, maxWidth: 1000);
      if (picked != null && mounted) {
        setState(() => _imageFile = picked);
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = 'Could not pick image. Please try again.');
    }
  }

  // Writes the real upload failure to an admin-only Firestore collection,
  // so it can be diagnosed centrally without ever showing a raw error to
  // the vendor. Best-effort and silent on failure - logging a problem
  // must never itself become a NEW problem the vendor has to deal with.
  Future<void> _logUploadFailure(String detail) async {
    try {
      await FirebaseFirestore.instance.collection('uploadFailureLogs').add({
        'vendorId': currentUserUid,
        'errorDetail': detail,
        'stage': _failureStage,
        'bucket': FirebaseStorage.instance.bucket,
        'context': 'bag_listing_photo',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {
      // Deliberately swallowed - if even the LOG can't be written (e.g.
      // no connection at all), there's nothing further to do here, and
      // the vendor's own retry/skip-photo options already cover them.
    }
  }

  // Uploads the bag photo and returns its download URL, or null if it
  // could not be uploaded. FIX: this used to wait with no time limit - on a
  // weak connection the Firebase SDK keeps retrying for up to 10 MINUTES by
  // default, so the vendor saw "Uploading photo..." spin forever and could
  // not list. It now gives up after 30s of retrying / 60s overall, and
  // shows live progress so a slow-but-working upload is visibly moving.
  Future<String?> _uploadImage(String bagId) async {
    if (_imageFile == null) return null;
    setState(() { _uploadingImage = true; _uploadProgress = 0; });
    _lastUploadErrorDetail = null;
    try {
      _failureStage = 'local_file';
      final bytes = await _imageFile!.readAsBytes();
      if (bytes.isEmpty || bytes.length >= 10 * 1024 * 1024) {
        throw const FormatException('Photo must be between 1 byte and 10 MB.');
      }
      final jpeg = bytes.length > 2 && bytes[0] == 255 && bytes[1] == 216;
      final png = bytes.length > 8 && bytes[0] == 137 && bytes[1] == 80 && bytes[2] == 78 && bytes[3] == 71;
      final webp = bytes.length > 12 && String.fromCharCodes(bytes.sublist(0, 4)) == 'RIFF' &&
          String.fromCharCodes(bytes.sublist(8, 12)) == 'WEBP';
      if (!jpeg && !png && !webp) throw const FormatException('Choose a JPEG, PNG or WebP photo.');
      final extension = jpeg ? 'jpg' : (png ? 'png' : 'webp');
      // Owner-scoped path is secure even BEFORE the bag document exists.
      final storage = FirebaseStorage.instance;
      storage.setMaxUploadRetryTime(const Duration(seconds: 30));
      final ref = storage.ref('bag_images/$currentUserUid/$bagId.$extension');
      _failureStage = 'upload';
      final task = ref.putData(bytes, SettableMetadata(contentType: jpeg ? 'image/jpeg' : 'image/$extension'));
      final subscription = task.snapshotEvents.listen((snapshot) {
        if (mounted && snapshot.totalBytes > 0) {
          setState(() => _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes);
        }
      }, onError: (Object _) {}); // The awaited task below captures the actual error.
      try {
        await task.timeout(const Duration(seconds: 60), onTimeout: () async {
          await task.cancel();
          throw TimeoutException('Upload timed out');
        });
        _failureStage = 'download_url';
        return await ref.getDownloadURL().timeout(const Duration(seconds: 20));
      } finally {
        await subscription.cancel();
      }
    } catch (e) {
      final code = e is FirebaseException ? e.code : (e is TimeoutException ? 'timeout' : 'invalid-local-image');
      _lastUploadErrorDetail = '$_failureStage:$code';
      debugPrint('Listing photo failure: $_lastUploadErrorDetail');
      return null;
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  Future<void> _pickTime(bool isFrom) async {
    final initial = isFrom
        ? (_pickupFrom ?? TimeOfDay.now())
        : (_pickupTo ?? TimeOfDay.now());
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(primary: _green)),
        child: child!),
    );
    if (picked != null) {
      setState(() { if (isFrom) _pickupFrom = picked; else _pickupTo = picked; });
    }
  }

  String _formatTime(TimeOfDay? t) {
    if (t == null) return '';
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $period';
  }

  // IMPORTANT: DateTime(y,m,d,h,min) without explicit UTC handling uses the
  // DEVICE's local timezone, not IST specifically. If a vendor's phone isn't
  // set to IST, this silently produces the wrong millisecondsSinceEpoch,
  // which can make a bag appear already-expired the moment it's created.
  // Always compute IST explicitly via UTC arithmetic, independent of
  // whatever timezone the device itself is set to.
  static const _istOffset = Duration(hours: 5, minutes: 30);

  int _pickupEndMillis() {
    if (_pickupTo == null) return 0;
    final istNaive = DateTime.utc(_pickupDate.year, _pickupDate.month,
        _pickupDate.day, _pickupTo!.hour, _pickupTo!.minute);
    final utcInstant = istNaive.subtract(_istOffset);
    return utcInstant.millisecondsSinceEpoch;
  }

  int _pickupStartMillis() {
    if (_pickupFrom == null) return 0;
    final istNaive = DateTime.utc(_pickupDate.year, _pickupDate.month,
        _pickupDate.day, _pickupFrom!.hour, _pickupFrom!.minute);
    final utcInstant = istNaive.subtract(_istOffset);
    return utcInstant.millisecondsSinceEpoch;
  }

  // NEW — capture vendor GPS location
  Future<void> _captureLocation() async {
    setState(() => _loadingLocation = true);
    try {
      final pos = await LocationService.getCurrentLocation();
      if (mounted) {
        setState(() {
          _vendorPosition = pos;
          _loadingLocation = false;
        });
        if (pos != null) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Shop location saved ✅ Customers can navigate to you'),
              backgroundColor: _green));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: const Text('Could not get location. Please enable GPS.'),
              backgroundColor: Colors.red.shade700));
        }
      }
    } catch (_) {
      if (mounted) setState(() => _loadingLocation = false);
    }
  }

  Future<void> _submit() async {
    if (_listingType == 'freshFood' && !_isFreshFoodApproved) {
      setState(() => _errorMessage =
          'Skip the Queue needs admin approval. You can list a Surprise Bag or Happy Hour now.');
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    if (_imageFile == null &&
        (_existingImageUrl == null || _existingImageUrl!.isEmpty)) {
      setState(() => _errorMessage = 'Please add a photo of your bag');
      return;
    }
    if (_pickupFrom == null || _pickupTo == null) {
      setState(() => _errorMessage = 'Please set both pickup times');
      return;
    }

    final price = double.tryParse(_priceController.text.trim()) ?? 0;
    if (price < kMinBagPrice) {
      setState(() => _errorMessage = 'Minimum bag price is Rs.$kMinBagPrice');
      return;
    }
    // Confirmed decision: the vendor's own number (what they type here)
    // must stay exactly what their payout and Surpl's commission are
    // based on - never inflated, never reduced. The customer-facing
    // price is a separate number with 5% GST built in silently, so a
    // customer sees one simple bag price (already including it) rather
    // than a visible "GST" line, and the vendor never sees this
    // calculation happen on their own screen at all.
    // Per the confirmed final decision: customer sees exactly the
    // vendor's entered price as the bag price - no markup, no inflated
    // number. GST is tracked separately in the backend (see checkout_widget.dart)
    // and absorbed from Surpl's own commission, never shown to or paid
    // by the customer or the vendor.
    final vendorBasePrice = price;

    final originalPriceCheck =
        double.tryParse(_originalPriceController.text.trim()) ?? 0;

    // Fraud-prevention check: "Skip the Queue" is defined as full price,
    // no discount — that's WHY it's commission-free. A vendor cannot
    // claim Skip the Queue while also setting a discounted price, since
    // that would mean claiming the 0%-commission label for what is
    // actually a discounted "Special Offer" listing. This is checked
    // against the vendor's own entered price data, not their toggle
    // selection alone, so it can't be talked around — the numbers have
    // to genuinely match what they're claiming.
    if (_listingType == 'freshFood' && originalPriceCheck > price) {
      setState(() => _errorMessage =
          '"Skip the Queue" must be full price (no discount) — that\'s why '
          'it\'s commission-free. Either set the original price equal to '
          'the selling price, or switch to "Happy Hour" if you want to '
          'offer a discount.');
      return;
    }

    // FIX: quantity was never validated before submission - a vendor
    // could end up with "0" in this freely-editable text field (typed
    // directly, or briefly cleared while adjusting it) and the app would
    // silently create a bag with availableQuantity: 0, making it show as
    // "Sold Out" the instant it's listed. Confirmed by direct evidence:
    // a bag listed one minute earlier already showing 0 left.
    final parsedQuantity = int.tryParse(_quantityController.text.trim());
    if (parsedQuantity == null || parsedQuantity < 1) {
      setState(() => _errorMessage =
          'Please enter a valid quantity of at least 1 before listing.');
      return;
    }

    setState(() { _isSubmitting = true; _errorMessage = null; });

    try {
      final originalPrice =
          double.tryParse(_originalPriceController.text.trim()) ?? 0;
      final quantity = parsedQuantity;
      final savingsPct = originalPrice > 0
          ? ((originalPrice - price) / originalPrice * 100).round() : 0;

      String shopArea = 'Other Area';
      String city = 'Jagtial';
      String shopName = 'Local Vendor';
      String fssaiNumber = '';
      String vendorStory = '';
      double? shopLat;
      double? shopLng;
      try {
        final userDoc = await FirebaseFirestore.instance
            .collection('users').doc(currentUserUid).get();
        shopArea = userDoc.data()?['shopArea'] as String? ?? 'Other Area';
        city = userDoc.data()?['city'] as String? ?? 'Jagtial';
        final registeredShopName = userDoc.data()?['shopName'] as String?;
        if (registeredShopName != null && registeredShopName.isNotEmpty) {
          shopName = registeredShopName;
        }
        fssaiNumber = userDoc.data()?['fssaiNumber'] as String? ?? '';
        vendorStory = userDoc.data()?['vendorStory'] as String? ?? '';
        shopLat = (userDoc.data()?['shopLat'] as num?)?.toDouble();
        shopLng = (userDoc.data()?['shopLng'] as num?)?.toDouble();
      } catch (_) {}

      // The actual root cause of customers confusing one restaurant for
      // another: shopName silently kept its 'Local Vendor' placeholder
      // whenever the read above failed for ANY reason (network blip,
      // timing, anything) - catch (_) {} swallowed it completely, and
      // the listing still got created. That's not a display glitch, it's
      // bad data written permanently into the bag - every screen a
      // customer sees afterward (listing, cart, checkout, confirmation,
      // order history) shows the same generic label. If two different
      // vendors ever hit this same failure, their listings become
      // genuinely indistinguishable. A blocked listing that asks the
      // vendor to retry is a minor inconvenience; a permanently
      // mislabeled one actively confuses real customers - not an
      // acceptable trade to make silently.
      if (shopName == 'Local Vendor') {
        setState(() {
          _errorMessage = "Couldn't confirm your shop name just now - please check your connection and try again. (Your listing was not created.)";
          _isSubmitting = false;
        });
        return;
      }

      final isEdit = _isEditMode && widget.editBagId != null;
      final docRef = isEdit
          ? FirebaseFirestore.instance.collection('bags').doc(widget.editBagId)
          : FirebaseFirestore.instance.collection('bags').doc();
      final bagId = docRef.id;

      String? imageUrl;
      if (_imageFile != null) {
        imageUrl = await _uploadImage(bagId);
        if (imageUrl == null) {
          // FIX: a vendor must never see a raw backend error string -
          // that's a real red flag (looks broken/unprofessional, and
          // can leak technical detail that isn't theirs to see). The
          // message shown here is now always plain and generic. The
          // REAL cause still gets captured - just routed to an
          // admin-only log instead of the vendor's screen, so this can
          // still be diagnosed without exposing anything to them.
          final detail = _lastUploadErrorDetail ?? 'unknown';
          final isTimeout = detail.contains('timeout');
          _logUploadFailure(detail); // best-effort, never blocks the vendor
          if (mounted) {
            setState(() {
              _errorMessage = isTimeout
                  ? "Your photo is taking too long to upload - please check your internet and try again. (Your listing was not created.)"
                  : "Your photo couldn't upload right now - please try again in a minute. (Your listing was not created.)";
              _isSubmitting = false;
            });
          }
          return;
        }
      } else {
        imageUrl = _existingImageUrl;
      }

      final bagData = <String, dynamic>{
        'title': InputSanitizer.sanitizeTitle(_titleController.text),
        'description': InputSanitizer.sanitizeText(
            _descController.text, maxLength: 500),
        'category': InputSanitizer.sanitizeText(
            _selectedCategory, maxLength: 50),
        'foodType': _foodType,
        'isSkipQueueFullPrice': _listingType == 'freshFood',
        'listingType': _listingType,
        if (_listingType == 'freshFood') 'snackType': _snackType,
        'originalPrice': originalPrice,
        'price': vendorBasePrice,
        'vendorBasePrice': vendorBasePrice,
        'availableQuantity': quantity,
        'totalQuantity': quantity,
        'pickupStart': _formatTime(_pickupFrom),
        'pickupEnd': _formatTime(_pickupTo),
        'pickupEndMillis': _pickupEndMillis(),
        'pickupStartMillis': _pickupStartMillis(),
        'merchantId': currentUserUid,
        'merchantName': shopName,
        'shopArea': shopArea,
        'city': city,
        'fssaiNumber': fssaiNumber,
        'vendorStory': vendorStory,
        'shopLat': shopLat,
        'shopLng': shopLng,
        'image': imageUrl ?? '',
        'isActive': true,
        'discountPct': savingsPct,
        // NEW location fields
        'vendorAddress': _addressController.text.trim(),
        'vendorLat': _vendorPosition?.latitude ?? _savedVendorCoordinates?.$1 ?? shopLat,
        'vendorLng': _vendorPosition?.longitude ?? _savedVendorCoordinates?.$2 ?? shopLng,
      };

      _failureStage = 'listing_write';
      if (isEdit) {
        await docRef.update(bagData);
      } else {
        bagData['createdAt'] = FieldValue.serverTimestamp();
        await docRef.set(bagData);
        // The food-lifecycle ledger is intentionally limited to genuine
        // Surprise Bag surplus. Happy Hour and Skip the Queue are normal
        // commerce products and must not inflate Surpl's recovery metrics.
        if (_listingType == 'surplus') {
          try { await EcosystemService.registerSurplusListing(
            bagId: bagId,
            vendorId: currentUserUid,
            city: city,
            category: _selectedCategory,
            foodType: _foodType,
            quantity: quantity,
            retailValuePerUnit: originalPrice,
            recoveryPricePerUnit: vendorBasePrice,
            pickupEndMillis: _pickupEndMillis(),
          ); } catch (_) { /* Listing exists; secondary tracking must not invite a duplicate. */ }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(_isEditMode
                ? 'Listing updated!' : 'Bag listed successfully! 🎉'),
            backgroundColor: _green));
        context.pop();
      }
    } catch (e) {
      final code = e is FirebaseException ? e.code : 'unknown';
      await _logUploadFailure('$_failureStage:$code');
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not save the listing. Please retry. Reference: $_failureStage/$code.';
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8F5),
      body: Column(children: [
        Container(
          color: _green,
          padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 12,
              left: 16, right: 16, bottom: 16),
          child: Row(children: [
            GestureDetector(
              onTap: () => context.pop(),
              child: Container(width: 36, height: 36,
                decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.arrow_back,
                    color: Colors.white, size: 20))),
            const SizedBox(width: 12),
            Text(_isEditMode ? 'Edit Listing' : 'List a Surprise Bag',
                style: const TextStyle(color: Colors.white, fontSize: 20,
                    fontWeight: FontWeight.w700)),
          ]),
        ),

        Expanded(child: Form(
          key: _formKey,
          child: ListView(padding: const EdgeInsets.all(16), children: [

            // ── Listing for (shop name) ──────────────────────
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                  color: _registeredShopName.isEmpty
                      ? const Color(0xFFFFF3E0) : const Color(0xFFE6F4ED),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _registeredShopName.isEmpty
                      ? const Color(0xFFF5A623).withValues(alpha: 0.4) : Colors.grey.shade200)),
              child: Row(children: [
                Icon(Icons.storefront_rounded, size: 18,
                    color: _registeredShopName.isEmpty ? const Color(0xFFE65100) : _green),
                const SizedBox(width: 10),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Listing for', style: TextStyle(
                      fontSize: 11, color: Colors.grey.shade600)),
                  Text(
                    _registeredShopName.isEmpty ? 'No shop name set' : _registeredShopName,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                        color: _registeredShopName.isEmpty ? const Color(0xFFE65100) : Colors.black87),
                  ),
                  if (_registeredShopName.isEmpty)
                    Text('Contact hello@surpl.in to set your shop name',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                ])),
              ]),
            ),

            // ── Photo ───────────────────────────────────────
            _sectionLabel('Bag Photo'),
            GestureDetector(
              onTap: _isSubmitting ? null : _pickImage,
              child: Container(
                height: 180,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: _imageFile != null ? _green : const Color(0xFFD4E8D4),
                      width: _imageFile != null ? 2 : 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 12, offset: const Offset(0, 4)),
                    BoxShadow(
                      color: _green.withValues(alpha: 0.04),
                      blurRadius: 6, offset: const Offset(0, 1)),
                  ]),
                clipBehavior: Clip.antiAlias,
                child: _imageFile != null
                  ? Stack(fit: StackFit.expand, children: [
                      Image.file(File(_imageFile!.path), fit: BoxFit.cover),
                      if (_uploadingImage) Container(color: Colors.black38,
                          child: const Center(child: CircularProgressIndicator(
                              color: Colors.white))),
                      if (!_uploadingImage) Positioned(top: 8, right: 8,
                          child: GestureDetector(
                            onTap: () => setState(() => _imageFile = null),
                            child: Container(padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(color: Colors.black54,
                                  borderRadius: BorderRadius.circular(20)),
                              child: const Icon(Icons.close,
                                  color: Colors.white, size: 16)))),
                    ])
                  : _existingImageUrl != null && _existingImageUrl!.isNotEmpty
                    ? Stack(fit: StackFit.expand, children: [
                        CachedNetworkImage(imageUrl: _existingImageUrl!, fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => _imagePlaceholder()),
                        Positioned(bottom: 8, right: 8, child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(color: Colors.black54,
                              borderRadius: BorderRadius.circular(8)),
                          child: const Text('Tap to change photo',
                              style: TextStyle(color: Colors.white,
                                  fontSize: 11)))),
                      ])
                  : _imagePlaceholder(),
              ),
            ),
            const SizedBox(height: 20),

            // Surprise Bag and Happy Hour are available to every approved vendor.
            ...[
              _sectionLabel('What are you listing?'),
              ListingTypeSelector(
                value: _listingType,
                skipQueueApproved: _isFreshFoodApproved,
                onChanged: (type) => setState(() => _listingType = type),
              ),
              const SizedBox(height: 8),
              if (_listingType == 'happyHour' || _listingType == 'freshFood')
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                      color: const Color(0xFFE6F4ED),
                      borderRadius: BorderRadius.circular(10)),
                  child: Row(children: [
                    const Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF1A4731)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(
                        _listingType == 'freshFood'
                          ? 'Full price, made fresh to order. 0% commission — only the usual ₹5 platform fee applies.'
                          : 'A short-time discounted deal (e.g. 1-2 hours). Standard 10% commission applies, same as Surprise Bags.',
                        style: const TextStyle(fontSize: 11.5, color: Color(0xFF1A4731)))),
                  ]),
                ),
              if (_listingType == 'freshFood') const SizedBox(height: 14),
              if (_listingType == 'freshFood') ...[
                _sectionLabel('Snack Type'),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  decoration: BoxDecoration(color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade200)),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _snackType,
                      isExpanded: true,
                      items: _snackTypes
                          .map((m) => DropdownMenuItem(value: m.$1, child: Text(m.$2)))
                          .toList(),
                      onChanged: (v) => setState(() => _snackType = v!),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ],

            // ── Title ───────────────────────────────────────
            _sectionLabel('Bag Title'),
            _textField(controller: _titleController,
                hint: 'e.g. Bakery Surprise Box',
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Required' : null),
            const SizedBox(height: 16),

            // ── Category ────────────────────────────────────
            _sectionLabel('Category'),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200)),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedCategory,
                  isExpanded: true,
                  style: const TextStyle(color: Color(0xFF1A4731),
                      fontSize: 15, fontWeight: FontWeight.w500),
                  items: _categories.map((c) => DropdownMenuItem(
                      value: c, child: Text(c,
                          style: const TextStyle(color: Colors.black87))))
                      .toList(),
                  onChanged: (v) => setState(() => _selectedCategory = v!)))),
            const SizedBox(height: 16),

            // ── Veg / Non-veg ─────────────────────────────────
            // Deliberately separate from Category — matches the
            // Zomato/Swiggy convention of a distinct veg indicator,
            // not folded into the cuisine/category list.
            _sectionLabel('Food Type'),
            Row(children: [
              Expanded(child: GestureDetector(
                onTap: () => setState(() => _foodType = 'veg'),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: _foodType == 'veg' ? const Color(0xFFE6F4ED) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _foodType == 'veg' ? const Color(0xFF1A8A3E) : Colors.grey.shade300,
                      width: _foodType == 'veg' ? 1.5 : 1)),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(width: 16, height: 16,
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFF1A8A3E), width: 1.5),
                        borderRadius: BorderRadius.circular(3)),
                      child: Center(child: Container(width: 8, height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFF1A8A3E), shape: BoxShape.circle)))),
                    const SizedBox(width: 8),
                    Text('Veg', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                      color: _foodType == 'veg' ? const Color(0xFF1A8A3E) : Colors.grey.shade600)),
                  ])))),
              const SizedBox(width: 10),
              Expanded(child: GestureDetector(
                onTap: () => setState(() => _foodType = 'nonveg'),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: _foodType == 'nonveg' ? const Color(0xFFFBEAEA) : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _foodType == 'nonveg' ? const Color(0xFFA83232) : Colors.grey.shade300,
                      width: _foodType == 'nonveg' ? 1.5 : 1)),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(width: 16, height: 16,
                      decoration: BoxDecoration(
                        border: Border.all(color: const Color(0xFFA83232), width: 1.5),
                        borderRadius: BorderRadius.circular(3)),
                      child: Center(child: Container(width: 8, height: 8,
                        decoration: const BoxDecoration(
                          color: Color(0xFFA83232), shape: BoxShape.rectangle)))),
                    const SizedBox(width: 8),
                    Text('Non-Veg', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                      color: _foodType == 'nonveg' ? const Color(0xFFA83232) : Colors.grey.shade600)),
                  ])))),
            ]),
            const SizedBox(height: 16),

            // ── Description ─────────────────────────────────
            _sectionLabel('Description'),
            _textField(controller: _descController,
                hint: 'Describe what might be inside — keep it exciting!',
                maxLines: 3),
            const SizedBox(height: 16),

            // ── Pricing ─────────────────────────────────────
            _sectionLabel('Pricing'),
            Row(children: [
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Original value (Rs.)', style: TextStyle(fontSize: 12,
                    color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                _textField(controller: _originalPriceController, hint: '350',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) => v == null || v.trim().isEmpty
                      ? 'Required' : null),
              ])),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Selling price (Rs.)', style: TextStyle(fontSize: 12,
                    color: Colors.grey.shade600, fontWeight: FontWeight.w500)),
                const SizedBox(height: 6),
                _textField(controller: _priceController,
                  hint: '$kMinBagPrice',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    final disc = double.tryParse(v.trim()) ?? 0;
                    if (disc < kMinBagPrice) return 'Min Rs.$kMinBagPrice';
                    final orig = double.tryParse(
                        _originalPriceController.text) ?? 0;
                    if (disc >= orig) return 'Must be less than original';
                    return null;
                  }),
              ])),
            ]),
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: _lightGreen,
                  borderRadius: BorderRadius.circular(8)),
              child: Row(children: [
                const Icon(Icons.info_outline, color: _green, size: 14),
                const SizedBox(width: 6),
                Text('Minimum selling price is Rs.$kMinBagPrice',
                    style: const TextStyle(color: _green, fontSize: 12,
                        fontWeight: FontWeight.w600)),
              ])),
            ValueListenableBuilder(
              valueListenable: _priceController,
              builder: (_, __, ___) {
                final orig = double.tryParse(
                    _originalPriceController.text) ?? 0;
                final disc = double.tryParse(_priceController.text) ?? 0;
                if (orig > 0 && disc > 0 && disc < orig) {
                  final pct = ((orig - disc) / orig * 100).round();
                  return Container(
                    margin: const EdgeInsets.only(top: 10),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                        color: const Color(0xFFFFF3E0),
                        borderRadius: BorderRadius.circular(8)),
                    child: Row(children: [
                      const Icon(Icons.local_offer, color: _amber, size: 16),
                      const SizedBox(width: 6),
                      Text('Customers save $pct% — Rs.${(orig - disc).toStringAsFixed(0)} off',
                          style: const TextStyle(color: Color(0xFF7B4F00),
                              fontSize: 13, fontWeight: FontWeight.w600)),
                    ]));
                }
                return const SizedBox.shrink();
              }),
            const SizedBox(height: 16),

            // ── Quantity ─────────────────────────────────────
            _sectionLabel('Available Quantity'),
            Row(children: [
              GestureDetector(
                onTap: () {
                  final v = int.tryParse(_quantityController.text) ?? 1;
                  if (v > 1) setState(() =>
                      _quantityController.text = '${v - 1}');
                },
                child: Container(width: 44, height: 44,
                  decoration: BoxDecoration(color: _lightGreen,
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.remove, color: _green, size: 20))),
              const SizedBox(width: 12),
              Expanded(child: _textField(
                  controller: _quantityController, hint: '1',
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  textAlign: TextAlign.center)),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () {
                  final v = int.tryParse(_quantityController.text) ?? 1;
                  setState(() => _quantityController.text = '${v + 1}');
                },
                child: Container(width: 44, height: 44,
                  decoration: BoxDecoration(color: _green,
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.add,
                      color: Colors.white, size: 20))),
            ]),
            const SizedBox(height: 16),

            // ── Pickup window ────────────────────────────────
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              _sectionLabel('Pickup Window (Today)'),
              Row(children: [
                Container(width: 6, height: 6,
                  decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text('Now: ${_formatTime(TimeOfDay.fromDateTime(_now))}',
                  style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600, fontWeight: FontWeight.w600)),
              ]),
            ]),
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => setState(() {
                _pickupFrom = TimeOfDay.fromDateTime(_now);
                _pickupTo = const TimeOfDay(hour: 23, minute: 0);
              }),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F4ED),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _green.withValues(alpha: 0.3))),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  const Icon(Icons.wb_sunny_rounded, size: 16, color: _green),
                  const SizedBox(width: 6),
                  Text('List for whole day (now – 11:00 PM)',
                    style: TextStyle(fontSize: 12.5, color: _green, fontWeight: FontWeight.w700)),
                ]))),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: GestureDetector(
                onTap: () => _pickTime(true),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200)),
                  child: Row(children: [
                    const Icon(Icons.access_time_rounded,
                        color: _green, size: 18),
                    const SizedBox(width: 8),
                    Text(_pickupFrom == null ? 'From'
                        : _formatTime(_pickupFrom),
                      style: TextStyle(fontSize: 14,
                        color: _pickupFrom == null
                            ? Colors.grey.shade400 : Colors.black87,
                        fontWeight: _pickupFrom == null
                            ? FontWeight.w400 : FontWeight.w600)),
                  ])))),
              const SizedBox(width: 12),
              Expanded(child: GestureDetector(
                onTap: () => _pickTime(false),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200)),
                  child: Row(children: [
                    const Icon(Icons.access_time_filled_rounded,
                        color: _green, size: 18),
                    const SizedBox(width: 8),
                    Text(_pickupTo == null ? 'To'
                        : _formatTime(_pickupTo),
                      style: TextStyle(fontSize: 14,
                        color: _pickupTo == null
                            ? Colors.grey.shade400 : Colors.black87,
                        fontWeight: _pickupTo == null
                            ? FontWeight.w400 : FontWeight.w600)),
                  ])))),
            ]),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: _lightGreen,
                  borderRadius: BorderRadius.circular(10)),
              child: const Row(children: [
                Icon(Icons.info_outline, color: _green, size: 16),
                SizedBox(width: 8),
                Expanded(child: Text(
                    'The bag is taken off the app automatically when the pickup window ends.',
                    style: TextStyle(color: _green, fontSize: 12,
                        height: 1.4))),
              ])),
            const SizedBox(height: 16),

            // ── Shop address (NEW) ───────────────────────────
            _sectionLabel('Shop Address'),
            _textField(
              controller: _addressController,
              hint: 'e.g. Main Road, Near Bus Stand, Jagtial',
              validator: (v) => v == null || v.trim().isEmpty
                  ? 'Required' : null),
            const SizedBox(height: 12),

            // ── Shop location / GPS (NEW) ────────────────────
            _sectionLabel('Shop Location (for customer navigation)'),
            GestureDetector(
              onTap: _loadingLocation ? null : _captureLocation,
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _vendorPosition != null
                      ? _lightGreen : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _vendorPosition != null
                        ? _green : Colors.grey.shade300,
                    width: _vendorPosition != null ? 1.5 : 1)),
                child: Row(children: [
                  Icon(
                    _vendorPosition != null
                        ? Icons.location_on : Icons.location_searching,
                    color: _vendorPosition != null
                        ? _green : Colors.grey.shade500,
                    size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: _loadingLocation
                    ? Row(children: [
                        const SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(0xFF1A4731))),
                        const SizedBox(width: 10),
                        Text('Getting your location...',
                          style: TextStyle(fontSize: 14,
                              color: Colors.grey.shade600)),
                      ])
                    : Text(
                        _vendorPosition != null
                          ? 'Location saved ✅'
                          : 'Tap to save your shop location (optional)',
                        style: TextStyle(
                          fontSize: 14,
                          color: _vendorPosition != null
                              ? _green : Colors.grey.shade600,
                          fontWeight: _vendorPosition != null
                              ? FontWeight.w600 : FontWeight.w400))),
                  if (_vendorPosition != null)
                    const Icon(Icons.check_circle,
                        color: Color(0xFF1A4731), size: 20),
                ])),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(color: _lightGreen,
                  borderRadius: BorderRadius.circular(8)),
              child: const Row(children: [
                Icon(Icons.info_outline, color: _green, size: 14),
                SizedBox(width: 6),
                Expanded(child: Text(
                    'Customers see distance to your shop and can tap Navigate to get directions.',
                    style: TextStyle(color: _green, fontSize: 12))),
              ])),
            const SizedBox(height: 24),

            // ── Error ────────────────────────────────────────
            if (_errorMessage != null) Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                  color: const Color(0xFFFFEBEE),
                  borderRadius: BorderRadius.circular(10)),
              child: Text(_errorMessage!,
                  style: const TextStyle(color: Color(0xFFC62828),
                      fontSize: 13))),

            // ── Submit ───────────────────────────────────────
            GestureDetector(
              onTap: _isSubmitting ? null : _submit,
              child: Container(
                height: 54,
                decoration: BoxDecoration(
                  color: _isSubmitting ? Colors.grey : _green,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: _isSubmitting ? [] : [
                    BoxShadow(
                      color: _green.withValues(alpha: 0.35),
                      blurRadius: 14, offset: const Offset(0, 5)),
                    BoxShadow(
                      color: _green.withValues(alpha: 0.12),
                      blurRadius: 6, offset: const Offset(0, 2)),
                  ]),
                child: Center(child: _isSubmitting
                  ? Row(mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                      const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(
                            color: Color(0xFFFBF3E4), strokeWidth: 2.5)),
                      const SizedBox(width: 12),
                      Text(_uploadingImage
                          ? 'Uploading photo... ${(_uploadProgress * 100).round()}%' : 'Publishing...',
                        style: const TextStyle(color: Color(0xFFFBF3E4),
                            fontSize: 15, fontWeight: FontWeight.w600)),
                    ])
                  : Text(_isEditMode ? 'Save Changes' : 'Publish Listing',
                      style: const TextStyle(color: Color(0xFFFBF3E4),
                          fontSize: 16, fontWeight: FontWeight.w700,
                          letterSpacing: -0.3))),
              )),
            const SizedBox(height: 32),
          ]),
        )),
      ]),
    );
  }

  Widget _imagePlaceholder() => Column(
    mainAxisAlignment: MainAxisAlignment.center, children: [
    Container(width: 56, height: 56,
      decoration: const BoxDecoration(
          color: _lightGreen, shape: BoxShape.circle),
      child: const Icon(Icons.add_a_photo, color: _green, size: 28)),
    const SizedBox(height: 10),
    const Text('Tap to add photo',
        style: TextStyle(color: _green, fontWeight: FontWeight.w600)),
    const SizedBox(height: 4),
    Text('Show what\'s in the bag',
        style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
  ]);

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(text, style: const TextStyle(
        color: Color(0xFF1A4731), fontSize: 14,
        fontWeight: FontWeight.w700, letterSpacing: -0.3)));

  Widget _textField({
    required TextEditingController controller,
    required String hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    TextAlign textAlign = TextAlign.start,
  }) => TextFormField(
    controller: controller, maxLines: maxLines,
    keyboardType: keyboardType, inputFormatters: inputFormatters,
    validator: validator, textAlign: textAlign,
    style: const TextStyle(fontSize: 15, color: Colors.black87),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
      filled: true, fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(
          horizontal: 16, vertical: 16),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD4E8D4))),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFD4E8D4))),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
              color: Color(0xFF1A4731), width: 1.5)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.red)),
    ));
}
