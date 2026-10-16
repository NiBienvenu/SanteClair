import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../network/api_client.dart';
import '../network/api_exception.dart';
import '../widgets/common.dart';

Future<void> downloadApiFile(
  BuildContext context,
  ApiClient api, {
  required String url,
  required String fileName,
}) async {
  try {
    final bytes = await api.getBytes(url);
    final extension = fileName.split('.').last.toLowerCase();
    final mime = switch (extension) {
      'pdf' => 'application/pdf',
      'png' => 'image/png',
      'jpg' || 'jpeg' => 'image/jpeg',
      'dicom' || 'dcm' => 'application/dicom',
      _ => 'application/octet-stream',
    };
    final saved = await FilePicker.saveFile(
      fileName: fileName,
      bytes: bytes,
      mimeType: mime,
      dialogTitle: 'Enregistrer le document',
    );
    if (saved != null && context.mounted) {
      showAppSnack(context, 'Document enregistré.');
    }
  } on ApiException catch (e) {
    if (context.mounted) showAppSnack(context, e.message, error: true);
  } catch (_) {
    if (context.mounted) {
      showAppSnack(
        context,
        'Impossible d’enregistrer le document.',
        error: true,
      );
    }
  }
}
