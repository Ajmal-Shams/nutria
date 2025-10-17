// lib/screens/home/home_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:http/http.dart' as http;
import 'package:nutria/screens/home/add_story_screen.dart';
import 'package:nutria/screens/home/create_post_screen.dart';
import 'package:nutria/screens/home/view_story_screen.dart';
import 'package:nutria/services/home/home_service.dart';
import 'package:nutria/widgets/common/navbar.dart';
import 'package:nutria/widgets/home/post_card.dart';
import 'package:nutria/widgets/home/story_item.dart';

class HomeScreen extends StatefulWidget {
  final GoogleSignInAccount? user;

  const HomeScreen({super.key, this.user});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List posts = [];
  List stories = [];
  bool isLoading = true;
  bool storyLoading = true;

  final String baseUrl = "http://172.20.10.3:8000/api/stories/";

  @override
  void initState() {
    super.initState();
    _fetchPosts();
    _fetchStories();
  }

  Future<void> _fetchPosts() async {
    setState(() => isLoading = true);
    try {
      final String currentUsername = widget.user?.displayName?.trim() ?? 'Unknown';
      final data = await HomeService.fetchPosts(username: currentUsername);
      if (mounted) {
        setState(() {
          posts = data;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to load posts: $e')));
      }
    }
  }

  Future<void> _fetchStories() async {
    setState(() => storyLoading = true);
    try {
      final response = await http.get(Uri.parse(baseUrl));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            stories = data is List ? data : [];
            storyLoading = false;
          });
        }
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() => storyLoading = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed to load stories: $e')));
      }
    }
  }

  Future<void> _likePost(String postId) async {
    final String currentUsername = widget.user?.displayName?.trim() ?? 'Unknown';
    final postIndex = posts.indexWhere((p) => p['post_id'] == postId);
    if (postIndex == -1) return;

    setState(() {
      final currentlyLiked = posts[postIndex]['liked_by_user'] ?? false;
      posts[postIndex]['liked_by_user'] = !currentlyLiked;
      final currentLikes = posts[postIndex]['likes'] ?? 0;
      posts[postIndex]['likes'] = currentlyLiked ? currentLikes - 1 : currentLikes + 1;
    });

    try {
      await HomeService.likePost(postId, currentUsername);
    } catch (e) {
      if (mounted) {
        setState(() {
          final currentlyLiked = posts[postIndex]['liked_by_user'] ?? false;
          posts[postIndex]['liked_by_user'] = !currentlyLiked;
          final currentLikes = posts[postIndex]['likes'] ?? 0;
          posts[postIndex]['likes'] = currentlyLiked ? currentLikes - 1 : currentLikes + 1;
        });
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Action failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final String currentUsername = widget.user?.displayName?.trim() ?? 'Unknown';
    final String? userPhotoUrl = widget.user?.photoUrl;

    Map<String, List<Map<String, dynamic>>> storiesByUser = {};
    for (final story in stories) {
      final username = (story['username'] as String?)?.trim() ?? 'Anonymous';
      storiesByUser.putIfAbsent(username, () => []).add(story);
    }

    final myStories = storiesByUser[currentUsername] ?? [];
    final hasMyStory = myStories.isNotEmpty;
    final otherUsernames =
        storiesByUser.keys.where((name) => name != currentUsername).toList();

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "Nutria",
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          if (widget.user != null)
            IconButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddPostScreen(user: widget.user),
                ),
              ).then((_) => _fetchPosts()),
              icon: const Icon(Icons.add_box_outlined, color: Colors.black),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _fetchPosts();
          await _fetchStories();
        },
        child: ListView.builder(
          itemCount: 1 + posts.length,
          itemBuilder: (context, index) {
            if (index == 0) {
              return SizedBox(
                height: 110,
                child: storyLoading
                    ? const Center(child: CircularProgressIndicator())
                    : ListView.builder(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 12,
                        ),
                        itemCount: 1 + otherUsernames.length,
                        itemBuilder: (context, i) {
                          if (i == 0) {
                            final avatar = myStories.isNotEmpty
                                ? myStories[0]['media_url'] ?? userPhotoUrl
                                : userPhotoUrl;
                            final displayAvatar = avatar ??
                                "https://www.gravatar.com/avatar/placeholder?s=150";

                            return Padding(
                              padding: const EdgeInsets.only(right: 14),
                              child: StoryItem(
                                avatarUrl: displayAvatar,
                                username: "Your Story",
                                hasNew: !hasMyStory,
                                isYourStory: true,
                                onTap: () {
                                  if (widget.user == null) return;

                                  if (hasMyStory) {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ViewStoryScreen(
                                          stories: myStories,
                                          username: currentUsername,
                                          isOwnStory: true,
                                          onAddStory: () {
                                            Navigator.pop(context);
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (_) =>
                                                    AddStoryScreen(user: widget.user),
                                              ),
                                            ).then((result) {
                                              if (result == true) _fetchStories();
                                            });
                                          },
                                        ),
                                      ),
                                    );
                                  } else {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) =>
                                            AddStoryScreen(user: widget.user),
                                      ),
                                    ).then((result) {
                                      if (result == true) _fetchStories();
                                    });
                                  }
                                },
                              ),
                            );
                          }

                          final username = otherUsernames[i - 1];
                          final userStories = storiesByUser[username]!;
                          final avatar = userStories[0]['media_url'] ??
                              userStories[0]['avatar_url'] ??
                              "https://www.gravatar.com/avatar/placeholder?s=150";

                          return Padding(
                            padding: const EdgeInsets.only(right: 14),
                            child: StoryItem(
                              avatarUrl: avatar,
                              username: username,
                              hasNew: true,
                              isYourStory: false,
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ViewStoryScreen(
                                      stories: userStories,
                                      username: username,
                                      isOwnStory: false,
                                    ),
                                  ),
                                );
                              },
                            ),
                          );
                        },
                      ),
              );
            }

            final post = posts[index - 1];
            return PostCard(
              post: post,
              onLike: () => _likePost(post['post_id']),
              onRefresh: _fetchPosts,
              currentUser: widget.user, // ✅ THIS WAS MISSING - NOW ADDED!
            );
          },
        ),
      ),
      bottomNavigationBar: Navbar(index: 0, user: widget.user),
    );
  }
}