// ignore_for_file: use_build_context_synchronously

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';

// MIXIN DO UPLOAD
import 'package:gym_app/mixins/upload_mixin.dart';

class EditarPerfilUsuarioPage extends StatefulWidget {
  const EditarPerfilUsuarioPage({super.key});

  @override
  State<EditarPerfilUsuarioPage> createState() => _EditarPerfilUsuarioPageState();
}

class _EditarPerfilUsuarioPageState extends State<EditarPerfilUsuarioPage>
    with UploadMixin { // ✔ IMPLEMENTA O MIXIN
  final _formKey = GlobalKey<FormState>();
  final _firestore = FirebaseFirestore.instance;
  final _picker = ImagePicker();

  // Controladores
  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();

  // Imagens
  Uint8List? _fotoPerfilBytes;
  String? _fotoPerfilUrlAtual;

  bool _isLoading = false;
  bool _isSaving = false;

  // UID
  String get _usuarioId {
    final user = FirebaseAuth.instance.currentUser;
    return user?.uid ?? 'usuario_demo';
  }

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  @override
  void dispose() {
    _nomeController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _carregarDados() async {
    setState(() => _isLoading = true);

    try {
      final doc = await _firestore.collection('users').doc(_usuarioId).get();

      if (doc.exists) {
        final data = doc.data()!;
        _nomeController.text = data['name'] ?? '';
        _bioController.text = data['descricao'] ?? '';
        _fotoPerfilUrlAtual = data['fotoPerfilUrl'];
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao carregar: $e")),
      );
    }

    setState(() => _isLoading = false);
  }

  // =========================================================
  // SELEÇÃO DA FOTO DE PERFIL
  // =========================================================

  Future<void> _escolherFotoPerfil() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final bytes = await picked.readAsBytes();
    setState(() => _fotoPerfilBytes = bytes);
  }

  // =========================================================
  // SALVAR PERFIL (USANDO O MIXIN)
  // =========================================================

  Future<void> _salvarPerfil() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      String? fotoPerfilUrl = _fotoPerfilUrlAtual;

      // ✔ FOTO DE PERFIL
      if (_fotoPerfilBytes != null) {
        fotoPerfilUrl = await uploadImageToSupabase(
          bytes: _fotoPerfilBytes!,
          folder: "usuarios/$_usuarioId/perfil",
        );
      }

      await _firestore.collection('users').doc(_usuarioId).set({
        'name': _nomeController.text.trim(),
        'descricao': _bioController.text.trim(),
        'fotoPerfilUrl': fotoPerfilUrl,
        'atualizadoEm': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Perfil atualizado com sucesso!")),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Erro ao salvar: $e")),
      );
    }

    setState(() => _isSaving = false);
  }

  // =========================================================
  // PREVIEW DA FOTO DE PERFIL
  // =========================================================

  Widget _buildFotoPerfilPreview() {
    ImageProvider<Object>? provider;

    if (_fotoPerfilBytes != null) {
      provider = MemoryImage(_fotoPerfilBytes!);
    } else if (_fotoPerfilUrlAtual != null && _fotoPerfilUrlAtual!.isNotEmpty) {
      provider = NetworkImage(_fotoPerfilUrlAtual!);
    }

    return Stack(
      children: [
        CircleAvatar(
          radius: 60,
          backgroundColor: Colors.grey.shade300,
          backgroundImage: provider,
          child: provider == null
              ? const Icon(Icons.person, size: 60, color: Colors.grey)
              : null,
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: CircleAvatar(
            backgroundColor: Colors.red,
            radius: 20,
            child: IconButton(
              icon: const Icon(Icons.camera_alt, color: Colors.white, size: 20),
              onPressed: _isSaving ? null : _escolherFotoPerfil,
            ),
          ),
        ),
      ],
    );
  }

  // =========================================================
  // UI
  // =========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Editar Perfil"),
        backgroundColor: Colors.red,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Colors.red))
          : _buildForm(),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          const SizedBox(height: 32),
          Center(
            child: _buildFotoPerfilPreview(),
          ),
          const SizedBox(height: 32),

          // CAMPOS
          _campo(_nomeController, "Nome", validator: true),
          const SizedBox(height: 16),
          _campo(_bioController, "Bio", maxLines: 4),
          const SizedBox(height: 24),

          ElevatedButton.icon(
            onPressed: _isSaving ? null : _salvarPerfil,
            icon: const Icon(Icons.save),
            label: Text(_isSaving ? "Salvando..." : "Salvar Alterações"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _campo(TextEditingController c, String label,
      {int maxLines = 1, bool validator = false}) {
    return TextFormField(
      controller: c,
      maxLines: maxLines,
      validator:
          validator ? (v) => v == null || v.isEmpty ? "Campo obrigatório" : null : null,
      decoration: InputDecoration(
        labelText: label,
        filled: true,
        fillColor: Colors.white,
        border:
            OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

