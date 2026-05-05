import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appreciationServiceProvider = Provider<AppreciationService>((ref) => AppreciationService());

class AppreciationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  CollectionReference get _ref => _db.collection('appreciations');

  // Send appreciation
  Future<DocumentReference> send({
    required String senderId,
    required String senderName,
    required String recipientId,
    required String recipientName,
    required String messageType, // appreciation, greeting, milestone
    required String message,
  }) async {
    return await _ref.add({
      'senderId': senderId,
      'senderName': senderName,
      'recipientId': recipientId,
      'recipientName': recipientName,
      'messageType': messageType,
      'message': message,
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Get appreciations sent by user
  Future<List<Appreciation>> getSent(String userId) async {
    final snapshot = await _ref
        .where('senderId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs.map((doc) => Appreciation.fromDoc(doc)).toList();
  }

  // Get appreciations received by user
  Future<List<Appreciation>> getReceived(String userId) async {
    final snapshot = await _ref
        .where('recipientId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs.map((doc) => Appreciation.fromDoc(doc)).toList();
  }

  // Mark as read
  Future<void> markAsRead(String id) async {
    await _ref.doc(id).update({'isRead': true});
  }

  // Get unread count
  Future<int> getUnreadCount(String userId) async {
    final snapshot = await _ref
        .where('recipientId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .get();
    return snapshot.docs.length;
  }
}

class Appreciation {
  final String id;
  final String senderId;
  final String senderName;
  final String recipientId;
  final String recipientName;
  final String messageType;
  final String message;
  final bool isRead;
  final DateTime? createdAt;

  Appreciation({
    required this.id,
    required this.senderId,
    required this.senderName,
    required this.recipientId,
    required this.recipientName,
    required this.messageType,
    required this.message,
    required this.isRead,
    this.createdAt,
  });

  factory Appreciation.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Appreciation(
      id: doc.id,
      senderId: data['senderId'] ?? '',
      senderName: data['senderName'] ?? '',
      recipientId: data['recipientId'] ?? '',
      recipientName: data['recipientName'] ?? '',
      messageType: data['messageType'] ?? 'appreciation',
      message: data['message'] ?? '',
      isRead: data['isRead'] ?? false,
      createdAt: data['createdAt'] != null ? (data['createdAt'] as Timestamp).toDate() : null,
    );
  }

  String get icon {
    switch (messageType) {
      case 'appreciation': return '👏';
      case 'greeting': return '🎉';
      case 'milestone': return '🏆';
      default: return '💜';
    }
  }
}

// Providers
final sentAppreciationsProvider = FutureProvider.family<List<Appreciation>, String>((ref, userId) {
  return ref.watch(appreciationServiceProvider).getSent(userId);
});

final receivedAppreciationsProvider = FutureProvider.family<List<Appreciation>, String>((ref, userId) {
  return ref.watch(appreciationServiceProvider).getReceived(userId);
});

final unreadAppreciationsProvider = FutureProvider.family<int, String>((ref, userId) {
  return ref.watch(appreciationServiceProvider).getUnreadCount(userId);
});