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

class _AddPostScreenState extends State<AddPostScreen> with TickerProviderStateMixin {
  final TextEditingController _captionController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  File? _selectedFile;
  bool _isUploading = false;
  bool _isVideo = false;

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _scaleController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
  }

  void _initializeAnimations() {
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _slideController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _scaleController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _scaleController, curve: Curves.elasticOut),
    );

    _fadeController.forward();
    _slideController.forward();
    _scaleController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    _scaleController.dispose();
    _captionController.dispose();
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
        setState(() {
          _selectedFile = File(picked!.path);
          _isVideo = video;
        });
        debugPrint("✅ Selected ${video ? 'video' : 'image'}: ${picked.path}");
      }
    } catch (e) {
      debugPrint("❌ Media picker error: $e");
      _showErrorSnackBar("Failed to pick media: $e");
    }
  }

  void _showMediaPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        margin: const EdgeInsets.all(16),
        child: SafeArea(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B5E3C).withOpacity(0.3),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5E8C7),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.add_photo_alternate_rounded,
                          color: const Color(0xFF8B5E3C),
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Choose Media',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF8B5E3C),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Options
                  _buildMediaOption(
                    icon: Icons.photo_library_rounded,
                    title: 'Choose from Gallery',
                    subtitle: 'Select photo from your gallery',
                    onTap: () {
                      Navigator.pop(context);
                      _pickMedia(ImageSource.gallery, video: false);
                    },
                  ),
                  
                  _buildMediaOption(
                    icon: Icons.video_library_rounded,
                    title: 'Choose Video',
                    subtitle: 'Select video from your gallery',
                    onTap: () {
                      Navigator.pop(context);
                      _pickMedia(ImageSource.gallery, video: true);
                    },
                  ),
                  
                  _buildMediaOption(
                    icon: Icons.camera_alt_rounded,
                    title: 'Take Photo',
                    subtitle: 'Capture a new photo',
                    onTap: () {
                      Navigator.pop(context);
                      _pickMedia(ImageSource.camera, video: false);
                    },
                  ),
                  
                  _buildMediaOption(
                    icon: Icons.videocam_rounded,
                    title: 'Record Video',
                    subtitle: 'Record a new video',
                    onTap: () {
                      Navigator.pop(context);
                      _pickMedia(ImageSource.camera, video: true);
                    },
                  ),
                  
                  // Cancel button
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.all(16),
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        side: BorderSide(
                          color: const Color(0xFF8B5E3C).withOpacity(0.3),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF8B5E3C),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMediaOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF8B5E3C).withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          icon,
          color: const Color(0xFF8B5E3C),
          size: 24,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: const Color(0xFF8B5E3C),
        ),
      ),
      subtitle: Text(
        subtitle,
        style: TextStyle(
          fontSize: 13,
          color: const Color(0xFF8B5E3C).withOpacity(0.6),
        ),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: const Color(0xFF8B5E3C).withOpacity(0.5),
      ),
      onTap: onTap,
    );
  }

  Future<void> _uploadPost() async {
    if (_selectedFile == null) {
      _showErrorSnackBar("Please select a media file to share");
      return;
    }

    if (widget.user == null) {
      _showErrorSnackBar("You must be signed in to upload a post");
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
        _showSuccessAnimation();
        await Future.delayed(const Duration(milliseconds: 1500));
        if (mounted) {
          Navigator.pop(context, true);
        }
      } else {
        _showErrorSnackBar("Upload failed! Status: ${response.statusCode}");
      }
    } catch (e, stackTrace) {
      setState(() => _isUploading = false);
      debugPrint("💥 Upload exception: $e");
      debugPrint("StackTrace: $stackTrace");
      _showErrorSnackBar("Upload failed: $e");
    }
  }

  void _showSuccessAnimation() {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black54,
      builder: (context) => Center(
        child: Container(
          margin: const EdgeInsets.all(40),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: const Color(0xFFF5E8C7),
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8B5E3C).withOpacity(0.3),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5E3C).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF8B5E3C),
                  size: 60,
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Posted!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF8B5E3C),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Your content has been shared',
                style: TextStyle(
                  fontSize: 15,
                  color: const Color(0xFF8B5E3C).withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5E8C7),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: SlideTransition(
            position: _slideAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Column(
                children: [
                  // App Bar
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF8B5E3C).withOpacity(0.1),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Back button
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF8B5E3C).withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.arrow_back_rounded,
                              color: const Color(0xFF8B5E3C),
                              size: 20,
                            ),
                          ),
                        ),
                        
                        const SizedBox(width: 12),
                        
                        // Title
                        Expanded(
                          child: Text(
                            'Create Post',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFF8B5E3C),
                            ),
                          ),
                        ),
                        
                        // Share button
                        _isUploading
                            ? Container(
                                padding: const EdgeInsets.all(12),
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: const Color(0xFF8B5E3C),
                                  ),
                                ),
                              )
                            : InkWell(
                                onTap: _uploadPost,
                                borderRadius: BorderRadius.circular(20),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        const Color(0xFF8B5E3C),
                                        const Color(0xFF6D4A2F),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF8B5E3C).withOpacity(0.3),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.send_rounded,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Share',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                      ],
                    ),
                  ),
                  
                  // Content
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          // User info
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF8B5E3C).withOpacity(0.1),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                // Profile picture
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFF8B5E3C).withOpacity(0.2),
                                      width: 2,
                                    ),
                                  ),
                                  child: ClipOval(
                                    child: widget.user?.photoUrl != null
                                        ? Image.network(
                                            widget.user!.photoUrl!,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) =>
                                                _buildDefaultAvatar(),
                                          )
                                        : _buildDefaultAvatar(),
                                  ),
                                ),
                                
                                const SizedBox(width: 12),
                                
                                // User info
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.user?.displayName ?? 'User',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF8B5E3C),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        widget.user?.email ?? '',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: const Color(0xFF8B5E3C).withOpacity(0.6),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // Caption input
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF8B5E3C).withOpacity(0.1),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.edit_rounded,
                                      color: const Color(0xFF8B5E3C).withOpacity(0.7),
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Caption',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF8B5E3C).withOpacity(0.8),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  controller: _captionController,
                                  maxLines: 4,
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: const Color(0xFF8B5E3C),
                                  ),
                                  decoration: InputDecoration(
                                    hintText: 'Share your thoughts...',
                                    hintStyle: TextStyle(
                                      color: const Color(0xFF8B5E3C).withOpacity(0.4),
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // Media preview/selector
                          Container(
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF8B5E3C).withOpacity(0.1),
                                  blurRadius: 15,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      _selectedFile != null 
                                          ? (_isVideo ? Icons.videocam_rounded : Icons.photo_rounded)
                                          : Icons.add_photo_alternate_rounded,
                                      color: const Color(0xFF8B5E3C).withOpacity(0.7),
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      _selectedFile != null 
                                          ? (_isVideo ? 'Video Selected' : 'Photo Selected')
                                          : 'Add Media',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xFF8B5E3C).withOpacity(0.8),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                
                                if (_selectedFile != null)
                                  _buildMediaPreview()
                                else
                                  _buildMediaSelector(),
                              ],
                            ),
                          ),
                          
                          const SizedBox(height: 20),
                          
                          // Action buttons
                          if (_selectedFile != null)
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: _showMediaPicker,
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      side: BorderSide(
                                        color: const Color(0xFF8B5E3C).withOpacity(0.3),
                                      ),
                                    ),
                                    icon: Icon(
                                      Icons.swap_horiz_rounded,
                                      color: const Color(0xFF8B5E3C),
                                    ),
                                    label: Text(
                                      'Change Media',
                                      style: TextStyle(
                                        color: const Color(0xFF8B5E3C),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => setState(() {
                                      _selectedFile = null;
                                      _isVideo = false;
                                    }),
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      side: BorderSide(
                                        color: Colors.red.withOpacity(0.3),
                                      ),
                                    ),
                                    icon: Icon(
                                      Icons.delete_rounded,
                                      color: Colors.red,
                                    ),
                                    label: Text(
                                      'Remove',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      color: const Color(0xFF8B5E3C).withOpacity(0.1),
      child: Icon(
        Icons.person_rounded,
        color: const Color(0xFF8B5E3C),
        size: 24,
      ),
    );
  }

  Widget _buildMediaPreview() {
    return Container(
      height: 280,
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.black,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Media content
            if (_isVideo)
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.play_circle_filled_rounded,
                      size: 80,
                      color: Colors.white.withOpacity(0.8),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Video File',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.8),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _selectedFile!.path.split('/').last,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.6),
                        fontSize: 12,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            else
              Image.file(
                _selectedFile!,
                fit: BoxFit.cover,
                width: double.infinity,
                height: double.infinity,
              ),
            
            // Overlay with media type indicator
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _isVideo ? Icons.videocam_rounded : Icons.photo_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _isVideo ? 'VIDEO' : 'PHOTO',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMediaSelector() {
    return GestureDetector(
      onTap: _showMediaPicker,
      child: Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          color: const Color(0xFFF5E8C7),
          borderRadius: BorderRadius.circular(16),
         
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF8B5E3C).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.add_photo_alternate_rounded,
                size: 40,
                color: const Color(0xFF8B5E3C),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Add Photo or Video',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: const Color(0xFF8B5E3C),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap to select from your gallery\nor capture new media',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: const Color(0xFF8B5E3C).withOpacity(0.6),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}