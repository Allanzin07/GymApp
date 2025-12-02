import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'notifications_service.dart';

/// Página que exibe a rede de conexões do usuário logado.
/// Se adapta automaticamente para alunos, profissionais e academias.
class MinhaRedePage extends StatefulWidget {
  const MinhaRedePage({super.key});

  @override
  State<MinhaRedePage> createState() => _MinhaRedePageState();
}

class _ConnectionRowData {
  _ConnectionRowData({
    required this.partner,
    required this.connectionDoc,
  });

  final Map<String, dynamic> partner;
  final DocumentSnapshot<Map<String, dynamic>> connectionDoc;

  Map<String, dynamic> get connection => connectionDoc.data() ?? {};
}

class _MinhaRedePageState extends State<MinhaRedePage> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Cache simples para evitar múltiplas consultas dos mesmos parceiros.
  final Map<String, Map<String, dynamic>> _partnerCache = {};

  String? _userType;
  String? _userId;
  bool _isLoadingUser = true;
  String? _userLoadError;

  @override
  void initState() {
    super.initState();
    _carregarTipoUsuario();
  }

  /// Carrega o tipo do usuário logado a partir da coleção `users`.
  Future<void> _carregarTipoUsuario() async {
    final currentUser = _auth.currentUser;

    if (currentUser == null) {
      setState(() {
        _userLoadError = 'Faça login para acessar sua rede.';
        _isLoadingUser = false;
      });
      return;
    }

    try {
      String? tipo;

      // 1) Verifica se existe em professionals
      final profDoc = await _firestore
          .collection('professionals')
          .doc(currentUser.uid)
          .get();
      if (profDoc.exists) {
        tipo = 'profissional';
      }

      // 2) Se não encontrou, verifica academias
      if (tipo == null) {
        final acadDoc =
            await _firestore.collection('academias').doc(currentUser.uid).get();
        if (acadDoc.exists) {
          tipo = 'academia';
        }
      }

      // 3) Se não encontrou, verifica users (por último, pois pode existir em múltiplas coleções)
      if (tipo == null) {
        final userDoc =
            await _firestore.collection('users').doc(currentUser.uid).get();
        if (userDoc.exists) {
          tipo = userDoc.data()?['tipo'] as String? ?? 'usuario';
        }
      }

      if (tipo == null) {
        setState(() {
          _userLoadError =
              'Perfil não encontrado nas coleções esperadas. Verifique seus dados.';
          _isLoadingUser = false;
        });
        return;
      }

      setState(() {
        _userType = tipo;
        _userId = currentUser.uid;
        _isLoadingUser = false;
      });
    } catch (error) {
      setState(() {
        _userLoadError = 'Erro ao carregar perfil: $error';
        _isLoadingUser = false;
      });
    }
  }

  /// Retorna o fluxo de conexões filtrado pelo tipo do usuário.
  Stream<QuerySnapshot<Map<String, dynamic>>>? _getConnectionsStream() {
    if (_userId == null || _userType == null) return null;

    final connections = _firestore.collection('connections');

    switch (_userType) {
      case 'usuario':
        return connections.where('usuarioId', isEqualTo: _userId).snapshots();
      case 'profissional':
        return connections
            .where('profissionalId', isEqualTo: _userId)
            .snapshots();
      case 'academia':
        // Busca conexões onde esta academia é participante
        return connections.where('academiaId', isEqualTo: _userId).snapshots();
      default:
        return null;
    }
  }

  /// Busca alternativa: tenta encontrar conexões mesmo se o campo não corresponder exatamente
  /// Útil para debug e casos onde o documento pode ter sido criado com ID diferente
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      _buscarConexoesAlternativa() async {
    if (_userId == null || _userType == null) return [];

    try {
      // Busca todas as conexões e filtra no cliente
      final allConnections = await _firestore.collection('connections').get();
      final filtered = allConnections.docs.where((doc) {
        final data = doc.data();
        switch (_userType) {
          case 'usuario':
            return data['usuarioId'] == _userId;
          case 'profissional':
            return data['profissionalId'] == _userId;
          case 'academia':
            return data['academiaId'] == _userId;
          default:
            return false;
        }
      }).toList();

      // Debug: se não encontrou nada, vamos verificar se há conexões com IDs diferentes
      if (filtered.isEmpty && _userType == 'academia') {
        // Para debug: mostra todas as conexões que têm academiaId (mesmo que diferente)
        final withAcademia = allConnections.docs.where((doc) {
          final data = doc.data();
          return data.containsKey('academiaId') && data['academiaId'] != null;
        }).toList();

        // Se encontrou conexões com academiaId diferente, retorna elas para debug
        // (isso vai mostrar que há uma inconsistência)
        if (withAcademia.isNotEmpty) {
          return withAcademia;
        }
      }

      return filtered;
    } catch (e) {
      return [];
    }
  }

  /// Busca o parceiro (ou parceiros) relacionados à conexão atual.
  /// Utiliza cache para reduzir idas ao Firestore.
  Future<Map<String, dynamic>?> _buscarParceiro(String partnerId) async {
    if (_partnerCache.containsKey(partnerId)) {
      return _partnerCache[partnerId];
    }

    try {
      // 1) users
      final partnerDoc =
          await _firestore.collection('users').doc(partnerId).get();
      if (partnerDoc.exists) {
        final data = partnerDoc.data();
        if (data != null) {
          _partnerCache[partnerId] = data;
          return data;
        }
      }

      // 2) professionals
      final profDoc =
          await _firestore.collection('professionals').doc(partnerId).get();
      if (profDoc.exists) {
        final data = profDoc.data();
        if (data != null) {
          _partnerCache[partnerId] = data;
          return data;
        }
      }

      // 3) academias
      final gymDoc =
          await _firestore.collection('academias').doc(partnerId).get();
      if (gymDoc.exists) {
        final data = gymDoc.data();
        if (data != null) {
          _partnerCache[partnerId] = data;
          return data;
        }
      }

      return null;
    } catch (_) {
      return null;
    }
  }

  /// Determina qual ID deve ser buscado como parceiro com base na conexão.
  String? _resolverParceiroId(Map<String, dynamic> connection) {
    switch (_userType) {
      case 'usuario':
        return connection['profissionalId'] as String? ??
            connection['academiaId'] as String?;
      case 'profissional':
      case 'academia':
        return connection['usuarioId'] as String?;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Minha Rede'),
        backgroundColor: Colors.red,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoadingUser) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.red),
      );
    }

    if (_userLoadError != null) {
      return _buildMessage(_userLoadError!);
    }

    final stream = _getConnectionsStream();
    if (stream == null) {
      return _buildMessage('Não foi possível carregar suas conexões.');
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
          return _buildMessage('Erro ao carregar conexões: ${snapshot.error}');
        }

        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          // Tenta busca alternativa para verificar se há conexões com IDs diferentes
          return FutureBuilder<
              List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
            future: _buscarConexoesAlternativa(),
            builder: (context, altSnapshot) {
              if (altSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.red),
                );
              }

              final altDocs = altSnapshot.data ?? [];
              if (altDocs.isNotEmpty) {
                // Encontrou conexões na busca alternativa - mostra elas
                return FutureBuilder<List<_ConnectionRowData?>>(
                  future: Future.wait(
                    altDocs.map((doc) async {
                      try {
                        final data = doc.data();
                        final partnerId = _resolverParceiroId(data);
                        if (partnerId == null) {
                          return _ConnectionRowData(
                            partner: {
                              'nome': 'Parceiro não encontrado',
                              'telefone': 'N/A',
                            },
                            connectionDoc: doc,
                          );
                        }
                        final partner = await _buscarParceiro(partnerId);
                        if (partner == null) {
                          return _ConnectionRowData(
                            partner: {
                              'nome':
                                  'Parceiro não encontrado (ID: ${partnerId.substring(0, 8)}...)',
                              'telefone': 'N/A',
                            },
                            connectionDoc: doc,
                          );
                        }
                        return _ConnectionRowData(
                          partner: partner,
                          connectionDoc: doc,
                        );
                      } catch (e) {
                        return _ConnectionRowData(
                          partner: {
                            'nome': 'Erro ao carregar',
                            'telefone': 'N/A',
                          },
                          connectionDoc: doc,
                        );
                      }
                    }),
                  ),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: Colors.red),
                      );
                    }
                    final rows = snapshot.data
                            ?.whereType<_ConnectionRowData>()
                            .toList(growable: false) ??
                        [];
                    if (rows.isEmpty) {
                      return _buildMessage(
                        'Nenhuma conexão encontrada.\n'
                        'Tipo: $_userType | UserId: $_userId\n'
                        'Verifique se você fez uma solicitação de conexão.',
                      );
                    }
                    return _buildConnectionsTable(rows);
                  },
                );
              }

              // Não encontrou nada mesmo na busca alternativa
              // Busca uma amostra de conexões para mostrar informações de debug
              return FutureBuilder<QuerySnapshot>(
                future: _firestore.collection('connections').limit(5).get(),
                builder: (context, sampleSnapshot) {
                  String debugInfo = 'Nenhuma conexão encontrada.\n\n';
                  debugInfo += 'Tipo: $_userType\n';
                  debugInfo += 'UserId logado: $_userId\n\n';

                  if (sampleSnapshot.hasData &&
                      sampleSnapshot.data!.docs.isNotEmpty) {
                    final fieldName = _userType == 'academia'
                        ? 'academiaId'
                        : _userType == 'profissional'
                            ? 'profissionalId'
                            : 'usuarioId';
                    final sample = sampleSnapshot.data!.docs.first.data()
                        as Map<String, dynamic>;
                    final sampleId = sample[fieldName] as String?;

                    if (sampleId != null) {
                      debugInfo +=
                          'Exemplo de ${fieldName} encontrado: $sampleId\n';
                      if (sampleId != _userId) {
                        debugInfo +=
                            '\n⚠️ ATENÇÃO: O ID no documento ($sampleId) é diferente do seu userId logado.\n';
                        debugInfo +=
                            'Isso significa que a conexão foi criada com um ID diferente.\n\n';
                        debugInfo += 'Solução:\n';
                        debugInfo +=
                            '1. No Firestore, edite o documento e altere o campo "$fieldName" para: $_userId\n';
                        debugInfo +=
                            '2. Ou peça ao usuário para criar uma nova solicitação de conexão.';
                      } else {
                        debugInfo += '\n✅ O ID corresponde ao seu userId.';
                      }
                    } else {
                      debugInfo +=
                          'Nenhum documento com o campo "$fieldName" foi encontrado.';
                    }
                  } else {
                    debugInfo += 'Nenhuma conexão encontrada no Firestore.';
                  }

                  return _buildMessage(debugInfo);
                },
              );
            },
          );
        }

        return FutureBuilder<List<_ConnectionRowData?>>(
          future: Future.wait(
            docs.map((doc) async {
              try {
                final data = doc.data();
                final partnerId = _resolverParceiroId(data);
                if (partnerId == null) {
                  // Se não conseguir resolver o parceiro, ainda mostra a conexão com dados básicos
                  return _ConnectionRowData(
                    partner: {
                      'nome': 'Parceiro não encontrado',
                      'telefone': 'N/A',
                    },
                    connectionDoc: doc,
                  );
                }
                final partner = await _buscarParceiro(partnerId);
                if (partner == null) {
                  // Se o parceiro não for encontrado, mostra com dados básicos
                  return _ConnectionRowData(
                    partner: {
                      'nome':
                          'Parceiro não encontrado (ID: ${partnerId.substring(0, 8)}...)',
                      'telefone': 'N/A',
                    },
                    connectionDoc: doc,
                  );
                }
                return _ConnectionRowData(
                  partner: partner,
                  connectionDoc: doc,
                );
              } catch (e) {
                // Em caso de erro, ainda tenta mostrar a conexão
                return _ConnectionRowData(
                  partner: {
                    'nome': 'Erro ao carregar',
                    'telefone': 'N/A',
                  },
                  connectionDoc: doc,
                );
              }
            }),
          ),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: Colors.red),
              );
            }

            final rows = snapshot.data
                    ?.whereType<_ConnectionRowData>()
                    .toList(growable: false) ??
                [];

            if (rows.isEmpty) {
              return _buildMessage(
                'Nenhum aluno/cliente válido encontrado para exibir.\n'
                'Total de documentos encontrados: ${docs.length}',
              );
            }

            return _buildConnectionsTable(rows);
          },
        );
      },
    );
  }

  /// Widget reutilizável para mensagens informativas na página.
  Widget _buildMessage(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
      ),
    );
  }

  Widget _buildConnectionsTable(List<_ConnectionRowData> rows) {
    final isManager = _userType == 'profissional' || _userType == 'academia';

    final conexoesAtivas = <_ConnectionRowData>[];
    final solicitacoesPendentes = <_ConnectionRowData>[];

    for (final row in rows) {
      final connection = row.connection;
      final status = (connection['status'] as String?) ?? 'pending';

      bool isActive = false;
      if (status == 'active') {
        if (_userType == 'profissional') {
          isActive = connection['isActiveForProfissional'] != false;
        } else if (_userType == 'academia') {
          isActive = connection['isActiveForAcademia'] != false;
        } else {
          isActive = connection['isActiveForUsuario'] != false;
        }
      }

      if (isActive) {
        conexoesAtivas.add(row);
      } else if (status != 'rejected') {
        solicitacoesPendentes.add(row);
      }
    }

    if (conexoesAtivas.isEmpty && solicitacoesPendentes.isEmpty) {
      return isManager
          ? _buildMessage('Nenhuma conexão ou solicitação encontrada.')
          : _buildMessage(
              'Nenhuma conexão.\nFaça uma solicitação em um perfil para aparecer aqui.');
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (solicitacoesPendentes.isNotEmpty && isManager)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Solicitações Pendentes',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange.shade900,
                ),
              ),
              const SizedBox(height: 12),
              ...solicitacoesPendentes.map((row) {
                return _buildConnectionCard(row, isManager, isRequest: true);
              }),
            ],
          ),
        if (solicitacoesPendentes.isNotEmpty && isManager)
          const SizedBox(height: 32),
        const Text(
          'Conexões Ativas',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...conexoesAtivas.map((row) {
          return _buildConnectionCard(row, isManager, isRequest: false);
        }),
      ],
    );
  }

  /// CARD moderno estilo rede social
  Widget _buildConnectionCard(
    _ConnectionRowData data,
    bool isManager, {
    bool isRequest = false,
  }) {
    final partner = data.partner;
    final connection = data.connection;

    final nome = partner['nome'] as String? ??
        partner['name'] as String? ??
        'Nome não informado';
    final foto = partner['fotoPerfilUrl'] as String? ??
        partner['fotoUrl'] as String? ??
        partner['avatar'] as String? ??
        '';
    final telefone = partner['whatsapp'] as String? ??
        partner['telefone'] as String? ??
        partner['phone'] as String? ??
        'Não informado';
    final dataVinculo =
        _formatDate(_extractConnectionDate(connection)) ?? 'Data não informada';
    final status = (connection['status'] as String?) ?? 'pending';

    Color statusColor = Colors.orange;
    String statusLabel = 'Pendente';
    if (status == 'active') {
      statusColor = Colors.green;
      statusLabel = 'Conectado';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // FOTO DO PERFIL (JÁ CORRIGIDO O BUG DO CircleAvatar)
            CircleAvatar(
              radius: 32,
              backgroundImage: foto.isNotEmpty ? NetworkImage(foto) : null,
              backgroundColor: Colors.grey.shade300,
              child: foto.isEmpty
                  ? const Icon(Icons.person, size: 32, color: Colors.grey)
                  : null,
            ),
            // ⚠️ AJUSTE 1: Redução do espaçamento de 16 para 12 pixels
            const SizedBox(width: 12),
            // TEXTO PRINCIPAL
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    nome,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    telefone,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  // STATUS
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          statusLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Icon(Icons.calendar_month,
                          size: 16, color: Colors.grey.shade600),
                      const SizedBox(width: 4),
                      // ⚠️ AJUSTE 2: Usar Flexible na data para evitar overflow na Row interna
                      Flexible(
                        child: Text(
                          dataVinculo,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // AÇÕES (Somente para academia/profissional)
            if (isManager && isRequest)
              Column(
                children: [
                  ElevatedButton.icon(
                    onPressed: () => _aceitarSolicitacao(data),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Aceitar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      // ⚠️ AJUSTE 3: Redução do padding vertical dos botões para economizar pixels
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6), // Era vertical: 8
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => _rejeitarSolicitacao(data),
                    icon: const Icon(Icons.close, size: 18, color: Colors.red),
                    label: const Text(
                      'Recusar',
                      style: TextStyle(color: Colors.red),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.red),
                      // ⚠️ AJUSTE 3: Redução do padding vertical dos botões para economizar pixels
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6), // Era vertical: 8
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _aceitarSolicitacao(_ConnectionRowData data) async {
    try {
      final updateData = <String, dynamic>{
        'status': 'active',
        'aceitoEm': FieldValue.serverTimestamp(),
        'isActiveForUsuario': true, // Sempre true quando aceito
      };

      // Define o flag apropriado baseado no tipo de usuário
      if (_userType == 'profissional') {
        updateData['isActiveForProfissional'] = true;
      } else if (_userType == 'academia') {
        updateData['isActiveForAcademia'] = true;
      }

      await data.connectionDoc.reference.update(updateData);

      // ✅ Cria notificação de conexão aceita
      final connection = data.connectionDoc.data() ?? {};
      final usuarioId = connection['usuarioId'] as String?;
      if (usuarioId != null && _userId != null) {
        try {
          Map<String, dynamic>? accepterProfile;
          if (_userType == 'academia') {
            accepterProfile =
                (await _firestore.collection('academias').doc(_userId).get())
                    .data();
          } else if (_userType == 'profissional') {
            accepterProfile = (await _firestore
                    .collection('professionals')
                    .doc(_userId)
                    .get())
                .data();
          }

          final accepterName = accepterProfile?['nome'] as String? ??
              accepterProfile?['name'] as String? ??
              (_userType == 'academia' ? 'Academia' : 'Profissional');

          final notificationsService = NotificationsService();
          await notificationsService.createNotification(
            senderId: _userId!,
            receiverId: usuarioId,
            type: 'connection_accept',
            title: '$accepterName aceitou sua solicitação de conexão',
            message: 'Vocês agora estão conectados!',
            data: {
              'connectionType': _userType == 'academia'
                  ? 'academia_to_usuario'
                  : 'profissional_to_usuario',
            },
          );
        } catch (e) {
          debugPrint('Erro ao criar notificação de conexão aceita: $e');
        }
      }

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
  Future<void> _rejeitarSolicitacao(_ConnectionRowData data) async {
    try {
      final updateData = <String, dynamic>{
        'status': 'rejected',
        'rejeitadoEm': FieldValue.serverTimestamp(),
      };

      // Define o flag apropriado como false baseado no tipo de usuário
      if (_userType == 'profissional') {
        updateData['isActiveForProfissional'] = false;
      } else if (_userType == 'academia') {
        updateData['isActiveForAcademia'] = false;
      }

      await data.connectionDoc.reference.update(updateData);
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

  DateTime? _extractConnectionDate(Map<String, dynamic> connection) {
    final dynamic rawDate = connection['vinculadoEm'] ??
        connection['dataVinculacao'] ??
        connection['criadoEm'] ??
        connection['createdAt'] ??
        connection['atualizadoEm'];

    if (rawDate is Timestamp) return rawDate.toDate();
    if (rawDate is DateTime) return rawDate;
    if (rawDate is String) {
      return DateTime.tryParse(rawDate);
    }
    return null;
  }

  String? _formatDate(DateTime? date) {
    if (date == null) return null;
    final local = date.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year.toString();
    return '$day/$month/$year';
  }
}
