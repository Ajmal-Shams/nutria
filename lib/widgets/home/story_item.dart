import 'package:flutter/material.dart';

class StoryItem extends StatelessWidget {
  final String avatarUrl;
  final String username;
  final bool hasNew;
  final bool isYourStory;
  final VoidCallback? onTap;

  const StoryItem({
    super.key,
    required this.avatarUrl,
    required this.username,
    required this.hasNew,
    this.isYourStory = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: hasNew
                      ? const LinearGradient(
                          colors: [Colors.purple, Colors.orange],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  border: Border.all(
                    color: hasNew ? Colors.transparent : Colors.grey.shade400,
                    width: 2,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: ClipOval(
                    child: Image.network(
                      avatarUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.person, size: 40, color: Colors.white),
                    ),
                  ),
                ),
              ),
              if (isYourStory)
                Positioned(
                  bottom: 2,
                  right: 2,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: const BoxDecoration(
                      color: Colors.blue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add, color: Colors.white, size: 14),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            username,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
