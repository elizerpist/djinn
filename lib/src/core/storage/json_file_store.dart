import 'dart:convert';
import 'dart:io';

class JsonFileStore {
  const JsonFileStore(this.file);

  final File file;

  Future<List<Map<String, Object?>>> readList() async {
    if (!await file.exists()) {
      return const [];
    }
    final text = await file.readAsString();
    if (text.trim().isEmpty) {
      return const [];
    }
    final decoded = jsonDecode(text);
    if (decoded is! List) {
      return const [];
    }
    return decoded
        .whereType<Map>()
        .map((item) => item.cast<String, Object?>())
        .toList(growable: false);
  }

  Future<void> writeList(List<Map<String, Object?>> items) async {
    await file.parent.create(recursive: true);
    const encoder = JsonEncoder.withIndent('  ');
    await file.writeAsString(encoder.convert(items));
  }
}
