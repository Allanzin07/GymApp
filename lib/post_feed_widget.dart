import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
  final _storage = FirebaseStorage.instance;
  final _picker = ImagePicker();
  final TextEditingController _textController = TextEditingController();

  File? _selectedImage;
  XFile? _selectedImageXFile;
  File? _selectedVideo;
  XFile? _selectedVideoXFile;
  bool _isUploading = false;
  double _uploadProgress = 0.0;

  Future<void> _pickImage() async {
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
          _selectedImageXFile = picked;
          if (!kIsWeb) {
            _selectedImage = File(picked.path);
          }
          _selectedVideo = null; // Remove vídeo se imagem for selecionada
          _selectedVideoXFile = null;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao selecionar imagem')),
      );
    }
  }

  Future<void> _pickVideo() async {
    try {
      final picked = await _picker.pickVideo(source: ImageSource.gallery);
      if (picked != null) {
        setState(() {
          _selectedVideoXFile = picked;
          if (!kIsWeb) {
            _selectedVideo = File(picked.path);
          }
          _selectedImage = null; // Remove imagem se vídeo for selecionado
          _selectedImageXFile = null;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao selecionar vídeo')),
      );
    }
  }

  Future<String> _uploadFile(dynamic file, String folder, String extension) async {
    final id = const Uuid().v4();
    final ref = _storage.ref().child('$folder/$id.$extension');

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

  Future<void> _createPost() async {
    final text = _textController.text.trim();
    
    if (text.isEmpty && _selectedImage == null && _selectedVideo == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Adicione texto, foto ou vídeo para publicar')),
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

      if (_selectedImageXFile != null) {
        mediaUrl = await _uploadFile(_selectedImageXFile!, 'posts/${widget.userId}', 'jpg');
        mediaType = 'image';
      } else if (_selectedVideoXFile != null) {
        mediaUrl = await _uploadFile(_selectedVideoXFile!, 'posts/${widget.userId}', 'mp4');
        mediaType = 'video';
      }

      await _firestore.collection('posts').add({
        'userId': widget.userId,
        'userName': widget.userName,
        'userPhotoUrl': widget.userPhotoUrl,
        'text': text,
        'mediaUrl': mediaUrl,
        'mediaType': mediaType, // 'image', 'video' ou null
        'collectionName': widget.collectionName,
        'createdAt': FieldValue.serverTimestamp(),
        'likes': 0,
        'comments': 0,
      });

      // Limpar campos
      _textController.clear();
      setState(() {
        _selectedImage = null;
        _selectedImageXFile = null;
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
        setState(() => _isUploading = false);
      }
    }
  }

  Widget _buildCreatePostCard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            // Campo de texto
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.grey.shade300,
                  backgroundImage: widget.userPhotoUrl.isNotEmpty
                      ? NetworkImage(widget.userPhotoUrl)
                      : null,
                  child: widget.userPhotoUrl.isEmpty
                      ? const Icon(Icons.person, size: 20)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _textController,
                    maxLines: 4,
                    decoration: InputDecoration(
                      hintText: 'O que você está pensando?',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                      filled: true,
                      fillColor: Colors.grey.shade100,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // Preview de mídia selecionada
            if (_selectedImageXFile != null) ...[
              const SizedBox(height: 12),
              Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: kIsWeb
                        ? FutureBuilder<Uint8List>(
                            future: _selectedImageXFile!.readAsBytes(),
                            builder: (context, snapshot) {
                              if (snapshot.hasData) {
                                return Image.memory(
                                  snapshot.data!,
                                  height: 200,
                                  width: double.infinity,
                                  fit: BoxFit.cover,
                                );
                              }
                              return Container(
                                height: 200,
                                color: Colors.grey.shade300,
                                child: const Center(child: CircularProgressIndicator()),
                              );
                            },
                          )
                        : Image.file(
                            _selectedImage!,
                            height: 200,
                            width: double.infinity,
                            fit: BoxFit.cover,
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
            // Botões de ação
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: _isUploading ? null : _pickImage,
                    icon: const Icon(Icons.photo, color: Colors.green),
                    label: const Text('Foto'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey.shade700,
                    ),
                  ),
                ),
                Expanded(
                  child: TextButton.icon(
                    onPressed: _isUploading ? null : _pickVideo,
                    icon: const Icon(Icons.video_library, color: Colors.red),
                    label: const Text('Vídeo'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.grey.shade700,
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
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text('Publicar'),
                  ),
                ),
              ],
            ),
            // Indicador de progresso
            if (_isUploading) ...[
              const SizedBox(height: 8),
              LinearProgressIndicator(value: _uploadProgress),
              const SizedBox(height: 4),
              Text(
                '${(_uploadProgress * 100).toStringAsFixed(0)}%',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildCreatePostCard(),
        StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('posts')
              .where('userId', isEqualTo: widget.userId)
              .orderBy('createdAt', descending: true)
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

            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
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
              itemCount: snapshot.data!.docs.length,
              itemBuilder: (context, index) {
                final doc = snapshot.data!.docs[index];
                final data = doc.data() as Map<String, dynamic>;
                return _PostCard(data: data);
              },
            );
          },
        ),
      ],
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }
}

class _PostCard extends StatelessWidget {
  final Map<String, dynamic> data;

  const _PostCard({required this.data});

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
    final text = data['text'] ?? '';
    final mediaUrl = data['mediaUrl'] as String?;
    final mediaType = data['mediaType'] as String?;
    final userName = data['userName'] ?? 'Usuário';
    final userPhotoUrl = data['userPhotoUrl'] ?? '';
    final timestamp = data['createdAt'];
    final likes = data['likes'] ?? 0;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabeçalho do post
          ListTile(
            leading: CircleAvatar(
              backgroundColor: Colors.grey.shade300,
              backgroundImage: userPhotoUrl.isNotEmpty
                  ? NetworkImage(userPhotoUrl)
                  : null,
              child: userPhotoUrl.isEmpty
                  ? const Icon(Icons.person)
                  : null,
            ),
            title: Text(
              userName,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(_formatDate(timestamp)),
          ),
          // Texto do post
          if (text.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                text,
                style: const TextStyle(fontSize: 15),
              ),
            ),
          // Mídia (imagem ou vídeo)
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
          // Ações do post
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.thumb_up_outlined),
                  onPressed: () {},
                  tooltip: 'Curtir',
                ),
                Text('$likes'),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.comment_outlined),
                  onPressed: () {},
                  tooltip: 'Comentar',
                ),
                const SizedBox(width: 16),
                IconButton(
                  icon: const Icon(Icons.share_outlined),
                  onPressed: () {},
                  tooltip: 'Compartilhar',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

