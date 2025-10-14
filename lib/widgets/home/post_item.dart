// lib/post_item.dart
import 'package:flutter/material.dart';

class PostItem extends StatefulWidget {
  final String avatarUrl;
  final String username;
  final String imageUrl;
  final String caption;
  final int likes;
  final bool isLiked;
  final List<String> comments;

  const PostItem({
    Key? key,
    required this.avatarUrl,
    required this.username,
    required this.imageUrl,
    required this.caption,
    required this.likes,
    required this.isLiked,
    required this.comments,
  }) : super(key: key);

  @override
  State<PostItem> createState() => _PostItemState();
}

class _PostItemState extends State<PostItem> {
  late bool _isLiked;
  late int _likes;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.isLiked;
    _likes = widget.likes;
  }

  void _toggleLike() {
    setState(() {
      if (_isLiked) {
        _likes--;
      } else {
        _likes++;
      }
      _isLiked = !_isLiked;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Post Header
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundImage: NetworkImage(widget.avatarUrl),
                  backgroundColor: Colors.grey[300],
                ),
                const SizedBox(width: 12),
                Text(
                  widget.username,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                const Icon(Icons.more_horiz),
              ],
            ),
          ),

          // Post Image
          Image.network(
            widget.imageUrl,
            fit: BoxFit.cover,
            width: double.infinity,
            height: MediaQuery.of(context).size.width,
            errorBuilder: (context, error, stackTrace) =>
                Container(height: 300, color: Colors.grey[300]),
          ),

          // Post Actions
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                IconButton(
                  icon: Icon(
                    _isLiked ? Icons.favorite : Icons.favorite_border,
                    color: _isLiked ? Colors.red : null,
                  ),
                  onPressed: _toggleLike,
                ),
                const IconButton(
                  icon: Icon(Icons.comment_outlined),
                  onPressed: null,
                ),
                const IconButton(
                  icon: Icon(Icons.send_outlined),
                  onPressed: null,
                ),
                const Spacer(),
                const IconButton(
                  icon: Icon(Icons.bookmark_border),
                  onPressed: null,
                ),
              ],
            ),
          ),

          // Likes Count
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              '$_likes likes',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),

          // Caption
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: RichText(
              text: TextSpan(
                style: DefaultTextStyle.of(context).style,
                children: [
                  TextSpan(
                    text: '${widget.username} ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: widget.caption),
                ],
              ),
            ),
          ),

          // Comments Preview
          if (widget.comments.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Text(
                'View all ${widget.comments.length} comments',
                style: const TextStyle(color: Colors.grey),
              ),
            ),

          // Timestamp
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              '2 HOURS AGO',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}