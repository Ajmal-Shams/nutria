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

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  List posts = [];
  List stories = [];
  bool isLoading = true;
  bool storyLoading = true;

  final String baseUrl = "http://172.20.10.3:8000/api/stories/";

  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
    _fetchPosts();
    _fetchStories();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
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
        _showCustomSnackBar('Failed to load posts: $e', isError: true);
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
        _showCustomSnackBar('Failed to load stories: $e', isError: true);
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
        _showCustomSnackBar('Action failed: $e', isError: true);
      }
    }
  }

  void _showCustomSnackBar(String message, {required bool isError}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? Colors.red.shade700 : const Color(0xFF8B5E3C),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
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
      backgroundColor: const Color(0xFFF5E8C7),
      appBar: AppBar(
        title: const Text(
          "Nutria",
          style: TextStyle(
            color: Color(0xFF8B5E3C),
            fontWeight: FontWeight.bold,
            fontSize: 24,
            letterSpacing: 0.5,
          ),
        ),
        backgroundColor: const Color(0xFFF5E8C7),
        elevation: 0,
        actions: [
          if (widget.user != null)
            Container(
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF8B5E3C), Color(0xFF6D4A2F)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B5E3C).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AddPostScreen(user: widget.user),
                    ),
                  ).then((_) => _fetchPosts()),
                  borderRadius: BorderRadius.circular(12),
                  child: const Padding(
                    padding: EdgeInsets.all(10),
                    child: Icon(Icons.add_box_outlined, color: Colors.white, size: 24),
                  ),
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _fetchPosts();
          await _fetchStories();
        },
        color: const Color(0xFF8B5E3C),
        backgroundColor: const Color(0xFFF5E8C7),
        child: ListView.builder(
          itemCount: 1 + posts.length,
          itemBuilder: (context, index) {
            if (index == 0) {
              return Column(
                children: [
                  // Stories Section
                  Container(
                    height: 120,
                    margin: const EdgeInsets.only(top: 8, bottom: 12),
                    child: storyLoading
                        ? _buildStoryLoadingShimmer()
                        : ListView.builder(
                            scrollDirection: Axis.horizontal,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
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
                  ),
                  // Divider
                  Container(
                    height: 8,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF8B5E3C).withOpacity(0.05),
                          const Color(0xFF8B5E3C).withOpacity(0.02),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            }

            // Posts Section
            if (isLoading) {
              return _buildPostLoadingShimmer();
            }

            if (posts.isEmpty) {
              return _buildEmptyPostsState();
            }

            final post = posts[index - 1];
            return PostCard(
              post: post,
              onLike: () => _likePost(post['post_id']),
              onRefresh: _fetchPosts,
              currentUser: widget.user,
            );
          },
        ),
      ),
      bottomNavigationBar: Navbar(index: 0, user: widget.user),
    );
  }

  Widget _buildStoryLoadingShimmer() {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: 5,
          itemBuilder: (context, index) {
            return Padding(
              padding: const EdgeInsets.only(right: 14),
              child: Column(
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white,
                          const Color(0xFF8B5E3C).withOpacity(0.1),
                          Colors.white,
                        ],
                        stops: [
                          _shimmerController.value - 0.3,
                          _shimmerController.value,
                          _shimmerController.value + 0.3,
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    width: 60,
                    height: 12,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(6),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white,
                          const Color(0xFF8B5E3C).withOpacity(0.1),
                          Colors.white,
                        ],
                        stops: [
                          _shimmerController.value - 0.3,
                          _shimmerController.value,
                          _shimmerController.value + 0.3,
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildPostLoadingShimmer() {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8B5E3C).withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header shimmer
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            Colors.white,
                            const Color(0xFF8B5E3C).withOpacity(0.1),
                            Colors.white,
                          ],
                          stops: [
                            _shimmerController.value - 0.3,
                            _shimmerController.value,
                            _shimmerController.value + 0.3,
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 120,
                            height: 14,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(7),
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white,
                                  const Color(0xFF8B5E3C).withOpacity(0.1),
                                  Colors.white,
                                ],
                                stops: [
                                  _shimmerController.value - 0.3,
                                  _shimmerController.value,
                                  _shimmerController.value + 0.3,
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: 80,
                            height: 10,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(5),
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white,
                                  const Color(0xFF8B5E3C).withOpacity(0.1),
                                  Colors.white,
                                ],
                                stops: [
                                  _shimmerController.value - 0.3,
                                  _shimmerController.value,
                                  _shimmerController.value + 0.3,
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Image shimmer
              Container(
                width: double.infinity,
                height: 300,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white,
                      const Color(0xFF8B5E3C).withOpacity(0.1),
                      Colors.white,
                    ],
                    stops: [
                      _shimmerController.value - 0.3,
                      _shimmerController.value,
                      _shimmerController.value + 0.3,
                    ],
                  ),
                ),
              ),
              // Bottom shimmer
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                Colors.white,
                                const Color(0xFF8B5E3C).withOpacity(0.1),
                                Colors.white,
                              ],
                              stops: [
                                _shimmerController.value - 0.3,
                                _shimmerController.value,
                                _shimmerController.value + 0.3,
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                Colors.white,
                                const Color(0xFF8B5E3C).withOpacity(0.1),
                                Colors.white,
                              ],
                              stops: [
                                _shimmerController.value - 0.3,
                                _shimmerController.value,
                                _shimmerController.value + 0.3,
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      height: 12,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        gradient: LinearGradient(
                          colors: [
                            Colors.white,
                            const Color(0xFF8B5E3C).withOpacity(0.1),
                            Colors.white,
                          ],
                          stops: [
                            _shimmerController.value - 0.3,
                            _shimmerController.value,
                            _shimmerController.value + 0.3,
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyPostsState() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF8B5E3C).withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF8B5E3C).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.photo_library_outlined,
              size: 64,
              color: const Color(0xFF8B5E3C).withOpacity(0.6),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Posts Yet',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF8B5E3C),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Be the first to share something!',
            style: TextStyle(
              fontSize: 15,
              color: const Color(0xFF8B5E3C).withOpacity(0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}