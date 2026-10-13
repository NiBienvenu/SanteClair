import 'package:file_picker/file_picker.dart';

import '../../data/repositories/patient_repository.dart';

Future<UploadFile?> pickUploadFile({
  List<String> extensions = const ['pdf', 'jpg', 'jpeg', 'png'],
}) async {
  final file = await FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: extensions,
  );
  if (file == null) return null;
  final path = file.path;
  return UploadFile(
    name: file.name,
    path: path,
    bytes: path == null ? await file.xFile.readAsBytes() : null,
  );
}
