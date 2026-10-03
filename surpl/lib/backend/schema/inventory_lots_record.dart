import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';
import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

/// A physical pool of perishable inventory that Surpl can recover.
/// Initially created automatically from a Surpl listing so the existing
/// vendor workflow does not gain any extra data-entry steps.
class InventoryLotsRecord extends FirestoreRecord {
  InventoryLotsRecord._(DocumentReference reference, Map<String, dynamic> data)
      : super(reference, data) {
    _initializeFields();
  }

  String? _vendorId;
  String get vendorId => _vendorId ?? '';
  String? _bagId;
  String get bagId => _bagId ?? '';
  String? _city;
  String get city => _city ?? '';
  String? _category;
  String get category => _category ?? '';
  String? _foodType;
  String get foodType => _foodType ?? '';
  String? _source;
  String get source => _source ?? '';
  int? _initialQuantity;
  int get initialQuantity => _initialQuantity ?? 0;
  int? _remainingQuantity;
  int get remainingQuantity => _remainingQuantity ?? 0;
  double? _retailValuePerUnit;
  double get retailValuePerUnit => _retailValuePerUnit ?? 0.0;
  double? _recoveryPricePerUnit;
  double get recoveryPricePerUnit => _recoveryPricePerUnit ?? 0.0;
  String? _status;
  String get status => _status ?? 'open';
  int? _createdAtMillis;
  int get createdAtMillis => _createdAtMillis ?? 0;
  int? _pickupEndMillis;
  int get pickupEndMillis => _pickupEndMillis ?? 0;

  void _initializeFields() {
    _vendorId = snapshotData['vendorId'] as String?;
    _bagId = snapshotData['bagId'] as String?;
    _city = snapshotData['city'] as String?;
    _category = snapshotData['category'] as String?;
    _foodType = snapshotData['foodType'] as String?;
    _source = snapshotData['source'] as String?;
    _initialQuantity = castToType<int>(snapshotData['initialQuantity']);
    _remainingQuantity = castToType<int>(snapshotData['remainingQuantity']);
    _retailValuePerUnit = castToType<double>(snapshotData['retailValuePerUnit']);
    _recoveryPricePerUnit = castToType<double>(snapshotData['recoveryPricePerUnit']);
    _status = snapshotData['status'] as String?;
    _createdAtMillis = castToType<int>(snapshotData['createdAtMillis']);
    _pickupEndMillis = castToType<int>(snapshotData['pickupEndMillis']);
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('inventoryLots');

  static Stream<InventoryLotsRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => InventoryLotsRecord.fromSnapshot(s));

  static Future<InventoryLotsRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => InventoryLotsRecord.fromSnapshot(s));

  static InventoryLotsRecord fromSnapshot(DocumentSnapshot snapshot) =>
      InventoryLotsRecord._(snapshot.reference,
          mapFromFirestore(snapshot.data() as Map<String, dynamic>));

  @override
  String toString() =>
      'InventoryLotsRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is InventoryLotsRecord && reference.path == other.reference.path;
}

Map<String, dynamic> createInventoryLotsRecordData({
  String? vendorId,
  String? bagId,
  String? city,
  String? category,
  String? foodType,
  String? source,
  int? initialQuantity,
  int? remainingQuantity,
  double? retailValuePerUnit,
  double? recoveryPricePerUnit,
  String? status,
  int? createdAtMillis,
  int? pickupEndMillis,
}) =>
    mapToFirestore(<String, dynamic>{
      'vendorId': vendorId,
      'bagId': bagId,
      'city': city,
      'category': category,
      'foodType': foodType,
      'source': source,
      'initialQuantity': initialQuantity,
      'remainingQuantity': remainingQuantity,
      'retailValuePerUnit': retailValuePerUnit,
      'recoveryPricePerUnit': recoveryPricePerUnit,
      'status': status,
      'createdAtMillis': createdAtMillis,
      'pickupEndMillis': pickupEndMillis,
    }.withoutNulls);
