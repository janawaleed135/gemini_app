// lib/core/services/firebase_service.dart

import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import '../../firebase_options.dart';

class FirebaseService {
  static FirebaseService? _instance;
  static FirebaseService get instance => _instance ??= FirebaseService._();
  
  FirebaseService._();

  FirebaseRemoteConfig? _remoteConfig;
  bool _isInitialized = false;
  String _cachedApiKey = '';

  bool get isInitialized => _isInitialized;
  String get apiKey => _cachedApiKey;

  /// Initialize Firebase and Remote Config
  Future<bool> initialize() async {
    if (_isInitialized) {
      if (kDebugMode) print('✅ Firebase already initialized');
      return true;
    }

    try {
      if (kDebugMode) print('🔥 Initializing Firebase...');
      
      // Initialize Firebase
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
      
      if (kDebugMode) print('✅ Firebase initialized');

      // Initialize Remote Config
      _remoteConfig = FirebaseRemoteConfig.instance;
      
      // Set config settings
      await _remoteConfig!.setConfigSettings(
        RemoteConfigSettings(
          fetchTimeout: const Duration(seconds: 10),
          minimumFetchInterval: const Duration(hours: 1), // Cache for 1 hour
        ),
      );

      // Set default values (fallback if fetch fails)
      await _remoteConfig!.setDefaults({
        'gemini_api_key': 'AIzaSyBF6f5CFVuAvviKurs9pDd-vdewQyEnZac',
      });

      if (kDebugMode) print('🔄 Fetching Remote Config...');
      
      // Fetch and activate
      await _remoteConfig!.fetchAndActivate();
      
      // Get the API key
      _cachedApiKey = _remoteConfig!.getString('gemini_api_key');
      
      if (kDebugMode) {
        final preview = _cachedApiKey.length > 10 
            ? '${_cachedApiKey.substring(0, 10)}...' 
            : _cachedApiKey;
        print('🔑 API Key loaded: $preview');
      }

      _isInitialized = true;
      
      if (kDebugMode) print('✅ Remote Config initialized');
      return true;
      
    } catch (e) {
      if (kDebugMode) print('❌ Firebase initialization error: $e');
      
      // Use fallback API key on error
      _cachedApiKey = 'AIzaSyBF6f5CFVuAvviKurs9pDd-vdewQyEnZac';
      _isInitialized = true; // Still mark as initialized to continue
      
      return false;
    }
  }

  /// Manually refresh the API key from Remote Config
  Future<void> refreshApiKey() async {
    if (_remoteConfig == null) return;
    
    try {
      await _remoteConfig!.fetchAndActivate();
      _cachedApiKey = _remoteConfig!.getString('gemini_api_key');
      
      if (kDebugMode) {
        print('🔄 API key refreshed from Remote Config');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error refreshing API key: $e');
      }
    }
  }
}