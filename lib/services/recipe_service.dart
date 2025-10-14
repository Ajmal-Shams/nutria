// 📁 lib/services/recipe_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;

/// Model for recipe data
class Recipe {
  final String title;
  final String instructions;
  final String image;
  final String source;
  final List<String> ingredients;

  Recipe({
    required this.title,
    required this.instructions,
    required this.image,
    required this.source,
    required this.ingredients,
  });
}

/// Combined recipe service (TheMealDB + API Ninjas + Open Data + Auto-correct)
class RecipeService {
  // Replace with your API Ninjas key
  static const _apiNinjasKey = "Z0WK5d6cz9BOAGz/Z3SIYQ==w8hoxhwcR9xzFJEu";

  /// 🔤 1️⃣ Auto-correct using Datamuse API
  static Future<String> getAutoCorrect(String query) async {
    final url = Uri.parse("https://api.datamuse.com/sug?s=$query");
    final res = await http.get(url);

    if (res.statusCode == 200) {
      final List data = jsonDecode(res.body);
      if (data.isNotEmpty) return data.first['word'];
    }
    return query;
  }

  /// 🍛 2️⃣ TheMealDB — main source (Indian + world cuisines)
  static Future<List<Recipe>> _fetchFromMealDB(String query) async {
    final url =
        Uri.parse("https://www.themealdb.com/api/json/v1/1/search.php?s=$query");
    final res = await http.get(url);

    if (res.statusCode != 200) return [];

    final data = jsonDecode(res.body);
    final meals = data['meals'];
    if (meals == null) return [];

    return meals.map<Recipe>((m) {
      List<String> ingredients = [];
      for (int i = 1; i <= 20; i++) {
        final ing = m['strIngredient$i'];
        if (ing != null && ing.toString().trim().isNotEmpty) {
          ingredients.add(ing);
        }
      }
      return Recipe(
        title: m['strMeal'] ?? '',
        instructions: m['strInstructions'] ?? '',
        image: m['strMealThumb'] ?? '',
        source: 'TheMealDB',
        ingredients: ingredients,
      );
    }).toList();
  }

  /// 🍲 3️⃣ API Ninjas — for more variety
  static Future<List<Recipe>> _fetchFromApiNinjas(String query) async {
    final url = Uri.parse("https://api.api-ninjas.com/v1/recipe?query=$query");
    final res = await http.get(url, headers: {
      "X-Api-Key": _apiNinjasKey,
    });

    if (res.statusCode != 200) return [];

    final List data = jsonDecode(res.body);
    return data.map<Recipe>((m) {
      return Recipe(
        title: m['title'] ?? '',
        instructions: m['instructions'] ?? '',
        image: "",
        source: 'API Ninjas',
        ingredients: (m['ingredients'] ?? '').toString().split(", "),
      );
    }).toList();
  }

  /// 🥘 4️⃣ Free Open Recipe Dataset (GitHub public JSON mirror)
  static Future<List<Recipe>> _fetchFromOpenSource(String query) async {
    try {
      final url = Uri.parse(
          "https://raw.githubusercontent.com/mk-5/Recipe-dataset/main/recipes-en.json");
      final res = await http.get(url);

      if (res.statusCode != 200) return [];

      final List data = jsonDecode(res.body);
      final filtered = data.where((r) =>
          (r['title'] ?? '').toString().toLowerCase().contains(query.toLowerCase()) ||
          (r['ingredients'] ?? '').toString().toLowerCase().contains(query.toLowerCase()));

      return filtered.map<Recipe>((r) {
        return Recipe(
          title: r['title'] ?? '',
          instructions: r['instructions'] ?? '',
          image: r['image'] ?? '',
          source: 'OpenDataset',
          ingredients:
              (r['ingredients'] ?? '').toString().split(",").map((e) => e.trim()).toList(),
        );
      }).toList();
    } catch (e) {
      return [];
    }
  }

  /// 🍽️ 5️⃣ Main combined recipe search (auto-correct + multi-source)
  static Future<List<Recipe>> searchRecipes(String query) async {
    if (query.trim().isEmpty) return [];

    // Step 1: Auto-correct query
    final correctedQuery = await getAutoCorrect(query);

    // Step 2: Fetch in parallel
    final results = await Future.wait([
      _fetchFromMealDB(correctedQuery),
      _fetchFromApiNinjas(correctedQuery),
      _fetchFromOpenSource(correctedQuery),
    ]);

    // Step 3: Merge & remove duplicates
    final allRecipes = <Recipe>[];
    final seenTitles = <String>{};

    for (var list in results) {
      for (var r in list) {
        final titleKey = r.title.toLowerCase();
        if (!seenTitles.contains(titleKey)) {
          seenTitles.add(titleKey);
          allRecipes.add(r);
        }
      }
    }

    // Step 4: Prioritize Indian cuisine
    allRecipes.sort((a, b) {
      final aIndian = a.title.toLowerCase().contains("indian") ? 1 : 0;
      final bIndian = b.title.toLowerCase().contains("indian") ? 1 : 0;
      return bIndian.compareTo(aIndian);
    });

    return allRecipes;
  }
}
