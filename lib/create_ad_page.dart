import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

class CreateAdPage extends StatefulWidget {
  // optional: pass a `ownerId` (uid) if you have auth; if null, uses 'anonymous'
  final String? ownerId;

  const CreateAdPage({Key? key, this.ownerId}) : super(key: key);

  @override
  State<CreateAdPage> createState() => _CreateAdPageState();
}

class _CreateAdPageState extends State<CreateAdPage> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _gymNameController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _distanceController = TextEditingController();

  File? _pickedImage;
  bool _isUploading = false;
  double _uploadProgress = 0.0;

  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _gymNameController.dispose();
    _titleController.dispose();
    _distanceController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 80, // reduz tamanho do arquivo
        maxWidth: 1600,
      );
      if (picked == null) return;
      setState(() => _pickedImage = File(picked.path));
    } catch (e) {
      debugPrint('Erro ao selecionar imagem: $e');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao selecionar imagem')));
    }
  }

  Future<String> _uploadImageToStorage(File file, String folder) async {
    final storage = FirebaseStorage.instance;
    final id = const Uuid().v4();
    final ref = storage.ref().child('$folder/$id.jpg');

    final uploadTask = ref.putFile(file);

    // monitorar progresso
    uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
      final progress = snapshot.bytesTransferred / (snapshot.totalBytes == 0 ? 1 : snapshot.totalBytes);
      setState(() => _uploadProgress = progress);
    });

    final snapshot = await uploadTask.whenComplete(() {});
    final downloadUrl = await snapshot.ref.getDownloadURL();
    return downloadUrl;
  }

  Future<void> _createAd() async {
    if (!_formKey.currentState!.validate()) return;
    if (_pickedImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecione uma imagem para o anúncio')));
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    try {
      final ownerId = widget.ownerId ?? 'anonymous';
      // 1) upload imagem
      final imageUrl = await _uploadImageToStorage(_pickedImage!, 'ads_images/$ownerId');

      // 2) criar documento no Firestore
      final docRef = FirebaseFirestore.instance.collection('ads').doc();
      final data = {
        'id': docRef.id,
        'gymName': _gymNameController.text.trim(),
        'title': _titleController.text.trim(),
        'imageUrl': imageUrl,
        'distanceText': _distanceController.text.trim(),
        'createdBy': ownerId,
        'createdAt': FieldValue.serverTimestamp(),
        'active': true,
      };

      await docRef.set(data);

      // sucesso
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Anúncio criado com sucesso')));
      // opcional: voltar ou limpar formulário
      Navigator.of(context).pop(true); // retorna true pra indicar sucesso
    } catch (e) {
      debugPrint('Erro ao criar anúncio: $e');
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Erro ao criar anúncio')));
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgress = 0.0;
        });
      }
    }
  }

  Widget _buildImagePreview() {
    final placeholder = Container(
      width: double.infinity,
      height: 160,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.image, size: 56, color: Colors.grey.shade600),
    );

    if (_pickedImage == null) return placeholder;

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.file(
        _pickedImage!,
        width: double.infinity,
        height: 160,
        fit: BoxFit.cover,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Criar Anúncio'),
        backgroundColor: Colors.red,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                // Preview imagem + botão selecionar
                _buildImagePreview(),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isUploading ? null : _pickImage,
                        icon: const Icon(Icons.photo_library),
                        label: const Text('Selecionar imagem'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (_pickedImage != null)
                      IconButton(
                        onPressed: _isUploading
                            ? null
                            : () {
                                setState(() => _pickedImage = null);
                              },
                        icon: const Icon(Icons.delete_forever),
                        color: Colors.red.shade700,
                      ),
                  ],
                ),

                const SizedBox(height: 16),

                TextFormField(
                  controller: _gymNameController,
                  decoration: InputDecoration(
                    labelText: 'Nome da academia',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe o nome da academia' : null,
                ),

                const SizedBox(height: 12),

                TextFormField(
                  controller: _titleController,
                  decoration: InputDecoration(
                    labelText: 'Título / Descrição curta',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  maxLines: 2,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Informe um título' : null,
                ),

                const SizedBox(height: 12),

                TextFormField(
                  controller: _distanceController,
                  decoration: InputDecoration(
                    labelText: 'Distância (ex: 350m ou 1.2km)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),

                const SizedBox(height: 20),

                if (_isUploading) ...[
                  LinearProgressIndicator(value: _uploadProgress),
                  const SizedBox(height: 8),
                  Text('${(_uploadProgress * 100).toStringAsFixed(0)}% enviado'),
                  const SizedBox(height: 12),
                ],

                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isUploading ? null : _createAd,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text(_isUploading ? 'Enviando...' : 'Publicar Anúncio'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
