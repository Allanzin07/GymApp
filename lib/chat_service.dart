// lib/chat_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Serviço simples para gerenciar conversas.
/// - getOrCreateConversation: garante a existência da conversa e retorna o id.
/// - user cache: evita múltiplas leituras ao buscar perfis para a lista de conversas.
class ChatService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // cache simples de perfis (userId -> Map)
  final Map<String, Map<String, dynamic>> _profileCache = {};

  String? get currentUid => _auth.currentUser?.uid;

  /// Retorna conversationId formado por dois UIDs ordenados: uidA_uidB
  String conversationIdFor(String uidA, String uidB) {
    final ids = [uidA, uidB]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  /// Cria a conversa se não existir e retorna o conversationId
  Future<String?> getOrCreateConversation(String otherUserId) async {
    final me = currentUid;
    if (me == null) return null;
    final conversationId = conversationIdFor(me, otherUserId);
    final ref = _firestore.collection('conversations').doc(conversationId);

    final snap = await ref.get();
    final participants = [me, otherUserId]..sort();

    if (!snap.exists) {
      await ref.set({
        'users': participants,
        'lastMessage': '',
        'updatedAt': FieldValue.serverTimestamp(),
        'createdAt': FieldValue.serverTimestamp(),
        'unreadBy': <String>[],
      });
    } else {
      // garante que a lista users esteja atualizada (merge)
      await ref.set({'users': participants}, SetOptions(merge: true));
    }
    return conversationId;
  }

  /// Adiciona uma mensagem e atualiza lastMessage/updatedAt
  Future<void> sendMessage(String conversationId, Map<String, dynamic> messageData) async {
    final convRef = _firestore.collection('conversations').doc(conversationId);
    final messagesRef = convRef.collection('messages');
    await messagesRef.add(messageData);

     final senderId = messageData['senderId']?.toString();
    String? otherId;
     List<String> participants = [];
     try {
       final snapshot = await convRef.get();
       final users = snapshot.data()?['users'] as List<dynamic>? ?? [];
       participants = users.map((e) => e.toString()).toList();
      otherId = participants.firstWhere(
        (id) => id != senderId,
        orElse: () => participants.isNotEmpty ? participants.first : '',
      );
     } catch (_) {}

     if (senderId != null) {
       await convRef.set({
         'unreadBy': FieldValue.arrayRemove([senderId]),
       }, SetOptions(merge: true));
     }

     final recipients = participants.where((id) => id != senderId).toList();
     if (recipients.isNotEmpty) {
       await convRef.set({
         'unreadBy': FieldValue.arrayUnion(recipients),
       }, SetOptions(merge: true));
     }

    await convRef.set({
      'lastSenderId': senderId,
      'lastReceiverId': otherId,
      'lastMessage': messageData['text'] ?? '',
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Marca a conversa como lida para o usuário atual.
  Future<void> markConversationRead(String conversationId) async {
    final uid = currentUid;
    if (uid == null) return;
    final convRef = _firestore.collection('conversations').doc(conversationId);
    await convRef.set({
      'unreadBy': FieldValue.arrayRemove([uid]),
    }, SetOptions(merge: true));
  }

  /// Busca perfil do usuário em coleções comuns (users, professionals, academias).
  /// Faz cache simples para reduzir leituras.
  Future<Map<String, dynamic>> fetchProfile(String userId) async {
    if (_profileCache.containsKey(userId)) return _profileCache[userId]!;

    final firestore = _firestore;

    // 1) users
    final u = await firestore.collection('users').doc(userId).get();
    if (u.exists) {
      final data = Map<String, dynamic>.from(u.data()!);
      _profileCache[userId] = data;
      return data;
    }

    // 2) professionals
    final p = await firestore.collection('professionals').doc(userId).get();
    if (p.exists) {
      final data = Map<String, dynamic>.from(p.data()!);
      _profileCache[userId] = data;
      return data;
    }

    // 3) academias
    final g = await firestore.collection('academias').doc(userId).get();
    if (g.exists) {
      final data = Map<String, dynamic>.from(g.data()!);
      _profileCache[userId] = data;
      return data;
    }

    // fallback minimal
    final fallback = {'nome': 'Contato', 'fotoUrl': null};
    _profileCache[userId] = fallback;
    return fallback;
  }
}
