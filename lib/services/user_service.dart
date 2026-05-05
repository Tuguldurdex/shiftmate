import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final userServiceProvider = Provider<UserService>((ref) => UserService());

class UserService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Get users collection reference
  CollectionReference get _usersRef => _db.collection('users');

  // Get user data by ID
  Future<UserProfile?> getUser(String uid) async {
    final doc = await _usersRef.doc(uid).get();
    if (!doc.exists) return null;
    return UserProfile.fromDoc(doc);
  }

// Create or update user
  Future<void> createUser({
    required String uid,
    required String name,
    required String email,
    String role = 'admin',
  }) async {
    await _usersRef.doc(uid).set({
      'uid': uid,
      'name': name,
      'email': email,
      'role': role,
      'createdAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // Get user role by ID
  Future<String> getUserRole(String uid) async {
    final doc = await _usersRef.doc(uid).get();
    if (!doc.exists) return 'worker';
    return (doc.data() as Map<String, dynamic>?)?['role'] as String? ?? 'worker';
  }

  // Update user role (manager only)
  Future<void> updateUserRole(String uid, String role) async {
    await _usersRef.doc(uid).update({'role': role});
  }

  // Get all users (for managers)
  Future<List<UserProfile>> getAllUsers() async {
    final snapshot = await _usersRef.get();
    return snapshot.docs.map((doc) => UserProfile.fromDoc(doc)).toList();
  }

  // Get workers
  Future<List<UserProfile>> getWorkers() async {
    final snapshot = await _usersRef.where('role', isEqualTo: 'worker').get();
    return snapshot.docs.map((doc) => UserProfile.fromDoc(doc)).toList();
  }
}

// User profile model
class UserProfile {
  final String uid;
  final String name;
  final String email;
  final String role;
  final DateTime? createdAt;

  UserProfile({
    required this.uid,
    required this.name,
    required this.email,
    required this.role,
    this.createdAt,
  });

  factory UserProfile.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserProfile(
      uid: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      role: data['role'] ?? 'worker',
      createdAt: data['createdAt'] != null ? (data['createdAt'] as Timestamp).toDate() : null,
    );
  }

  bool get isManager => role == 'admin';
  bool get isWorker => role == 'worker';
  bool get isAdmin => role == 'admin';
}

// Providers
final userProfileProvider = FutureProvider.family<UserProfile?, String>((ref, uid) {
  return ref.watch(userServiceProvider).getUser(uid);
});

final allUsersProvider = FutureProvider<List<UserProfile>>((ref) {
  return ref.watch(userServiceProvider).getAllUsers();
});

final workersProvider = FutureProvider<List<UserProfile>>((ref) {
  return ref.watch(userServiceProvider).getWorkers();
});