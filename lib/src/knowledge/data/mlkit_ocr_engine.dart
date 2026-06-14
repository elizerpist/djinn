import 'dart:convert';

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class OcrResult {
  const OcrResult({required this.text, required this.blocksJson});

  final String text;
  final String blocksJson;
}

abstract class OcrEngine {
  Future<OcrResult> recognizeImage(String imagePath);

  Future<void> close() async {}
}

class MlKitOcrEngine implements OcrEngine {
  MlKitOcrEngine({TextRecognitionScript script = TextRecognitionScript.latin})
    : _recognizer = TextRecognizer(script: script);

  final TextRecognizer _recognizer;

  @override
  Future<OcrResult> recognizeImage(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final recognized = await _recognizer.processImage(inputImage);
    return OcrResult(
      text: recognized.text,
      blocksJson: jsonEncode(_blocksToJson(recognized.blocks)),
    );
  }

  @override
  Future<void> close() async {
    await _recognizer.close();
  }

  List<Map<String, Object?>> _blocksToJson(List<TextBlock> blocks) {
    return [
      for (final block in blocks)
        {
          'text': block.text,
          'rect': _rectToJson(block.boundingBox),
          'languages': block.recognizedLanguages,
          'lines': [
            for (final line in block.lines)
              {
                'text': line.text,
                'rect': _rectToJson(line.boundingBox),
                'languages': line.recognizedLanguages,
                'elements': [
                  for (final element in line.elements)
                    {
                      'text': element.text,
                      'rect': _rectToJson(element.boundingBox),
                      'languages': element.recognizedLanguages,
                    },
                ],
              },
          ],
        },
    ];
  }

  Map<String, double> _rectToJson(dynamic rect) {
    return {
      'left': rect.left.toDouble(),
      'top': rect.top.toDouble(),
      'right': rect.right.toDouble(),
      'bottom': rect.bottom.toDouble(),
    };
  }
}
