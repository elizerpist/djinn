import 'package:flutter/material.dart';

import 'src/chat/data/local_chat_repository.dart';
import 'src/chat/ui/main_screen.dart';

void main() {
  runApp(const DjinnApp());
}

class DjinnApp extends StatefulWidget {
  const DjinnApp({super.key});

  @override
  State<DjinnApp> createState() => _DjinnAppState();
}

class _DjinnAppState extends State<DjinnApp> {
  final LocalChatRepository _repository = LocalChatRepository();

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
      home: MainScreen(repository: _repository),
    );
  }
}

class MyApp extends DjinnApp {
  const MyApp({super.key});
}
