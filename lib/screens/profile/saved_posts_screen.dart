// lib/screens/saved/saved_posts_screen.dart
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:nutria/services/saved_posts_service.dart';
import 'package:nutria/widgets/common/navbar.dart';

class SavedPostsScreen extends StatefulWidget {
  final GoogleSignInAccount? user;

  const SavedPostsScreen({super.key, this.user});

  @override
  State<SavedPostsScreen> createState() => _SavedPostsScreenState();
}

class _SavedPostsScreenState extends State<SavedPostsScreen> {
  List savedPosts = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedPosts();
  }

  Future<void> _loadSavedPosts() async {
    setState(() => isLoading = true);
    try {
      final username = widget.user?.displayName?.trim();
      if (username == null) {
        if (mounted) {
          setState(() => isLoading = false);
        }
        return;
      }

      final posts = await SavedPostsService.getSavedPosts(username);
      if (mounted) {
        setState(() {
          savedPosts = posts;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load saved posts: $e')),
        );
      }
    }
  }

  String? _getMediaUrl(Map<String, dynamic> post) => post['media_url'];

  bool _isVideoUrl(String url) {
    final lower = url.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.avi') ||
        lower.endsWith('.mkv') ||
        lower.endsWith('.webm');
  }

  void _showPostDetail(Map<String, dynamic> post) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              AppBar(
                title: Text(post['username'] ?? 'Post'),
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              
              // Image
              Expanded(
                child: Image.network(
                  post['media_url'] ?? '',
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(child: Icon(Icons.broken_image, size: 60));
                  },
                ),
              ),
              
              // Caption
              if (post['caption'] != null && post['caption'].isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    post['caption'],
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              
              // Stats
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.favorite, color: Colors.red, size: 20),
                    const SizedBox(width: 4),
                    Text('${post['likes'] ?? 0} likes'),
                    const SizedBox(width: 16),
                    const Icon(Icons.comment, color: Colors.grey, size: 20),
                    const SizedBox(width: 4),
                    Text('${(post['comments'] ?? []).length} comments'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'Saved Posts',
          style: TextStyle(color: Colors.black),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        foregroundColor: Colors.black,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : savedPosts.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.bookmark_border,
                        size: 100,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No saved posts yet',
                        style: TextStyle(
                          fontSize: 20,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Save posts to see them here',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey[500],
                        ),
                      ),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _loadSavedPosts,
                  child: GridView.builder(
                    padding: const EdgeInsets.all(2),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 2,
                      mainAxisSpacing: 2,
                    ),
                    itemCount: savedPosts.length,
                    itemBuilder: (context, index) {
                      final post = savedPosts[index];
                      final mediaUrl = _getMediaUrl(post) ?? '';
                      final isVideo = _isVideoUrl(mediaUrl);

                      return GestureDetector(
                        onTap: () => _showPostDetail(post),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            if (mediaUrl.isNotEmpty)
                              Image.network(
                                mediaUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return Container(
                                    color: Colors.grey[300],
                                    child: const Icon(
                                      Icons.broken_image,
                                      color: Colors.grey,
                                    ),
                                  );
                                },
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Container(
                                    color: Colors.grey[300],
                                    child: const Center(
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    ),
                                  );
                                },
                              )
                            else
                              Container(
                                color: Colors.grey[300],
                                child: const Icon(Icons.image, color: Colors.grey),
                              ),

                            // Video indicator
                            if (isVideo)
                              Positioned(
                                top: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Icon(
                                    Icons.play_arrow,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            
                            // Bookmark indicator
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.black54,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Icon(
                                  Icons.bookmark,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
      bottomNavigationBar: Navbar(index: 3, user: widget.user), // Index 3 for saved tab
    );
  }
}