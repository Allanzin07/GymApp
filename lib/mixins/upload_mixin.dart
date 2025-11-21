import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

mixin UploadMixin {
  final supabase = Supabase.instance.client;

  /// Envia uma imagem para o bucket "uploads"
  /// e retorna a URL pública.
  Future<String> uploadImageToSupabase({
    required Uint8List bytes,
    required String folder,
  }) async {
    final id = const Uuid().v4();
    final path = '$folder/$id.jpg';

    final result = await supabase.storage.from('uploads').uploadBinary(
      path,
      bytes,
      fileOptions: const FileOptions(contentType: 'image/jpeg'),
    );

    if (result.isEmpty) {
      throw Exception("Erro ao enviar imagem ao Supabase.");
    }

    return supabase.storage.from('uploads').getPublicUrl(path);
  }
}