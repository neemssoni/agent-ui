import 'package:flutter/material.dart';
import 'package:cards_agent_app/services/agui_client.dart';
import 'package:cards_agent_app/ui/main_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  void main() {
  // Add this line first:
  WidgetsFlutterBinding.ensureInitialized();
  
  runApp(const MyApp());
}

  @override
  Widget build(BuildContext context) {
    final aguiClient = AgUiClient(baseUrl: 'http://127.0.0.1:8080');

    return MaterialApp(
      title: 'Cards Agent',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: MainBankingScreen(client: aguiClient),
    );
  }
}