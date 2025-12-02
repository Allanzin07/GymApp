// ignore_for_file: use_build_context_synchronously

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image/image.dart' as img; // ✔ para recorte da imagem
import 'package:geolocator/geolocator.dart';

// MIXIN DO UPLOAD
import 'package:gym_app/mixins/upload_mixin.dart';

class EditarPerfilAcademiaPage extends StatefulWidget {
  const EditarPerfilAcademiaPage({super.key});

  @override
  State<EditarPerfilAcademiaPage> createState() => _EditarPerfilAcademiaPageState();
}

class _EditarPerfilAcademiaPageState extends State<EditarPerfilAcademiaPage>
    with UploadMixin { // ✔ IMPLEMENTA O MIXIN
  final _formKey = GlobalKey<FormState>();
  final _firestore = FirebaseFirestore.instance;
  final _picker = ImagePicker();

  // Controladores
  final TextEditingController _nomeController = TextEditingController();
  final TextEditingController _descricaoController = TextEditingController();
  final TextEditingController _localizacaoController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _whatsappController = TextEditingController();
  final TextEditingController _linkController = TextEditingController();

  // Imagens
  Uint8List? _fotoPerfilBytes;
  Uint8List? _fotoCapaBytes;
  String? _fotoPerfilUrlAtual;
  String? _fotoCapaUrlAtual;

  bool _isLoading = false;
  bool _isSaving = false;
  
  // Localização GPS
  double? _latitude;
  double? _longitude;
  bool _isGettingLocation = false;

  // UID
  String get _academiaId {
    final user = FirebaseAuth.instance.currentUser;
    return user?.uid ?? 'academia_demo';
  }

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  @override
  void dispose() {
    _nomeController.dispose();
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
      final doc = await _firestore.collection('academias').doc(_academiaId).get();

      if (doc.exists) {
        final data = doc.data()!;
        _nomeController.text = data['nome'] ?? '';
        _descricaoController.text = data['descricao'] ?? '';
        _localizacaoController.text = data['localizacao'] ?? '';
        _emailController.text = data['email'] ?? '';
        _whatsappController.text = data['whatsapp'] ?? '';
        _linkController.text = data['link'] ?? '';
        _fotoPerfilUrlAtual = data['fotoPerfilUrl'];
        _fotoCapaUrlAtual = data['capaUrl'];
        
        // Carrega localização GPS se existir
        if (data['localizacaoGPS'] != null) {
          final gps = data['localizacaoGPS'] as Map<String, dynamic>;
          _latitude = (gps['lat'] as num?)?.toDouble();
          _longitude = (gps['lng'] as num?)?.toDouble();
        }
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
  // SELEÇÃO DA FOTO DE CAPA (COM FORÇA PARA PAISAGEM)
  // =========================================================

  /// Força o crop para 16:9 (capa estilo profissional)
  Uint8List _forcarPaisagem(Uint8List imgBytes) {
    final image = img.decodeImage(imgBytes);
    if (image == null) return imgBytes;

    final width = image.width;
    final height = image.height;

    // Queremos 16:9
    final targetRatio = 16 / 9;
    final currentRatio = width / height;

    img.Image cropped;

    if (currentRatio > targetRatio) {
      // A imagem é mais "larga" do que deveria → cortar laterais
      final newWidth = (height * targetRatio).toInt();
      final xOffset = (width - newWidth) ~/ 2;

      cropped = img.copyCrop(image,
          x: xOffset, y: 0, width: newWidth, height: height);
    } else {
      // A imagem é mais "alta" → cortar topo/bottom
      final newHeight = (width / targetRatio).toInt();
      final yOffset = (height - newHeight) ~/ 2;

      cropped = img.copyCrop(image,
          x: 0, y: yOffset, width: width, height: newHeight);
    }

    return Uint8List.fromList(img.encodeJpg(cropped, quality: 90));
  }

  Future<void> _escolherFotoCapa() async {
    final picked = await _picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    final originalBytes = await picked.readAsBytes();

    // ✔ força paisagem 16:9
    final corrigida = _forcarPaisagem(originalBytes);

    setState(() => _fotoCapaBytes = corrigida);
  }

  // =========================================================
  // CAPTURAR LOCALIZAÇÃO GPS
  // =========================================================

  Future<void> _capturarLocalizacaoGPS() async {
    setState(() => _isGettingLocation = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Por favor, ative o GPS nas configurações do dispositivo.'),
            ),
          );
        }
        setState(() => _isGettingLocation = false);
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever || 
          permission == LocationPermission.denied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Permissão de localização negada.'),
            ),
          );
        }
        setState(() => _isGettingLocation = false);
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );

      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
        _isGettingLocation = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Localização capturada com sucesso!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isGettingLocation = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao capturar localização: $e')),
        );
      }
    }
  }

  // =========================================================
  // SALVAR PERFIL (AGORA USANDO O MIXIN)
  // =========================================================

  Future<void> _salvarPerfil() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      String? fotoPerfilUrl = _fotoPerfilUrlAtual;
      String? fotoCapaUrl = _fotoCapaUrlAtual;

      // ✔ FOTO DE PERFIL
      if (_fotoPerfilBytes != null) {
        fotoPerfilUrl = await uploadImageToSupabase(
          bytes: _fotoPerfilBytes!,
          folder: "academias/$_academiaId/perfil",
        );
      }

      // ✔ FOTO DE CAPA (já está paisagem)
      if (_fotoCapaBytes != null) {
        fotoCapaUrl = await uploadImageToSupabase(
          bytes: _fotoCapaBytes!,
          folder: "academias/$_academiaId/capa",
        );
      }

      final updateData = {
        'nome': _nomeController.text.trim(),
        'descricao': _descricaoController.text.trim(),
        'localizacao': _localizacaoController.text.trim(),
        'email': _emailController.text.trim(),
        'whatsapp': _whatsappController.text.trim(),
        'link': _linkController.text.trim(),
        'fotoPerfilUrl': fotoPerfilUrl,
        'capaUrl': fotoCapaUrl,
        'atualizadoEm': FieldValue.serverTimestamp(),
      };

      // Adiciona localização GPS se foi capturada
      if (_latitude != null && _longitude != null) {
        updateData['localizacaoGPS'] = {
          'lat': _latitude,
          'lng': _longitude,
        };
      }

      await _firestore.collection('academias').doc(_academiaId).set(
        updateData,
        SetOptions(merge: true),
      );

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
  // PREVIEW DAS FOTOS
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

  Widget _buildFotoCapaPreview() {
    ImageProvider<Object>? provider;

    if (_fotoCapaBytes != null) {
      provider = MemoryImage(_fotoCapaBytes!);
    } else if (_fotoCapaUrlAtual != null && _fotoCapaUrlAtual!.isNotEmpty) {
      provider = NetworkImage(_fotoCapaUrlAtual!);
    }

    return Stack(
      children: [
        Container(
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: Colors.grey.shade300,
          ),
          clipBehavior: Clip.hardEdge,
          child: provider != null
              ? Image(image: provider, fit: BoxFit.cover)
              : const Icon(Icons.image, size: 60, color: Colors.grey),
        ),
        Positioned(
          bottom: 16,
          right: 16,
          child: FloatingActionButton(
            mini: true,
            backgroundColor: Colors.red,
            onPressed: _isSaving ? null : _escolherFotoCapa,
            child: const Icon(Icons.camera_alt, color: Colors.white),
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
        title: const Text("Editar Perfil da Academia"),
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
          const SizedBox(height: 16),
          _buildFotoCapaPreview(),
          const SizedBox(height: 20),
          Center(
            child: Transform.translate(
              offset: const Offset(0, -60),
              child: _buildFotoPerfilPreview(),
            ),
          ),
          const SizedBox(height: 0),

          // CAMPOS
          _campo(_nomeController, "Nome da academia", validator: true),
          const SizedBox(height: 16),
          _campo(_descricaoController, "Descrição", maxLines: 3),
          const SizedBox(height: 16),
          _campo(_localizacaoController, "Localização (Endereço)"),
          const SizedBox(height: 12),
          
          // Botão para capturar localização GPS
          Card(
            color: Colors.grey.shade100,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.location_on, color: Colors.red, size: 20),
                      const SizedBox(width: 8),
                      const Text(
                        'Localização GPS',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (_latitude != null && _longitude != null)
                    Text(
                      'Lat: ${_latitude!.toStringAsFixed(6)}, Lng: ${_longitude!.toStringAsFixed(6)}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green.shade700,
                      ),
                    )
                  else
                    const Text(
                      'Nenhuma localização GPS capturada',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: Colors.orange.shade200,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 18,
                          color: Colors.orange.shade700,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Capture sua localização somente quando estiver no endereço/localização descrito acima para que a busca do cliente funcione corretamente',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.orange.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: _isGettingLocation ? null : _capturarLocalizacaoGPS,
                    icon: _isGettingLocation
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.my_location, size: 18),
                    label: Text(_isGettingLocation ? 'Capturando...' : 'Capturar Localização Atual'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text("Informações de Contato",
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          _campo(_emailController, "E-mail"),
          const SizedBox(height: 12),
          _campo(_whatsappController, "WhatsApp"),
          const SizedBox(height: 12),
          _campo(_linkController, "Links (Instagram, site, etc.)"),
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