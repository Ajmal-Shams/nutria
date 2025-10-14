// lib/services/home_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;

class HomeService {
  static const String baseUrl = 'http://10.10.160.214:8000/api';

  // Fetch all posts with username to get like status
  static Future<List<dynamic>> fetchPosts({String? username}) async {
    // Add username as query parameter if provided
    final uri = username != null 
        ? Uri.parse('$baseUrl/posts/').replace(queryParameters: {'username': username})
        : Uri.parse('$baseUrl/posts/');
    
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to load posts: ${response.statusCode}');
    }
  }

  // Like/Unlike a post by post_id
  static Future<Map<String, dynamic>> likePost(String postId, String username) async {
    final response = await http.post(
      Uri.parse('$baseUrl/posts/$postId/like/'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({'username': username}),
    );
    
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Like/Unlike failed: ${response.statusCode}');
    }
  }

  // Add a comment
  static Future<void> addComment({
    required String post_id,
    required String username,
    required String text,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/comments/'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'post': post_id,
        'username': username,
        'text': text,
      }),
    );
    if (response.statusCode != 201) {
      throw Exception('Comment failed: ${response.statusCode}');
    }
  }
}