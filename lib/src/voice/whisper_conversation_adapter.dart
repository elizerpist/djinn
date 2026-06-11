import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:whisper_ggml/whisper_ggml.dart';

import '../debug/debug_console.dart';
import 'speech_adapter.dart';

class WhisperConversationAdapter implements SpeechAdapter {
  WhisperConversationAdapter({
    WhisperController? whisperController,
    WhisperModel model = WhisperModel.tiny,
    AudioRecorder? recorder,
    this.chunkDuration = const Duration(seconds: 2),
  }) : _whisperController = whisperController ?? WhisperController(),
       _model = model,
       _recorder = recorder ?? AudioRecorder();

  final WhisperController _whisperController;
  final WhisperModel _model;
  final AudioRecorder _recorder;
  final Duration chunkDuration;

  StreamController<SpeechEvent>? _activeController;
  Timer? _chunkTimer;
  Future<void>? _modelPreparation;
  bool _stopping = false;
  bool _recording = false;
  bool _processingChunk = false;
  int _sessionCounter = 0;
  int _activeSessionId = 0;
  String _currentTranscript = '';
  String? _currentLocale;
  String? _currentChunkPath;

  @override
  Stream<SpeechEvent> listen({required String locale}) {
    final controller = StreamController<SpeechEvent>();
    final sessionId = ++_sessionCounter;
    _stopping = false;
    _recording = false;
    _processingChunk = false;
    _currentTranscript = '';
    _currentLocale = locale;

    DebugConsole.log('[Voice/Whisper] listen start locale=$locale');

    Future<void>(() async {
      try {
        if (_activeController != null) {
          await stop();
        }
        if (_activeSessionId != 0 || _activeController != null) {
          return;
        }
        _activeSessionId = sessionId;
        _activeController = controller;
        final available = await _recorder.hasPermission();
        if (_activeController != controller || _activeSessionId != sessionId) {
          return;
        }
        DebugConsole.log(
          '[Voice/Whisper] permission status=${available ? 'granted' : 'denied'}',
        );
        if (!available) {
          _emitError(controller, 'error_permission');
          return;
        }

        await _prepareModel();
        if (_activeController != controller || _activeSessionId != sessionId) {
          return;
        }
        await _startChunkRecording(sessionId);
        if (_activeController != controller || _activeSessionId != sessionId) {
          return;
        }
        _addTo(controller, const SpeechEvent.status('listening'));

        _chunkTimer = Timer.periodic(chunkDuration, (_) {
          unawaited(_rotateChunk(sessionId));
        });
      } catch (error) {
        DebugConsole.log('[Voice/Whisper] listen failed error=$error');
        _emitError(controller, error.toString());
      }
    });

    controller.onCancel = () async {
      await stop();
    };
    return controller.stream;
  }

  @override
  Future<void> stop() async {
    final controller = _activeController;
    if (controller == null) {
      return;
    }
    if (_stopping) {
      return;
    }
    final sessionId = _activeSessionId;
    _stopping = true;
    _chunkTimer?.cancel();
    _chunkTimer = null;
    await _finalizeCurrentChunk(sessionId: sessionId, commit: true);
    if (_activeController == controller && _activeSessionId == sessionId) {
      _addTo(controller, const SpeechEvent.status('notListening'));
      _addTo(controller, const SpeechEvent.status('done'));
      _close(controller);
    }
  }

  Future<void> _prepareModel() {
    final preparation =
        _modelPreparation ?? _whisperController.downloadModel(_model);
    _modelPreparation = preparation;
    return preparation;
  }

  Future<void> _startChunkRecording(int sessionId) async {
    if (_activeSessionId != sessionId || _stopping) {
      return;
    }
    final path = await _nextChunkPath();
    if (_activeSessionId != sessionId || _stopping) {
      await _safeDelete(path);
      return;
    }
    _currentChunkPath = path;
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: 16000,
        numChannels: 1,
      ),
      path: path,
    );
    if (_activeSessionId != sessionId || _stopping) {
      try {
        await _recorder.stop();
      } catch (_) {}
      _currentChunkPath = null;
      await _safeDelete(path);
      return;
    }
    _recording = true;
    DebugConsole.log(
      '[Voice/Whisper] session=$sessionId chunk recording started path=$path',
    );
  }

  Future<void> _rotateChunk(int sessionId) async {
    if (_activeSessionId != sessionId ||
        _stopping ||
        _processingChunk ||
        !_recording) {
      return;
    }
    _processingChunk = true;
    try {
      await _finalizeCurrentChunk(sessionId: sessionId, commit: false);
      if (!_stopping &&
          _activeController != null &&
          _activeSessionId == sessionId) {
        await _startChunkRecording(sessionId);
      }
    } catch (error) {
      DebugConsole.log('[Voice/Whisper] chunk rotation failed error=$error');
      final controller = _activeController;
      if (controller != null) {
        _emitError(controller, error.toString());
      }
    } finally {
      _processingChunk = false;
    }
  }

  Future<void> _finalizeCurrentChunk({
    required int sessionId,
    required bool commit,
  }) async {
    if (_activeSessionId != sessionId || !_recording) {
      return;
    }
    final controller = _activeController;
    final currentPath = _currentChunkPath;
    _currentChunkPath = null;
    _recording = false;
    final recordedPath = await _recorder.stop();
    final audioPath = recordedPath ?? currentPath;
    if (audioPath == null) {
      return;
    }

    final text = await _transcribeChunk(audioPath, sessionId: sessionId);
    await _safeDelete(audioPath);
    if (_activeSessionId != sessionId || _activeController != controller) {
      DebugConsole.log(
        '[Voice/Whisper] drop stale chunk session=$sessionId chars=${text.length}',
      );
      return;
    }
    if (text.isEmpty) {
      if (commit && _currentTranscript.isNotEmpty && controller != null) {
        _addTo(controller, SpeechEvent.result(_currentTranscript, true));
      }
      return;
    }

    _currentTranscript = _mergeTranscript(_currentTranscript, text);
    if (controller != null) {
      _addTo(controller, SpeechEvent.result(_currentTranscript, commit));
      DebugConsole.log(
        commit
            ? '[Voice/Whisper] final transcript chars=${_currentTranscript.length}'
            : '[Voice/Whisper] partial transcript updated chars=${_currentTranscript.length}',
      );
    }
  }

  Future<String> _transcribeChunk(
    String audioPath, {
    required int sessionId,
  }) async {
    final locale = _currentLocale ?? 'auto';
    final lang = _whisperLanguage(locale);
    DebugConsole.log(
      '[Voice/Whisper] session=$sessionId transcribe chunk path=$audioPath '
      'lang=$lang model=$_model',
    );
    final result = await _whisperController.transcribe(
      model: _model,
      audioPath: audioPath,
      lang: lang,
    );
    return result?.transcription.text.trim() ?? '';
  }

  Future<void> _safeDelete(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }

  Future<String> _nextChunkPath() async {
    final directory = await getTemporaryDirectory();
    return '${directory.path}/djinn-whisper-${DateTime.now().microsecondsSinceEpoch}.wav';
  }

  void _emitError(StreamController<SpeechEvent> controller, String code) {
    _addTo(controller, SpeechEvent.error(code));
    _close(controller);
  }

  void _addTo(StreamController<SpeechEvent> controller, SpeechEvent event) {
    if (_activeController == controller && !controller.isClosed) {
      controller.add(event);
    }
  }

  void _close(StreamController<SpeechEvent> controller) {
    if (_activeController == controller) {
      _activeController = null;
      _chunkTimer?.cancel();
      _chunkTimer = null;
      _currentChunkPath = null;
      _recording = false;
      _processingChunk = false;
      _stopping = false;
      _activeSessionId = 0;
      _currentLocale = null;
    }
    if (!controller.isClosed) {
      controller.close();
    }
  }
}

String _whisperLanguage(String locale) {
  final trimmed = locale.trim();
  if (trimmed.isEmpty || trimmed.toLowerCase() == 'auto') {
    return 'auto';
  }
  final separator = trimmed.contains('-') ? '-' : '_';
  return trimmed.split(separator).first.toLowerCase();
}

String _mergeTranscript(String current, String next) {
  final left = current.trim();
  final right = next.trim();
  if (left.isEmpty) {
    return right;
  }
  if (right.isEmpty) {
    return left;
  }
  final leftWords = left.split(RegExp(r'\s+'));
  final rightWords = right.split(RegExp(r'\s+'));
  final maxOverlap = [
    leftWords.length,
    rightWords.length,
    8,
  ].reduce((a, b) => a < b ? a : b);
  for (var overlap = maxOverlap; overlap > 0; overlap -= 1) {
    final leftSuffix = leftWords.sublist(leftWords.length - overlap).join(' ').toLowerCase();
    final rightPrefix = rightWords.sublist(0, overlap).join(' ').toLowerCase();
    if (leftSuffix == rightPrefix) {
      final remainder = rightWords.sublist(overlap).join(' ').trim();
      return remainder.isEmpty ? left : '$left $remainder';
    }
  }
  return '$left $right';
}
