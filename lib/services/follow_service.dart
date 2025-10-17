// lib/services/follow_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class FollowService {
  static const String baseUrl = "http://172.20.10.3:8000/api"; // Update with your URL

  /// Toggle follow/unfollow a user
  static Future<Map<String, dynamic>> toggleFollow({
    required String follower,
    required String following,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/toggle-follow/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'follower': follower,
          'following': following,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to toggle follow: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error toggling follow: $e');
    }
  }

  /// Get user statistics (followers, following, posts count)
  static Future<Map<String, dynamic>> getUserStats({
    required String username,
    String? currentUser,
  }) async {
    try {
      String url = '$baseUrl/user-stats/$username/';
      if (currentUser != null) {
        url += '?current_user=$currentUser';
      }

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to fetch user stats: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching user stats: $e');
    }
  }

  /// Get list of followers
  static Future<List<String>> getFollowersList(String username) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/followers/$username/'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<String>.from(data['followers'] ?? []);
      } else {
        throw Exception('Failed to fetch followers: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching followers: $e');
    }
  }

  /// Get list of users this user is following
  static Future<List<String>> getFollowingList(String username) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/following/$username/'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<String>.from(data['following'] ?? []);
      } else {
        throw Exception('Failed to fetch following: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching following: $e');
    }
  }

  /// Check if one user follows another
  static Future<bool> checkFollowStatus({
    required String follower,
    required String following,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/check-follow/?follower=$follower&following=$following'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['is_following'] ?? false;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }
}