// lib/widgets/post_card.dart
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:nutria/widgets/home/comment_sheet.dart';

class PostCard extends StatefulWidget {
  final Map<String, dynamic> post;
  final VoidCallback onLike;
  final VoidCallback onRefresh;

  const PostCard({
    super.key,
    required this.post,
    required this.onLike,
    required this.onRefresh,
  });

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeVideo();
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
        
        // Use network constructor with error callback
        _videoController = VideoPlayerController.network(
          mediaUrl,
          videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
        );
        
        // Add error listener
        _videoController!.addListener(() {
          if (_videoController!.value.hasError) {
            debugPrint('❌ Video error: ${_videoController!.value.errorDescription}');
          }
        });
        
        await _videoController!.initialize();
        await _videoController!.setLooping(true);
        
        if (mounted) {
          setState(() => _isVideoInitialized = true);
          // Auto-play video
          _videoController!.play();
          debugPrint('✅ Video initialized and playing');
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

  @override
  Widget build(BuildContext context) {
    final mediaUrl = _getMediaUrl() ?? '';
    final avatarUrl = _getAvatarUrl() ?? '';
    final isVideo = _isVideoUrl(mediaUrl);
    final isImage = _isImageUrl(mediaUrl);
    final isLiked = widget.post['liked_by_user'] ?? false;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            leading: CircleAvatar(
              radius: 20,
              backgroundImage: avatarUrl.isNotEmpty
                  ? NetworkImage(avatarUrl)
                  : null,
              child: avatarUrl.isEmpty
                  ? const Icon(Icons.person, color: Colors.grey, size: 20)
                  : null,
            ),
            title: Text(
              widget.post['username'] ?? 'Unknown User',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text(_getRelativeTime()),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          
          // Media display
          if (isVideo && _isVideoInitialized && _videoController != null)
            GestureDetector(
              onTap: _toggleVideoPlayback,
              child: AspectRatio(
                aspectRatio: _videoController!.value.aspectRatio,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    VideoPlayer(_videoController!),
                    // Play/Pause indicator
                    if (!_videoController!.value.isPlaying)
                      Container(
                        decoration: BoxDecoration(
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
                    // Mute/Unmute button
                    Positioned(
                      bottom: 10,
                      right: 10,
                      child: Container(
                        decoration: BoxDecoration(
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
            )
          else if (isVideo && _videoController != null)
            AspectRatio(
              aspectRatio: 16 / 9,
              child: Container(
                color: Colors.black,
                child: const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                ),
              ),
            )
          else if (isVideo)
            Container(
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
            )
          else if (isImage)
            Container(
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
            )
          else if (mediaUrl.isNotEmpty)
            Container(
              height: 300,
              color: Colors.grey[300],
              child: const Center(child: Text('Unsupported media type')),
            )
          else
            Container(
              height: 300,
              color: Colors.grey[300],
              child: const Center(child: Text('No media available')),
            ),
          
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
          
          if ((widget.post['caption'] ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: RichText(
                text: TextSpan(
                  style: DefaultTextStyle.of(context).style,
                  children: [
                    TextSpan(
                      text: '${widget.post['username']}: ',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    TextSpan(text: widget.post['caption']),
                  ],
                ),
              ),
            ),
          
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}