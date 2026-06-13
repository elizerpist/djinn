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

  @override
  void initState() {
    super.initState();
    _notesController = TextEditingController(text: widget.item.notes);
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveNotes(String value) async {
    await widget.repository.updateNotes(widget.item.id, value);
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
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.chat_bubble_outline),
            title: Text('Kapcsolt chatek'),
            subtitle: Text('Később innen lehet beszélgetéseket kapcsolni.'),
          ),
          const ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.picture_as_pdf_outlined),
            title: Text('Kapcsolt PDF-ek'),
            subtitle: Text('Később innen lehet forrás PDF-eket kapcsolni.'),
          ),
        ],
      ),
    );
  }
}
