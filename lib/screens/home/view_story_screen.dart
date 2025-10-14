// lib/screens/home/view_story_screen.dart
import 'package:flutter/material.dart';
import 'package:story_view/story_view.dart';

class ViewStoryScreen extends StatefulWidget {
  final List<Map<String, dynamic>> stories;
  final String username;
  final bool isOwnStory;
  final VoidCallback? onAddStory;

  const ViewStoryScreen({
    super.key,
    required this.stories,
    required this.username,
    this.isOwnStory = false,
    this.onAddStory,
  });

  @override
  State<ViewStoryScreen> createState() => _ViewStoryScreenState();
}

class _ViewStoryScreenState extends State<ViewStoryScreen> {
  late final StoryController _controller;
  late final List<StoryItem> storyItems;

  @override
  void initState() {
    super.initState();
    _controller = StoryController();
    storyItems = _buildStoryItems();
  }

  List<StoryItem> _buildStoryItems() {
    final items = <StoryItem>[];
    
    for (final story in widget.stories) {
      final url = story['media_url'] as String? ?? '';
      
      if (url.isEmpty || Uri.tryParse(url) == null) {
        continue;
      }

      // Determine if media is video based on URL extension
      final isVideo = _isVideoUrl(url);

      if (isVideo) {
        // Add video story item
        items.add(
          StoryItem.pageVideo(
            url,
            controller: _controller,
            caption: Text(
              widget.username,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            duration: const Duration(seconds: 10),
          ),
        );
      } else {
        // Add image story item
        items.add(
          StoryItem.pageImage(
            url: url,
            controller: _controller,
            caption: Text(
              widget.username,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }

    // Fallback if no valid stories
    if (items.isEmpty) {
      items.add(
        StoryItem.text(
          title: "${widget.username}'s story is unavailable.",
          backgroundColor: Colors.grey.shade800,
        ),
      );
    }
    
    return items;
  }

  /// Check if URL is a video based on extension
  bool _isVideoUrl(String url) {
    final videoExtensions = ['.mp4', '.mov', '.avi', '.mkv', '.webm', '.m4v'];
    final lowerUrl = url.toLowerCase();
    return videoExtensions.any((ext) => lowerUrl.contains(ext));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Story viewer
            StoryView(
              storyItems: storyItems,
              controller: _controller,
              repeat: false,
              inline: false,
              onComplete: () => Navigator.pop(context),
              onVerticalSwipeComplete: (direction) {
                if (direction == Direction.down) {
                  Navigator.pop(context);
                }
              },
            ),

            // Top gradient overlay for better text visibility
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                height: 100,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.6),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Username overlay
            Positioned(
              top: 20,
              left: 16,
              right: 16,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: Colors.white24,
                    child: Text(
                      widget.username[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.username,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        shadows: [
                          Shadow(
                            color: Colors.black45,
                            blurRadius: 4,
                          ),
                        ],
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),

            // Add story button (only for own stories)
            if (widget.isOwnStory)
              Positioned(
                bottom: 30,
                right: 20,
                child: GestureDetector(
                  onTap: widget.onAddStory,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.add,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}