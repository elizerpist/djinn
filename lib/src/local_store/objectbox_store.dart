import 'dart:io';

import 'package:path/path.dart' as p;

import '../../objectbox.g.dart';

class ObjectBoxStore {
  ObjectBoxStore._(this.store);

  final Store store;

  static Future<ObjectBoxStore> open({required Directory directory}) async {
    final path = p.join(directory.path, 'objectbox');
    final store = await openStore(directory: path);
    return ObjectBoxStore._(store);
  }

  void close() => store.close();
}
