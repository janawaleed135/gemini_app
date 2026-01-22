import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/services/ai_service.dart';
import 'presentation/screens/ai_chat_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AIService()),
      ],
      child: MaterialApp(
        title: 'AI Tutor App',
        theme: ThemeData(
          primarySwatch: Colors.purple,
          useMaterial3: true,
        ),
        home: const AIChatScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}