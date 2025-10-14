// lib/screens/home/add_post_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:mime/mime.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AddPostScreen extends StatefulWidget {
  final GoogleSignInAccount? user;
  const AddPostScreen({super.key, this.user});

  @override
  State<AddPostScreen> createState() => _AddPostScreenState();
}

class _AddPostScreenState extends State<AddPostScreen> {
  final TextEditingController _captionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  File? _selectedFile;
  bool _isUploading = false;
  bool _isVideo = false;

  Future<void> _pickMedia(ImageSource source, {bool video = false}) async {
    try {
      final XFile? picked;
      if (video) {
        picked = await _picker.pickVideo(source: source);
      } else {
        picked = await _picker.pickImage(source: source);
      }
      
      if (picked != null) {
        setState(() {
          _selectedFile = File(picked!.path);
          _isVideo = video;
        });
        debugPrint("✅ Selected ${video ? 'video' : 'image'}: ${picked.path}");
      }
    } catch (e) {
      debugPrint("❌ Media picker error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Media picker error: $e")),
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

  Future<void> _uploadPost() async {
    if (_selectedFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a media file")),
      );
      return;
    }

    if (widget.user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("You must be signed in to upload a post")),
      );
      return;
    }

    setState(() => _isUploading = true);

    try {
      final uri = Uri.parse("http://172.20.10.3:8000/api/posts/");
      final request = http.MultipartRequest('POST', uri);

      // Add form fields
      request.fields['username'] = widget.user?.displayName ?? 'Unknown';
      request.fields['email'] = widget.user?.email ?? '';
      request.fields['caption'] = _captionController.text;

      // Add file with proper MIME type
      String mimeType = lookupMimeType(_selectedFile!.path) ?? 
                       (_isVideo ? 'video/mp4' : 'image/jpeg');
      final file = await http.MultipartFile.fromPath(
        'media_file',
        _selectedFile!.path,
        contentType: MediaType.parse(mimeType),
      );
      request.files.add(file);

      debugPrint("📤 Uploading ${_isVideo ? 'video' : 'image'} with MIME: $mimeType");

      // Send request
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      setState(() => _isUploading = false);

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Post uploaded successfully!")),
        );
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Upload failed! Status: ${response.statusCode}\n${response.body}"),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e, stackTrace) {
      setState(() => _isUploading = false);
      debugPrint("💥 Upload exception: $e");
      debugPrint("StackTrace: $stackTrace");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Exception: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0.5,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text("New Post", style: TextStyle(color: Colors.black)),
        actions: [
          TextButton(
            onPressed: (_isUploading || widget.user == null) ? null : _uploadPost,
            child: Text(
              "Share",
              style: TextStyle(
                color: (_isUploading || widget.user == null) ? Colors.grey : Colors.blue,
                fontWeight: FontWeight.bold,
              ),
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundImage: widget.user?.photoUrl != null
                      ? NetworkImage(widget.user!.photoUrl!)
                      : null,
                  radius: 20,
                  child: widget.user?.photoUrl == null
                      ? const Icon(Icons.person, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _captionController,
                    decoration: const InputDecoration(
                      hintText: "Write a caption...",
                      border: InputBorder.none,
                    ),
                    maxLines: null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (_selectedFile != null)
              Container(
                height: 350,
                width: double.infinity,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.black,
                ),
                child: _isVideo
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.video_library, size: 80, color: Colors.white70),
                            const SizedBox(height: 10),
                            Text(
                              _selectedFile!.path.split('/').last,
                              style: const TextStyle(color: Colors.white70),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.file(
                          _selectedFile!,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: 350,
                        ),
                      ),
              )
            else
              GestureDetector(
                onTap: _showMediaPicker,
                child: Container(
                  height: 350,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.grey[200],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add_photo_alternate_outlined, 
                                 size: 60, color: Colors.grey),
                      const SizedBox(height: 8),
                      Text(
                        'Tap to select photo or video',
                        style: TextStyle(color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 20),
            if (_isUploading)
              const CircularProgressIndicator()
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: _showMediaPicker,
                    icon: const Icon(Icons.collections_outlined),
                    label: const Text("Select Media"),
                  ),
                  if (_selectedFile != null) ...[
                    const SizedBox(width: 10),
                    OutlinedButton.icon(
                      onPressed: () => setState(() {
                        _selectedFile = null;
                        _isVideo = false;
                      }),
                      icon: const Icon(Icons.close, color: Colors.red),
                      label: const Text("Remove", style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }
}