class RecipeOverlay {
  final String instruction; // The recipe step instruction
  final String? ingredient; // Optional ingredient being used
  final String? quantity; // Optional quantity (e.g., "2 cups")
  final double startTime; // When to show the overlay
  final double endTime; // When to hide the overlay
  final double x; // X position (0-1)
  final double y; // Y position (0-1)
  final String color; // Text color (hex)
  final String backgroundColor; // Background color (hex)
  final double backgroundOpacity; // Background opacity (0-1)
  final double fontSize; // Font size
  final String fontFamily; // Font family
  final bool showIcon; // Whether to show a cooking icon
  final String? iconType; // Type of icon (e.g., 'stir', 'chop', 'heat')

  const RecipeOverlay({
    required this.instruction,
    this.ingredient,
    this.quantity,
    required this.startTime,
    required this.endTime,
    required this.x,
    required this.y,
    this.color = '#FFFFFF',
    this.backgroundColor = '#000000',
    this.backgroundOpacity = 0.7,
    this.fontSize = 24,
    this.fontFamily = 'Arial',
    this.showIcon = true,
    this.iconType,
  });

  Map<String, dynamic> toJson() => {
        'instruction': instruction,
        'ingredient': ingredient,
        'quantity': quantity,
        'startTime': startTime,
        'endTime': endTime,
        'x': x,
        'y': y,
        'color': color,
        'backgroundColor': backgroundColor,
        'backgroundOpacity': backgroundOpacity,
        'fontSize': fontSize,
        'fontFamily': fontFamily,
        'showIcon': showIcon,
        'iconType': iconType,
      };

  factory RecipeOverlay.fromJson(Map<String, dynamic> json) => RecipeOverlay(
        instruction: json['instruction'],
        ingredient: json['ingredient'],
        quantity: json['quantity'],
        startTime: json['startTime'],
        endTime: json['endTime'],
        x: json['x'],
        y: json['y'],
        color: json['color'],
        backgroundColor: json['backgroundColor'],
        backgroundOpacity: json['backgroundOpacity'],
        fontSize: json['fontSize'],
        fontFamily: json['fontFamily'],
        showIcon: json['showIcon'],
        iconType: json['iconType'],
      );
}
