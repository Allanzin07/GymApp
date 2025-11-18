import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseStorageService {
  final SupabaseClient _client = Supabase.instance.client;
  final String bucket = 'uploads';

  Future<String?> uploadProfileImage({
    required Uint8List bytes,
    required String uid,
  }) async {
    try {
      final String filePath = 'users/$uid/profile.jpg';

      await _client.storage.from(bucket).uploadBinary(
            filePath,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );

      final publicUrl = _client.storage.from(bucket).getPublicUrl(filePath);
      return publicUrl;
    } catch (e) {
      print('Erro ao enviar imagem para Supabase: $e');
      return null;
    }
  }
}