import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

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
      final userDoc =
          await _firestore.collection('users').doc(currentUser.uid).get();
      if (userDoc.exists) {
        tipo = userDoc.data()?['tipo'] as String?;
      }

      if (tipo == null) {
        final profDoc =
            await _firestore.collection('professionals').doc(currentUser.uid).get();
        if (profDoc.exists) {
          tipo = 'profissional';
        }
      }

      if (tipo == null) {
        final acadDoc =
            await _firestore.collection('academias').doc(currentUser.uid).get();
        if (acadDoc.exists) {
          tipo = 'academia';
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
        return connections.where('academiaId', isEqualTo: _userId).snapshots();
      default:
        return null;
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
          return _buildMessage('Nenhuma conexão encontrada.');
        }

        return FutureBuilder<List<_ConnectionRowData?>>(
          future: Future.wait(
            docs.map((doc) async {
              final data = doc.data();
              final partnerId = _resolverParceiroId(data);
              if (partnerId == null) return null;
              final partner = await _buscarParceiro(partnerId);
              if (partner == null) return null;
              return _ConnectionRowData(
                partner: partner,
                connectionDoc: doc,
              );
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
                'Nenhum aluno/cliente válido encontrado para exibir.',
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

    final filteredRows = rows.where((row) {
      final connection = row.connection;
      if (_userType == 'profissional') {
        final flag = connection['isActiveForProfissional'];
        return flag == true;
      }
      if (_userType == 'academia') {
        final flag = connection['isActiveForAcademia'];
        return flag == true;
      }
      // usuario
      final flag = connection['isActiveForUsuario'];
      return flag == true;
    }).toList();

    if (filteredRows.isEmpty) {
      return isManager
          ? _buildMessage('Nenhuma conexão ativa ainda.')
          : _buildMessage('Nenhuma conexão.\nFaça uma solicitação em um perfil para aparecer aqui.');
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 3,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Gerenciamento de alunos/clientes',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _userType == 'profissional'
                    ? 'Abaixo estão os alunos vinculados ao seu perfil profissional.'
                    : 'Abaixo estão os clientes vinculados à sua academia.',
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  headingRowColor: MaterialStateColor.resolveWith(
                    (states) => Colors.red.shade50,
                  ),
                  columns: [
                    const DataColumn(label: Text('Nome')),
                    const DataColumn(label: Text('Contato')),
                    const DataColumn(label: Text('Status')),
                    const DataColumn(label: Text('Vínculo')),
                    if (isManager) const DataColumn(label: Text('Ações')),
                  ],
                  rows: filteredRows.map((row) => _buildDataRow(row, isManager)).toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  DataRow _buildDataRow(_ConnectionRowData data, bool isManager) {
    final partner = data.partner;
    final connection = data.connection;

    final nome = partner['nome'] as String? ?? 'Nome não informado';
    final telefone = partner['telefone'] as String? ??
        partner['whatsapp'] as String? ??
        partner['phone'] as String? ??
        'Não informado';
    final vinculo = _formatDate(_extractConnectionDate(connection)) ??
        'Data indisponível';
    final status = (connection['status'] as String?) ?? 'pending';
    final statusLabel =
        status == 'active' ? 'Conectado' : status == 'pending' ? 'Pendente' : status;
    final statusColor = status == 'active'
        ? Colors.green
        : status == 'pending'
            ? Colors.orange
            : Colors.grey;

    final cells = <DataCell>[
      DataCell(Text(nome)),
      DataCell(Text(telefone)),
      DataCell(
        Chip(
          avatar: Icon(
            status == 'active' ? Icons.check_circle : Icons.hourglass_top,
            color: Colors.white,
            size: 16,
          ),
          label: Text(
            statusLabel,
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: statusColor,
        ),
      ),
      DataCell(Text(vinculo)),
    ];

    if (isManager) {
      Widget actionWidget;
      if (status == 'pending') {
        actionWidget = ElevatedButton(
          onPressed: () => _aceitarSolicitacao(data),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('Aceitar'),
        );
      } else {
        actionWidget = const Text(
          'Ativo',
          style: TextStyle(color: Colors.green),
        );
      }
      cells.add(DataCell(actionWidget));
    }

    return DataRow(cells: cells);
  }

  Future<void> _aceitarSolicitacao(_ConnectionRowData data) async {
    try {
      await data.connectionDoc.reference.update({
        'status': 'active',
        'aceitoEm': FieldValue.serverTimestamp(),
        'isActiveForProfissional': _userType == 'profissional' ? true : FieldValue.delete(),
        'isActiveForAcademia': _userType == 'academia' ? true : FieldValue.delete(),
        'isActiveForUsuario': true,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Solicitação aceita com sucesso.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao aceitar solicitação: $e')),
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


