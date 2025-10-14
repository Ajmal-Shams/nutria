// lib/services/google_service.dart

import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/material.dart';

class GoogleAuthService {
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  /// Auto sign in if user already logged in before
  Future<GoogleSignInAccount?> getCurrentUser() async {
    final user = await _googleSignIn.signInSilently();
    return user;
  }

  /// Performs Google sign-in and saves user data to Django backend
  Future<GoogleSignInAccount?> signInWithGoogle(BuildContext context) async {
    try {
      final user = await _googleSignIn.signIn();
      if (user == null) return null; // cancelled

      await _saveUserToDjango(user, context);
      return user;
    } catch (error) {
      print('Google Sign-In Error: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Google Sign-In failed")),
      );
      return null;
    }
  }

  /// Save Google user data to Django backend
Future<void> _saveUserToDjango(GoogleSignInAccount user, BuildContext context) async {
  const String apiUrl = 'http://10.10.160.214:8000/api/save-user/';

  final response = await http.post(
    Uri.parse(apiUrl),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'name': user.displayName,
      'email': user.email,
      'photoUrl': user.photoUrl,
    }),
  );

  if (response.statusCode == 200) {
    final data = jsonDecode(response.body);
    if (data['status'] == 'created') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("User data saved successfully!")),
      );
    } else if (data['status'] == 'exists') {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Welcome back, ${data['user']['name']}!")),
      );
    }
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Failed to save user!")),
    );
  }
}


  /// Logs out from Google
  Future<void> signOut() async {
    await _googleSignIn.signOut();
  }
}
