import 'note_document.dart';

const List<String> noteHierarchyChildMarkers = [
  '▪',
  '•',
  '◦',
  '‣',
  '⁃',
  '▫',
  '∙',
  '–',
];

String noteHierarchyChildMarkerForLevel(int level) {
  final index = (level - 1)
      .clamp(0, noteHierarchyChildMarkers.length - 1)
      .toInt();
  return noteHierarchyChildMarkers[index];
}

Map<String, String> noteHierarchyMarkersForItems(Iterable<NoteListItem> items) {
  var motherIndex = 0;
  final markers = <String, String>{};
  for (final item in items) {
    markers[item.id] = item.level <= 0
        ? '${++motherIndex}.'
        : noteHierarchyChildMarkerForLevel(item.level);
  }
  return markers;
}
