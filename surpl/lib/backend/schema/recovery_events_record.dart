import 'dart:async';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';
import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

/// Immutable event ledger for what ultimately happened to recoverable food.
/// Current app integration writes `surpl_sale` events. Future routes can add
/// donation, markdown, staff use, B2B transfer and disposal without changing
/// historical records.
class RecoveryEventsRecord extends FirestoreRecord {
  RecoveryEventsRecord._(DocumentReference reference, Map<String, dynamic> data)
      : super(reference, data) {
    _initializeFields();
  }

  String? _vendorId;
  String get vendorId => _vendorId ?? '';
  String? _customerId;
  String get customerId => _customerId ?? '';
  String? _bagId;
  String get bagId => _bagId ?? '';
  String? _orderId;
  String get orderId => _orderId ?? '';
  String? _inventoryLotId;
  String get inventoryLotId => _inventoryLotId ?? '';
  String? _city;
  String get city => _city ?? '';
  String? _route;
  String get route => _route ?? '';
  int? _quantity;
  int get quantity => _quantity ?? 0;
  double? _retailValue;
  double get retailValue => _retailValue ?? 0.0;
  double? _recoveredValue;
  double get recoveredValue => _recoveredValue ?? 0.0;
  double? _vendorPayout;
  double get vendorPayout => _vendorPayout ?? 0.0;
  double? _surplRevenue;
  double get surplRevenue => _surplRevenue ?? 0.0;
  int? _createdAtMillis;
  int get createdAtMillis => _createdAtMillis ?? 0;

  void _initializeFields() {
    _vendorId = snapshotData['vendorId'] as String?;
    _customerId = snapshotData['customerId'] as String?;
    _bagId = snapshotData['bagId'] as String?;
    _orderId = snapshotData['orderId'] as String?;
    _inventoryLotId = snapshotData['inventoryLotId'] as String?;
    _city = snapshotData['city'] as String?;
    _route = snapshotData['route'] as String?;
    _quantity = castToType<int>(snapshotData['quantity']);
    _retailValue = castToType<double>(snapshotData['retailValue']);
    _recoveredValue = castToType<double>(snapshotData['recoveredValue']);
    _vendorPayout = castToType<double>(snapshotData['vendorPayout']);
    _surplRevenue = castToType<double>(snapshotData['surplRevenue']);
    _createdAtMillis = castToType<int>(snapshotData['createdAtMillis']);
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('recoveryEvents');

  static Stream<RecoveryEventsRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => RecoveryEventsRecord.fromSnapshot(s));

  static Future<RecoveryEventsRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => RecoveryEventsRecord.fromSnapshot(s));

  static RecoveryEventsRecord fromSnapshot(DocumentSnapshot snapshot) =>
      RecoveryEventsRecord._(snapshot.reference,
          mapFromFirestore(snapshot.data() as Map<String, dynamic>));

  @override
  String toString() =>
      'RecoveryEventsRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is RecoveryEventsRecord && reference.path == other.reference.path;
}
