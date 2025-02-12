class RecipeAnalysis {
  final Recipe recipe;
  final List<FrameAnalysis> frameAnalyses;
  final bool success;

  RecipeAnalysis({
    required this.recipe,
    required this.frameAnalyses,
    required this.success,
  });

  factory RecipeAnalysis.fromJson(Map<String, dynamic> json) {
    return RecipeAnalysis(
      success: json['success'] ?? false,
      recipe: Recipe.fromJson(json['recipe']),
      frameAnalyses: (json['frameAnalyses'] as List)
          .map((e) => FrameAnalysis.fromJson(e))
          .toList(),
    );
  }
}

class Recipe {
  final String title;
  final EstimatedTime estimatedTime;
  final String difficulty;
  final List<Ingredient> ingredients;
  final List<String> equipment;
  final List<RecipeStep> steps;
  final List<String> tips;
  final List<String> variations;

  Recipe({
    required this.title,
    required this.estimatedTime,
    required this.difficulty,
    required this.ingredients,
    required this.equipment,
    required this.steps,
    required this.tips,
    required this.variations,
  });

  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      title: json['title'],
      estimatedTime: EstimatedTime.fromJson(json['estimatedTime']),
      difficulty: json['difficulty'],
      ingredients: (json['ingredients'] as List)
          .map((e) => Ingredient.fromJson(e))
          .toList(),
      equipment: List<String>.from(json['equipment']),
      steps:
          (json['steps'] as List).map((e) => RecipeStep.fromJson(e)).toList(),
      tips: List<String>.from(json['tips']),
      variations: List<String>.from(json['variations']),
    );
  }
}

class EstimatedTime {
  final String prep;
  final String cook;
  final String total;

  EstimatedTime({
    required this.prep,
    required this.cook,
    required this.total,
  });

  factory EstimatedTime.fromJson(Map<String, dynamic> json) {
    return EstimatedTime(
      prep: json['prep'],
      cook: json['cook'],
      total: json['total'],
    );
  }
}

class Ingredient {
  final String item;
  final String amount;
  final String unit;
  final String? notes;

  Ingredient({
    required this.item,
    required this.amount,
    required this.unit,
    this.notes,
  });

  factory Ingredient.fromJson(Map<String, dynamic> json) {
    return Ingredient(
      item: json['item'],
      amount: json['amount'],
      unit: json['unit'],
      notes: json['notes'],
    );
  }
}

class RecipeStep {
  final int number;
  final String instruction;
  final int timestamp;
  final String? technique;
  final String? tip;

  RecipeStep({
    required this.number,
    required this.instruction,
    required this.timestamp,
    this.technique,
    this.tip,
  });

  factory RecipeStep.fromJson(Map<String, dynamic> json) {
    return RecipeStep(
      number: json['number'],
      instruction: json['instruction'],
      timestamp: json['timestamp'],
      technique: json['technique'],
      tip: json['tip'],
    );
  }
}

class FrameAnalysis {
  final int timestamp;
  final List<String> ingredients;
  final String technique;
  final String? measurements;
  final List<String> equipment;

  FrameAnalysis({
    required this.timestamp,
    required this.ingredients,
    required this.technique,
    this.measurements,
    required this.equipment,
  });

  factory FrameAnalysis.fromJson(Map<String, dynamic> json) {
    return FrameAnalysis(
      timestamp: json['timestamp'],
      ingredients: List<String>.from(json['ingredients']),
      technique: json['technique'],
      measurements: json['measurements'],
      equipment: List<String>.from(json['equipment']),
    );
  }
}
