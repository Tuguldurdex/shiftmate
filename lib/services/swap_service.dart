import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final swapServiceProvider = Provider<SwapService>((ref) => SwapService());

class SwapService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Get swaps collection reference
  CollectionReference get _swapsRef => _db.collection('swaps');

  // Create a swap request
  Future<DocumentReference> createSwapRequest({
    required String requesterId,
    required String targetId,
    required String offeredShiftId,
    required String requestedShiftId,
  }) async {
    return await _swapsRef.add({
      'requesterId': requesterId,
      'targetId': targetId,
      'offeredShiftId': offeredShiftId,
      'requestedShiftId': requestedShiftId,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Get swap requests sent by user
  Future<List<SwapRequest>> getSentRequests(String requesterId) async {
    final snapshot = await _swapsRef
        .where('requesterId', isEqualTo: requesterId)
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs.map((doc) => SwapRequest.fromDoc(doc)).toList();
  }

  // Get swap requests received by user
  Future<List<SwapRequest>> getReceivedRequests(String userId) async {
    final snapshot = await _swapsRef
        .where('targetId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .get();
    return snapshot.docs.map((doc) => SwapRequest.fromDoc(doc)).toList();
  }

  // Accept a swap request
  Future<void> acceptSwap(String swapId) async {
    await _swapsRef.doc(swapId).update({
      'status': 'accepted',
      'acceptedAt': FieldValue.serverTimestamp(),
    });
  }

  // Decline a swap request
  Future<void> declineSwap(String swapId) async {
    await _swapsRef.doc(swapId).update({
      'status': 'declined',
      'declinedAt': FieldValue.serverTimestamp(),
    });
  }

  // Cancel a swap request
  Future<void> cancelSwap(String swapId) async {
    await _swapsRef.doc(swapId).update({
      'status': 'cancelled',
      'cancelledAt': FieldValue.serverTimestamp(),
    });
  }

  // Pending requests count provider
  Future<int> getPendingCount(String userId) async {
    final snapshot = await _swapsRef
        .where('targetId', isEqualTo: userId)
        .where('status', isEqualTo: 'pending')
        .get();
    return snapshot.docs.length;
  }
}

// Swap request model
class SwapRequest {
  final String id;
  final String requesterId;
  final String targetId;
  final String offeredShiftId;
  final String requestedShiftId;
  final String status;
  final DateTime? createdAt;
  final DateTime? acceptedAt;
  final DateTime? declinedAt;

  SwapRequest({
    required this.id,
    required this.requesterId,
    required this.targetId,
    required this.offeredShiftId,
    required this.requestedShiftId,
    required this.status,
    this.createdAt,
    this.acceptedAt,
    this.declinedAt,
  });

  factory SwapRequest.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return SwapRequest(
      id: doc.id,
      requesterId: data['requesterId'] ?? '',
      targetId: data['targetId'] ?? '',
      offeredShiftId: data['offeredShiftId'] ?? '',
      requestedShiftId: data['requestedShiftId'] ?? '',
      status: data['status'] ?? 'pending',
      createdAt: data['createdAt'] != null ? (data['createdAt'] as Timestamp).toDate() : null,
      acceptedAt: data['acceptedAt'] != null ? (data['acceptedAt'] as Timestamp).toDate() : null,
      declinedAt: data['declinedAt'] != null ? (data['declinedAt'] as Timestamp).toDate() : null,
    );
  }

  bool get isPending => status == 'pending';
  bool get isAccepted => status == 'accepted';
  bool get isDeclined => status == 'declined';
}

// Providers
final sentSwapRequestsProvider = FutureProvider.family<List<SwapRequest>, String>((ref, requesterId) {
  return ref.watch(swapServiceProvider).getSentRequests(requesterId);
});

final receivedSwapRequestsProvider = FutureProvider.family<List<SwapRequest>, String>((ref, userId) {
  return ref.watch(swapServiceProvider).getReceivedRequests(userId);
});

final pendingSwapsCountProvider = FutureProvider.family<int, String>((ref, userId) {
  return ref.watch(swapServiceProvider).getPendingCount(userId);
});