// lib/widgets/navbar.dart (or wherever Navbar is defined)
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:nutria/screens/auth/login.dart';
import 'package:nutria/screens/home/add_story_screen.dart';
import 'package:nutria/screens/home/home_screen.dart';
import 'package:nutria/screens/profile/saved_posts_screen.dart';
import 'package:nutria/screens/recipe/recipe_search_screen.dart';
import 'package:nutria/services/auth/google_service.dart'; // 👈 Import auth service

class Navbar extends StatefulWidget {
  final int index;
  final GoogleSignInAccount? user; // 👈 Pass current user

  const Navbar({
    super.key,
    this.index = 0,
    this.user,
  });

  @override
  State<Navbar> createState() => _NavbarState();
}

class _NavbarState extends State<Navbar> {
  late int _selectedIndex;
  final GoogleAuthService _authService = GoogleAuthService(); // Auth instance

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.index;
  }

  void _onItemTapped(int index) {
    if (index == 3) {
      // 👉 Handle Profile tab: LOG OUT + go to login
      _handleLogoutAndNavigate();
      return;
    }

    if (index == _selectedIndex) return;

    setState(() => _selectedIndex = index);

    // Navigate to other screens
    Widget selectedScreen;
    switch (index) {
      case 0:
        selectedScreen = HomeScreen(user: widget.user);
        break;
      case 1:
        selectedScreen =  RecipeSearchScreen(user: widget.user);
        break;
      case 2:
        selectedScreen = SavedPostsScreen(user: widget.user);
        break;
      default:
        selectedScreen = HomeScreen(user: widget.user);
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => selectedScreen),
    );
  }

  Future<void> _handleLogoutAndNavigate() async {
    // Show confirmation dialog (optional but recommended)
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Log Out"),
        content: const Text("Are you sure you want to log out?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Log Out", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // Perform sign-out
      await _authService.signOut();

      // Navigate to login page (clear all previous screens)
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const GoogleLoginPage()),
        (route) => false, // Remove all routes
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: _selectedIndex,
      onTap: _onItemTapped,
      type: BottomNavigationBarType.fixed,
      selectedItemColor: Colors.blueAccent,
      unselectedItemColor: Colors.grey,
      showUnselectedLabels: false,
      showSelectedLabels: false,
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home),
          label: 'Home',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.search_outlined),
          activeIcon: Icon(Icons.search),
          label: 'Search',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.add_box_outlined),
          activeIcon: Icon(Icons.add_box),
          label: 'Add',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          activeIcon: Icon(Icons.person),
          label: 'Profile',
        ),
      ],
    );
  }
}