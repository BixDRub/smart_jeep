import 'package:flutter/material.dart';
import 'test_map.dart';
import 'intro.dart';

//main file. Just runs the app, nothing special here
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'TransitLink',
      home: const IntroScreen(),
      routes: {
        '/home': (context) => const TestMap(),
        '/dev': (context) => const TestMap(),
      },
    );
  }
}