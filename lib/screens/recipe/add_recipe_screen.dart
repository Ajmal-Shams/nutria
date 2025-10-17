// lib/add_recipe_screen.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:image_picker/image_picker.dart'; // 👈 NEW

class AddRecipeScreen extends StatefulWidget {
  final GoogleSignInAccount? user;

  const AddRecipeScreen({super.key, this.user});

  @override
  State<AddRecipeScreen> createState() => _AddRecipeScreenState();
}

class _AddRecipeScreenState extends State<AddRecipeScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _ingredientsController = TextEditingController();
  final TextEditingController _instructionsController = TextEditingController();
  final TextEditingController _cuisineController = TextEditingController();
  final TextEditingController _timeController = TextEditingController();
  File? _imageFile;
  bool _isSaving = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() {
        _imageFile = File(picked.path);
      });
    }
  }

  Future<void> _saveRecipe() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.user?.email == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be signed in to save recipes!')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final uri = Uri.parse('http://172.20.10.3:8000/api/recipes/add/');

      // Create multipart request
      final request = http.MultipartRequest('POST', uri);

      // Add text fields
      request.fields['title'] = _nameController.text.trim();
      request.fields['ingredients'] = _ingredientsController.text.trim();
      request.fields['instructions'] = _instructionsController.text.trim();
      request.fields['cuisine'] = _cuisineController.text.trim();
      request.fields['total_time_mins'] =
          (int.tryParse(_timeController.text.trim()) ?? 45).toString();
      request.fields['author_email'] = widget.user!.email!;

      // Add image if selected
      if (_imageFile != null) {
        request.files.add(
          await http.MultipartFile.fromPath('image', _imageFile!.path),
        );
      }

      final response = await request.send();

      if (response.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('✅ Recipe saved successfully!')),
        );
        Navigator.of(context).pop(true);
      } else {
        String responseBody = await response.stream.bytesToString();
        final error = jsonDecode(responseBody);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Save failed: ${error.toString()}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('❌ Network error: $e')),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add New Recipe')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Recipe Name *'),
                validator: (v) => v!.trim().isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _ingredientsController,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Ingredients (comma-separated) *',
                  hintText: 'e.g., karela, onion, cumin seeds, besan',
                ),
                validator: (v) => v!.trim().isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _instructionsController,
                maxLines: 8,
                decoration: const InputDecoration(
                  labelText: 'Instructions *',
                ),
                validator: (v) => v!.trim().isEmpty ? 'Required' : null,
              ),
              TextFormField(
                controller: _cuisineController,
                decoration: const InputDecoration(labelText: 'Cuisine (e.g., Indian)'),
              ),
              TextFormField(
                controller: _timeController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Total Time (mins)'),
              ),
              const SizedBox(height: 16),
              // Image Preview & Picker
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  height: 120,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: _imageFile == null
                      ? const Center(child: Text('📷 Tap to add photo'))
                      : Image.file(_imageFile!, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _isSaving ? null : _saveRecipe,
                icon: _isSaving
                    ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.save),
                label: const Text('Save Recipe'),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 