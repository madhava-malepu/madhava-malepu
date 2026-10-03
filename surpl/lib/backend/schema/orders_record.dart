import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class OrdersRecord extends FirestoreRecord {
  OrdersRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "customerId" field.
  String? _customerId;
  String get customerId => _customerId ?? '';
  bool hasCustomerId() => _customerId != null;

  // "bagId" field.
  String? _bagId;
  String get bagId => _bagId ?? '';
  bool hasBagId() => _bagId != null;

  // "merchantId" field.
  String? _merchantId;
  String get merchantId => _merchantId ?? '';
  bool hasMerchantId() => _merchantId != null;

  // "amountPaid" field.
  double? _amountPaid;
  double get amountPaid => _amountPaid ?? 0.0;
  bool hasAmountPaid() => _amountPaid != null;

  // "pickupCode" field.
  String? _pickupCode;
  String get pickupCode => _pickupCode ?? '';
  bool hasPickupCode() => _pickupCode != null;

  // "status" field.
  String? _status;
  String get status => _status ?? '';
  bool hasStatus() => _status != null;

  // "timestamp" field.
  int? _timestamp;
  int get timestamp => _timestamp ?? 0;
  bool hasTimestamp() => _timestamp != null;

  // "quantity" field.
  int? _quantity;
  int get quantity => _quantity ?? 1;
  bool hasQuantity() => _quantity != null;

  // "orderGroupId" field — links multiple order docs created from one cart checkout.
  String? _orderGroupId;
  String get orderGroupId => _orderGroupId ?? '';
  bool hasOrderGroupId() => _orderGroupId != null;

  void _initializeFields() {
    _customerId = snapshotData['customerId'] as String?;
    _bagId = snapshotData['bagId'] as String?;
    _merchantId = snapshotData['merchantId'] as String?;
    _amountPaid = castToType<double>(snapshotData['amountPaid']);
    _pickupCode = snapshotData['pickupCode'] as String?;
    _status = snapshotData['status'] as String?;
    _timestamp = castToType<int>(snapshotData['timestamp']);
    _quantity = castToType<int>(snapshotData['quantity']);
    _orderGroupId = snapshotData['orderGroupId'] as String?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('orders');

  static Stream<OrdersRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => OrdersRecord.fromSnapshot(s));

  static Future<OrdersRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => OrdersRecord.fromSnapshot(s));

  static OrdersRecord fromSnapshot(DocumentSnapshot snapshot) => OrdersRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static OrdersRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      OrdersRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'OrdersRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is OrdersRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createOrdersRecordData({
  String? customerId,
  String? bagId,
  String? merchantId,
  double? amountPaid,
  String? pickupCode,
  String? status,
  int? timestamp,
  int? quantity,
  String? orderGroupId,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'customerId': customerId,
      'bagId': bagId,
      'merchantId': merchantId,
      'amountPaid': amountPaid,
      'pickupCode': pickupCode,
      'status': status,
      'timestamp': timestamp,
      'quantity': quantity,
      'orderGroupId': orderGroupId,
    }.withoutNulls,
  );

  return firestoreData;
}

class OrdersRecordDocumentEquality implements Equality<OrdersRecord> {
  const OrdersRecordDocumentEquality();

  @override
  bool equals(OrdersRecord? e1, OrdersRecord? e2) {
    return e1?.customerId == e2?.customerId &&
        e1?.bagId == e2?.bagId &&
        e1?.merchantId == e2?.merchantId &&
        e1?.amountPaid == e2?.amountPaid &&
        e1?.pickupCode == e2?.pickupCode &&
        e1?.status == e2?.status &&
        e1?.timestamp == e2?.timestamp;
  }

  @override
  int hash(OrdersRecord? e) => const ListEquality().hash([
        e?.customerId,
        e?.bagId,
        e?.merchantId,
        e?.amountPaid,
        e?.pickupCode,
        e?.status,
        e?.timestamp
      ]);

  @override
  bool isValidKey(Object? o) => o is OrdersRecord;
}
