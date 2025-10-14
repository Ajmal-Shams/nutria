// lib/add_recipe_screen.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class AddRecipeScreen extends StatefulWidget {
  const AddRecipeScreen({super.key});

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
  final TextEditingController _imageUrlController = TextEditingController();

  bool _isSaving = false;

  Future<String> _getLocalRecipesPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/recipes.json';
  }

  String _generateCleanedIngredients(String raw) {
    return raw
        .toLowerCase()
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .join(',');
  }

  Future<void> _saveRecipe() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);

    try {
      final localPath = await _getLocalRecipesPath();
      final file = File(localPath);

      // Ensure file exists
      if (!await file.exists()) {
        // Should not happen, but safe fallback
        await file.writeAsString('[]');
      }

      final jsonString = await file.readAsString();
      List<dynamic> recipes = json.decode(jsonString);

      final newRecipe = {
        "TranslatedRecipeName": _nameController.text.trim(),
        "TranslatedIngredients": _ingredientsController.text.trim(),
        "TotalTimeInMins": int.tryParse(_timeController.text.trim()) ?? 45,
        "Cuisine": _cuisineController.text.trim(),
        "TranslatedInstructions": _instructionsController.text.trim(),
        "URL": "",
        "Cleaned-Ingredients": _generateCleanedIngredients(_ingredientsController.text.trim()),
        "image-url": _imageUrlController.text.trim(),
        "Ingredient-count": _ingredientsController.text.split(',').length,
      };

      recipes.add(newRecipe);
      await file.writeAsString(json.encode(recipes));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('✅ Recipe saved successfully!')),
      );

      Navigator.of(context).pop(true); // return true to signal refresh
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('❌ Save failed: $e')));
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
              TextFormField(
                controller: _imageUrlController,
                decoration: const InputDecoration(
                  labelText: 'Image URL (Optional)',
                  hintText: 'https://example.com/recipe.jpg',
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