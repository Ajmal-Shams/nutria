// lib/widgets/comment_sheet.dart
import 'package:flutter/material.dart';
import 'package:nutria/services/home/home_service.dart';


class CommentSheet extends StatefulWidget {
  final List comments;
  final String post_id;
  final String username;

  const CommentSheet({
    super.key,
    required this.comments,
    required this.post_id,
    required this.username,
  });

  @override
  State<CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<CommentSheet> {
  final TextEditingController _commentController = TextEditingController();

  void _postComment() async {
    if (_commentController.text.trim().isEmpty) return;

    try {
      await HomeService.addComment(
        post_id: widget.post_id,
        username: widget.username,
        text: _commentController.text.trim(),
      );
      Navigator.pop(context, true); // Signal refresh
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Comment failed: $e')),
      );
    } finally {
      _commentController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: 400,
        child: Column(
          children: [
            const SizedBox(height: 10),
            const Text("Comments", style: TextStyle(fontWeight: FontWeight.bold)),
            Expanded(
              child: ListView.builder(
                itemCount: widget.comments.length,
                itemBuilder: (_, i) {
                  final comment = widget.comments[i];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage: comment['avatar_url'] != null
                          ? NetworkImage(comment['avatar_url'])
                          : null,
                      child: comment['avatar_url'] == null
                          ? const Icon(Icons.person, color: Colors.grey)
                          : null,
                    ),
                    title: Text(comment['username']),
                    subtitle: Text(comment['text']),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      decoration: const InputDecoration(
                        hintText: "Add a comment...",
                        border: OutlineInputBorder(),
                      ),
                      onSubmitted: (_) => _postComment(),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.send),
                    onPressed: _postComment,
                  )
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}