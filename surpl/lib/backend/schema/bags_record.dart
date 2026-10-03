import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class BagsRecord extends FirestoreRecord {
  BagsRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "merchantId" field.
  String? _merchantId;
  String get merchantId => _merchantId ?? '';
  bool hasMerchantId() => _merchantId != null;

  // "title" field.
  String? _title;
  String get title => _title ?? '';
  bool hasTitle() => _title != null;

  // "description" field.
  String? _description;
  String get description => _description ?? '';
  bool hasDescription() => _description != null;

  // "price" field.
  double? _price;
  double get price => _price ?? 0.0;
  bool hasPrice() => _price != null;

  // "originalPrice" field.
  double? _originalPrice;
  double get originalPrice => _originalPrice ?? 0.0;
  bool hasOriginalPrice() => _originalPrice != null;

  // "discountPct" field.
  int? _discountPct;
  int get discountPct => _discountPct ?? 0;
  bool hasDiscountPct() => _discountPct != null;

  // "pickupStart" field.
  String? _pickupStart;
  String get pickupStart => _pickupStart ?? '';
  bool hasPickupStart() => _pickupStart != null;

  // "pickupEnd" field.
  String? _pickupEnd;
  String get pickupEnd => _pickupEnd ?? '';
  bool hasPickupEnd() => _pickupEnd != null;

  // "totalQuantity" field.
  int? _totalQuantity;
  int get totalQuantity => _totalQuantity ?? 0;
  bool hasTotalQuantity() => _totalQuantity != null;

  // "availableQuantity" field.
  int? _availableQuantity;
  int get availableQuantity => _availableQuantity ?? 0;
  bool hasAvailableQuantity() => _availableQuantity != null;

  // "category" field.
  String? _category;
  String get category => _category ?? '';
  bool hasCategory() => _category != null;

  // "tags" field.
  List<String>? _tags;
  List<String> get tags => _tags ?? const [];
  bool hasTags() => _tags != null;

  // "image" field.
  String? _image;
  String get image => _image ?? '';
  bool hasImage() => _image != null;


  // Live fields written by create_listing_widget.dart but missing from the
  // original generated schema. Keeping them typed prevents future model drift.
  String? _foodType;
  String get foodType => _foodType ?? '';
  String? _listingType;
  String get listingType => _listingType ?? '';
  String? _snackType;
  String get snackType => _snackType ?? '';
  double? _vendorBasePrice;
  double get vendorBasePrice => _vendorBasePrice ?? 0.0;
  String? _merchantName;
  String get merchantName => _merchantName ?? '';
  String? _shopArea;
  String get shopArea => _shopArea ?? '';
  String? _city;
  String get city => _city ?? '';
  String? _fssaiNumber;
  String get fssaiNumber => _fssaiNumber ?? '';
  int? _pickupStartMillis;
  int get pickupStartMillis => _pickupStartMillis ?? 0;
  int? _pickupEndMillis;
  int get pickupEndMillis => _pickupEndMillis ?? 0;
  bool? _isActive;
  bool get isActive => _isActive ?? true;

  void _initializeFields() {
    _merchantId = snapshotData['merchantId'] as String?;
    _title = snapshotData['title'] as String?;
    _description = snapshotData['description'] as String?;
    _price = castToType<double>(snapshotData['price']);
    _originalPrice = castToType<double>(snapshotData['originalPrice']);
    _discountPct = castToType<int>(snapshotData['discountPct']);
    _pickupStart = snapshotData['pickupStart'] as String?;
    _pickupEnd = snapshotData['pickupEnd'] as String?;
    _totalQuantity = castToType<int>(snapshotData['totalQuantity']);
    _availableQuantity = castToType<int>(snapshotData['availableQuantity']);
    _category = snapshotData['category'] as String?;
    _tags = getDataList(snapshotData['tags']);
    _image = snapshotData['image'] as String?;
    _foodType = snapshotData['foodType'] as String?;
    _listingType = snapshotData['listingType'] as String?;
    _snackType = snapshotData['snackType'] as String?;
    _vendorBasePrice = castToType<double>(snapshotData['vendorBasePrice']);
    _merchantName = snapshotData['merchantName'] as String?;
    _shopArea = snapshotData['shopArea'] as String?;
    _city = snapshotData['city'] as String?;
    _fssaiNumber = snapshotData['fssaiNumber'] as String?;
    _pickupStartMillis = castToType<int>(snapshotData['pickupStartMillis']);
    _pickupEndMillis = castToType<int>(snapshotData['pickupEndMillis']);
    _isActive = snapshotData['isActive'] as bool?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('bags');

  static Stream<BagsRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => BagsRecord.fromSnapshot(s));

  static Future<BagsRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => BagsRecord.fromSnapshot(s));

  static BagsRecord fromSnapshot(DocumentSnapshot snapshot) => BagsRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static BagsRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      BagsRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'BagsRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is BagsRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createBagsRecordData({
  String? merchantId,
  String? title,
  String? description,
  double? price,
  double? originalPrice,
  int? discountPct,
  String? pickupStart,
  String? pickupEnd,
  int? totalQuantity,
  int? availableQuantity,
  String? category,
  String? image,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'merchantId': merchantId,
      'title': title,
      'description': description,
      'price': price,
      'originalPrice': originalPrice,
      'discountPct': discountPct,
      'pickupStart': pickupStart,
      'pickupEnd': pickupEnd,
      'totalQuantity': totalQuantity,
      'availableQuantity': availableQuantity,
      'category': category,
      'image': image,
    }.withoutNulls,
  );

  return firestoreData;
}

class BagsRecordDocumentEquality implements Equality<BagsRecord> {
  const BagsRecordDocumentEquality();

  @override
  bool equals(BagsRecord? e1, BagsRecord? e2) {
    const listEquality = ListEquality();
    return e1?.merchantId == e2?.merchantId &&
        e1?.title == e2?.title &&
        e1?.description == e2?.description &&
        e1?.price == e2?.price &&
        e1?.originalPrice == e2?.originalPrice &&
        e1?.discountPct == e2?.discountPct &&
        e1?.pickupStart == e2?.pickupStart &&
        e1?.pickupEnd == e2?.pickupEnd &&
        e1?.totalQuantity == e2?.totalQuantity &&
        e1?.availableQuantity == e2?.availableQuantity &&
        e1?.category == e2?.category &&
        listEquality.equals(e1?.tags, e2?.tags) &&
        e1?.image == e2?.image;
  }

  @override
  int hash(BagsRecord? e) => const ListEquality().hash([
        e?.merchantId,
        e?.title,
        e?.description,
        e?.price,
        e?.originalPrice,
        e?.discountPct,
        e?.pickupStart,
        e?.pickupEnd,
        e?.totalQuantity,
        e?.availableQuantity,
        e?.category,
        e?.tags,
        e?.image
      ]);

  @override
  bool isValidKey(Object? o) => o is BagsRecord;
}
