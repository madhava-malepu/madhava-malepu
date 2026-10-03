import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class MerchantsRecord extends FirestoreRecord {
  MerchantsRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "name" field.
  String? _name;
  String get name => _name ?? '';
  bool hasName() => _name != null;

  // "location" field.
  String? _location;
  String get location => _location ?? '';
  bool hasLocation() => _location != null;

  // "address" field.
  String? _address;
  String get address => _address ?? '';
  bool hasAddress() => _address != null;

  // "rating" field.
  double? _rating;
  double get rating => _rating ?? 0.0;
  bool hasRating() => _rating != null;

  // "category" field.
  String? _category;
  String get category => _category ?? '';
  bool hasCategory() => _category != null;

  // "image" field.
  String? _image;
  String get image => _image ?? '';
  bool hasImage() => _image != null;

  void _initializeFields() {
    _name = snapshotData['name'] as String?;
    _location = snapshotData['location'] as String?;
    _address = snapshotData['address'] as String?;
    _rating = castToType<double>(snapshotData['rating']);
    _category = snapshotData['category'] as String?;
    _image = snapshotData['image'] as String?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('merchants');

  static Stream<MerchantsRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => MerchantsRecord.fromSnapshot(s));

  static Future<MerchantsRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => MerchantsRecord.fromSnapshot(s));

  static MerchantsRecord fromSnapshot(DocumentSnapshot snapshot) =>
      MerchantsRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static MerchantsRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      MerchantsRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'MerchantsRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is MerchantsRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createMerchantsRecordData({
  String? name,
  String? location,
  String? address,
  double? rating,
  String? category,
  String? image,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'name': name,
      'location': location,
      'address': address,
      'rating': rating,
      'category': category,
      'image': image,
    }.withoutNulls,
  );

  return firestoreData;
}

class MerchantsRecordDocumentEquality implements Equality<MerchantsRecord> {
  const MerchantsRecordDocumentEquality();

  @override
  bool equals(MerchantsRecord? e1, MerchantsRecord? e2) {
    return e1?.name == e2?.name &&
        e1?.location == e2?.location &&
        e1?.address == e2?.address &&
        e1?.rating == e2?.rating &&
        e1?.category == e2?.category &&
        e1?.image == e2?.image;
  }

  @override
  int hash(MerchantsRecord? e) => const ListEquality().hash(
      [e?.name, e?.location, e?.address, e?.rating, e?.category, e?.image]);

  @override
  bool isValidKey(Object? o) => o is MerchantsRecord;
}
