// lib/widgets/home/post_card.dart
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
    
    if (visiblePercentage >= 50) {
      if (!_isVisible) {
        setState(() => _isVisible = true);
        _videoController!.play();
        debugPrint('▶️ Video playing (${visiblePercentage.toStringAsFixed(0)}% visible)');
      }
    } else {
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
      backgroundColor: Colors.transparent,
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
      _showCustomSnackBar('Unable to save post: missing user or post ID', isError: true);
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

        _showCustomSnackBar(
          _isSaved == true ? 'Post saved!' : 'Post removed from saved',
          isError: false,
        );
      }
    } catch (e) {
      if (mounted) {
        _showCustomSnackBar('Failed to update save status: $e', isError: true);
        setState(() {
          _isSaved = !_isSaved!;
        });
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
        duration: const Duration(seconds: 2),
      ),
    );
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
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5E3C).withOpacity(0.9),
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8B5E3C).withOpacity(0.4),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
                    size: 56,
                  ),
                ),
              Positioned(
                bottom: 16,
                right: 16,
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          _videoController!.setVolume(
                            _videoController!.value.volume > 0 ? 0 : 1,
                          );
                        });
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Icon(
                          _videoController!.value.volume > 0
                              ? Icons.volume_up_rounded
                              : Icons.volume_off_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
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
          color: Colors.black87,
          child: Center(
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5E3C).withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const CircularProgressIndicator(
                color: Color(0xFF8B5E3C),
                strokeWidth: 3,
              ),
            ),
          ),
        ),
      );
    } else if (isVideo) {
      mediaWidget = Container(
        height: 300,
        color: Colors.black87,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  color: Colors.white70,
                  size: 48,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Failed to load video',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
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
              color: const Color(0xFFF5E8C7).withOpacity(0.3),
              child: Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                  color: const Color(0xFF8B5E3C),
                  strokeWidth: 3,
                ),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: const Color(0xFFF5E8C7).withOpacity(0.3),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.broken_image_rounded,
                      size: 64,
                      color: const Color(0xFF8B5E3C).withOpacity(0.4),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Failed to load image',
                      style: TextStyle(
                        color: const Color(0xFF8B5E3C).withOpacity(0.6),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    } else if (mediaUrl.isNotEmpty) {
      mediaWidget = Container(
        height: 300,
        color: const Color(0xFFF5E8C7).withOpacity(0.3),
        child: Center(
          child: Text(
            'Unsupported media type',
            style: TextStyle(
              color: const Color(0xFF8B5E3C).withOpacity(0.6),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    } else {
      mediaWidget = Container(
        height: 300,
        color: const Color(0xFFF5E8C7).withOpacity(0.3),
        child: Center(
          child: Text(
            'No media available',
            style: TextStyle(
              color: const Color(0xFF8B5E3C).withOpacity(0.6),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      );
    }

    return VisibilityDetector(
      key: Key('post-${_getPostId()}'),
      onVisibilityChanged: _onVisibilityChanged,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF8B5E3C).withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with clickable profile
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _navigateToProfile,
                      child: Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color(0xFF8B5E3C).withOpacity(0.2),
                            width: 2,
                          ),
                        ),
                        child: CircleAvatar(
                          radius: 20,
                          backgroundImage: avatarUrl.isNotEmpty
                              ? NetworkImage(avatarUrl)
                              : null,
                          backgroundColor: const Color(0xFFF5E8C7),
                          child: avatarUrl.isEmpty
                              ? const Icon(
                                  Icons.person_rounded,
                                  color: Color(0xFF8B5E3C),
                                  size: 24,
                                )
                              : null,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: _navigateToProfile,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.post['username'] ?? 'Unknown User',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: Color(0xFF8B5E3C),
                              ),
                            ),
                            Text(
                              _getRelativeTime(),
                              style: TextStyle(
                                fontSize: 12,
                                color: const Color(0xFF8B5E3C).withOpacity(0.6),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (_isSaved != null)
                      Container(
                        decoration: BoxDecoration(
                          color: _isSaved!
                              ? const Color(0xFF8B5E3C).withOpacity(0.1)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _toggleSave,
                            borderRadius: BorderRadius.circular(10),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Icon(
                                _isSaved! ? Icons.bookmark_rounded : Icons.bookmark_border_rounded,
                                color: _isSaved!
                                    ? const Color(0xFF8B5E3C)
                                    : const Color(0xFF8B5E3C).withOpacity(0.5),
                                size: 24,
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // Media display
              mediaWidget,

              // Action buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: isLiked
                            ? Colors.red.withOpacity(0.1)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: widget.onLike,
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Icon(
                              isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                              color: isLiked ? Colors.red : const Color(0xFF8B5E3C).withOpacity(0.6),
                              size: 26,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${widget.post['likes'] ?? 0}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: const Color(0xFF8B5E3C).withOpacity(0.8),
                      ),
                    ),
                    const SizedBox(width: 24),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _openComments(
                            context,
                            widget.post['username'] ?? 'Anonymous',
                          ),
                          borderRadius: BorderRadius.circular(10),
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child: Icon(
                              Icons.comment_outlined,
                              color: const Color(0xFF8B5E3C).withOpacity(0.6),
                              size: 26,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${_getComments().length}',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: const Color(0xFF8B5E3C).withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),

              // Caption
              if ((widget.post['caption'] ?? '').isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: RichText(
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: 14,
                        color: const Color(0xFF8B5E3C).withOpacity(0.9),
                        height: 1.4,
                      ),
                      children: [
                        WidgetSpan(
                          child: GestureDetector(
                            onTap: _navigateToProfile,
                            child: Text(
                              '${widget.post['username']}: ',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF8B5E3C),
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                        TextSpan(text: widget.post['caption']),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }
}