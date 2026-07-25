import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unified chunk schema preserves every legacy DocumentChunk UID', () {
    final model =
        jsonDecode(File('lib/objectbox-model.json').readAsStringSync())
            as Map<String, Object?>;
    final entities = (model['entities'] as List).whereType<Map>().toList();
    final chunk = entities.singleWhere(
      (entity) => entity['name'] == 'DocumentChunkEntity',
    );

    expect(chunk['id'], '6:9012920818068651330');

    final propertyUids = <String, String>{
      for (final property in (chunk['properties'] as List).whereType<Map>())
        property['name'] as String: property['id'] as String,
    };
    const legacyPropertyUids = <String, String>{
      'id': '1:5206250045140841812',
      'publicId': '2:1628053356831854107',
      'documentPublicId': '3:8638837129045034888',
      'text': '4:5697290722411591078',
      'pageNumber': '5:7701346108871482881',
      'sectionTitle': '6:1063090330926866476',
      'sourceRectJson': '7:6184607323443707496',
      'pipeline': '8:260415155013015694',
      'chunkKind': '9:5537504821889093045',
      'auditState': '10:9042423905567594545',
      'endPageNumber': '11:4953371634906505277',
      'confidence': '12:8662152663731677051',
      'sourcePageImagePath': '13:4895734823750777506',
      'tagsJson': '14:1230647960012750427',
      'sortOrder': '15:6100123456789012345',
      'structuredContentJson': '16:7328401746589023419',
    };
    for (final entry in legacyPropertyUids.entries) {
      expect(propertyUids, containsPair(entry.key, entry.value));
    }
    expect(propertyUids.keys, contains('creationMethod'));
    expect(propertyUids.keys, contains('originalText'));
  });

  test('schema contains collector and explicit M:N membership entities', () {
    final model =
        jsonDecode(File('lib/objectbox-model.json').readAsStringSync())
            as Map<String, Object?>;
    final names = (model['entities'] as List)
        .whereType<Map>()
        .map((entity) => entity['name'])
        .toSet();

    expect(names, contains('NoteEntity'));
    expect(names, contains('NoteFolderEntity'));
    expect(names, contains('ChunkNoteLinkEntity'));
    expect(names, contains('DataMigrationEntity'));
  });
}
