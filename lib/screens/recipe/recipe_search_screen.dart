// lib/recipe_search_screen.dart
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:nutria/widgets/common/navbar.dart';
import 'package:path_provider/path_provider.dart';
import 'add_recipe_screen.dart';

class RecipeSearchScreen extends StatefulWidget {
  const RecipeSearchScreen({super.key});

  @override
  State<RecipeSearchScreen> createState() => _RecipeSearchScreenState();
}

class _RecipeSearchScreenState extends State<RecipeSearchScreen> {
  List<dynamic> _allRecipes = [];
  List<Map<String, dynamic>> _results = [];
  final TextEditingController _controller = TextEditingController();
  bool _isLoading = false;

  List<_NormalizedRecipe>? _normalizedCache;

  Future<String> _getLocalRecipesPath() async {
    final dir = await getApplicationDocumentsDirectory();
    return '${dir.path}/recipes.json';
  }

  Future<void> _loadRecipes() async {
    setState(() => _isLoading = true);
    try {
      final localPath = await _getLocalRecipesPath();
      final localFile = File(localPath);

      String jsonString;
      if (await localFile.exists()) {
        jsonString = await localFile.readAsString();
      } else {
        jsonString = await rootBundle.loadString('assets/recipes.json');
        await localFile.writeAsString(jsonString);
      }

      final List<dynamic> data = json.decode(jsonString);
      _allRecipes = data;
      _normalizedCache = _allRecipes.map((r) => _normalizeRecipe(r)).toList();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading recipes: $e')));
    }
    setState(() => _isLoading = false);
  }

  @override
  void initState() {
    super.initState();
    _loadRecipes();
  }

  Set<String> _tokenize(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .map((s) => s.trim())
        .where((s) => s.length >= 3)
        .toSet();
  }

  _NormalizedRecipe _normalizeRecipe(dynamic recipe) {
    final rawIng = recipe['Cleaned-Ingredients'] as String?;
    final name = recipe['TranslatedRecipeName'] as String? ?? '';

    Set<String> tokens = Set<String>();
    if (rawIng != null) {
      for (var part in rawIng.split(',')) {
        tokens.addAll(_tokenize(part));
      }
    }
    tokens.addAll(_tokenize(name));
    return _NormalizedRecipe(recipe: recipe, tokens: tokens);
  }

  void _search() {
    final input = _controller.text.trim();
    if (input.isEmpty) {
      setState(() {
        _results = [];
      });
      return;
    }

    final userTokens = _tokenize(input);
    if (userTokens.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter valid ingredients!')));
      return;
    }

    List<_ScoredItem> scored = [];

    for (var norm in _normalizedCache ?? []) {
      final matched = norm.tokens.intersection(userTokens).length;
      if (matched == 0) continue;

      final totalTokens = norm.tokens.length;
      final score = matched / (1 + sqrt(totalTokens));

      scored.add(_ScoredItem(
        recipe: norm.recipe as Map<String, dynamic>,
        score: score,
        matched: matched,
        total: totalTokens,
      ));
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    final top = scored.take(15).map((s) => s.recipe).toList();

    if (top.isEmpty && _allRecipes.isNotEmpty) {
      final random = Random();
      final shuffled = List<dynamic>.from(_allRecipes)..shuffle(random);
      top.addAll(shuffled.take(10).map((r) => r as Map<String, dynamic>).toList());
    }

    setState(() {
      _results = top;
    });
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(recipe['TranslatedRecipeName'] ?? 'Recipe'),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (recipe['image-url'] != null && recipe['image-url'].toString().trim().isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      recipe['image-url'].toString().trim(),
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
                Text(recipe['TranslatedIngredients'] ?? 'N/A'),
                const SizedBox(height: 12),
                const Text('Instructions:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text((recipe['TranslatedInstructions'] ?? 'N/A').replaceAll('\n', '\n\n')),
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
                MaterialPageRoute(builder: (context) => const AddRecipeScreen()),
              );
              if (result == true) {
                _loadRecipes();
                _controller.clear();
                setState(() {
                  _results = [];
                });
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
                          final name = r['TranslatedRecipeName'] ?? 'Recipe';
                          final img = r['image-url'] ?? '';
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
                              subtitle: isTop
                                  ? const Text('🏆 Best Match!', style: TextStyle(color: Colors.green))
                                  : null,
                              onTap: () => _showDetail(r),
                            ),
                          );
                        },
                      ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: Navbar(index: 1),
    );
  }
}

class _NormalizedRecipe {
  final dynamic recipe;
  final Set<String> tokens;
  _NormalizedRecipe({required this.recipe, required this.tokens});
}

class _ScoredItem {
  final Map<String, dynamic> recipe;
  final double score;
  final int matched;
  final int total;
  _ScoredItem({required this.recipe, required this.score, required this.matched, required this.total});
}