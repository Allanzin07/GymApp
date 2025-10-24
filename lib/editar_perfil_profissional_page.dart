import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

class EditarPerfilProfissionalPage extends StatefulWidget {
  final String? userId; // ID do profissional autenticado (opcional)

  const EditarPerfilProfissionalPage({Key? key, this.userId}) : super(key: key);

  @override
  State<EditarPerfilProfissionalPage> createState() =>
      _EditarPerfilProfissionalPageState();
}

class _EditarPerfilProfissionalPageState
    extends State<EditarPerfilProfissionalPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _especialidadeController =
      TextEditingController();
  final TextEditingController _descricaoController = TextEditingController();

  File? _pickedImage;
  bool _isSaving = false;
  double _uploadProgress = 0.0;

  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _nomeController.dispose();
    _especialidadeController.dispose();
    _descricaoController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80,
        maxWidth: 1600,
      );
      if (picked == null) return;
      setState(() => _pickedImage = File(picked.path));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao selecionar imagem')),
      );
    }
  }

  Future<String> _uploadProfileImage(File file, String folder) async {
    final storage = FirebaseStorage.instance;
    final id = const Uuid().v4();
    final ref = storage.ref().child('$folder/$id.jpg');

    final uploadTask = ref.putFile(file);

    uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
      final progress = snapshot.bytesTransferred /
          (snapshot.totalBytes == 0 ? 1 : snapshot.totalBytes);
      setState(() => _uploadProgress = progress);
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
      final userId = widget.userId ?? 'anonymous';
      String? imageUrl;

      // Se o usuário escolheu uma imagem, faz upload
      if (_pickedImage != null) {
        imageUrl =
            await _uploadProfileImage(_pickedImage!, 'profile_images/$userId');
      }

      final docRef =
          FirebaseFirestore.instance.collection('professionals').doc(userId);
      final data = {
        'nome': _nomeController.text.trim(),
        'especialidade': _especialidadeController.text.trim(),
        'descricao': _descricaoController.text.trim(),
        if (imageUrl != null) 'fotoUrl': imageUrl,
        'atualizadoEm': FieldValue.serverTimestamp(),
      };

      await docRef.set(data, SetOptions(merge: true));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Perfil atualizado com sucesso!')),
      );

      Navigator.of(context).pop(true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar perfil: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _buildImagePreview() {
    final placeholder = Container(
      width: 140,
      height: 140,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(70),
      ),
      child: const Icon(Icons.person, size: 70, color: Colors.grey),
    );

    if (_pickedImage == null) return placeholder;

    return ClipOval(
      child: Image.file(
        _pickedImage!,
        width: 140,
        height: 140,
        fit: BoxFit.cover,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Perfil Profissional'),
        backgroundColor: Colors.red,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              const SizedBox(height: 10),
              _buildImagePreview(),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _pickImage,
                icon: const Icon(Icons.photo_camera),
                label: const Text('Alterar Foto'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nomeController,
                decoration: InputDecoration(
                  labelText: 'Nome completo',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Informe seu nome' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _especialidadeController,
                decoration: InputDecoration(
                  labelText:
                      'Especialidade (ex: Personal Trainer, Nutricionista...)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
                validator: (v) => v == null || v.trim().isEmpty
                    ? 'Informe sua especialidade'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descricaoController,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Descrição / Sobre você',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                ),
              ),
              const SizedBox(height: 20),
              if (_isSaving) ...[
                LinearProgressIndicator(value: _uploadProgress),
                const SizedBox(height: 8),
                Text('${(_uploadProgress * 100).toStringAsFixed(0)}% enviado'),
                const SizedBox(height: 12),
              ],
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _salvarPerfil,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child:
                      Text(_isSaving ? 'Salvando...' : 'Salvar Alterações'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
