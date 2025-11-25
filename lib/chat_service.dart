// lib/chat_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'notifications_service.dart';

class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final NotificationsService _notificationsService = NotificationsService();

  final Map<String, Map<String, dynamic>> _profileCache = {};

  String? get currentUid => _auth.currentUser?.uid;

  /// Gera ID único baseado nos dois participantes
  String conversationIdFor(String uidA, String uidB) {
    final ids = [uidA, uidB]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  /// Cria conversa se não existir
  Future<String?> getOrCreateConversation(String otherUserId) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return null;

    final uid = currentUser.uid;

    final existing = await _firestore
        .collection('conversations')
        .where('users', arrayContains: uid)
        .get();

    for (var doc in existing.docs) {
      final users = List<String>.from(doc['users'] ?? []);
      if (users.contains(otherUserId)) {
        return doc.id;
      }
    }

    final doc = await _firestore.collection('conversations').add({
      'users': [uid, otherUserId],
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessage': '',
      'updatedAt': FieldValue.serverTimestamp(),
      'unreadBy': [],
      'unreadCount': {
        uid: 0,
        otherUserId: 0,
      }
    });

    return doc.id;
  }

  /// ENVIA MENSAGEM E ATUALIZA CONTADOR CORRETAMENTE
  Future<void> sendMessage(String conversationId, Map<String, dynamic> messageData) async {
    final senderId = messageData['senderId']?.toString();
    if (senderId == null) return;

    final convRef = _firestore.collection('conversations').doc(conversationId);
    final messagesRef = convRef.collection('messages');

    await messagesRef.add(messageData);

    final snapshot = await convRef.get();
    final participants = List<String>.from(snapshot.data()?['users'] ?? []);

    final receiverId = participants.firstWhere((id) => id != senderId);

    // ✅ INCREMENTA NÃO LIDA PARA DESTINATÁRIO
    await convRef.update({
      'lastSenderId': senderId,
      'lastReceiverId': receiverId,
      'lastMessage': messageData['text'] ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
      'unreadBy': FieldValue.arrayUnion([receiverId]),
      'unreadCount.$receiverId': FieldValue.increment(1),
    });

    // ✅ Cria notificação para o destinatário
    try {
      final senderProfile = await fetchProfile(senderId);
      final senderName = senderProfile['nome'] as String? ?? 'Usuário';
      final senderPhotoUrl = senderProfile['fotoUrl'] as String?;

      await _notificationsService.createNotification(
        senderId: senderId,
        receiverId: receiverId,
        type: 'message',
        title: senderName,
        message: '$senderName te enviou uma mensagem: "${messageData['text']}"',
        data: {
          'conversationId': conversationId,
          'otherUserId': senderId,
          'otherUserName': senderName,
          'otherUserPhoto': senderPhotoUrl,
        },
      );
    } catch (e) {
      debugPrint('Erro ao criar notificação de mensagem: $e');
    }
  }

  /// MARCA COMO LIDA SOMENTE SE O USUÁRIO REALMENTE FOR DESTINATÁRIO
  Future<void> markConversationRead(String conversationId) async {
    final uid = currentUid;
    if (uid == null) return;

    final convRef = _firestore.collection('conversations').doc(conversationId);
    final snap = await convRef.get();
    if (!snap.exists) return;

    final data = snap.data() ?? {};
    final List unreadBy = data['unreadBy'] ?? [];

    if (!unreadBy.contains(uid)) return; // ✅ só zera se realmente tiver pendência

    await convRef.update({
      'unreadBy': FieldValue.arrayRemove([uid]),
      'unreadCount.$uid': 0,
    });
  }

  /// BUSCA PERFIL COM CACHE
  Future<Map<String, dynamic>> fetchProfile(String userId) async {
    if (_profileCache.containsKey(userId)) return _profileCache[userId]!;

    try {
      final firestore = _firestore;

      final userDoc = await firestore.collection('users').doc(userId).get();
      if (userDoc.exists) {
        final data = userDoc.data()!;
        final normalized = {
          'nome': data['nome'] ?? data['name'] ?? 'Usuário',
          'fotoUrl': data['fotoUrl'] ?? data['fotoPerfilUrl'] ?? '',
          ...data,
        };
        _profileCache[userId] = normalized;
        return normalized;
      }

      final profDoc = await firestore.collection('professionals').doc(userId).get();
      if (profDoc.exists) {
        final data = profDoc.data()!;
        final normalized = {
          'nome': data['nome'] ?? 'Profissional',
          'fotoUrl': data['fotoUrl'] ?? data['fotoPerfilUrl'] ?? '',
          ...data,
        };
        _profileCache[userId] = normalized;
        return normalized;
      }

      final acadDoc = await firestore.collection('academias').doc(userId).get();
      if (acadDoc.exists) {
        final data = acadDoc.data()!;
        final normalized = {
          'nome': data['nome'] ?? 'Academia',
          'fotoUrl': data['fotoUrl'] ?? data['fotoPerfilUrl'] ?? '',
          ...data,
        };
        _profileCache[userId] = normalized;
        return normalized;
      }
    } catch (e) {
      debugPrint('Erro ao buscar perfil: $e');
    }

    final fallback = {
      'nome': 'Contato',
      'fotoUrl': '',
    };

    _profileCache[userId] = fallback;
    return fallback;
  }
}
