// lib/screens/home/add_story_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:video_player/video_player.dart';

class AddStoryScreen extends StatefulWidget {
  final GoogleSignInAccount? user;
  const AddStoryScreen({super.key, this.user});

  @override
  State<AddStoryScreen> createState() => _AddStoryScreenState();
}

class _AddStoryScreenState extends State<AddStoryScreen> {
  final ImagePicker _picker = ImagePicker();
  File? _selectedFile;
  bool _isUploading = false;
  bool _isVideo = false;
  VideoPlayerController? _videoController;
  bool _isVideoInitialized = false;

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  Future<void> _pickMedia(ImageSource source, {bool video = false}) async {
    try {
      final XFile? picked;
      if (video) {
        picked = await _picker.pickVideo(source: source);
      } else {
        picked = await _picker.pickImage(source: source);
      }

      if (picked != null) {
        // Dispose previous video controller if exists
        await _videoController?.dispose();
        _videoController = null;
        
        setState(() {
          _selectedFile = File(picked!.path);
          _isVideo = video;
          _isVideoInitialized = false;
        });

        // Initialize video player if video is selected
        if (video) {
          await _initializeVideoPlayer();
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Media picker error: $e")),
      );
    }
  }

  Future<void> _initializeVideoPlayer() async {
    if (_selectedFile == null || !_isVideo) return;

    try {
      _videoController = VideoPlayerController.file(_selectedFile!);
      await _videoController!.initialize();
      
      setState(() {
        _isVideoInitialized = true;
      });

      // Auto play the video
      _videoController!.play();
      _videoController!.setLooping(true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Video initialization error: $e")),
      );
    }
  }

  void _showMediaPicker() {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose Image'),
              onTap: () {
                Navigator.pop(context);
                _pickMedia(ImageSource.gallery, video: false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.video_library),
              title: const Text('Choose Video'),
              onTap: () {
                Navigator.pop(context);
                _pickMedia(ImageSource.gallery, video: true);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickMedia(ImageSource.camera, video: false);
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam),
              title: const Text('Record Video'),
              onTap: () {
                Navigator.pop(context);
                _pickMedia(ImageSource.camera, video: true);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadStory() async {
    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a media file")),
      );
      return;
    }

    if (widget.user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You must be signed in to upload a story")),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final uri = Uri.parse("http://10.10.160.214:8000/api/stories/");
      final request = http.MultipartRequest('POST', uri);

      request.fields['username'] = widget.user?.displayName ?? 'Unknown';
      request.fields['email'] = widget.user?.email ?? '';

      String mimeType = lookupMimeType(_selectedFile!.path) ??
                        (_isVideo ? 'video/mp4' : 'image/jpeg');

      request.files.add(
        await http.MultipartFile.fromPath(
          'media_file',
          _selectedFile!.path,
          contentType: MediaType.parse(mimeType),
        ),
      );

      final response = await http.Response.fromStream(await request.send());

      if (response.statusCode == 201) {
        Navigator.pop(context, true); // Signal success
      } else {
        throw Exception('Upload failed: ${response.statusCode}');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Story upload failed: $e')),
      );
    } finally {
      setState(() => _isUploading = false);
    }
  }

  void _togglePlayPause() {
    if (_videoController == null) return;
    
    setState(() {
      if (_videoController!.value.isPlaying) {
        _videoController!.pause();
      } else {
        _videoController!.play();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                  ElevatedButton(
                    onPressed: (_isUploading || widget.user == null || _selectedFile == null)
                        ? null
                        : _uploadStory,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                    child: _isUploading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text("Share", style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),

            // Media preview or picker
            Expanded(
              child: _selectedFile != null
                  ? Container(
                      color: Colors.black,
                      child: Center(
                        child: _isVideo
                            ? _buildVideoPreview()
                            : Image.file(
                                _selectedFile!,
                                fit: BoxFit.contain,
                                width: double.infinity,
                                height: double.infinity,
                              ),
                      ),
                    )
                  : GestureDetector(
                      onTap: _showMediaPicker,
                      child: Container(
                        color: Colors.grey[900],
                        child: const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_a_photo, size: 60, color: Colors.white54),
                              SizedBox(height: 16),
                              Text(
                                'Tap to add photo or video',
                                style: TextStyle(color: Colors.white54, fontSize: 16),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
            ),

            // Action buttons
            if (_selectedFile == null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: OutlinedButton.icon(
                  onPressed: _showMediaPicker,
                  icon: const Icon(Icons.image, color: Colors.white),
                  label: const Text("Select Media", style: TextStyle(color: Colors.white)),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.white),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _showMediaPicker,
                      icon: const Icon(Icons.change_circle_outlined, color: Colors.white),
                      label: const Text("Change", style: TextStyle(color: Colors.white)),
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.white)),
                    ),
                    const SizedBox(width: 12),
                    OutlinedButton.icon(
                      onPressed: () {
                        _videoController?.dispose();
                        _videoController = null;
                        setState(() {
                          _selectedFile = null;
                          _isVideo = false;
                          _isVideoInitialized = false;
                        });
                      },
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      label: const Text("Remove", style: TextStyle(color: Colors.red)),
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPreview() {
    if (!_isVideoInitialized || _videoController == null) {
      return const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 16),
          Text(
            'Loading video...',
            style: TextStyle(color: Colors.white70),
          ),
        ],
      );
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        // Video player
        AspectRatio(
          aspectRatio: _videoController!.value.aspectRatio,
          child: VideoPlayer(_videoController!),
        ),

        // Play/Pause overlay button
        GestureDetector(
          onTap: _togglePlayPause,
          child: Container(
            color: Colors.transparent,
            width: double.infinity,
            height: double.infinity,
            child: Center(
              child: AnimatedOpacity(
                opacity: _videoController!.value.isPlaying ? 0.0 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.play_arrow,
                    color: Colors.white,
                    size: 50,
                  ),
                ),
              ),
            ),
          ),
        ),

        // Video controls at bottom
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.black.withOpacity(0.7),
                  Colors.transparent,
                ],
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Progress bar
                VideoProgressIndicator(
                  _videoController!,
                  allowScrubbing: true,
                  colors: const VideoProgressColors(
                    playedColor: Colors.blue,
                    bufferedColor: Colors.white38,
                    backgroundColor: Colors.white24,
                  ),
                ),
                const SizedBox(height: 8),
                // Duration text
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDuration(_videoController!.value.position),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                    Text(
                      _formatDuration(_videoController!.value.duration),
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Play/Pause button at bottom center
        Positioned(
          bottom: 80,
          child: GestureDetector(
            onTap: _togglePlayPause,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black54,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _videoController!.value.isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: 30,
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}