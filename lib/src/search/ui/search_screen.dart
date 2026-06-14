import 'package:flutter/material.dart';

import '../../debug/debug_header_button.dart';
import '../../knowledge/data/knowledge_document_repository.dart';
import '../../knowledge/models/extracted_knowledge_item.dart';
import '../../knowledge/models/local_extraction.dart';
import '../../notes/data/note_repository.dart';
import '../../notes/models/note_item.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    required this.knowledgeRepository,
    required this.noteRepository,
  });

  final KnowledgeDocumentRepository knowledgeRepository;
  final NoteRepository noteRepository;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _queryController = TextEditingController();
  List<_SearchResult> _results = const [];
  bool _loading = false;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _search(String rawQuery) async {
    final query = rawQuery.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() => _results = const []);
      return;
    }
    setState(() => _loading = true);
    final results = <_SearchResult>[];
    final notes = await widget.noteRepository.listNotes();
    for (final note in notes.where((note) => note.ragEligible)) {
      final noteHaystack = '${note.title}\n${note.plainText}'.toLowerCase();
      if (noteHaystack.contains(query)) {
        results.add(
          _SearchResult(
            title: note.title,
            source: 'Jegyzet · ${note.type.label}',
            preview: note.plainText,
            icon: _iconForNoteType(note.type),
            auditState: note.auditState,
          ),
        );
      }
    }

    final documents = await widget.knowledgeRepository.listDocuments();
    for (final document in documents) {
      final items = await widget.knowledgeRepository
          .listExtractedKnowledgeItems(document.id);
      for (final item in items.where(_isEligibleExtractedItem)) {
        final sectionTitle = item.sectionTitle ?? '';
        final itemHaystack = '$sectionTitle\n${item.text}'.toLowerCase();
        if (itemHaystack.contains(query)) {
          results.add(
            _SearchResult(
              title: item.sectionTitle?.trim().isNotEmpty == true
                  ? item.sectionTitle!.trim()
                  : item.typeLabel,
              source: '${document.filename} · ${item.pageLabel}',
              preview: item.text,
              icon: _iconForExtractedItem(item),
              auditState: item.auditState,
            ),
          );
        }
      }
    }

    if (!mounted) {
      return;
    }
    setState(() {
      _results = results;
      _loading = false;
    });
  }

  bool _isEligibleExtractedItem(ExtractedKnowledgeItem item) {
    return item.auditState == LocalAuditState.accepted ||
        item.auditState == LocalAuditState.edited;
  }

  IconData _iconForNoteType(NoteItemType type) {
    return switch (type) {
      NoteItemType.document => Icons.note_alt_outlined,
      NoteItemType.text => Icons.notes_outlined,
      NoteItemType.table => Icons.table_chart_outlined,
      NoteItemType.flowchart => Icons.account_tree_outlined,
    };
  }

  IconData _iconForExtractedItem(ExtractedKnowledgeItem item) {
    return switch (item.chunkKind) {
      LocalChunkKind.table => Icons.table_chart_outlined,
      LocalChunkKind.flowchart => Icons.account_tree_outlined,
      LocalChunkKind.score => Icons.rule_folder_outlined,
      LocalChunkKind.imageRegion || LocalChunkKind.visualFact => Icons.image_outlined,
      LocalChunkKind.text || LocalChunkKind.list || LocalChunkKind.unknown => Icons.subject,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Keresés'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: const [DebugHeaderButton()],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              key: const ValueKey('search-query-field'),
              controller: _queryController,
              autofocus: false,
              textInputAction: TextInputAction.search,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                labelText: 'Keresés a helyi tudástárban',
                border: OutlineInputBorder(),
              ),
              onChanged: _search,
              onSubmitted: _search,
            ),
          ),
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: _results.isEmpty
                ? const Center(
                    child: Text(
                      'Írj be egy keresőkifejezést',
                      style: TextStyle(color: Color(0xFF6B7280)),
                    ),
                  )
                : ListView.separated(
                    physics: const BouncingScrollPhysics(
                      parent: AlwaysScrollableScrollPhysics(),
                    ),
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                    itemCount: _results.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) => _SearchResultCard(
                      result: _results[index],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _SearchResult {
  const _SearchResult({
    required this.title,
    required this.source,
    required this.preview,
    required this.icon,
    required this.auditState,
  });

  final String title;
  final String source;
  final String preview;
  final IconData icon;
  final LocalAuditState auditState;
}

class _SearchResultCard extends StatelessWidget {
  const _SearchResultCard({required this.result});

  final _SearchResult result;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(result.icon, color: const Color(0xFF155EEF)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    result.source,
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    result.preview,
                    maxLines: 4,
                    style: const TextStyle(height: 1.25),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
