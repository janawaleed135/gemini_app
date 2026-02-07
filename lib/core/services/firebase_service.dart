// lib/core/services/firebase_service.dart

import 'package:flutter/foundation.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_remote_config/firebase_remote_config.dart';
import '../../firebase_options.dart';
import 'api_key_manager.dart'; // Import the manager

class FirebaseService {
  static FirebaseService? _instance;
  static FirebaseService get instance => _instance ??= FirebaseService._();
  FirebaseService._();

  Future<bool> initialize() async {
    try {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      
      final remoteConfig = FirebaseRemoteConfig.instance;
      await remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(hours: 1),
      ));

      // Default value is empty string to trigger fallback
      await remoteConfig.setDefaults({'gemini_api_key_list': ''});
      await remoteConfig.fetchAndActivate();

      // 1. FETCH THE LIST STRING
      final keyString = remoteConfig.getString('gemini_api_key_list');
      
      // 2. PARSE AND SEND TO MANAGER
      if (keyString.isNotEmpty && keyString.contains(',')) {
        final keys = keyString.split(',').map((e) => e.trim()).toList();
        // Send valid keys to the manager
        ApiKeyManager.instance.setKeys(keys);
      } else if (keyString.length > 20) {
        // Handle case where it's just one single key
        ApiKeyManager.instance.setKeys([keyString.trim()]);
      }
      
      if (kDebugMode) print('✅ Firebase Service Initialized');
      return true;
    } catch (e) {
      if (kDebugMode) print('❌ Firebase Init Error: $e');
      return false; 
    }
  }
}