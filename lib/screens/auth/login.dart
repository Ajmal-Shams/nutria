// lib/screens/login.dart

import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:nutria/screens/home/home_screen.dart';
import 'package:nutria/services/auth/google_service.dart';


class GoogleLoginPage extends StatefulWidget {
  const GoogleLoginPage({super.key});

  @override
  State<GoogleLoginPage> createState() => _GoogleLoginPageState();
}

class _GoogleLoginPageState extends State<GoogleLoginPage> {
  final GoogleAuthService _authService = GoogleAuthService();
  GoogleSignInAccount? _user;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _checkExistingUser();
  }

  /// Check if user already signed in before
  Future<void> _checkExistingUser() async {
    final existingUser = await _authService.getCurrentUser();
    if (existingUser != null) {
      setState(() {
        _user = existingUser;
      });
      // Navigate to HomeScreen if already logged in
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => HomeScreen(user: existingUser)),
        );
      });
    }
    setState(() => _isLoading = false);
  }

  Future<void> _handleGoogleSignIn() async {
    final user = await _authService.signInWithGoogle(context);
    if (user != null) {
      // Navigate to HomeScreen on successful login
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => HomeScreen(user: user)),
      );
    }
  }

  Future<void> _handleLogout() async {
    await _authService.signOut();
    setState(() => _user = null);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Google Login Example")),
      body: Center(
        child: _user == null
            ? ElevatedButton.icon(
                icon: const Icon(Icons.login),
                label: const Text("Login with Google"),
                onPressed: _handleGoogleSignIn,
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    backgroundImage: NetworkImage(_user!.photoUrl ?? ''),
                    radius: 40,
                  ),
                  const SizedBox(height: 10),
                  Text("Welcome back, ${_user!.displayName}!"),
                  Text(_user!.email),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: _handleLogout,
                    child: const Text("Logout"),
                  ),
                ],
              ),
      ),
    );
  }
}