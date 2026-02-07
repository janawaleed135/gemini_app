import 'package:flutter/foundation.dart';

class DocumentKnowledgeService extends ChangeNotifier {
  late String _documentId;
  String _fullText = '';
  final Map<int, String> _slideSummaries = {};
  final Map<int, List<String>> _equations = {};
  final Map<int, String> _imageDescriptions = {};

  bool _isReady = false;

  bool get isReady => _isReady;
  String get fullText => _fullText;
  String get documentId => _documentId;

  void reset() {
    _documentId = '';
    _fullText = '';
    _slideSummaries.clear();
    _equations.clear();
    _imageDescriptions.clear();
    _isReady = false;
  }

  void setDocumentId(String id) {
    _documentId = id;
  }

  void addSlideData({
    required int slideIndex,
    required String summary,
    required List<String> equations,
    required String imageDescription,
  }) {
    _slideSummaries[slideIndex] = summary;
    _equations[slideIndex] = equations;
    _imageDescriptions[slideIndex] = imageDescription;
  }

  void finalizeDocument() {
    final buffer = StringBuffer();
    buffer.writeln('FULL DOCUMENT CONTENT:\n');

    for (final index in _slideSummaries.keys) {
      buffer.writeln('--- Slide ${index + 1} ---');
      buffer.writeln(_slideSummaries[index]);
      if (_equations[index]?.isNotEmpty == true) {
        buffer.writeln('Equations: ${_equations[index]!.join(', ')}');
      }
      buffer.writeln();
    }

    _fullText = buffer.toString();
    _isReady = true;
    notifyListeners();
  }

  String buildPromptContext({int? slideIndex}) {
    if (!_isReady) return '';

    if (slideIndex != null && _slideSummaries.containsKey(slideIndex)) {
      return '''
[DOCUMENT CONTEXT]
Slide ${slideIndex + 1} Summary:
${_slideSummaries[slideIndex]}

Equations:
${_equations[slideIndex]?.join('\n') ?? 'None'}

Image Details:
${_imageDescriptions[slideIndex] ?? 'None'}
''';
    }

    return '''
[DOCUMENT CONTEXT – FULL FILE]
$_fullText
''';
  }
}
