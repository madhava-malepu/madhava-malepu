import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class UsersRecord extends FirestoreRecord {
  UsersRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "phoneNumber" field.
  String? _phoneNumber;
  String get phoneNumber => _phoneNumber ?? '';
  bool hasPhoneNumber() => _phoneNumber != null;

  // "name" field.
  String? _name;
  String get name => _name ?? '';
  bool hasName() => _name != null;

  // "email" field.
  String? _email;
  String get email => _email ?? '';
  bool hasEmail() => _email != null;

  // "isVendor" field.
  bool? _isVendor;
  bool get isVendor => _isVendor ?? false;
  bool hasIsVendor() => _isVendor != null;

  // "savedBags" field.
  List<String>? _savedBags;
  List<String> get savedBags => _savedBags ?? const [];
  bool hasSavedBags() => _savedBags != null;

  void _initializeFields() {
    _phoneNumber = snapshotData['phoneNumber'] as String?;
    _name = snapshotData['name'] as String?;
    _email = snapshotData['email'] as String?;
    _isVendor = snapshotData['isVendor'] as bool?;
    _savedBags = getDataList(snapshotData['savedBags']);
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('users');

  static Stream<UsersRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => UsersRecord.fromSnapshot(s));

  static Future<UsersRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => UsersRecord.fromSnapshot(s));

  static UsersRecord fromSnapshot(DocumentSnapshot snapshot) => UsersRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static UsersRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      UsersRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'UsersRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is UsersRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createUsersRecordData({
  String? phoneNumber,
  String? name,
  String? email,
  bool? isVendor,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'phoneNumber': phoneNumber,
      'name': name,
      'email': email,
      'isVendor': isVendor,
    }.withoutNulls,
  );

  return firestoreData;
}

class UsersRecordDocumentEquality implements Equality<UsersRecord> {
  const UsersRecordDocumentEquality();

  @override
  bool equals(UsersRecord? e1, UsersRecord? e2) {
    return e1?.phoneNumber == e2?.phoneNumber &&
        e1?.name == e2?.name &&
        e1?.email == e2?.email &&
        e1?.isVendor == e2?.isVendor;
  }

  @override
  int hash(UsersRecord? e) => const ListEquality()
      .hash([e?.phoneNumber, e?.name, e?.email, e?.isVendor]);

  @override
  bool isValidKey(Object? o) => o is UsersRecord;
}