import 'package:flutter/material.dart';

void main() {
  runApp(const DjinnWebPreviewApp());
}

/// Browser-only version of the current Djinn UI.
///
/// It intentionally uses only in-memory UI state. The Android entry point in
/// `main.dart` continues to own ObjectBox, document import, and AI services.
class DjinnWebPreviewApp extends StatelessWidget {
  const DjinnWebPreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Djinn',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF155EEF),
          primary: const Color(0xFF155EEF),
        ),
        scaffoldBackgroundColor: const Color(0xFFF6F7F9),
        useMaterial3: true,
      ),
      home: const _WebMainScreen(),
    );
  }
}

class _WebMainScreen extends StatefulWidget {
  const _WebMainScreen();

  @override
  State<_WebMainScreen> createState() => _WebMainScreenState();
}

class _WebMainScreenState extends State<_WebMainScreen> {
  final List<_PreviewConversation> _conversations = [];
  var _nextConversationId = 1;

  Future<void> _openKnowledgeBase() {
    return Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const _WebKnowledgeBaseScreen()));
  }

  Future<void> _openSettings() {
    return Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const _WebSettingsScreen()));
  }

  Future<void> _openNewChat() async {
    final conversation = _PreviewConversation(
      id: 'conversation-${_nextConversationId++}',
      title: 'Új chat',
    );
    setState(() => _conversations.insert(0, conversation));
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _WebChatScreen(conversation: conversation),
      ),
    );
  }

  Future<void> _openConversation(_PreviewConversation conversation) {
    return Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _WebChatScreen(conversation: conversation),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: Drawer(
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              const ListTile(
                title: Text('Djinn'),
                subtitle: Text('Böngészős UI-előnézet'),
              ),
              ListTile(
                leading: const Icon(Icons.chat),
                title: const Text('Beszélgetések'),
                onTap: () => Navigator.of(context).pop(),
              ),
              ListTile(
                leading: const Icon(Icons.folder),
                title: const Text('Tudástár'),
                onTap: () {
                  Navigator.of(context).pop();
                  _openKnowledgeBase();
                },
              ),
              const ListTile(
                leading: Icon(Icons.account_tree),
                title: Text('Flowchart validáció'),
                enabled: false,
              ),
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Beállítások'),
                onTap: () {
                  Navigator.of(context).pop();
                  _openSettings();
                },
              ),
            ],
          ),
        ),
      ),
      appBar: AppBar(
        title: const Text('Djinn'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        actions: [
          IconButton(
            tooltip: 'Tudastar',
            onPressed: _openKnowledgeBase,
            icon: const Icon(Icons.folder),
          ),
        ],
      ),
      body: _conversations.isEmpty
          ? const Center(
              child: Text(
                'Nincs még beszélgetés',
                style: TextStyle(color: Color(0xFF6B7280)),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
              itemCount: _conversations.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final conversation = _conversations[index];
                return ListTile(
                  tileColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  title: Text(conversation.title),
                  subtitle: Text('${conversation.messages.length} uzenet'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _openConversation(conversation),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Új chat',
        onPressed: _openNewChat,
        child: const Icon(Icons.add_comment),
      ),
    );
  }
}

class _WebKnowledgeBaseScreen extends StatelessWidget {
  const _WebKnowledgeBaseScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tudastar'),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: const Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Böngészős UI-előnézet',
                style: TextStyle(
                  color: Color(0xFF166534),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          Expanded(
            child: Center(
              child: Text(
                'Nincs importált PDF',
                style: TextStyle(color: Color(0xFF6B7280)),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'PDF hozzáadása',
        onPressed: null,
        child: const Icon(Icons.upload_file),
      ),
    );
  }
}

class _WebSettingsScreen extends StatelessWidget {
  const _WebSettingsScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Beállítások')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: const [
          _PreviewSection(
            title: 'Böngészős fejlesztői mód',
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.web),
                title: Text('Csak UI és navigáció'),
                subtitle: Text(
                  'Az ObjectBox, PDF-feldolgozás és AI ki van kapcsolva.',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PreviewSection extends StatelessWidget {
  const _PreviewSection({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _WebChatScreen extends StatefulWidget {
  const _WebChatScreen({required this.conversation});

  final _PreviewConversation conversation;

  @override
  State<_WebChatScreen> createState() => _WebChatScreenState();
}

class _WebChatScreenState extends State<_WebChatScreen> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) {
      return;
    }
    setState(() {
      widget.conversation.messages.add(text);
      _controller.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.conversation.title),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: const Row(
              children: [
                Icon(Icons.folder_off, color: Color(0xFF6B7280), size: 18),
                SizedBox(width: 8),
                Text(
                  'Nincs betoltott tudastar',
                  style: TextStyle(
                    color: Color(0xFF6B7280),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: widget.conversation.messages.isEmpty
                ? const Center(child: Text('Ird be az elso kerdest'))
                : ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: widget.conversation.messages.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) => Align(
                      alignment: Alignment.centerRight,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Text(widget.conversation.messages[index]),
                        ),
                      ),
                    ),
                  ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Kérdés',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    tooltip: 'Küldés',
                    onPressed: _send,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewConversation {
  _PreviewConversation({required this.id, required this.title});

  final String id;
  final String title;
  final List<String> messages = [];
}
