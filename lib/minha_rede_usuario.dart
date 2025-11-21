import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

/// Modal que exibe a rede de conexões do usuário logado.
/// Mostra conexões ativas e solicitações pendentes.
class MinhaRedeUsuario extends StatefulWidget {
  const MinhaRedeUsuario({super.key});

  @override
  State<MinhaRedeUsuario> createState() => _MinhaRedeUsuarioState();
}

class _ConnectionData {
  _ConnectionData({
    required this.partner,
    required this.connectionDoc,
    required this.partnerType,
  });

  final Map<String, dynamic> partner;
  final DocumentSnapshot<Map<String, dynamic>> connectionDoc;
  final String partnerType; // 'profissional' ou 'academia'

  Map<String, dynamic> get connection => connectionDoc.data() ?? {};
}

class _MinhaRedeUsuarioState extends State<MinhaRedeUsuario> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Cache simples para evitar múltiplas consultas dos mesmos parceiros.
  final Map<String, Map<String, dynamic>> _partnerCache = {};

  String? _userId;

  @override
  void initState() {
    super.initState();
    _userId = _auth.currentUser?.uid;
  }

  /// Retorna o stream de conexões do usuário.
  Stream<QuerySnapshot<Map<String, dynamic>>>? _getConnectionsStream() {
    if (_userId == null) return null;
    return _firestore
        .collection('connections')
        .where('usuarioId', isEqualTo: _userId)
        .snapshots();
  }

  /// Busca o parceiro (profissional ou academia) relacionado à conexão.
  Future<Map<String, dynamic>?> _buscarParceiro(String partnerId) async {
    if (_partnerCache.containsKey(partnerId)) {
      return _partnerCache[partnerId];
    }

    try {
      // 1) Busca em professionals
      final profDoc =
          await _firestore.collection('professionals').doc(partnerId).get();
      if (profDoc.exists) {
        final data = profDoc.data();
        if (data != null) {
          _partnerCache[partnerId] = {...data, '_type': 'profissional'};
          return _partnerCache[partnerId];
        }
      }

      // 2) Busca em academias
      final acadDoc =
          await _firestore.collection('academias').doc(partnerId).get();
      if (acadDoc.exists) {
        final data = acadDoc.data();
        if (data != null) {
          _partnerCache[partnerId] = {...data, '_type': 'academia'};
          return _partnerCache[partnerId];
        }
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  /// Determina o tipo e ID do parceiro com base na conexão.
  Future<_ConnectionData?> _resolverConexao(
      DocumentSnapshot<Map<String, dynamic>> doc) async {
    try {
      final data = doc.data();
      if (data == null) return null;

      String? partnerId;
      String? partnerType;

      // Verifica se é profissional ou academia
      if (data['profissionalId'] != null) {
        partnerId = data['profissionalId'] as String?;
        partnerType = 'profissional';
      } else if (data['academiaId'] != null) {
        partnerId = data['academiaId'] as String?;
        partnerType = 'academia';
      }

      if (partnerId == null) return null;

      final partner = await _buscarParceiro(partnerId);
      if (partner == null) {
        return _ConnectionData(
          partner: {
            'nome': 'Parceiro não encontrado',
            '_type': partnerType ?? 'desconhecido',
          },
          connectionDoc: doc,
          partnerType: partnerType ?? 'desconhecido',
        );
      }

      return _ConnectionData(
        partner: partner,
        connectionDoc: doc,
        partnerType: partner['_type'] as String? ?? partnerType ?? 'desconhecido',
      );
    } catch (e) {
      return null;
    }
  }

  /// Aceita uma solicitação de conexão.
  Future<void> _aceitarSolicitacao(_ConnectionData data) async {
    try {
      await data.connectionDoc.reference.update({
        'status': 'active',
        'aceitoEm': FieldValue.serverTimestamp(),
        'isActiveForUsuario': true,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Solicitação aceita com sucesso.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao aceitar solicitação: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Rejeita uma solicitação de conexão.
  Future<void> _rejeitarSolicitacao(_ConnectionData data) async {
    try {
      await data.connectionDoc.reference.update({
        'status': 'rejected',
        'rejeitadoEm': FieldValue.serverTimestamp(),
        'isActiveForUsuario': false,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Solicitação rejeitada.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao rejeitar solicitação: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        height: MediaQuery.of(context).size.height * 0.85,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Cabeçalho
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Minha Rede',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            // Conteúdo
            Expanded(
              child: _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_userId == null) {
      return const Center(
        child: Text('Faça login para acessar sua rede.'),
      );
    }

    final stream = _getConnectionsStream();
    if (stream == null) {
      return const Center(
        child: Text('Não foi possível carregar suas conexões.'),
      );
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: stream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.red),
          );
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Erro ao carregar conexões: ${snapshot.error}'),
          );
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(
            child: Text('Nenhuma conexão encontrada.'),
          );
        }

        return FutureBuilder<List<_ConnectionData?>>(
          future: Future.wait(docs.map((doc) => _resolverConexao(doc))),
          builder: (context, futureSnapshot) {
            if (futureSnapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.red),
              );
            }

            final connections = futureSnapshot.data
                    ?.whereType<_ConnectionData>()
                    .toList(growable: false) ??
                [];

            // Separa conexões ativas e solicitações pendentes
            final conexoesAtivas = connections.where((conn) {
              final status = (conn.connection['status'] as String?) ?? 'pending';
              final isActive = conn.connection['isActiveForUsuario'] ?? false;
              return status == 'active' && isActive == true;
            }).toList();

            final solicitacoes = connections.where((conn) {
              final status = (conn.connection['status'] as String?) ?? 'pending';
              final isActive = conn.connection['isActiveForUsuario'] ?? false;
              return status != 'active' && status != 'rejected' && isActive != true;
            }).toList();

            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Painel: Minhas Conexões Ativas
                  _buildPanelConexoesAtivas(conexoesAtivas),
                  const SizedBox(height: 16),
                  // Painel: Solicitações
                  _buildPanelSolicitacoes(solicitacoes),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPanelConexoesAtivas(List<_ConnectionData> conexoes) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.people, color: Colors.green.shade700),
                const SizedBox(width: 8),
                const Text(
                  'Minhas Conexões Ativas',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (conexoes.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Nenhuma conexão ativa no momento.',
                  style: TextStyle(color: Colors.black54),
                ),
              )
            else
              ...conexoes.map((conn) => _buildConnectionCard(conn, isActive: true)),
          ],
        ),
      ),
    );
  }

  Widget _buildPanelSolicitacoes(List<_ConnectionData> solicitacoes) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.notifications_active, color: Colors.orange.shade700),
                const SizedBox(width: 8),
                const Text(
                  'Solicitações',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (solicitacoes.isEmpty)
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Nenhuma solicitação pendente.',
                  style: TextStyle(color: Colors.black54),
                ),
              )
            else
              ...solicitacoes.map((conn) => _buildConnectionCard(conn, isActive: false)),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionCard(_ConnectionData data, {required bool isActive}) {
    final partner = data.partner;
    final nome = partner['nome'] as String? ?? 'Nome não informado';
    final tipo = data.partnerType == 'profissional' ? 'Profissional' : 'Academia';
    final fotoUrl = partner['fotoUrl'] as String? ??
        partner['fotoPerfilUrl'] as String? ??
        'https://cdn-icons-png.flaticon.com/512/149/149071.png';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          // Foto
          CircleAvatar(
            radius: 30,
            backgroundImage: NetworkImage(fotoUrl),
            onBackgroundImageError: (_, __) {},
            child: const Icon(Icons.person),
          ),
          const SizedBox(width: 12),
          // Informações
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nome,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      data.partnerType == 'profissional'
                          ? Icons.person_outline
                          : Icons.fitness_center,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      tipo,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Ações (apenas para solicitações)
          if (!isActive)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.check_circle, color: Colors.green),
                  onPressed: () => _aceitarSolicitacao(data),
                  tooltip: 'Aceitar',
                ),
                IconButton(
                  icon: const Icon(Icons.cancel, color: Colors.red),
                  onPressed: () => _rejeitarSolicitacao(data),
                  tooltip: 'Rejeitar',
                ),
              ],
            ),
        ],
      ),
    );
  }
}

