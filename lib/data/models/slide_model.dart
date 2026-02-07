// lib/data/models/slide_model.dart

import 'dart:typed_data';

/// Represents the entire slide deck
class SlideModel {
  final String id;
  final String fileName;
  final String filePath;
  final SlideFileType fileType;
  final int totalSlides;
  final List<SlideData> slides;
  final DateTime uploadedAt;
  final int fileSizeBytes;
  final bool isAnalyzed;


  SlideModel({
    required this.id,
    required this.fileName,
    required this.filePath,
    required this.fileType,
    required this.totalSlides,
    required this.slides,
    required this.uploadedAt,
    required this.fileSizeBytes,
    required this.isAnalyzed,
  });

  SlideModel copyWith({
    String? id,
    String? fileName,
    String? filePath,
    SlideFileType? fileType,
    int? totalSlides,
    List<SlideData>? slides,
    DateTime? uploadedAt,
    int? fileSizeBytes,
    bool? isAnalyzed,
  }) {
    return SlideModel(
      id: id ?? this.id,
      fileName: fileName ?? this.fileName,
      filePath: filePath ?? this.filePath,
      fileType: fileType ?? this.fileType,
      totalSlides: totalSlides ?? this.totalSlides,
      slides: slides ?? this.slides,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      isAnalyzed: isAnalyzed ?? this.isAnalyzed,
    );
  }

  /// Get file size in human readable format
  String get formattedFileSize {
    if (fileSizeBytes < 1024) return '$fileSizeBytes B';
    if (fileSizeBytes < 1024 * 1024) return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Get the title of the slide deck (from fileName)
  String get title => fileName;

  /// Check if slide has a title
  bool get hasTitle => fileName.isNotEmpty;

  /// Get image bytes from the first slide if available
  Uint8List? get imageBytes {
    if (slides.isNotEmpty && slides[0].imageBytes != null) {
      return slides[0].imageBytes;
    }
    return null;
  }
}

/// Individual slide data
class SlideData {
  final int index;
  final Uint8List? imageBytes;
  final String? imagePath;
  final SlideMetadata? metadata;
  final bool isAnalyzed;

  SlideData({
    required this.index,
    this.imageBytes,
    this.imagePath,
    this.metadata,
    this.isAnalyzed = false,
  });

  SlideData copyWith({
    int? index,
    Uint8List? imageBytes,
    String? imagePath,
    SlideMetadata? metadata,
    bool? isAnalyzed,
  }) {
    return SlideData(
      index: index ?? this.index,
      imageBytes: imageBytes ?? this.imageBytes,
      imagePath: imagePath ?? this.imagePath,
      metadata: metadata ?? this.metadata,
      isAnalyzed: isAnalyzed ?? this.isAnalyzed,
    );
  }
}

/// Slide analysis metadata from Gemini Vision
class SlideMetadata {
  final String extractedText;
  final List<String> keyConcepts;
  final String? diagramDescription;
  final String? formulaExplanation;
  final String educationalSummary;
  final List<String> suggestedQuestions;
  final DateTime analyzedAt;

  SlideMetadata({
    required this.extractedText,
    required this.keyConcepts,
    this.diagramDescription,
    this.formulaExplanation,
    required this.educationalSummary,
    required this.suggestedQuestions,
    required this.analyzedAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'extractedText': extractedText,
      'keyConcepts': keyConcepts,
      'diagramDescription': diagramDescription,
      'formulaExplanation': formulaExplanation,
      'educationalSummary': educationalSummary,
      'suggestedQuestions': suggestedQuestions,
      'analyzedAt': analyzedAt.toIso8601String(),
    };
  }

  factory SlideMetadata.fromJson(Map<String, dynamic> json) {
    return SlideMetadata(
      extractedText: json['extractedText'] as String,
      keyConcepts: List<String>.from(json['keyConcepts'] as List),
      diagramDescription: json['diagramDescription'] as String?,
      formulaExplanation: json['formulaExplanation'] as String?,
      educationalSummary: json['educationalSummary'] as String,
      suggestedQuestions: List<String>.from(json['suggestedQuestions'] as List),
      analyzedAt: DateTime.parse(json['analyzedAt'] as String),
    );
  }

  /// Get a formatted context string for AI prompts
  String toContextString() {
    final buffer = StringBuffer();
    buffer.writeln('=== SLIDE CONTENT ===');
    buffer.writeln('Text: $extractedText');
    if (keyConcepts.isNotEmpty) {
      buffer.writeln('Key Concepts: ${keyConcepts.join(", ")}');
    }
    if (diagramDescription != null) {
      buffer.writeln('Diagram: $diagramDescription');
    }
    if (formulaExplanation != null) {
      buffer.writeln('Formulas: $formulaExplanation');
    }
    buffer.writeln('Summary: $educationalSummary');
    buffer.writeln('====================');
    return buffer.toString();
  }
}

/// File type enum
enum SlideFileType {
  pdf,
  ppt,
  pptx,
  unknown;

  static SlideFileType fromExtension(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return SlideFileType.pdf;
      case 'ppt':
        return SlideFileType.ppt;
      case 'pptx':
        return SlideFileType.pptx;
      default:
        return SlideFileType.unknown;
    }
  }

  String get displayName {
    switch (this) {
      case SlideFileType.pdf:
        return 'PDF';
      case SlideFileType.ppt:
        return 'PowerPoint';
      case SlideFileType.pptx:
        return 'PowerPoint';
      case SlideFileType.unknown:
        return 'Unknown';
    }
  }
}
