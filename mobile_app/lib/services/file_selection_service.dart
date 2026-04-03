import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:file_selector/file_selector.dart';

class PickedAttachment {
  const PickedAttachment({
    required this.name,
    required this.bytes,
  });

  final String name;
  final Uint8List bytes;
}

class FileSelectionService {
  Future<List<PickedAttachment>> pickFiles({
    required List<String> allowedExtensions,
    required bool allowMultiple,
    String dialogLabel = 'Files',
  }) async {
    if (Platform.isMacOS) {
      return _pickFilesOnMac(
        allowedExtensions: allowedExtensions,
        allowMultiple: allowMultiple,
        dialogLabel: dialogLabel,
      );
    }

    final result = await FilePicker.platform.pickFiles(
      type: allowedExtensions.isEmpty ? FileType.any : FileType.custom,
      allowedExtensions: allowedExtensions.isEmpty ? null : allowedExtensions,
      allowMultiple: allowMultiple,
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      return const [];
    }

    final attachments = <PickedAttachment>[];
    for (final file in result.files) {
      final bytes = file.bytes;
      if (bytes == null || bytes.isEmpty) {
        continue;
      }
      attachments.add(PickedAttachment(name: file.name, bytes: bytes));
    }
    return attachments;
  }

  Future<List<PickedAttachment>> _pickFilesOnMac({
    required List<String> allowedExtensions,
    required bool allowMultiple,
    required String dialogLabel,
  }) async {
    final groups = allowedExtensions.isEmpty
        ? <XTypeGroup>[
            XTypeGroup(label: dialogLabel),
          ]
        : <XTypeGroup>[
            XTypeGroup(
              label: dialogLabel,
              extensions: allowedExtensions,
            ),
          ];

    if (allowMultiple) {
      final files = await openFiles(acceptedTypeGroups: groups);
      return _convertXFiles(files);
    }

    final file = await openFile(acceptedTypeGroups: groups);
    if (file == null) {
      return const [];
    }
    return _convertXFiles([file]);
  }

  Future<List<PickedAttachment>> _convertXFiles(List<dynamic> files) async {
    final attachments = <PickedAttachment>[];
    for (final file in files) {
      final Uint8List bytes = await file.readAsBytes();
      if (bytes.isEmpty) {
        continue;
      }
      attachments.add(
        PickedAttachment(
          name: file.name as String,
          bytes: bytes,
        ),
      );
    }
    return attachments;
  }
}
