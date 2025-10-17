// lib/widgets/post_card.dart
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:nutria/widgets/home/comment_sheet.dart';
import 'package:nutria/screens/profile/user_profile_screen.dart';
import 'package:nutria/services/saved_posts_service.dart';

class PostCard extends StatefulWidget {
  final Map<String, dynamic> post;
  final VoidCallback onLike;
  final VoidCallback onRefresh;
  final GoogleSignInAccount? currentUser;

  const PostCard({
    super.key,
    required this.post,
    required this.onLike,
    required this.onRefresh,
    this.currentUser,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;
  bool? _isSaved;
  bool _isVisible = false;
  bool _wasPlayingBeforeInvisible = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
    _checkSavedStatus();
  }

  Future<void> _checkSavedStatus() async {
    final username = widget.currentUser?.displayName?.trim();
    if (username == null) return;

    final postId = widget.post['post_id'] ?? '';
    if (postId.isEmpty) return;

    try {
      final isSaved = await SavedPostsService.checkSavedStatus(
        postId: postId,
        username: username,
      );
      if (mounted) {
        setState(() => _isSaved = isSaved);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaved = false);
      }
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _initializeVideo() async {
    final mediaUrl = _getMediaUrl();
    if (mediaUrl != null && _isVideoUrl(mediaUrl)) {
      try {
        debugPrint('🎥 Initializing video: $mediaUrl');
        _videoController = VideoPlayerController.network(
          mediaUrl,
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        );

        _videoController!.addListener(() {
          if (_videoController!.value.hasError) {
            debugPrint('❌ Video error: ${_videoController!.value.errorDescription}');
          }
        });

        await _videoController!.initialize();
        await _videoController!.setLooping(true);
        await _videoController!.setVolume(1.0);

        if (mounted) {
          setState(() => _isVideoInitialized = true);
          debugPrint('✅ Video initialized (paused by default)');
        }
      } catch (e, stackTrace) {
        debugPrint('❌ Video initialization error: $e');
        debugPrint('Video URL was: $mediaUrl');
        debugPrint('Stack trace: $stackTrace');
        if (mounted) {
          setState(() => _isVideoInitialized = false);
        }
      }
    }
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    if (!_isVideoInitialized || _videoController == null) return;

    final visiblePercentage = info.visibleFraction * 100;
    
    // Play video when at least 50% is visible
    if (visiblePercentage >= 50) {
      if (!_isVisible) {
        setState(() => _isVisible = true);
        _videoController!.play();
        debugPrint('▶️ Video playing (${visiblePercentage.toStringAsFixed(0)}% visible)');
      }
    } else {
      // Pause when less than 50% visible
      if (_isVisible) {
        setState(() => _isVisible = false);
        _videoController!.pause();
        debugPrint('⏸️ Video paused (${visiblePercentage.toStringAsFixed(0)}% visible)');
      }
    }
  }

  void _toggleVideoPlayback() {
    if (_videoController != null && _isVideoInitialized) {
      setState(() {
        if (_videoController!.value.isPlaying) {
          _videoController!.pause();
        } else {
          _videoController!.play();
        }
      });
    }
  }

  String? _getMediaUrl() => widget.post['media_url'];
  String? _getAvatarUrl() => widget.post['avatar_url'];
  String _getPostId() => widget.post['post_id'] ?? 'unknown';
  List _getComments() => widget.post['comments'] ?? [];

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

  String _getRelativeTime() {
    try {
      final createdAt = widget.post['created_at'];
      if (createdAt == null) return 'Just now';
      
      final postTime = DateTime.parse(createdAt);
      final now = DateTime.now();
      final difference = now.difference(postTime);

      if (difference.inSeconds < 60) {
        return 'Just now';
      } else if (difference.inMinutes < 60) {
        final minutes = difference.inMinutes;
        return '$minutes ${minutes == 1 ? 'minute' : 'minutes'} ago';
      } else if (difference.inHours < 24) {
        final hours = difference.inHours;
        return '$hours ${hours == 1 ? 'hour' : 'hours'} ago';
      } else if (difference.inDays < 7) {
        final days = difference.inDays;
        return '$days ${days == 1 ? 'day' : 'days'} ago';
      } else if (difference.inDays < 30) {
        final weeks = (difference.inDays / 7).floor();
        return '$weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
      } else if (difference.inDays < 365) {
        final months = (difference.inDays / 30).floor();
        return '$months ${months == 1 ? 'month' : 'months'} ago';
      } else {
        final years = (difference.inDays / 365).floor();
        return '$years ${years == 1 ? 'year' : 'years'} ago';
      }
    } catch (e) {
      return 'Just now';
    }
  }

  void _openComments(BuildContext context, String username) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (_) => CommentSheet(
        comments: _getComments(),
        post_id: _getPostId(),
        username: username,
      ),
    ).then((shouldRefresh) {
      if (shouldRefresh == true) widget.onRefresh();
    });
  }

  void _navigateToProfile() {
    final username = widget.post['username'] ?? 'Unknown User';
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => UserProfileScreen(
          username: username,
          currentUser: widget.currentUser,
        ),
      ),
    );
  }

  Future<void> _toggleSave() async {
    final username = widget.currentUser?.displayName?.trim();
    final postId = widget.post['post_id'] ?? '';

    if (username == null || postId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to save post: missing user or post ID')),
      );
      return;
    }

    try {
      final result = await SavedPostsService.toggleSavePost(
        postId: postId,
        username: username,
      );

      if (mounted) {
        setState(() {
          _isSaved = result['is_saved'] ?? !_isSaved!;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_isSaved == true ? 'Post saved!' : 'Post removed from saved'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update save status: $e')),
        );
        setState(() {
          _isSaved = !_isSaved!;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaUrl = _getMediaUrl() ?? '';
    final avatarUrl = _getAvatarUrl() ?? '';
    final isVideo = _isVideoUrl(mediaUrl);
    final isImage = _isImageUrl(mediaUrl);
    final isLiked = widget.post['liked_by_user'] ?? false;

    Widget mediaWidget;

    if (isVideo && _isVideoInitialized && _videoController != null) {
      mediaWidget = GestureDetector(
        onTap: _toggleVideoPlayback,
        child: AspectRatio(
          aspectRatio: _videoController!.value.aspectRatio,
          child: Stack(
            alignment: Alignment.center,
            children: [
              VideoPlayer(_videoController!),
              if (!_videoController!.value.isPlaying)
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(16),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 50,
                  ),
                ),
              Positioned(
                bottom: 10,
                right: 10,
                child: Container(
                  decoration: const BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: Icon(
                      _videoController!.value.volume > 0
                          ? Icons.volume_up
                          : Icons.volume_off,
                      color: Colors.white,
                    ),
                    onPressed: () {
                      setState(() {
                        _videoController!.setVolume(
                          _videoController!.value.volume > 0 ? 0 : 1,
                        );
                      });
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    } else if (isVideo && _videoController != null) {
      mediaWidget = AspectRatio(
        aspectRatio: 16 / 9,
        child: Container(
          color: Colors.black,
          child: const Center(
            child: CircularProgressIndicator(color: Colors.white),
          ),
        ),
      );
    } else if (isVideo) {
      mediaWidget = Container(
        height: 300,
        color: Colors.black,
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.white70, size: 60),
              SizedBox(height: 10),
              Text(
                'Failed to load video',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      );
    } else if (isImage) {
      mediaWidget = SizedBox(
        width: double.infinity,
        height: MediaQuery.of(context).size.width,
        child: Image.network(
          mediaUrl,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              color: Colors.grey[300],
              child: const Center(child: CircularProgressIndicator()),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.grey[300],
              child: const Center(
                child: Icon(Icons.broken_image, size: 60, color: Colors.grey),
              ),
            );
          },
        ),
      );
    } else if (mediaUrl.isNotEmpty) {
      mediaWidget = Container(
        height: 300,
        color: Colors.grey[300],
        child: const Center(child: Text('Unsupported media type')),
      );
    } else {
      mediaWidget = Container(
        height: 300,
        color: Colors.grey[300],
        child: const Center(child: Text('No media available')),
      );
    }

    return VisibilityDetector(
      key: Key('post-${_getPostId()}'),
      onVisibilityChanged: _onVisibilityChanged,
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with clickable profile
            ListTile(
              leading: GestureDetector(
                onTap: _navigateToProfile,
                child: CircleAvatar(
                  radius: 20,
                  backgroundImage: avatarUrl.isNotEmpty
                      ? NetworkImage(avatarUrl)
                      : null,
                  child: avatarUrl.isEmpty
                      ? const Icon(Icons.person, color: Colors.grey, size: 20)
                      : null,
                ),
              ),
              title: GestureDetector(
                onTap: _navigateToProfile,
                child: Text(
                  widget.post['username'] ?? 'Unknown User',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              subtitle: Text(_getRelativeTime()),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              trailing: _isSaved == null
                  ? const SizedBox(width: 24, height: 24)
                  : IconButton(
                      icon: Icon(
                        _isSaved! ? Icons.bookmark : Icons.bookmark_border,
                        color: _isSaved! ? Colors.blue : Colors.grey,
                      ),
                      onPressed: _toggleSave,
                    ),
            ),

            // Media display
            mediaWidget,

            // Action buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    icon: Icon(
                      isLiked ? Icons.favorite : Icons.favorite_border,
                      color: isLiked ? Colors.red : Colors.grey[700],
                    ),
                    onPressed: widget.onLike,
                  ),
                  Text('${widget.post['likes'] ?? 0} likes'),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: const Icon(Icons.comment_outlined, color: Colors.black),
                    onPressed: () => _openComments(
                      context,
                      widget.post['username'] ?? 'Anonymous',
                    ),
                  ),
                  Text('${_getComments().length} comments'),
                ],
              ),
            ),

            // Caption
            if ((widget.post['caption'] ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: RichText(
                  text: TextSpan(
                    style: DefaultTextStyle.of(context).style,
                    children: [
                      WidgetSpan(
                        child: GestureDetector(
                          onTap: _navigateToProfile,
                          child: Text(
                            '${widget.post['username']}: ',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                      ),
                      TextSpan(text: widget.post['caption']),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}