// lib/services/saved_posts_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class SavedPostsService {
  static const String baseUrl = "http://172.20.10.3:8000/api"; // Update with your URL

  /// Toggle save/unsave a post
  static Future<Map<String, dynamic>> toggleSavePost({
    required String postId,
    required String username,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/toggle-save/'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'post_id': postId,
          'username': username,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Failed to toggle save: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error toggling save: $e');
    }
  }

  /// Get all saved posts for a user
  static Future<List<dynamic>> getSavedPosts(String username) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/saved-posts/$username/'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['saved_posts'] ?? [];
      } else {
        throw Exception('Failed to fetch saved posts: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error fetching saved posts: $e');
    }
  }

  /// Check if a post is saved by a user
  static Future<bool> checkSavedStatus({
    required String postId,
    required String username,
  }) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/check-saved/?post_id=$postId&username=$username'),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['is_saved'] ?? false;
      } else {
        return false;
      }
    } catch (e) {
      return false;
    }
  }
}