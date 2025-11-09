import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:uuid/uuid.dart';

class EditarPerfilProfissionalPage extends StatefulWidget {
  const EditarPerfilProfissionalPage({super.key});

  @override
  State<EditarPerfilProfissionalPage> createState() =>
      _EditarPerfilProfissionalPageState();
}

class _EditarPerfilProfissionalPageState
    extends State<EditarPerfilProfissionalPage> {
  final _formKey = GlobalKey<FormState>();
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _picker = ImagePicker();

  // Controladores de texto
  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _especialidadeController =
      TextEditingController();
  final TextEditingController _descricaoController = TextEditingController();
  final TextEditingController _localizacaoController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _whatsappController = TextEditingController();
  final TextEditingController _linkController = TextEditingController();

  // Imagens
  File? _fotoPerfil;
  File? _fotoCapa;
  XFile? _fotoPerfilXFile;
  XFile? _fotoCapaXFile;
  String? _fotoPerfilUrlAtual;
  String? _fotoCapaUrlAtual;

  bool _isLoading = false;
  bool _isSaving = false;
  double _uploadProgress = 0.0;

  // Recuperar UID do usuário autenticado (profissional)
  String get _profissionalId {
    final user = FirebaseAuth.instance.currentUser;
    return user?.uid ?? 'profissional_demo';
  }

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _especialidadeController.dispose();
    _descricaoController.dispose();
    _localizacaoController.dispose();
    _emailController.dispose();
    _whatsappController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  Future<void> _carregarDados() async {
    setState(() => _isLoading = true);
    try {
      final doc =
          await _firestore.collection('professionals').doc(_profissionalId).get();

      if (doc.exists) {
        final data = doc.data()!;
        _nomeController.text = data['nome'] ?? '';
        _especialidadeController.text = data['especialidade'] ?? '';
        _descricaoController.text = data['descricao'] ?? '';
        _localizacaoController.text = data['localizacao'] ?? '';
        _emailController.text = data['email'] ?? '';
        _whatsappController.text = data['whatsapp'] ?? '';
        _linkController.text = data['link'] ?? '';
        _fotoPerfilUrlAtual = data['fotoUrl'];
        _fotoCapaUrlAtual = data['capaUrl'];
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao carregar dados: $e')),
      );
    }
    setState(() => _isLoading = false);
  }

  Future<void> _escolherFotoPerfil() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galeria'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Câmera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1200,
      );
      if (picked != null) {
        setState(() {
          _fotoPerfilXFile = picked;
          if (!kIsWeb) {
            _fotoPerfil = File(picked.path);
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao selecionar foto')),
      );
    }
  }

  Future<void> _escolherFotoCapa() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galeria'),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Câmera'),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1920,
      );
      if (picked != null) {
        setState(() {
          _fotoCapaXFile = picked;
          if (!kIsWeb) {
            _fotoCapa = File(picked.path);
          }
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao selecionar foto de capa')),
      );
    }
  }

  Future<String> _uploadImagem(dynamic file, String folder) async {
    final id = const Uuid().v4();
    final ref = _storage.ref().child('$folder/$id.jpg');

    final uploadTask = kIsWeb 
        ? ref.putData(await file.readAsBytes())
        : ref.putFile(file as File);

    uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
      final progress = snapshot.bytesTransferred /
          (snapshot.totalBytes == 0 ? 1 : snapshot.totalBytes);
      if (mounted) {
        setState(() => _uploadProgress = progress);
      }
    });

    final snapshot = await uploadTask.whenComplete(() {});
    final downloadUrl = await snapshot.ref.getDownloadURL();
    return downloadUrl;
  }

  Future<void> _salvarPerfil() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
      _uploadProgress = 0.0;
    });

    try {
      String? fotoPerfilUrl = _fotoPerfilUrlAtual;
      String? fotoCapaUrl = _fotoCapaUrlAtual;

      // Upload da foto de perfil se foi selecionada
      if (_fotoPerfilXFile != null) {
        fotoPerfilUrl = await _uploadImagem(
          _fotoPerfilXFile!,
          'professionals/$_profissionalId/perfil',
        );
      }

      // Upload da foto de capa se foi selecionada
      if (_fotoCapaXFile != null) {
        fotoCapaUrl = await _uploadImagem(
          _fotoCapaXFile!,
          'professionals/$_profissionalId/capa',
        );
      }

      // Salvar dados no Firestore
      await _firestore.collection('professionals').doc(_profissionalId).set({
        'nome': _nomeController.text.trim(),
        'especialidade': _especialidadeController.text.trim(),
        'descricao': _descricaoController.text.trim(),
        'localizacao': _localizacaoController.text.trim(),
        'email': _emailController.text.trim(),
        'whatsapp': _whatsappController.text.trim(),
        'link': _linkController.text.trim(),
        if (fotoPerfilUrl != null) 'fotoUrl': fotoPerfilUrl,
        if (fotoCapaUrl != null) 'capaUrl': fotoCapaUrl,
        'atualizadoEm': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Perfil atualizado com sucesso!')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao salvar: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _buildFotoCapaPreview() {
    return Stack(
      children: [
        Container(
          height: 200,
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(12),
          ),
          child: _fotoCapaXFile != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: kIsWeb
                      ? FutureBuilder<Uint8List>(
                          future: _fotoCapaXFile!.readAsBytes(),
                          builder: (context, snapshot) {
                            if (snapshot.hasData) {
                              return Image.memory(
                                snapshot.data!,
                                fit: BoxFit.cover,
                              );
                            }
                            return const Center(child: CircularProgressIndicator());
                          },
                        )
                      : Image.file(
                          _fotoCapa!,
                          fit: BoxFit.cover,
                        ),
                )
              : _fotoCapaUrlAtual != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        _fotoCapaUrlAtual!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Icon(
                          Icons.image,
                          size: 60,
                          color: Colors.grey,
                        ),
                      ),
                    )
                  : const Icon(Icons.image, size: 60, color: Colors.grey),
        ),
        Positioned(
          bottom: 12,
          right: 12,
          child: FloatingActionButton.small(
            onPressed: _isSaving ? null : _escolherFotoCapa,
            backgroundColor: Colors.red,
            child: const Icon(Icons.camera_alt, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildFotoPerfilPreview() {
    return Stack(
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 4),
          ),
          child: _fotoPerfilXFile != null
              ? ClipOval(
                  child: kIsWeb
                      ? FutureBuilder<Uint8List>(
                          future: _fotoPerfilXFile!.readAsBytes(),
                          builder: (context, snapshot) {
                            if (snapshot.hasData) {
                              return Image.memory(
                                snapshot.data!,
                                fit: BoxFit.cover,
                              );
                            }
                            return const Center(child: CircularProgressIndicator());
                          },
                        )
                      : Image.file(
                          _fotoPerfil!,
                          fit: BoxFit.cover,
                        ),
                )
              : _fotoPerfilUrlAtual != null
                  ? ClipOval(
                      child: Image.network(
                        _fotoPerfilUrlAtual!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => const Icon(
                          Icons.person,
                          size: 60,
                          color: Colors.grey,
                        ),
                      ),
                    )
                  : const Icon(Icons.person, size: 60, color: Colors.grey),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: Container(
            decoration: const BoxDecoration(
              color: Colors.red,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              onPressed: _isSaving ? null : _escolherFotoPerfil,
              icon: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Perfil Profissional'),
        backgroundColor: Colors.red,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : Form(
              key: _formKey,
              child: ListView(
                children: [
                  // Foto de capa
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: _buildFotoCapaPreview(),
                  ),
                  // Foto de perfil (centralizada)
                  Center(
                    child: Transform.translate(
                      offset: const Offset(0, -60),
                      child: _buildFotoPerfilPreview(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Campos do formulário
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _nomeController,
                          decoration: InputDecoration(
                            labelText: 'Nome completo',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          validator: (v) =>
                              v == null || v.trim().isEmpty ? 'Informe seu nome' : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _especialidadeController,
                          decoration: InputDecoration(
                            labelText:
                                'Especialidade (ex: Personal Trainer, Nutricionista...)',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          validator: (v) => v == null || v.trim().isEmpty
                              ? 'Informe sua especialidade'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _descricaoController,
                          maxLines: 4,
                          decoration: InputDecoration(
                            labelText: 'Descrição / Sobre você',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _localizacaoController,
                          decoration: InputDecoration(
                            labelText: 'Localização',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Informações para contato',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _emailController,
                          decoration: InputDecoration(
                            labelText: 'E-mail',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _whatsappController,
                          decoration: InputDecoration(
                            labelText: 'WhatsApp / Telefone',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                          keyboardType: TextInputType.phone,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _linkController,
                          decoration: InputDecoration(
                            labelText: 'Links (Instagram, site, etc.)',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 24),
                        // Indicador de progresso
                        if (_isSaving) ...[
                          LinearProgressIndicator(
                            value: _uploadProgress,
                            backgroundColor: Colors.grey.shade300,
                            valueColor: const AlwaysStoppedAnimation<Color>(Colors.red),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${(_uploadProgress * 100).toStringAsFixed(0)}% enviado',
                            style: const TextStyle(color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                        ],
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isSaving ? null : _salvarPerfil,
                            icon: const Icon(Icons.save),
                            label: Text(_isSaving ? 'Salvando...' : 'Salvar Alterações'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
