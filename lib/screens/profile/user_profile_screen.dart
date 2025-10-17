// lib/screens/profile/user_profile_screen.dart
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:nutria/services/follow_service.dart';
import 'package:nutria/services/home/home_service.dart';

class UserProfileScreen extends StatefulWidget {
  final String username; // The profile being viewed
  final GoogleSignInAccount? currentUser; // Currently logged-in user

  const UserProfileScreen({
    super.key,
    required this.username,
    this.currentUser,
  });

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  bool isLoading = true;
  bool isFollowing = false;
  int followersCount = 0;
  int followingCount = 0;
  int postsCount = 0;
  bool isOwnProfile = false;
  List userPosts = []; // Added to store user's posts
  bool postsLoading = true; // Added to track posts loading

  @override
  void initState() {
    super.initState();
    _loadUserStats();
    _loadUserPosts(); // Added
  }

  Future<void> _loadUserStats() async {
    setState(() => isLoading = true);
    try {
      final currentUsername = widget.currentUser?.displayName?.trim();
      final stats = await FollowService.getUserStats(
        username: widget.username,
        currentUser: currentUsername,
      );

      if (mounted) {
        setState(() {
          followersCount = stats['followers_count'] ?? 0;
          followingCount = stats['following_count'] ?? 0;
          postsCount = stats['posts_count'] ?? 0;
          isFollowing = stats['is_following'] ?? false;
          isOwnProfile = stats['is_own_profile'] ?? false;
          isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load profile: $e')),
        );
      }
    }
  }

  // Added method to load user's posts
  Future<void> _loadUserPosts() async {
    setState(() => postsLoading = true);
    try {
      final allPosts = await HomeService.fetchPosts(
        username: widget.currentUser?.displayName?.trim(),
      );
      
      // Filter posts by the profile username
      final filteredPosts = allPosts.where((post) {
        return post['username']?.trim() == widget.username;
      }).toList();

      if (mounted) {
        setState(() {
          userPosts = filteredPosts;
          postsLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => postsLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load posts: $e')),
        );
      }
    }
  }

  Future<void> _toggleFollow() async {
    final currentUsername = widget.currentUser?.displayName?.trim();
    if (currentUsername == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to follow users')),
      );
      return;
    }

    // Optimistic update
    setState(() {
      isFollowing = !isFollowing;
      followersCount += isFollowing ? 1 : -1;
    });

    try {
      final result = await FollowService.toggleFollow(
        follower: currentUsername,
        following: widget.username,
      );

      if (mounted) {
        setState(() {
          isFollowing = result['is_following'] ?? false;
          followersCount = result['followers_count'] ?? followersCount;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result['message'] ?? 'Success')),
        );
      }
    } catch (e) {
      // Revert on error
      if (mounted) {
        setState(() {
          isFollowing = !isFollowing;
          followersCount += isFollowing ? 1 : -1;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update follow status: $e')),
        );
      }
    }
  }

  void _showFollowersList() async {
    try {
      final followers = await FollowService.getFollowersList(widget.username);
      if (mounted) {
        _showUsernameList(context, 'Followers', followers);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load followers: $e')),
      );
    }
  }

  void _showFollowingList() async {
    try {
      final following = await FollowService.getFollowingList(widget.username);
      if (mounted) {
        _showUsernameList(context, 'Following', following);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load following: $e')),
      );
    }
  }

  void _showUsernameList(BuildContext context, String title, List<String> usernames) {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            if (usernames.isEmpty)
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text('No users to show'),
              )
            else
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: usernames.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      leading: const CircleAvatar(
                        child: Icon(Icons.person),
                      ),
                      title: Text(usernames[index]),
                      onTap: () {
                        Navigator.pop(context);
                        if (usernames[index] != widget.username) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => UserProfileScreen(
                                username: usernames[index],
                                currentUser: widget.currentUser,
                              ),
                            ),
                          );
                        }
                      },
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }

  String? _getMediaUrl(Map<String, dynamic> post) => post['media_url'];

  bool _isImageUrl(String url) {
    final lower = url.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp');
  }

  bool _isVideoUrl(String url) {
    final lower = url.toLowerCase();
    return lower.endsWith('.mp4') ||
        lower.endsWith('.mov') ||
        lower.endsWith('.avi') ||
        lower.endsWith('.mkv') ||
        lower.endsWith('.webm');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.username),
        backgroundColor: Colors.white,
        elevation: 0.5,
        foregroundColor: Colors.black,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: () async {
                await _loadUserStats();
                await _loadUserPosts();
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  // Profile Header
                  SliverToBoxAdapter(
                    child: Column(
                      children: [
                        const SizedBox(height: 20),
                        
                        // Profile Picture
                        CircleAvatar(
                          radius: 50,
                          backgroundImage: widget.currentUser?.photoUrl != null
                              ? NetworkImage(widget.currentUser!.photoUrl!)
                              : null,
                          child: widget.currentUser?.photoUrl == null
                              ? const Icon(Icons.person, size: 50)
                              : null,
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Username
                        Text(
                          widget.username,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Stats Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _buildStatColumn('Posts', postsCount, null),
                            _buildStatColumn('Followers', followersCount, _showFollowersList),
                            _buildStatColumn('Following', followingCount, _showFollowingList),
                          ],
                        ),
                        
                        const SizedBox(height: 20),
                        
                        // Follow/Edit Button
                        if (!isOwnProfile)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 50),
                            child: SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: _toggleFollow,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isFollowing ? Colors.grey[300] : Colors.blue,
                                  foregroundColor: isFollowing ? Colors.black : Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: Text(isFollowing ? 'Following' : 'Follow'),
                              ),
                            ),
                          ),
                        
                        if (isOwnProfile)
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 50),
                            child: SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: () {
                                  // Navigate to edit profile
                                },
                                style: OutlinedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text('Edit Profile'),
                              ),
                            ),
                          ),
                        
                        const SizedBox(height: 30),
                        const Divider(height: 1),
                      ],
                    ),
                  ),
                  
                  // Posts Grid
                  if (postsLoading)
                    const SliverFillRemaining(
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (userPosts.isEmpty)
                    const SliverFillRemaining(
                      child: Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.photo_library_outlined, size: 80, color: Colors.grey),
                            SizedBox(height: 16),
                            Text(
                              'No posts yet',
                              style: TextStyle(fontSize: 18, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.all(2),
                      sliver: SliverGrid(
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 2,
                          mainAxisSpacing: 2,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final post = userPosts[index];
                            final mediaUrl = _getMediaUrl(post) ?? '';
                            final isVideo = _isVideoUrl(mediaUrl);
                            
                            return GestureDetector(
                              onTap: () {
                                // Navigate to post detail or show dialog
                                _showPostDetail(post);
                              },
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
                                ],
                              ),
                            );
                          },
                          childCount: userPosts.length,
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
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

  Widget _buildStatColumn(String label, int count, VoidCallback? onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Text(
            count.toString(),
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }
}