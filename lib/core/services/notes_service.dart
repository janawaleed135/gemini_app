// lib/core/services/notes_service.dart

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class NotesService extends ChangeNotifier {
  final SharedPreferences _prefs;
  
  // Map of documentId -> Map of slideIndex -> note content
  Map<String, Map<int, String>> _documentNotes = {};
  
  // Current document being viewed
  String? _currentDocumentId;
  
  NotesService(this._prefs) {
    _loadAllNotes();
  }
  
  // ========== Getters ==========
  
  /// Get note for specific slide in current document
  String? getNoteForSlide(int slideIndex) {
    if (_currentDocumentId == null) return null;
    return _documentNotes[_currentDocumentId!]?[slideIndex];
  }
  
  /// Check if slide has a note
  bool hasNoteForSlide(int slideIndex) {
    if (_currentDocumentId == null) return false;
    final note = _documentNotes[_currentDocumentId!]?[slideIndex];
    return note != null && note.isNotEmpty;
  }
  
  /// Get all notes for current document
  Map<int, String> getAllNotesForCurrentDocument() {
    if (_currentDocumentId == null) return {};
    return Map.from(_documentNotes[_currentDocumentId!] ?? {});
  }
  
  /// Get total count of notes for current document
  int getNotesCount() {
    if (_currentDocumentId == null) return 0;
    return _documentNotes[_currentDocumentId!]?.length ?? 0;
  }
  
  // ========== Setters ==========
  
  /// Set current document
  void setCurrentDocument(String documentId) {
    _currentDocumentId = documentId;
    if (!_documentNotes.containsKey(documentId)) {
      _documentNotes[documentId] = {};
    }
    notifyListeners();
  }
  
  /// Save note for a slide
  Future<void> saveNoteForSlide(int slideIndex, String note) async {
    if (_currentDocumentId == null) return;
    
    if (!_documentNotes.containsKey(_currentDocumentId!)) {
      _documentNotes[_currentDocumentId!] = {};
    }
    
    if (note.trim().isEmpty) {
      // Remove note if empty
      _documentNotes[_currentDocumentId!]!.remove(slideIndex);
    } else {
      // Save note
      _documentNotes[_currentDocumentId!]![slideIndex] = note.trim();
    }
    
    await _saveAllNotes();
    notifyListeners();
  }
  
  /// Delete note for a slide
  Future<void> deleteNoteForSlide(int slideIndex) async {
    if (_currentDocumentId == null) return;
    
    _documentNotes[_currentDocumentId!]?.remove(slideIndex);
    await _saveAllNotes();
    notifyListeners();
  }
  
  /// Clear all notes for current document
  Future<void> clearNotesForDocument() async {
    if (_currentDocumentId == null) return;
    
    _documentNotes[_currentDocumentId!]?.clear();
    await _saveAllNotes();
    notifyListeners();
  }
  
  /// Clear all notes for all documents
  Future<void> clearAllNotes() async {
    _documentNotes.clear();
    await _saveAllNotes();
    notifyListeners();
  }
  
  // ========== Persistence ==========
  
  Future<void> _saveAllNotes() async {
    try {
      // Convert to JSON-serializable format
      final Map<String, Map<String, String>> jsonData = {};
      
      _documentNotes.forEach((docId, notesMap) {
        jsonData[docId] = notesMap.map(
          (slideIndex, note) => MapEntry(slideIndex.toString(), note)
        );
      });
      
      final jsonString = jsonEncode(jsonData);
      await _prefs.setString('student_notes', jsonString);
      
      if (kDebugMode) {
        print('💾 Saved notes to storage');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error saving notes: $e');
      }
    }
  }
  
  Future<void> _loadAllNotes() async {
    try {
      final jsonString = _prefs.getString('student_notes');
      if (jsonString == null || jsonString.isEmpty) {
        _documentNotes = {};
        return;
      }
      
      final Map<String, dynamic> jsonData = jsonDecode(jsonString);
      _documentNotes = {};
      
      jsonData.forEach((docId, notesMap) {
        final Map<int, String> parsedNotes = {};
        (notesMap as Map<String, dynamic>).forEach((slideIndexStr, note) {
          parsedNotes[int.parse(slideIndexStr)] = note as String;
        });
        _documentNotes[docId] = parsedNotes;
      });
      
      if (kDebugMode) {
        print('📂 Loaded notes from storage');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error loading notes: $e');
      }
      _documentNotes = {};
    }
  }
  
  /// Export all notes for current document as formatted text
  String exportNotesForDocument() {
    if (_currentDocumentId == null) return '';
    
    final notes = _documentNotes[_currentDocumentId!];
    if (notes == null || notes.isEmpty) return 'No notes available.';
    
    final buffer = StringBuffer();
    buffer.writeln('📚 STUDY NOTES');
    buffer.writeln('Document: $_currentDocumentId');
    buffer.writeln('Generated: ${DateTime.now().toString().split('.')[0]}');
    buffer.writeln('${'=' * 50}\n');
    
    final sortedKeys = notes.keys.toList()..sort();
    for (final slideIndex in sortedKeys) {
      buffer.writeln('📄 Slide ${slideIndex + 1}');
      buffer.writeln('-' * 50);
      buffer.writeln(notes[slideIndex]);
      buffer.writeln();
    }
    
    return buffer.toString();
  }
}