// lib/core/services/slide_service.dart

import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart' as fp;
import 'package:pdfx/pdfx.dart';
import '../../data/models/slide_model.dart';

class SlideService extends ChangeNotifier {
  SlideModel? _currentSlideModel;
  Uint8List? _rawFileBytes; // Stores the PDF bytes for the AI
  String? _mimeType;
  
  int _currentSlideIndex = 0;
  bool _isLoading = false;
  String _errorMessage = '';
  double _processingProgress = 0.0;
  
  // Getters
  SlideModel? get currentSlideModel => _currentSlideModel;
  Uint8List? get rawFileBytes => _rawFileBytes;
  String? get mimeType => _mimeType;
  int get currentSlideIndex => _currentSlideIndex;
  bool get isLoading => _isLoading;
  String get errorMessage => _errorMessage;
  double get processingProgress => _processingProgress;
  
  bool get hasSlides => _currentSlideModel != null && _currentSlideModel!.slides.isNotEmpty;
  int get totalSlides => _currentSlideModel?.totalSlides ?? 0;
  
  SlideData? get currentSlide {
    if (_currentSlideModel == null || _currentSlideModel!.slides.isEmpty) return null;
    if (_currentSlideIndex >= _currentSlideModel!.slides.length) return null;
    return _currentSlideModel!.slides[_currentSlideIndex];
  }

  // ========== Pick and Load File ==========
  Future<bool> pickFile() async {
    try {
      _errorMessage = '';
      _isLoading = true;
      notifyListeners();

      // Pick file (PDF)
      final result = await fp.FilePicker.platform.pickFiles(
        type: fp.FileType.custom,
        allowedExtensions: ['pdf'], 
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        
        // 1. Store Raw Bytes for AI (Crucial for "Seeing" the PDF)
        _rawFileBytes = file.bytes;
        _mimeType = 'application/pdf'; 

        // 2. Process for UI Display
        return await _processPdfForUI(file);
      }
      
      _isLoading = false;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Error picking file: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> _processPdfForUI(fp.PlatformFile file) async {
    try {
      _processingProgress = 0.0;
      notifyListeners();

      final document = await PdfDocument.openData(file.bytes!);
      final pageCount = document.pagesCount;
      List<SlideData> slides = [];

      // Render thumbnails for UI only
      for (int i = 1; i <= pageCount; i++) {
        _processingProgress = i / pageCount;
        notifyListeners(); 

        final page = await document.getPage(i);
        final pageImage = await page.render(
          width: page.width, 
          height: page.height,
          format: PdfPageImageFormat.png
        );
        await page.close();
        
        slides.add(SlideData(
          index: i-1, 
          imageBytes: pageImage?.bytes,
          isAnalyzed: false, // Required param fixed
        ));
      }

      await document.close();

      _currentSlideModel = SlideModel(
        id: DateTime.now().toString(),
        fileName: file.name,
        filePath: kIsWeb ? '' : (file.path ?? ''),
        fileType: SlideFileType.pdf,
        totalSlides: pageCount,
        slides: slides,
        uploadedAt: DateTime.now(),
        fileSizeBytes: file.size,
        isAnalyzed: false,
      );

      _currentSlideIndex = 0;
      _isLoading = false;
      notifyListeners();
      return true;

    } catch (e) {
      _errorMessage = "Failed to process PDF for display: $e";
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void goToSlide(int index) {
    if (_currentSlideModel == null) return;
    if (index >= 0 && index < totalSlides) {
      _currentSlideIndex = index;
      notifyListeners();
    }
  }
  
  void clearSlides() {
    _currentSlideModel = null;
    _rawFileBytes = null;
    _currentSlideIndex = 0;
    notifyListeners();
  }
}