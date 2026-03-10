import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

class VectorBootstrapService {
  Future<String?> bootstrapIfNeeded(String zipUrl) async {
    if (zipUrl.trim().isEmpty) {
      return null;
    }

    final docs = await getApplicationDocumentsDirectory();
    final vectorDir = Directory('${docs.path}/vectorstore/faiss_index');
    final indexFile = File('${vectorDir.path}/index.faiss');
    if (await indexFile.exists()) {
      return indexFile.path;
    }

    await vectorDir.create(recursive: true);
    final response = await http.get(Uri.parse(zipUrl));
    if (response.statusCode != 200) {
      throw Exception('Failed to download vector zip: ${response.statusCode}');
    }

    final tempZip = File('${docs.path}/vectorstore/vectorstore.zip');
    await tempZip.writeAsBytes(response.bodyBytes, flush: true);

    final input = InputFileStream(tempZip.path);
    final archive = ZipDecoder().decodeBuffer(input);
    extractArchiveToDisk(archive, '${docs.path}/vectorstore');
    await tempZip.delete();

    if (!await indexFile.exists()) {
      // Accept zip files that contain `vectorstore/faiss_index/...` as root.
      final nestedIndex = File('${docs.path}/vectorstore/vectorstore/faiss_index/index.faiss');
      final nestedPkl = File('${docs.path}/vectorstore/vectorstore/faiss_index/index.pkl');
      if (await nestedIndex.exists()) {
        await nestedIndex.copy(indexFile.path);
        if (await nestedPkl.exists()) {
          await nestedPkl.copy('${vectorDir.path}/index.pkl');
        }
      }
    }

    if (!await indexFile.exists()) {
      throw Exception(
        'Vector zip extracted but index.faiss missing. Zip must contain '
        'faiss_index/index.faiss (or vectorstore/faiss_index/index.faiss).',
      );
    }

    return indexFile.path;
  }
}
