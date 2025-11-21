import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'pages/mapa_page.dart';

import 'firebase_options.dart';
import 'splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // -------------------------------
  // Inicializa Firebase
  // -------------------------------
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // -------------------------------
  // Inicializa Supabase
  // -------------------------------
  await Supabase.initialize(
    url: 'https://bgqfvspxsdetxrnbdlsu.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJncWZ2c3B4c2RldHhybmJkbHN1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjMzMTY0MjksImV4cCI6MjA3ODg5MjQyOX0.vZSlqg7NAo2IM1IGiHzNq43T70hDsgj0CkIB8s5yZrE',
  );

  runApp(const GymApp());
}

class GymApp extends StatelessWidget {
  const GymApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Gym Club',
      theme: ThemeData(
        primarySwatch: Colors.red,
        useMaterial3: true,
      ),
      home: const SplashScreen(),

      // 👇 ADICIONE ISSO
      routes: {
        '/mapa': (context) => const MapaPage(),
      },
    );
  }
}