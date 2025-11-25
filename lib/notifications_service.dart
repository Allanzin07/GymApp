// lib/notifications_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationsService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String collection = 'notifications';

  /// Cria uma notificação para `receiverId`.
  /// `data` pode conter informações adicionais (conversationId, etc).
  Future<DocumentReference<Map<String, dynamic>>> createNotification({
    required String senderId,
    required String receiverId,
    required String type, // ex: 'message', 'connection'
    required String title,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    final doc = _firestore.collection(collection).doc();
    final payload = <String, dynamic>{
      'senderId': senderId,
      'receiverId': receiverId,
      'type': type,
      'title': title,
      'message': message,
      'data': data ?? {},
      'isRead': false,
      'createdAt': FieldValue.serverTimestamp(),
    };
    await doc.set(payload);
    return doc;
  }

  /// Stream de notificações por destinatário (ordenadas por data desc no cliente).
  /// Nota: Removido orderBy da query para evitar necessidade de índice composto.
  /// A ordenação é feita no cliente.
  Stream<QuerySnapshot<Map<String, dynamic>>> streamNotificationsForUser(String receiverId) {
    return _firestore
        .collection(collection)
        .where('receiverId', isEqualTo: receiverId)
        .snapshots();
  }

  /// Stream da contagem de notificações não lidas para o destinatário.
  Stream<int> streamUnreadCount(String receiverId) {
    return _firestore
        .collection(collection)
        .where('receiverId', isEqualTo: receiverId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snap) => snap.size);
  }

  /// Marca uma notificação como lida.
  Future<void> markAsRead(String notificationId) {
    return _firestore.collection(collection).doc(notificationId).update({'isRead': true});
  }

  /// Marca todas as notificações do usuário como lidas.
  Future<void> markAllAsRead(String receiverId) async {
    final snap = await _firestore
        .collection(collection)
        .where('receiverId', isEqualTo: receiverId)
        .where('isRead', isEqualTo: false)
        .get();
    final batch = _firestore.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }
}
