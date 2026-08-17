import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:transit_core/transit_core.dart';

/// Typed entry points to every Firestore collection.
///
/// Using `withConverter` means repositories hand back real domain objects
/// instead of `Map<String, dynamic>`, so a typo in a field name is a compile
/// error rather than a null at runtime.
///
/// These are getters, not `static final` fields — a field would touch
/// `FirebaseFirestore.instance` at class-load time, which can run before
/// `Firebase.initializeApp()` and throw.
class Db {
  Db._();

  static FirebaseFirestore get fs => FirebaseFirestore.instance;

  /// Written into `createdAt` / `updatedAt` so ordering never depends on the
  /// device clock, which users can change.
  static FieldValue get now => FieldValue.serverTimestamp();

  static CollectionReference<AppUser> get users =>
      fs.collection('users').withConverter<AppUser>(
            fromFirestore: (snap, _) => AppUser.fromMap(snap.id, snap.data() ?? {}),
            toFirestore: (value, _) => value.toMap(),
          );

  static CollectionReference<Student> get students =>
      fs.collection('students').withConverter<Student>(
            fromFirestore: (snap, _) => Student.fromMap(snap.id, snap.data() ?? {}),
            toFirestore: (value, _) => value.toMap(),
          );

  static CollectionReference<Driver> get drivers =>
      fs.collection('drivers').withConverter<Driver>(
            fromFirestore: (snap, _) => Driver.fromMap(snap.id, snap.data() ?? {}),
            toFirestore: (value, _) => value.toMap(),
          );

  static CollectionReference<Bus> get buses =>
      fs.collection('buses').withConverter<Bus>(
            fromFirestore: (snap, _) => Bus.fromMap(snap.id, snap.data() ?? {}),
            toFirestore: (value, _) => value.toMap(),
          );

  static CollectionReference<BusRoute> get routes =>
      fs.collection('routes').withConverter<BusRoute>(
            fromFirestore: (snap, _) => BusRoute.fromMap(snap.id, snap.data() ?? {}),
            toFirestore: (value, _) => value.toMap(),
          );

  static CollectionReference<Trip> get trips =>
      fs.collection('trips').withConverter<Trip>(
            fromFirestore: (snap, _) => Trip.fromMap(snap.id, snap.data() ?? {}),
            toFirestore: (value, _) => value.toMap(),
          );

  /// `trips/{tripId}/attendance/{studentId}`
  static CollectionReference<AttendanceRecord> attendance(String tripId) =>
      trips.doc(tripId).collection('attendance').withConverter<AttendanceRecord>(
            fromFirestore: (snap, _) =>
                AttendanceRecord.fromMap(snap.id, snap.data() ?? {}),
            toFirestore: (value, _) => value.toMap(),
          );

  static CollectionReference<Payment> get payments =>
      fs.collection('payments').withConverter<Payment>(
            fromFirestore: (snap, _) => Payment.fromMap(snap.id, snap.data() ?? {}),
            toFirestore: (value, _) => value.toMap(),
          );

  static CollectionReference<MissedBusRequest> get missedBusRequests =>
      fs.collection('missedBusRequests').withConverter<MissedBusRequest>(
            fromFirestore: (snap, _) =>
                MissedBusRequest.fromMap(snap.id, snap.data() ?? {}),
            toFirestore: (value, _) => value.toMap(),
          );

  /// `notifications/{uid}/items/{id}` — scoped per recipient so the security
  /// rule is a single `uid == request.auth.uid` check.
  static CollectionReference<UserNotification> notifications(String uid) => fs
      .collection('notifications')
      .doc(uid)
      .collection('items')
      .withConverter<UserNotification>(
        fromFirestore: (snap, _) => UserNotification.fromMap(snap.id, snap.data() ?? {}),
        toFirestore: (value, _) => value.toMap(),
      );

  static CollectionReference<ChatThread> get chats =>
      fs.collection('chats').withConverter<ChatThread>(
            fromFirestore: (snap, _) => ChatThread.fromMap(snap.id, snap.data() ?? {}),
            toFirestore: (value, _) => value.toMap(),
          );

  static CollectionReference<ChatMessage> messages(String chatId) =>
      chats.doc(chatId).collection('messages').withConverter<ChatMessage>(
            fromFirestore: (snap, _) => ChatMessage.fromMap(snap.id, snap.data() ?? {}),
            toFirestore: (value, _) => value.toMap(),
          );

  static CollectionReference<DriverRating> get ratings =>
      fs.collection('ratings').withConverter<DriverRating>(
            fromFirestore: (snap, _) => DriverRating.fromMap(snap.id, snap.data() ?? {}),
            toFirestore: (value, _) => value.toMap(),
          );

  static CollectionReference<DriverDocument> get documents =>
      fs.collection('documents').withConverter<DriverDocument>(
            fromFirestore: (snap, _) =>
                DriverDocument.fromMap(snap.id, snap.data() ?? {}),
            toFirestore: (value, _) => value.toMap(),
          );

  static CollectionReference<Incident> get incidents =>
      fs.collection('incidents').withConverter<Incident>(
            fromFirestore: (snap, _) => Incident.fromMap(snap.id, snap.data() ?? {}),
            toFirestore: (value, _) => value.toMap(),
          );
}

/// Maps a query snapshot to a plain list — used by every repository stream.
extension SnapshotListX<T> on Stream<QuerySnapshot<T>> {
  Stream<List<T>> get docsList =>
      map((snap) => snap.docs.map((d) => d.data()).toList());
}
