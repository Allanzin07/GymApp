import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';

class PostFeedWidget extends StatefulWidget {
  final String userId;
  final String userName;
  final String userPhotoUrl;
  final String collectionName; // 'academias' ou 'professionals'

  const PostFeedWidget({
    super.key,
    required this.userId,
    required this.userName,
    required this.userPhotoUrl,
    required this.collectionName,
  });

  @override
  State<PostFeedWidget> createState() => _PostFeedWidgetState();
}

class _PostFeedWidgetState extends State<PostFeedWidget> {
  final _firestore = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _picker = ImagePicker();
  final _supabase = Supabase.instance.client;
  final TextEditingController _textController = TextEditingController();

  File? _selectedImage;
  XFile? _selectedImageXFile;
  Uint8List? _selectedImageBytes;
  File? _selectedVideo;
  XFile? _selectedVideoXFile;

  bool _isUploading = false;
  double _uploadProgress = 0.0; // agora só usado pra exibir "indeterminado"

  bool get _canManage => _auth.currentUser?.uid == widget.userId;

  // =========================================================
  // SELEÇÃO DE MÍDIA
  // =========================================================

  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    // 1. Determina a coleção principal a ser buscada
    final collectionToSearch = widget.collectionName.isNotEmpty
        ? widget.collectionName
        : 'users'; // Fallback para 'users' se a coleção não for definida

    DocumentSnapshot<Map<String, dynamic>> doc;
    Map<String, dynamic>? data;

    try {
      // 2. Tenta buscar na coleção principal (academias/professionals/users)
      doc = await FirebaseFirestore.instance
          .collection(collectionToSearch)
          .doc(uid)
          .get();
      data = doc.data();

      // 3. Se não encontrar o perfil na coleção principal (e não for users), tenta buscar em 'users'
      if (!doc.exists && collectionToSearch != 'users') {
        final userDoc =
            await FirebaseFirestore.instance.collection('users').doc(uid).get();
        data = userDoc.data();
      }
    } catch (_) {
      // Ignora erros de leitura de Firestore, deixando 'data' como null.
    }

    // 4. Normaliza e prioriza os campos de Nome e Foto
    String userName =
        data?['nome'] as String? ?? data?['name'] as String? ?? 'Usuário';
    String userPhotoUrl =
        data?['fotoPerfilUrl'] as String? ?? data?['fotoUrl'] as String? ?? '';

    // Fallback: Se o nome do Firestore for genérico/vazio, usa o nome do Firebase Auth (display name)
    // Isso deve ser o último recurso, pois é o que está dando o nome incorreto (João Victor)
    if (userName.isEmpty || userName == 'Usuário') {
      userName = _auth.currentUser?.displayName ?? 'Usuário';
    }

    setState(() {
      // 5. Salva os dados normalizados no _userData
      _userData = {
        'name': userName,
        'fotoPerfilUrl': userPhotoUrl,
        // Você pode adicionar outros dados necessários aqui, se tiver.
      };
    });
  }

  Future<XFile?> _selectImageFile() async {
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

    if (source == null) return null;

    try {
      final picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1920,
      );
      return picked;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao selecionar imagem')),
        );
      }
      return null;
    }
  }

  Future<XFile?> _selectVideoFile() async {
    try {
      final picked = await _picker.pickVideo(source: ImageSource.gallery);
      return picked;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erro ao selecionar vídeo')),
        );
      }
      return null;
    }
  }

  Future<void> _pickImage() async {
    final picked = await _selectImageFile();
    if (picked == null) return;

    Uint8List? bytes;
    try {
      bytes = await picked.readAsBytes();
    } catch (_) {}

    setState(() {
      _selectedImageXFile = picked;
      _selectedImageBytes = bytes;
      _selectedImage = kIsWeb ? null : File(picked.path);
      _selectedVideo = null;
      _selectedVideoXFile = null;
    });
  }

  Future<void> _pickVideo() async {
    final picked = await _selectVideoFile();
    if (picked == null) return;

    setState(() {
      _selectedVideoXFile = picked;
      _selectedVideo = kIsWeb ? null : File(picked.path);
      _selectedImage = null;
      _selectedImageXFile = null;
      _selectedImageBytes = null;
    });
  }

  // =========================================================
  // UPLOAD PARA SUPABASE (IMAGEM + VÍDEO)
  // =========================================================

  Future<Uint8List> _compressImageBytes(Uint8List data) async {
    try {
      final result = await FlutterImageCompress.compressWithList(
        data,
        minWidth: 1280,
        minHeight: 720,
        quality: 75,
        format: CompressFormat.jpeg,
      );
      if (result.isNotEmpty) {
        return Uint8List.fromList(result);
      }
    } catch (_) {}
    return data;
  }

  Future<Map<String, String>> _uploadImageToSupabase(Uint8List bytes) async {
    final compressed = await _compressImageBytes(bytes);
    final id = const Uuid().v4();
    final path = 'gymapp/posts/${widget.userId}/$id.jpg';

    final response = await _supabase.storage.from('uploads').uploadBinary(
          path,
          compressed,
          fileOptions: const FileOptions(
            contentType: 'image/jpeg',
          ),
        );

    if (response.isEmpty) {
      throw Exception('Falha ao enviar imagem');
    }

    final url = _supabase.storage.from('uploads').getPublicUrl(path);
    return {'url': url, 'path': path};
  }

  Future<Map<String, String>> _uploadVideoToSupabase(XFile xfile) async {
    final bytes = await xfile.readAsBytes();
    final id = const Uuid().v4();
    final path = 'gymapp/posts/${widget.userId}/$id.mp4';

    final response = await _supabase.storage.from('uploads').uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(
            contentType: 'video/mp4',
          ),
        );

    if (response.isEmpty) {
      throw Exception('Falha ao enviar vídeo');
    }

    final url = _supabase.storage.from('uploads').getPublicUrl(path);
    return {'url': url, 'path': path};
  }

  // =========================================================
  // CRIAR POST
  // =========================================================

  Future<void> _createPost() async {
    final text = _textController.text.trim();

    if (text.isEmpty && _selectedImage == null && _selectedVideo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Adicione texto, foto ou vídeo para publicar')),
      );
      return;
    }

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
    });

    try {
      String? mediaUrl;
      String? mediaType;
      String? mediaPath;

      if (_selectedImageXFile != null || _selectedImageBytes != null) {
        Uint8List bytes;

        if (_selectedImageBytes != null) {
          bytes = _selectedImageBytes!;
        } else if (_selectedImage != null) {
          bytes = await _selectedImage!.readAsBytes();
        } else {
          throw Exception('Erro ao ler imagem selecionada.');
        }

        final uploaded = await _uploadImageToSupabase(bytes);
        mediaUrl = uploaded['url'];
        mediaPath = uploaded['path'];
        mediaType = 'image';
      } else if (_selectedVideoXFile != null) {
        final uploaded = await _uploadVideoToSupabase(_selectedVideoXFile!);
        mediaUrl = uploaded['url'];
        mediaPath = uploaded['path'];
        mediaType = 'video';
      }

      await _firestore.collection('posts').add({
        'userId': widget.userId,
        'userName': widget.userName,
        'userPhotoUrl': widget.userPhotoUrl,
        'text': text,
        'mediaUrl': mediaUrl,
        'mediaType': mediaType, // 'image', 'video' ou null
        'mediaPath': mediaPath, // caminho no Supabase
        'collectionName': widget.collectionName,
        'createdAt': FieldValue.serverTimestamp(),
        'likes': 0,
        'comments': 0,
        'likedBy': <String>[],
      });

      _textController.clear();
      setState(() {
        _selectedImage = null;
        _selectedImageXFile = null;
        _selectedImageBytes = null;
        _selectedVideo = null;
        _selectedVideoXFile = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Publicação criada com sucesso!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao criar publicação: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadProgress = 0.0;
        });
      }
    }
  }

  // =========================================================
  // EXCLUIR POST (REMOVE DO SUPABASE SE TIVER mediaPath)
  // =========================================================

  Future<void> _deletePost(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Excluir publicação'),
        content: const Text(
          'Deseja realmente excluir esta publicação? Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final mediaPath = data['mediaPath'] as String?;
      if (mediaPath != null && mediaPath.isNotEmpty) {
        try {
          await _supabase.storage.from('uploads').remove([mediaPath]);
        } catch (_) {
          // ignora falha ao remover mídia antiga
        }
      }

      await doc.reference.delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Publicação excluída.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao excluir publicação: $e')),
        );
      }
    }
  }

  // =========================================================
  // EDITAR POST (TAMBÉM USA SUPABASE)
  // =========================================================

  Future<void> _editPost(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final textController =
        TextEditingController(text: data['text'] as String? ?? '');
    final initialMediaUrl = data['mediaUrl'] as String?;
    final initialMediaType = data['mediaType'] as String?;
    final initialMediaPath = data['mediaPath'] as String?;

    XFile? newImageXFile;
    File? newImageFile;
    Uint8List? newImageBytes;
    XFile? newVideoXFile;
    File? newVideoFile;
    bool removeMedia = false;
    double editProgress = 0.0;
    bool isSaving = false;

    Future<void> pickNewImage(StateSetter modalSetState) async {
      final picked = await _selectImageFile();
      if (picked == null) return;

      Uint8List? bytes;
      try {
        bytes = await picked.readAsBytes();
      } catch (_) {}

      modalSetState(() {
        newImageXFile = picked;
        newImageFile = kIsWeb ? null : File(picked.path);
        newImageBytes = bytes;
        newVideoXFile = null;
        newVideoFile = null;
        removeMedia = false;
      });
    }

    Future<void> pickNewVideo(StateSetter modalSetState) async {
      final picked = await _selectVideoFile();
      if (picked == null) return;

      modalSetState(() {
        newVideoXFile = picked;
        newVideoFile = kIsWeb ? null : File(picked.path);
        newImageXFile = null;
        newImageFile = null;
        newImageBytes = null;
        removeMedia = false;
      });
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, modalSetState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            final String? existingMediaUrl =
                !removeMedia && (initialMediaUrl?.isNotEmpty ?? false)
                    ? initialMediaUrl
                    : null;
            final hasExistingMedia = existingMediaUrl != null;
            final hasNewImage = newImageXFile != null || newImageFile != null;
            final hasNewVideo = newVideoXFile != null || newVideoFile != null;

            Widget? mediaPreview;
            if (hasNewImage) {
              if (newImageBytes != null) {
                mediaPreview = ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    newImageBytes!,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                );
              } else if (newImageFile != null) {
                mediaPreview = ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    newImageFile!,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                );
              }
            } else if (hasNewVideo) {
              mediaPreview = Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Icon(
                    Icons.play_circle_outline,
                    color: Colors.white,
                    size: 60,
                  ),
                ),
              );
            } else if (existingMediaUrl != null &&
                initialMediaType == 'image') {
              mediaPreview = ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: CachedNetworkImage(
                  imageUrl: existingMediaUrl,
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    height: 200,
                    color: Colors.grey.shade300,
                    child: const Center(child: CircularProgressIndicator()),
                  ),
                  errorWidget: (context, url, error) => Container(
                    height: 200,
                    color: Colors.grey.shade300,
                    child: const Icon(Icons.error),
                  ),
                ),
              );
            } else if (existingMediaUrl != null &&
                initialMediaType == 'video') {
              mediaPreview = Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Icon(
                    Icons.play_circle_outline,
                    color: Colors.white,
                    size: 60,
                  ),
                ),
              );
            }

            final disableActions = isSaving;

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: 16 + bottomInset,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Editar publicação',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          onPressed: disableActions
                              ? null
                              : () => Navigator.pop(context),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: textController,
                      maxLines: 5,
                      minLines: 3,
                      enabled: !disableActions,
                      decoration: const InputDecoration(
                        labelText: 'Escreva algo...',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (mediaPreview != null) mediaPreview,
                    if (mediaPreview != null) const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        ElevatedButton.icon(
                          onPressed: disableActions
                              ? null
                              : () => pickNewImage(modalSetState),
                          icon: const Icon(Icons.photo),
                          label: const Text('Substituir foto'),
                        ),
                        ElevatedButton.icon(
                          onPressed: disableActions
                              ? null
                              : () => pickNewVideo(modalSetState),
                          icon: const Icon(Icons.video_library),
                          label: const Text('Substituir vídeo'),
                        ),
                        if ((hasExistingMedia || hasNewImage || hasNewVideo) &&
                            !disableActions)
                          OutlinedButton.icon(
                            onPressed: () {
                              modalSetState(() {
                                removeMedia = true;
                                newImageXFile = null;
                                newImageFile = null;
                                newImageBytes = null;
                                newVideoXFile = null;
                                newVideoFile = null;
                              });
                            },
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Remover mídia'),
                          ),
                      ],
                    ),
                    if (isSaving) ...[
                      const SizedBox(height: 12),
                      LinearProgressIndicator(
                        value: editProgress == 0 ? null : editProgress,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        editProgress == 0
                            ? 'Salvando...'
                            : '${(editProgress * 100).toStringAsFixed(0)}% enviado',
                        style:
                            const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: disableActions
                            ? null
                            : () async {
                                final newText = textController.text.trim();
                                final hasContent = newText.isNotEmpty ||
                                    (!removeMedia &&
                                        (hasExistingMedia ||
                                            hasNewImage ||
                                            hasNewVideo));
                                if (!hasContent) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Adicione texto ou mídia para manter a publicação.',
                                      ),
                                    ),
                                  );
                                  return;
                                }

                                modalSetState(() {
                                  isSaving = true;
                                  editProgress = 0;
                                });

                                try {
                                  String? mediaUrl = initialMediaUrl;
                                  String? mediaType = initialMediaType;
                                  String? mediaPath = initialMediaPath;

                                  // remover mídia
                                  if (removeMedia && initialMediaPath != null) {
                                    try {
                                      await _supabase.storage
                                          .from('uploads')
                                          .remove([initialMediaPath]);
                                    } catch (_) {}
                                    mediaUrl = null;
                                    mediaType = null;
                                    mediaPath = null;
                                  }
                                  // substituir por nova
                                  else if (hasNewImage || hasNewVideo) {
                                    Map<String, String> uploaded;

                                    if (hasNewImage) {
                                      Uint8List bytes;
                                      if (newImageBytes != null) {
                                        bytes = newImageBytes!;
                                      } else if (newImageFile != null) {
                                        bytes =
                                            await newImageFile!.readAsBytes();
                                      } else {
                                        throw Exception(
                                            'Erro ao ler nova imagem.');
                                      }
                                      uploaded =
                                          await _uploadImageToSupabase(bytes);
                                      mediaType = 'image';
                                    } else {
                                      // vídeo
                                      final xfile = newVideoXFile;
                                      if (xfile == null) {
                                        throw Exception(
                                            'Erro ao ler novo vídeo.');
                                      }
                                      uploaded =
                                          await _uploadVideoToSupabase(xfile);
                                      mediaType = 'video';
                                    }

                                    // remove mídia antiga se tiver path
                                    if (initialMediaPath != null &&
                                        initialMediaPath.isNotEmpty) {
                                      try {
                                        await _supabase.storage
                                            .from('uploads')
                                            .remove([initialMediaPath]);
                                      } catch (_) {}
                                    }

                                    mediaUrl = uploaded['url'];
                                    mediaPath = uploaded['path'];
                                  }

                                  await doc.reference.update({
                                    'text': newText,
                                    'mediaUrl': mediaUrl,
                                    'mediaType': mediaType,
                                    'mediaPath': mediaPath,
                                    'updatedAt': FieldValue.serverTimestamp(),
                                  });

                                  FocusScope.of(context).unfocus();

                                  if (mounted) {
                                    Navigator.of(context).pop();
                                    ScaffoldMessenger.of(this.context)
                                        .showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                            'Publicação atualizada com sucesso!'),
                                      ),
                                    );
                                  }
                                } catch (e) {
                                  modalSetState(() {
                                    isSaving = false;
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                        content: Text('Erro ao atualizar: $e')),
                                  );
                                }
                              },
                        icon: const Icon(Icons.save),
                        label: const Text('Salvar alterações'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // =========================================================
  // CARD DE CRIAÇÃO DO POST
  // =========================================================

  Widget _buildCreatePostCard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor:
                      Theme.of(context).cardTheme.color ?? Colors.grey.shade300,
                  backgroundImage: widget.userPhotoUrl.isNotEmpty
                      ? NetworkImage(widget.userPhotoUrl)
                      : null,
                  child: widget.userPhotoUrl.isEmpty
                      ? Icon(Icons.person,
                          size: 20, color: Theme.of(context).iconTheme.color)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _textController,
                    maxLines: 4,
                    style: TextStyle(
                        color: Theme.of(context).textTheme.bodyLarge?.color),
                    decoration: InputDecoration(
                      hintText: 'O que você está pensando?',
                      hintStyle: TextStyle(
                          color: Theme.of(context).textTheme.bodySmall?.color),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      filled: true,
                      fillColor:
                          Theme.of(context).inputDecorationTheme.fillColor,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_selectedImageBytes != null || _selectedImage != null) ...[
              const SizedBox(height: 12),
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: _selectedImageBytes != null
                        ? Image.memory(
                            _selectedImageBytes!,
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          )
                        : _selectedImage != null
                            ? Image.file(
                                _selectedImage!,
                                height: 200,
                                width: double.infinity,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                height: 200,
                                color: Colors.grey.shade300,
                                child: const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => setState(() {
                        _selectedImage = null;
                        _selectedImageXFile = null;
                        _selectedImageBytes = null;
                      }),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black54,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (_selectedVideoXFile != null) ...[
              const SizedBox(height: 12),
              Stack(
                children: [
                  Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Icon(Icons.play_circle_outline,
                          color: Colors.white, size: 60),
                    ),
                  ),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => setState(() {
                        _selectedVideo = null;
                        _selectedVideoXFile = null;
                      }),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black54,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: _isUploading ? null : _pickImage,
                    icon: const Icon(Icons.photo, color: Colors.green),
                    label: Text('Foto',
                        style: TextStyle(
                            color:
                                Theme.of(context).textTheme.bodyLarge?.color)),
                    style: TextButton.styleFrom(
                      foregroundColor:
                          Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: _isUploading ? null : _pickVideo,
                    icon: const Icon(Icons.video_library, color: Colors.red),
                    label: Text('Vídeo',
                        style: TextStyle(
                            color:
                                Theme.of(context).textTheme.bodyLarge?.color)),
                    style: TextButton.styleFrom(
                      foregroundColor:
                          Theme.of(context).textTheme.bodyMedium?.color,
                    ),
                  ),
                ),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isUploading ? null : _createPost,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    child: _isUploading
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text('Publicar'),
                  ),
                ),
              ],
            ),
            if (_isUploading) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: (_uploadProgress > 0 && _uploadProgress < 1)
                    ? _uploadProgress
                    : null, // indeterminado
              ),
              const SizedBox(height: 4),
              Text(
                'Enviando...',
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).textTheme.bodySmall?.color),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  // =========================================================
  // BUILD PRINCIPAL
  // =========================================================

  @override
  Widget build(BuildContext context) {
    final widgets = <Widget>[];
    if (_canManage) {
      widgets.add(_buildCreatePostCard());
    }
    widgets.add(
      StreamBuilder<QuerySnapshot>(
        stream: _firestore
            .collection('posts')
            .where('userId', isEqualTo: widget.userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: CircularProgressIndicator(color: Colors.red),
              ),
            );
          }

          if (snapshot.hasError) {
            return Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 40),
                  const SizedBox(height: 12),
                  Text(
                    'Erro ao carregar publicações:\n${snapshot.error}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final docs = snapshot.data?.docs.toList() ?? [];

          docs.sort((a, b) {
            final aTime = (a['createdAt'] as Timestamp?)?.toDate();
            final bTime = (b['createdAt'] as Timestamp?)?.toDate();
            if (aTime == null && bTime == null) return 0;
            if (aTime == null) return 1;
            if (bTime == null) return -1;
            return bTime.compareTo(aTime);
          });

          if (docs.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(32),
              child: Text(
                'Nenhuma publicação ainda.\nComece compartilhando algo!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final doc = docs[index];
              final data = doc.data() as Map<String, dynamic>;
              return PostCard(
                key: ValueKey(doc.id),
                docId: doc.id,
                data: data,
                canManage: _canManage,
                currentUserId: _auth.currentUser?.uid,
                currentUserName: _userData?['nome'] ?? _userData?['name'] ?? '',
                currentUserPhotoUrl: _userData?['fotoPerfilUrl'] ?? '',
                isAuthenticated: _auth.currentUser != null,
                onEdit: _canManage ? () => _editPost(doc) : null,
                onDelete: _canManage ? () => _deletePost(doc) : null,
              );
            },
          );
        },
      ),
    );
    return Column(children: widgets);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }
}

// =====================================================================
// A PARTIR DAQUI: PostCard (NÃO PRECISA DE SUPABASE, MEXE SÓ COM FIRESTORE)
// =====================================================================

/// Widget público para exibir um post com funcionalidade completa de comentários
class PostCard extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> data;
  final bool canManage;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final String? currentUserId;
  final String currentUserName;
  final String currentUserPhotoUrl;
  final bool isAuthenticated;

  const PostCard({
    super.key,
    required this.docId,
    required this.data,
    required this.canManage,
    required this.currentUserId,
    required this.currentUserName,
    required this.currentUserPhotoUrl,
    required this.isAuthenticated,
    this.onEdit,
    this.onDelete,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final TextEditingController _commentController = TextEditingController();
  bool _showComments = false;
  bool _isSendingComment = false;
  bool _isProcessingLike = false;
  final Map<String, TextEditingController> _replyControllers = {};
  final Set<String> _replyingCommentIds = {};
  final Set<String> _processingReplies = {};
  final Set<String> _processingDeletes = {};
  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>? _commentsFuture;

  /// Obtém o ID do usuário atual (prioriza widget, depois Firebase Auth)
  String? get _effectiveUserId {
    final widgetId = widget.currentUserId?.trim();
    final authId = _auth.currentUser?.uid;
    final result = widgetId?.isNotEmpty == true ? widgetId : authId;

    debugPrint(
        '[PostCard] _effectiveUserId: widgetId=$widgetId, authId=$authId, result=$result');

    return result;
  }

  List<String> get _likedBy {
    final likedBy = widget.data['likedBy'];
    if (likedBy is Iterable) {
      return likedBy.map((e) => e.toString()).toList();
    }
    return const [];
  }

  int get _likesCount {
    final likedBy = _likedBy;
    if (likedBy.isNotEmpty) {
      return likedBy.length;
    }
    final likes = widget.data['likes'];
    if (likes is int) return likes;
    if (likes is num) return likes.toInt();
    return 0;
  }

  bool get _hasLiked {
    final userId = _effectiveUserId;
    if (userId == null) return false;
    return _likedBy.contains(userId);
  }

  int get _commentsCount {
    final comments = widget.data['comments'];
    if (comments is int) return comments;
    if (comments is num) return comments.toInt();
    return 0;
  }

  DocumentReference<Map<String, dynamic>> get _postRef =>
      _firestore.collection('posts').doc(widget.docId);

  /// Verifica se o usuário atual pode EXCLUIR o comentário
  /// O dono do comentário OU o dono do post podem excluir
  bool _canDeleteComment(String? commentUserId) {
    final currentUserId = _effectiveUserId;

    // Se é o dono do post → pode excluir tudo
    if (widget.canManage) return true;

    if (currentUserId == null) return false;

    // Fallback: se o snapshot ainda não sincronizou userId do comentário,
    // considere que o comentário acabou de ser criado pelo próprio usuário
    if (commentUserId == null || commentUserId.trim().isEmpty) {
      return true;
    }

    // Caso normal: comparar IDs
    return commentUserId.trim() == currentUserId.trim();
  }

  TextEditingController _replyControllerFor(String commentId) {
    return _replyControllers.putIfAbsent(commentId, TextEditingController.new);
  }

  @override
  void didUpdateWidget(covariant PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Se o docId mudar, limpe todos os controladores de resposta.
    // Embora a chave deva garantir que isso não aconteça, é uma segurança extra.
    if (widget.docId != oldWidget.docId) {
      for (final controller in _replyControllers.values) {
        controller.dispose();
      }
      _replyControllers.clear();
      _replyingCommentIds.clear();
      _processingReplies.clear();
      _processingDeletes.clear();
    }
  }

  void _toggleReplying(String commentId) {
    setState(() {
      if (_replyingCommentIds.contains(commentId)) {
        _replyingCommentIds.remove(commentId);
        _replyControllers[commentId]?.clear();
      } else {
        _replyingCommentIds.add(commentId);
      }
    });
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
      _loadComments() async {
    final snapshot = await _postRef
        .collection('comments')
        .orderBy('createdAt', descending: true)
        .limit(20)
        .get();

    // Remove comentários ainda não sincronizados
    return snapshot.docs
        .where((doc) => !doc.metadata.hasPendingWrites)
        .toList();
  }

  Future<void> _deleteComment({
    required DocumentReference<Map<String, dynamic>> docRef,
    required bool isReply,
    required String? commentUserId,
  }) async {
    debugPrint(
        '[PostCard] _deleteComment: Iniciando exclusão - commentUserId=$commentUserId, currentUserId=${_effectiveUserId}, canManage=${widget.canManage}');

    // Verifica se o usuário tem permissão para excluir
    if (!_canDeleteComment(commentUserId)) {
      debugPrint(
          '[PostCard] _deleteComment: PERMISSÃO NEGADA - não pode excluir');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Você não tem permissão para excluir este comentário.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    debugPrint(
        '[PostCard] _deleteComment: Permissão OK - prosseguindo com exclusão');

    if (_processingDeletes.contains(docRef.path)) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Excluir comentário'),
        content: const Text('Tem certeza que deseja excluir este comentário?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Excluir'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() {
      _processingDeletes.add(docRef.path);
    });

    try {
      debugPrint(
          '[PostCard] _deleteComment: Deletando comentário - docRef=${docRef.path}, isReply=$isReply');

      int decrement = 1;
      if (!isReply) {
        debugPrint('[PostCard] _deleteComment: Buscando replies...');
        final repliesSnapshot = await docRef.collection('replies').get();
        debugPrint(
            '[PostCard] _deleteComment: Encontradas ${repliesSnapshot.size} replies');

        for (final replyDoc in repliesSnapshot.docs) {
          await replyDoc.reference.delete();
        }
        decrement += repliesSnapshot.size;
      }

      debugPrint(
          '[PostCard] _deleteComment: Deletando comentário principal...');
      await docRef.delete();

      debugPrint(
          '[PostCard] _deleteComment: Atualizando contador de comentários (decrement=$decrement)...');
      await _postRef.update({
        'comments': FieldValue.increment(-decrement),
      });

      debugPrint('[PostCard] _deleteComment: Exclusão concluída com sucesso!');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Comentário excluído.')),
        );
      }
    } catch (e) {
      debugPrint('[PostCard] _deleteComment: ERRO ao excluir - $e');
      debugPrint(
          '[PostCard] _deleteComment: Stack trace: ${StackTrace.current}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao excluir comentário: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _processingDeletes.remove(docRef.path);
        });
      }
    }
  }

  Future<void> _submitReply({
    required String parentCommentId,
    required DocumentReference<Map<String, dynamic>> parentRef,
  }) async {
    final currentUserId = _effectiveUserId;

    if (!widget.isAuthenticated || currentUserId == null) {
      _showLoginSnack('Faça login para responder comentários.');
      return;
    }

    final controller = _replyControllerFor(parentCommentId);
    final text = controller.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Digite algo para responder.')),
      );
      return;
    }

    if (_processingReplies.contains(parentCommentId)) return;

    setState(() {
      _processingReplies.add(parentCommentId);
    });

    try {
      final replyId = _firestore.collection('tmp').doc().id;

      // 🚨 CORREÇÃO DE NOME E FOTO AQUI:
      // Prioriza widget.currentUserName e widget.currentUserPhotoUrl

      final userName = widget.currentUserName.isNotEmpty
          ? widget.currentUserName
          : (_auth.currentUser?.displayName ??
              'Usuário'); // Mantém fallback para segurança, mas prioriza o Widget

      final userPhotoUrl = widget.currentUserPhotoUrl.isNotEmpty
          ? widget.currentUserPhotoUrl
          : (_auth.currentUser?.photoURL ??
              ''); // Mantém fallback para segurança

      await parentRef.collection('replies').doc(replyId).set({
        'userId': currentUserId,
        'userName': userName,
        'userPhotoUrl': userPhotoUrl,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(),
      });

      await _postRef.update({
        'comments': FieldValue.increment(1),
      });

      controller.clear();
      setState(() {
        _replyingCommentIds.remove(parentCommentId);
      });
      FocusScope.of(context).unfocus();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível enviar a resposta: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _processingReplies.remove(parentCommentId);
        });
      }
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Agora';
    try {
      final date = (timestamp as Timestamp).toDate();
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inMinutes < 1) return 'Agora';
      if (difference.inMinutes < 60) return '${difference.inMinutes}m';
      if (difference.inHours < 24) return '${difference.inHours}h';
      if (difference.inDays < 7) return '${difference.inDays}d';
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return 'Agora';
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = widget.data['text'] ?? '';
    final mediaUrl = widget.data['mediaUrl'] as String?;
    final mediaType = widget.data['mediaType'] as String?;
    final userName = widget.data['userName'] ?? 'Usuário';
    final userPhotoUrl = widget.data['userPhotoUrl'] ?? '';
    final timestamp = widget.data['createdAt'];
    final updatedAt = widget.data['updatedAt'];
    final editedLabel = updatedAt != null ? ' • editado' : '';

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: CircleAvatar(
              backgroundColor:
                  Theme.of(context).cardTheme.color ?? Colors.grey.shade300,
              backgroundImage:
                  userPhotoUrl.isNotEmpty ? NetworkImage(userPhotoUrl) : null,
              child: userPhotoUrl.isEmpty
                  ? Icon(Icons.person, color: Theme.of(context).iconTheme.color)
                  : null,
            ),
            title: Text(
              userName,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).textTheme.titleMedium?.color,
              ),
            ),
            subtitle: Text(
              '${_formatDate(timestamp)}$editedLabel',
              style: TextStyle(
                  color: Theme.of(context).textTheme.bodySmall?.color),
            ),
            trailing: widget.canManage
                ? PopupMenuButton<String>(
                    onSelected: (value) {
                      switch (value) {
                        case 'edit':
                          widget.onEdit?.call();
                          break;
                        case 'delete':
                          widget.onDelete?.call();
                          break;
                      }
                    },
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: 'edit',
                        child: Text('Editar'),
                      ),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('Excluir'),
                      ),
                    ],
                  )
                : null,
          ),
          if (text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 15,
                  color: Theme.of(context).textTheme.bodyLarge?.color,
                ),
              ),
            ),
          if (mediaUrl != null) ...[
            const SizedBox(height: 8),
            if (mediaType == 'image')
              CachedNetworkImage(
                imageUrl: mediaUrl,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  height: 200,
                  color: Colors.grey.shade300,
                  child: const Center(child: CircularProgressIndicator()),
                ),
                errorWidget: (context, url, error) => Container(
                  height: 200,
                  color: Colors.grey.shade300,
                  child: const Icon(Icons.error),
                ),
              )
            else if (mediaType == 'video')
              Container(
                height: 200,
                width: double.infinity,
                color: Colors.black,
                child: const Center(
                  child: Icon(Icons.play_circle_outline,
                      color: Colors.white, size: 60),
                ),
              ),
          ],
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    _hasLiked ? Icons.thumb_up : Icons.thumb_up_outlined,
                    color: _hasLiked ? Colors.red : null,
                  ),
                  onPressed: _isProcessingLike ? null : _toggleLike,
                  tooltip: _hasLiked ? 'Remover curtida' : 'Curtir',
                ),
                Text('$_likesCount'),
                const SizedBox(width: 16),
                IconButton(
                  icon: Icon(
                    _showComments ? Icons.comment : Icons.comment_outlined,
                    color: _showComments ? Colors.red : null,
                  ),
                  onPressed: () async {
                    setState(() {
                      _showComments = !_showComments;

                      if (_showComments) {
                        _commentsFuture = _loadComments();
                      }
                    });
                  },
                  tooltip: 'Comentar',
                ),
                Text('$_commentsCount'),
              ],
            ),
          ),
          if (_showComments) _buildCommentsSection(context),
        ],
      ),
    );
  }

  Widget _buildCommentsSection(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _postRef
                .collection('comments')
                .orderBy('createdAt', descending: true)
                .limit(20)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Center(
                    child: CircularProgressIndicator(color: Colors.red),
                  ),
                );
              }

              // 🔥 FILTRA comentários incompletos (pendingWrites)
              final allDocs = snapshot.data?.docs ?? [];
              final comments = allDocs
                  .where((doc) => !doc.metadata.hasPendingWrites)
                  .toList();

              if (comments.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Seja o primeiro a comentar!',
                    style: TextStyle(color: Colors.grey),
                  ),
                );
              }

              return ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: comments.length,
                itemBuilder: (context, index) {
                  final commentDoc = comments[index];
                  return Padding(
                    padding: EdgeInsets.only(
                      bottom: index == comments.length - 1 ? 0 : 12,
                    ),
                    child: _buildCommentItem(
                      commentDoc,
                      isReply: false,
                    ),
                  );
                },
              );
            },
          ),

          const SizedBox(height: 12),

          // 🔥 Campo de escrever comentário
          Row(
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: Colors.grey.shade300,
                backgroundImage: widget.currentUserPhotoUrl.isNotEmpty
                    ? NetworkImage(widget.currentUserPhotoUrl)
                    : null,
                child: widget.currentUserPhotoUrl.isEmpty
                    ? const Icon(Icons.person, size: 18)
                    : null,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _commentController,
                  enabled: widget.isAuthenticated && !_isSendingComment,
                  decoration: InputDecoration(
                    hintText: widget.isAuthenticated
                        ? 'Escreva um comentário...'
                        : 'Entre para comentar',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                  ),
                  minLines: 1,
                  maxLines: 3,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: _isSendingComment
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.send, color: Colors.red),
                onPressed: !_isSendingComment ? _submitComment : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommentItem(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    required bool isReply,
  }) {
    final commentId = doc.id;
    final data = doc.data() ?? {};
    final commentUserName = data['userName'] as String? ?? 'Usuário';
    final commentText = data['text'] as String? ?? 'Comentário removido';
    final commentUserPhoto = data['userPhotoUrl'] as String? ?? '';
    final createdAt = data['createdAt'];

    // Garante que o userId seja extraído corretamente, tratando diferentes tipos
    final commentUserIdRaw = data['userId'];
    debugPrint(
        '[PostCard] _buildCommentItem: commentUserIdRaw do Firestore=$commentUserIdRaw (tipo: ${commentUserIdRaw.runtimeType})');

    final commentUserId = commentUserIdRaw?.toString().trim() ?? '';
    // Se está vazio, considera null
    final commentUserIdFinal = commentUserId.isEmpty ? null : commentUserId;

    debugPrint(
        '[PostCard] _buildCommentItem: commentId=$commentId, commentUserIdFinal=$commentUserIdFinal, currentUserId=${_effectiveUserId}');

    // Permissão de exclusão: pode excluir se for dono do comentário OU dono do post
    final canDeleteComment = _canDeleteComment(commentUserIdFinal);
    final canManageComment =
        canDeleteComment; // Mostra menu apenas se pode excluir
    final isReplying = _replyingCommentIds.contains(commentId);
    final replyController = _replyControllerFor(commentId);
    final isSendingReply = _processingReplies.contains(commentId);
    final isDeleting = _processingDeletes.contains(doc.reference.path);

    Widget commentBubble = Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            commentUserName,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            commentText,
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                _formatDate(createdAt),
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
              ),
              if (widget.isAuthenticated && !isReply && !isDeleting) ...[
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () => _toggleReplying(commentId),
                  child: Text(
                    isReplying ? 'Cancelar' : 'Responder',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.red,
                    ),
                  ),
                ),
              ],
              if (canManageComment) ...[
                const SizedBox(width: 12),
                PopupMenuButton<String>(
                  enabled: !isDeleting,
                  icon: Icon(
                    Icons.more_vert,
                    size: 18,
                    color: isDeleting ? Colors.grey : Colors.black87,
                  ),
                  onSelected: (value) {
                    if (value == 'delete') {
                      _deleteComment(
                        docRef: doc.reference,
                        isReply: isReply,
                        commentUserId: commentUserIdFinal,
                      );
                    }
                  },
                  itemBuilder: (context) => [
                    // Mostra opção de excluir se o usuário pode excluir (dono do comentário OU dono do post)
                    PopupMenuItem(
                      value: 'delete',
                      enabled: !isDeleting,
                      child: const Row(
                        children: [
                          Icon(Icons.delete, size: 18, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Excluir'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          if (isDeleting)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                children: const [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Removendo comentário...',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                ],
              ),
            ),
          if (isReplying)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 16,
                    backgroundColor: Colors.grey.shade300,
                    backgroundImage: widget.currentUserPhotoUrl.isNotEmpty
                        ? NetworkImage(widget.currentUserPhotoUrl)
                        : null,
                    child: widget.currentUserPhotoUrl.isEmpty
                        ? const Icon(Icons.person, size: 18)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      children: [
                        TextField(
                          controller: replyController,
                          maxLines: 3,
                          minLines: 1,
                          decoration: InputDecoration(
                            hintText: 'Responder...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Align(
                          alignment: Alignment.centerRight,
                          child: ElevatedButton.icon(
                            onPressed: isSendingReply
                                ? null
                                : () => _submitReply(
                                      parentCommentId: commentId,
                                      parentRef: doc.reference,
                                    ),
                            icon: isSendingReply
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.send, size: 18),
                            label: const Text('Enviar'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red,
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey.shade300,
              backgroundImage: commentUserPhoto.isNotEmpty
                  ? NetworkImage(commentUserPhoto)
                  : null,
              child: commentUserPhoto.isEmpty
                  ? const Icon(Icons.person, size: 18)
                  : null,
            ),
            const SizedBox(width: 8),
            Expanded(child: commentBubble),
          ],
        ),
        if (!isReply)
          Padding(
            padding: const EdgeInsets.only(left: 40, top: 8),
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: doc.reference
                  .collection('replies')
                  .orderBy('createdAt', descending: false)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const SizedBox.shrink();
                }
                final replies = snapshot.data!.docs;
                return Column(
                  children: replies
                      .map(
                        (reply) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _buildCommentItem(
                            reply,
                            isReply: true,
                          ),
                        ),
                      )
                      .toList(),
                );
              },
            ),
          ),
      ],
    );
  }

  Future<void> _toggleLike() async {
    final currentUserId = _effectiveUserId;

    if (!widget.isAuthenticated || currentUserId == null) {
      _showLoginSnack('Faça login para curtir publicações.');
      return;
    }
    if (_isProcessingLike) return;

    setState(() {
      _isProcessingLike = true;
    });

    try {
      final postRef = _firestore.collection('posts').doc(widget.docId);
      await _firestore.runTransaction((transaction) async {
        final snapshot = await transaction.get(postRef);
        if (!snapshot.exists) {
          throw Exception('Publicação não encontrada.');
        }

        final data = snapshot.data() as Map<String, dynamic>;
        final likedBy = (data['likedBy'] as List<dynamic>? ?? [])
            .map((e) => e.toString())
            .toList();

        if (likedBy.contains(currentUserId)) {
          likedBy.remove(currentUserId);
        } else {
          likedBy.add(currentUserId);
        }

        transaction.update(postRef, {
          'likedBy': likedBy,
          'likes': likedBy.length,
        });
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Não foi possível atualizar a curtida: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingLike = false;
        });
      }
    }
  }

  Future<void> _submitComment() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    final uid = currentUser.uid;

    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSendingComment = true);

    try {
      final commentId = _firestore.collection('tmp').doc().id;

      await _postRef.collection('comments').doc(commentId).set({
        'userId': uid,
        'userName': widget.currentUserName, // AGORA correto
        'userPhotoUrl': widget.currentUserPhotoUrl,
        'text': text,
        'createdAt': FieldValue.serverTimestamp(), // 🔥 AQUI RESOLVE O BUG!!!
      });

      await _postRef.update({
        'comments': FieldValue.increment(1),
      });

      _commentController.clear();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao comentar: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isSendingComment = false);
      }
    }
  }

  void _showLoginSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void dispose() {
    _commentController.dispose();
    for (final controller in _replyControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }
}
