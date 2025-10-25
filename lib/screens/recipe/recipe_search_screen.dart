// lib/screens/recipe/recipe_search_screen.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';
import 'package:nutria/screens/recipe/add_recipe_screen.dart';
import 'package:nutria/widgets/common/navbar.dart';

class RecipeSearchScreen extends StatefulWidget {
  final GoogleSignInAccount? user;

  const RecipeSearchScreen({super.key, this.user});

  @override
  State<RecipeSearchScreen> createState() => _RecipeSearchScreenState();
}

class _RecipeSearchScreenState extends State<RecipeSearchScreen> {
  List<Map<String, dynamic>> _results = [];
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false;

  /// Load local recipes
  Future<List<Map<String, dynamic>>> _loadLocalRecipes() async {
    try {
      final jsonString = await rootBundle.loadString('assets/recipes.json');
      final List<dynamic> data = jsonDecode(jsonString);
      return data.map((item) {
        return {
          'id': 'local_${item['TranslatedRecipeName']}',
          'title': item['TranslatedRecipeName'] ?? 'Untitled',
          'ingredients': item['TranslatedIngredients'] ?? '',
          'instructions': item['TranslatedInstructions'] ?? '',
          'cuisine': item['Cuisine'] ?? 'Unknown',
          'total_time_mins': item['TotalTimeInMins'] ?? 45,
          'image_url': item['image-url'] ?? '',
          'author_name': 'System',
          'author_email': 'system@nutria.com',
          'is_local': true,
        };
      }).toList();
    } catch (e) {
      debugPrint('Failed to load local recipes: $e');
      return [];
    }
  }

  /// Fetch recipes from Django
  Future<List<Map<String, dynamic>>> _fetchDjangoRecipes(String query) async {
    try {
      final uri = Uri.parse(
          'http://172.20.10.3:8000/api/recipes/search/?q=$query');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        return data
            .map((item) =>
                Map<String, dynamic>.from(item)..['is_local'] = false)
            .toList();
      }
    } catch (e) {
      debugPrint('Django fetch error: $e');
    }
    return [];
  }

  /// 🔥 Multi-ingredient combined search
  Future<void> _searchCombined(String query) async {
    setState(() => _isLoading = true);
    try {
      final ingredients = query
          .split(',')
          .map((s) => s.trim().toLowerCase())
          .where((s) => s.isNotEmpty)
          .toList();

      final localRecipes = await _loadLocalRecipes();
      final djangoRecipes = <Map<String, dynamic>>[];

      // Fetch Django per ingredient
      for (final ing in ingredients.isEmpty ? [''] : ingredients) {
        final partial = await _fetchDjangoRecipes(ing);
        djangoRecipes.addAll(partial);
      }

      // Filter local recipes
      List<Map<String, dynamic>> filteredLocal = [];
      if (ingredients.isEmpty) {
        filteredLocal = localRecipes;
      } else {
        filteredLocal = localRecipes.where((r) {
          final ingText = (r['ingredients'] ?? '').toString().toLowerCase();
          // Check if recipe contains ALL input ingredients
          return ingredients.every((ing) =>
              (r['title'] as String).toLowerCase().contains(ing) ||
              ingText.contains(ing));
        }).toList();
      }

      // Combine and deduplicate
      final combined = [...filteredLocal, ...djangoRecipes];
      final seen = <String>{};
      final unique = <Map<String, dynamic>>[];
      for (var r in combined) {
        final key = (r['title'] ?? '').toString().toLowerCase();
        if (!seen.contains(key)) {
          seen.add(key);
          unique.add(r);
        }
      }

      setState(() => _results = unique);
    } catch (e) {
      debugPrint("Search error: $e");
      setState(() => _results = []);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _search() {
    final input = _controller.text.trim();
    _searchCombined(input);
  }

  @override
  void initState() {
    super.initState();
    _searchCombined('');
  }

  Widget _buildImage(String url) {
    if (url.isEmpty) {
      return const Icon(Icons.fastfood, size: 48, color: Colors.grey);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.network(
        url.trim(),
        width: 56,
        height: 56,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            const Icon(Icons.fastfood, size: 48, color: Colors.orange),
      ),
    );
  }

  void _showDetail(Map<String, dynamic> recipe) {
    final authorName = recipe['author_name'] ?? 'Anonymous';
    final isLocal = recipe['is_local'] == true;
    final imageUrl = (recipe['image_url'] ?? '').toString().trim();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(recipe['title'] ?? 'Recipe'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ✅ Only show image if available
              if (imageUrl.isNotEmpty)
                SizedBox(
                  width: double.infinity,
                  height: 180,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) =>
                          const Icon(Icons.fastfood,
                              size: 80, color: Colors.orange),
                    ),
                  ),
                ),
              if (imageUrl.isNotEmpty) const SizedBox(height: 12),

              const Text('Ingredients:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text(recipe['ingredients'] ?? 'N/A'),
              const SizedBox(height: 12),
              const Text('Instructions:',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              Text((recipe['instructions'] ?? 'N/A')
                  .replaceAll('\n', '\n\n')),
              const SizedBox(height: 12),
              Text(
                isLocal ? 'Source: Preloaded Dataset' : 'By: $authorName',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isLocal ? Colors.grey : Colors.blue),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Best Match First'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (context) => AddRecipeScreen(user: widget.user)),
              );
              if (result == true) {
                _controller.clear();
                _searchCombined('');
              }
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: 'Enter ingredients (comma separated)',
                labelText: 'Your ingredients',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _search,
                ),
              ),
              onSubmitted: (_) => _search(),
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const LinearProgressIndicator()
            else
              Expanded(
                child: _results.isEmpty
                    ? const Center(
                        child: Text('Enter ingredients to find your match!'))
                    : ListView.builder(
                        itemCount: _results.length,
                        itemBuilder: (context, index) {
                          final r = _results[index];
                          final name = r['title'] ?? 'Recipe';
                          final img = r['image_url'] ?? '';
                          final author = r['author_name'] ?? 'Anonymous';
                          final isLocal = r['is_local'] == true;
                          final isTop = index == 0;

                          return Card(
                            elevation: isTop ? 6 : 2,
                            margin: EdgeInsets.symmetric(
                                vertical: isTop ? 12 : 4),
                            shape: isTop
                                ? RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: const BorderSide(
                                        color: Colors.green, width: 2),
                                  )
                                : null,
                            child: ListTile(
                              leading: _buildImage(img),
                              title: Text(
                                name,
                                style: isTop
                                    ? const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)
                                    : null,
                              ),
                              subtitle: Text.rich(
                                TextSpan(
                                  children: [
                                    if (isTop)
                                      const TextSpan(
                                          text: '🏆 Best Match!\n',
                                          style: TextStyle(color: Colors.green)),
                                    TextSpan(
                                      text: isLocal
                                          ? 'Source: Preloaded'
                                          : 'By: $author',
                                      style: TextStyle(
                                          color: isLocal ? Colors.grey : null),
                                    ),
                                  ],
                                ),
                              ),
                              onTap: () => _showDetail(r),
                            ),
                          );
                        },
                      ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: Navbar(index: 1, user: widget.user),
    );
  }
}
