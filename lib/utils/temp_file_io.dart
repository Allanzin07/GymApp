import 'dart:io';
import 'dart:typed_data';

Future<File> createTempFile(Uint8List bytes, String filename) async {
  final directory = await Directory.systemTemp.createTemp('gym_app_upload_');
  final file = File('${directory.path}/$filename');
  return file.writeAsBytes(bytes, flush: true);
}
















