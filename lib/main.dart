// lib/main.dart
import 'package:flutter/material.dart';
import 'package:nutria/screens/auth/login.dart';


void main() => runApp(const RecipeApp());

class RecipeApp extends StatelessWidget {
  const RecipeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Best Match Recipe Finder',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.green),
      home: const GoogleLoginPage(),
    );
  }
}