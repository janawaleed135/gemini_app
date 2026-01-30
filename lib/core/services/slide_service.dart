// lib/core/services/slide_service.dart

import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:pdfx/pdfx.dart';
import 'package:path_provider/path_provider.dart';
import '../../data/models/slide_model.dart';

/// Service for managing slide upload and processing
class SlideService extends ChangeNotifier {
  SlideModel? _currentSlideModel;
  int _currentSlideIndex = 0;
  bool _isLoading = false;
  bool _isProcessing = false;
  String _errorMessage = '';
  double _processingProgress = 0.0;
  
  // PDF document reference for display
  PdfDocument? _pdfDocument;

  // ========== Getters ==========
  SlideModel? get currentSlideModel => _currentSlideModel;
  int get currentSlideIndex => _currentSlideIndex;
  bool get isLoading => _isLoading;
  bool get isProcessing => _isProcessing;
  String get errorMessage => _errorMessage;
  bool get hasError => _errorMessage.isNotEmpty;
  double get processingProgress => _processingProgress;
  bool get hasSlides => _currentSlideModel != null && _currentSlideModel!.slides.isNotEmpty;
  int get totalSlides => _currentSlideModel?.totalSlides ?? 0;
  PdfDocument? get pdfDocument => _pdfDocument;
  
  SlideData? get currentSlide {
    if (_currentSlideModel == null || _currentSlideModel!.slides.isEmpty) return null;
    if (_currentSlideIndex >= _currentSlideModel!.slides.length) return null;
    return _currentSlideModel!.slides[_currentSlideIndex];
  }

  // ========== Constants ==========
  static const int maxFileSizeBytes = 50 * 1024 * 1024; // 50MB
  static const List<String> supportedExtensions = ['pdf', 'ppt', 'pptx'];

  // ========== File Picking ==========
  /// Pick a file from the user's device
  Future<fp.PlatformFile?> pickFile() async {
    try {
      _errorMessage = '';
      notifyListeners();

      final result = await fp.FilePicker.platform.pickFiles(
        type: fp.FileType.custom,
        allowedExtensions: supportedExtensions,
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        
        // Validate file size
        if (file.size > maxFileSizeBytes) {
          _errorMessage = 'File too large. Maximum size is 50MB.';
          notifyListeners();
          return null;
        }

        return file;
      }
      return null;
    } catch (e) {
      _errorMessage = 'Error picking file: $e';
      notifyListeners();
      if (kDebugMode) print('❌ Error picking file: $e');
      return null;
    }
  }

  // ========== Load and Process File ==========
  /// Load and process a slide file (PDF or PPTX)
  Future<bool> loadSlideFile(fp.PlatformFile file) async {
    try {
      _isLoading = true;
      _isProcessing = true;
      _processingProgress = 0.0;
      _errorMessage = '';
      notifyListeners();

      if (kDebugMode) print('📂 Loading file: ${file.name}');

      // Get file extension
      final extension = file.extension?.toLowerCase() ?? '';
      final fileType = SlideFileType.fromExtension(extension);

      if (fileType == SlideFileType.unknown) {
        throw Exception('Unsupported file type: $extension');
      }

      // Process based on file type
      List<SlideData> slides = [];
      
      if (fileType == SlideFileType.pdf) {
        slides = await _processPdfFile(file);
      } else if (fileType == SlideFileType.ppt || fileType == SlideFileType.pptx) {
        // For PPTX, we'll show a message that it needs conversion
        // In production, you'd use a server-side conversion
        _errorMessage = 'PowerPoint files require server-side conversion. Please convert to PDF first.';
        _isLoading = false;
        _isProcessing = false;
        notifyListeners();
        return false;
      }

      // Create slide model
      // Note: file.path is not available on web, use empty string
      _currentSlideModel = SlideModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        fileName: file.name,
        filePath: kIsWeb ? '' : (file.path ?? ''),
        fileType: fileType,
        totalSlides: slides.length,
        slides: slides,
        uploadedAt: DateTime.now(),
        fileSizeBytes: file.size,
      );

      _currentSlideIndex = 0;
      _isLoading = false;
      _isProcessing = false;
      _processingProgress = 1.0;
      notifyListeners();

      if (kDebugMode) print('✅ Loaded ${slides.length} slides from ${file.name}');
      return true;
    } catch (e) {
      _errorMessage = 'Error loading file: $e';
      _isLoading = false;
      _isProcessing = false;
      notifyListeners();
      if (kDebugMode) print('❌ Error loading file: $e');
      return false;
    }
  }

  // ========== PDF Processing ==========
  /// Process a PDF file and extract slides as images
  Future<List<SlideData>> _processPdfFile(fp.PlatformFile file) async {
    List<SlideData> slides = [];

    try {
      // Load PDF document
      _pdfDocument = await PdfDocument.openData(file.bytes!);
      final pageCount = _pdfDocument!.pagesCount;

      if (kDebugMode) print('📄 PDF has $pageCount pages');

      // Extract each page as an image
      for (int i = 1; i <= pageCount; i++) {
        _processingProgress = i / pageCount;
        notifyListeners();

        final page = await _pdfDocument!.getPage(i);
        final pageImage = await page.render(
          width: page.width * 2, // 2x for better quality
          height: page.height * 2,
          format: PdfPageImageFormat.png,
        );
        await page.close();

        slides.add(SlideData(
          index: i - 1,
          imageBytes: pageImage?.bytes,
        ));

        if (kDebugMode) print('📊 Processed page $i/$pageCount');
      }
    } catch (e) {
      if (kDebugMode) print('❌ Error processing PDF: $e');
      rethrow;
    }

    return slides;
  }

  // ========== Navigation ==========
  /// Navigate to a specific slide
  void goToSlide(int index) {
    if (_currentSlideModel == null) return;
    if (index < 0 || index >= _currentSlideModel!.slides.length) return;

    _currentSlideIndex = index;
    notifyListeners();

    if (kDebugMode) print('📍 Navigated to slide ${index + 1}/${_currentSlideModel!.slides.length}');
  }

  /// Go to next slide
  void nextSlide() {
    if (_currentSlideModel == null) return;
    if (_currentSlideIndex < _currentSlideModel!.slides.length - 1) {
      goToSlide(_currentSlideIndex + 1);
    }
  }

  /// Go to previous slide
  void previousSlide() {
    if (_currentSlideIndex > 0) {
      goToSlide(_currentSlideIndex - 1);
    }
  }

  // ========== Update Slide Metadata ==========
  /// Update metadata for a specific slide after AI analysis
  void updateSlideMetadata(int index, SlideMetadata metadata) {
    if (_currentSlideModel == null) return;
    if (index < 0 || index >= _currentSlideModel!.slides.length) return;

    final updatedSlides = List<SlideData>.from(_currentSlideModel!.slides);
    updatedSlides[index] = updatedSlides[index].copyWith(
      metadata: metadata,
      isAnalyzed: true,
    );

    _currentSlideModel = _currentSlideModel!.copyWith(slides: updatedSlides);
    notifyListeners();

    if (kDebugMode) print('📝 Updated metadata for slide ${index + 1}');
  }

  // ========== Get Page Image ==========
  /// Get rendered image for a specific page (for thumbnails)
  Future<Uint8List?> getPageThumbnail(int index, {int width = 200}) async {
    if (_pdfDocument == null) return null;
    if (index < 0 || index >= _pdfDocument!.pagesCount) return null;

    try {
      final page = await _pdfDocument!.getPage(index + 1);
      final aspectRatio = page.height / page.width;
      final height = (width * aspectRatio).toInt();
      
      final pageImage = await page.render(
        width: width.toDouble(),
        height: height.toDouble(),
        format: PdfPageImageFormat.png,
      );
      await page.close();
      
      return pageImage?.bytes;
    } catch (e) {
      if (kDebugMode) print('❌ Error getting thumbnail: $e');
      return null;
    }
  }

  // ========== Clear ==========
  /// Clear current slides
  void clearSlides() {
    _currentSlideModel = null;
    _currentSlideIndex = 0;
    _pdfDocument = null;
    _errorMessage = '';
    notifyListeners();

    if (kDebugMode) print('🗑️ Slides cleared');
  }

  // ========== Error Management ==========
  void clearError() {
    _errorMessage = '';
    notifyListeners();
  }

  @override
  void dispose() {
    _pdfDocument = null;
    super.dispose();
  }
}
