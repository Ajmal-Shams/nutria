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
  List<Map<String, dynamic>> _allRecipes = []; // Combined list
  List<Map<String, dynamic>> _results = [];
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false;

  // Load local recipes from assets/recipes.json
  Future<List<Map<String, dynamic>>> _loadLocalRecipes() async {
    try {
      final jsonString = await rootBundle.loadString('assets/recipes.json');
      final List<dynamic> data = jsonDecode(jsonString);
      return data.map((item) {
        // Normalize to match Django structure
        return {
          'id': 'local_${item['TranslatedRecipeName']}',
          'title': item['TranslatedRecipeName'] ?? 'Untitled',
          'ingredients': item['TranslatedIngredients'] ?? '',
          'instructions': item['TranslatedInstructions'] ?? '',
          'cuisine': item['Cuisine'] ?? 'Unknown',
          'total_time_mins': item['TotalTimeInMins'] ?? 45,
          'image_url': item['image-url'] ?? '',
          'author_name': 'System', // 👈 Mark as system recipe
          'author_email': 'system@nutria.com',
          'is_local': true,
        };
      }).toList();
    } catch (e) {
      debugPrint('Failed to load local recipes: $e');
      return [];
    }
  }

  // Fetch user-submitted recipes from Django
  Future<List<Map<String, dynamic>>> _fetchDjangoRecipes(String query) async {
    try {
      final uri = Uri.parse('http://172.20.10.3:8000/api/recipes/search/?q=$query');
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        // Mark as cloud
        return data.map((item) => Map<String, dynamic>.from(item)..['is_local'] = false).toList();
      } else {
        throw Exception('HTTP ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('Django fetch error: $e');
      return [];
    }
  }

  // 🔥 Combined search: local + Django
  Future<void> _searchCombined(String query) async {
    setState(() => _isLoading = true);
    try {
      // Always load local recipes (full list)
      final localRecipes = await _loadLocalRecipes();

      // Fetch Django recipes (filtered by query)
      final djangoRecipes = await _fetchDjangoRecipes(query);

      // Combine: local (full) + django (filtered)
      // If query is empty, show all local + all django
      List<Map<String, dynamic>> combined;
      if (query.isEmpty) {
        combined = [...localRecipes, ...djangoRecipes];
      } else {
        // Filter local recipes by query too
        final filteredLocal = localRecipes.where((r) =>
            (r['title'] as String).toLowerCase().contains(query.toLowerCase()) ||
            (r['ingredients'] as String).toLowerCase().contains(query.toLowerCase())).toList();
        combined = [...filteredLocal, ...djangoRecipes];
      }

      // Optional: remove duplicates by title (case-insensitive)
      final seen = <String>{};
      final unique = <Map<String, dynamic>>[];
      for (var r in combined) {
        final key = (r['title'] as String).toLowerCase();
        if (!seen.contains(key)) {
          seen.add(key);
          unique.add(r);
        }
      }

      setState(() {
        _allRecipes = unique; // store for re-filtering if needed
        _results = unique;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      setState(() {
        _results = [];
      });
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
    _searchCombined(''); // Load all on start
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(recipe['title'] ?? 'Recipe'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (recipe['image_url'] != null && recipe['image_url'].toString().trim().isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      recipe['image_url'].toString().trim(),
                      height: 150,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (c, e, s) => Container(
                        height: 150,
                        color: Colors.grey[300],
                        child: const Icon(Icons.image, size: 50, color: Colors.grey),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                const Text('Ingredients:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(recipe['ingredients'] ?? 'N/A'),
                const SizedBox(height: 12),
                const Text('Instructions:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text((recipe['instructions'] ?? 'N/A').replaceAll('\n', '\n\n')),
                const SizedBox(height: 12),
                Text(
                  isLocal ? 'Source: Preloaded Dataset' : 'By: $authorName',
                  style: TextStyle(fontWeight: FontWeight.bold, color: isLocal ? Colors.grey : Colors.blue),
                ),
              ],
            ),
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
                MaterialPageRoute(builder: (context) => AddRecipeScreen(user: widget.user)),
              );
              if (result == true) {
                _controller.clear();
                _searchCombined(''); // refresh all
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
              keyboardType: TextInputType.text,
              decoration: InputDecoration(
                hintText: 'e.g., mushroom, paneer, soya, onion',
                labelText: 'Your ingredients',
                border: OutlineInputBorder(),
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
                    ? const Center(child: Text('Enter ingredients to find your best match!'))
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
                            margin: EdgeInsets.symmetric(vertical: isTop ? 12 : 4),
                            shape: isTop
                                ? RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    side: const BorderSide(color: Colors.green, width: 2),
                                  )
                                : null,
                            child: ListTile(
                              leading: _buildImage(img),
                              title: Text(
                                name,
                                style: isTop
                                    ? const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                                    : null,
                              ),
                              subtitle: Text.rich(
                                TextSpan(
                                  children: [
                                    if (isTop)
                                      const TextSpan(
                                        text: '🏆 Best Match!\n',
                                        style: TextStyle(color: Colors.green),
                                      ),
                                    TextSpan(
                                      text: isLocal ? 'Source: Preloaded' : 'By: $author',
                                      style: TextStyle(
                                        color: isLocal ? Colors.grey : null,
                                      ),
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