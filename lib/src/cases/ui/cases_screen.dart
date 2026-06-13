import 'package:flutter/material.dart';

import '../data/case_repository.dart';
import '../models/case_workspace.dart';

class CasesScreen extends StatefulWidget {
  const CasesScreen({
    super.key,
    required this.repository,
    this.showAppBar = true,
  });

  final CaseRepository repository;
  final bool showAppBar;

  @override
  State<CasesScreen> createState() => _CasesScreenState();
}

class _CasesScreenState extends State<CasesScreen> {
  List<CaseWorkspace> _cases = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final cases = await widget.repository.listCases();
      if (!mounted) {
        return;
      }
      setState(() {
        _cases = cases;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loading = false;
        _error = 'Az esetek betöltése nem sikerült';
      });
    }
  }

  Future<void> _createCase() async {
    try {
      await widget.repository.createCase();
      await _load();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Az eset létrehozása nem sikerült');
      }
    }
  }

  Future<void> _openCase(CaseWorkspace item) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            CaseDetailScreen(repository: widget.repository, item: item),
      ),
    );
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final body = _buildBody();
    return Scaffold(
      appBar: widget.showAppBar
          ? AppBar(
              title: const Text('Esetek'),
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
            )
          : null,
      body: body,
      floatingActionButton: FloatingActionButton(
        tooltip: 'Új eset',
        onPressed: _createCase,
        child: const Icon(Icons.note_add_outlined),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final error = _error;
    if (error != null) {
      return Center(child: Text(error));
    }
    if (_cases.isEmpty) {
      return const Center(
        child: Text(
          'Nincs mentett eset',
          style: TextStyle(color: Color(0xFF6B7280)),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      itemCount: _cases.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) =>
          _CaseTile(item: _cases[index], onTap: () => _openCase(_cases[index])),
    );
  }
}

class _CaseTile extends StatelessWidget {
  const _CaseTile({required this.item, required this.onTap});

  final CaseWorkspace item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: ListTile(
        onTap: onTap,
        title: Text(
          item.title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.notesPreview,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              children: [
                _CountChip(
                  icon: Icons.chat_bubble_outline,
                  label: '${item.linkedChatCount} chat',
                ),
                _CountChip(
                  icon: Icons.picture_as_pdf_outlined,
                  label: '${item.linkedDocumentCount} PDF',
                ),
              ],
            ),
          ],
        ),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}

class _CountChip extends StatelessWidget {
  const _CountChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: const Color(0xFF4B5563)),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF4B5563)),
          ),
        ],
      ),
    );
  }
}

class CaseDetailScreen extends StatefulWidget {
  const CaseDetailScreen({
    super.key,
    required this.repository,
    required this.item,
  });

  final CaseRepository repository;
  final CaseWorkspace item;

  @override
  State<CaseDetailScreen> createState() => _CaseDetailScreenState();
}

class _CaseDetailScreenState extends State<CaseDetailScreen> {
  late final TextEditingController _notesController;
  List<String> _linkedChats = const [];
  List<String> _linkedDocuments = const [];

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController(text: widget.item.notes);
    _loadLinks();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadLinks() async {
    final chats = await widget.repository.listLinkedChats(widget.item.id);
    final documents = await widget.repository.listLinkedDocuments(
      widget.item.id,
    );
    if (!mounted) {
      return;
    }
    setState(() {
      _linkedChats = chats;
      _linkedDocuments = documents;
    });
  }

  Future<void> _saveNotes(String value) async {
    await widget.repository.updateNotes(widget.item.id, value);
  }

  Future<void> _addChatLink() async {
    final id = await _showLinkDialog(
      title: 'Chat kapcsolása',
      label: 'Chat azonosító',
    );
    if (id == null) {
      return;
    }
    await widget.repository.linkChat(widget.item.id, id);
    await _loadLinks();
  }

  Future<void> _addDocumentLink() async {
    final id = await _showLinkDialog(
      title: 'PDF kapcsolása',
      label: 'Dokumentum azonosító',
    );
    if (id == null) {
      return;
    }
    await widget.repository.linkDocument(widget.item.id, id);
    await _loadLinks();
  }

  Future<String?> _showLinkDialog({
    required String title,
    required String label,
  }) {
    return showDialog<String>(
      context: context,
      builder: (context) => _AddCaseLinkDialog(title: title, label: label),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.item.title),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          const Text(
            'Jegyzetek',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          TextField(
            key: const Key('case-notes-field'),
            controller: _notesController,
            minLines: 8,
            maxLines: 16,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Esetjegyzetek',
            ),
            onChanged: _saveNotes,
          ),
          const SizedBox(height: 16),
          _LinkedCaseSection(
            title: 'Kapcsolt chatek',
            emptyText: 'Nincs kapcsolt chat',
            icon: Icons.chat_bubble_outline,
            addKey: const Key('add-case-chat-link'),
            onAdd: _addChatLink,
            items: _linkedChats,
          ),
          const SizedBox(height: 12),
          _LinkedCaseSection(
            title: 'Kapcsolt PDF-ek',
            emptyText: 'Nincs kapcsolt PDF',
            icon: Icons.picture_as_pdf_outlined,
            addKey: const Key('add-case-document-link'),
            onAdd: _addDocumentLink,
            items: _linkedDocuments,
          ),
        ],
      ),
    );
  }
}

class _LinkedCaseSection extends StatelessWidget {
  const _LinkedCaseSection({
    required this.title,
    required this.emptyText,
    required this.icon,
    required this.addKey,
    required this.onAdd,
    required this.items,
  });

  final String title;
  final String emptyText;
  final IconData icon;
  final Key addKey;
  final VoidCallback onAdd;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: const Color(0xFF4B5563)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                IconButton(
                  key: addKey,
                  tooltip: 'Hozzáadás',
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_circle_outline),
                ),
              ],
            ),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4, left: 28),
                child: Text(
                  emptyText,
                  style: const TextStyle(color: Color(0xFF6B7280)),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final item in items)
                      Chip(
                        label: Text(item),
                        visualDensity: VisualDensity.compact,
                        backgroundColor: const Color(0xFFF3F4F6),
                        side: const BorderSide(color: Color(0xFFE5E7EB)),
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

class _AddCaseLinkDialog extends StatefulWidget {
  const _AddCaseLinkDialog({required this.title, required this.label});

  final String title;
  final String label;

  @override
  State<_AddCaseLinkDialog> createState() => _AddCaseLinkDialogState();
}

class _AddCaseLinkDialogState extends State<_AddCaseLinkDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        key: const Key('case-link-id-field'),
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: widget.label,
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Mégse'),
        ),
        FilledButton(
          onPressed: () {
            final value = _controller.text.trim();
            Navigator.of(context).pop(value.isEmpty ? null : value);
          },
          child: const Text('Hozzáadás'),
        ),
      ],
    );
  }
}
