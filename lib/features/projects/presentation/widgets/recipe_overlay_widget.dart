import 'package:flutter/material.dart';
import '../../data/models/recipe_analysis.dart';

class RecipeOverlayWidget extends StatelessWidget {
  final RecipeAnalysis analysis;
  final double videoProgress; // 0.0 to 1.0
  final double videoDuration;

  const RecipeOverlayWidget({
    Key? key,
    required this.analysis,
    required this.videoProgress,
    required this.videoDuration,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Find current step based on video progress
    final currentTime = (videoProgress * videoDuration).floor();
    final currentStep = analysis.recipe.steps.lastWhere(
      (step) => step.timestamp <= currentTime,
      orElse: () => analysis.recipe.steps.first,
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            analysis.recipe.title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          _buildTimeAndDifficulty(),
          const SizedBox(height: 16),
          Expanded(
            child: DefaultTabController(
              length: 4,
              child: Column(
                children: [
                  const TabBar(
                    tabs: [
                      Tab(text: 'Current Step'),
                      Tab(text: 'Ingredients'),
                      Tab(text: 'Equipment'),
                      Tab(text: 'All Steps'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        _buildCurrentStep(currentStep),
                        _buildIngredients(),
                        _buildEquipment(),
                        _buildAllSteps(currentStep),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeAndDifficulty() {
    return Row(
      children: [
        Icon(Icons.timer, color: Colors.white.withOpacity(0.7)),
        const SizedBox(width: 4),
        Text(
          'Prep: ${analysis.recipe.estimatedTime.prep}',
          style: TextStyle(color: Colors.white.withOpacity(0.7)),
        ),
        const SizedBox(width: 16),
        Icon(Icons.local_fire_department, color: Colors.white.withOpacity(0.7)),
        const SizedBox(width: 4),
        Text(
          'Cook: ${analysis.recipe.estimatedTime.cook}',
          style: TextStyle(color: Colors.white.withOpacity(0.7)),
        ),
        const SizedBox(width: 16),
        Icon(Icons.trending_up, color: Colors.white.withOpacity(0.7)),
        const SizedBox(width: 4),
        Text(
          analysis.recipe.difficulty,
          style: TextStyle(color: Colors.white.withOpacity(0.7)),
        ),
      ],
    );
  }

  Widget _buildCurrentStep(RecipeStep step) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Step ${step.number}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            step.instruction,
            style: const TextStyle(color: Colors.white),
          ),
          if (step.technique != null) ...[
            const SizedBox(height: 8),
            Text(
              'Technique: ${step.technique}',
              style: TextStyle(color: Colors.white.withOpacity(0.7)),
            ),
          ],
          if (step.tip != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Icon(Icons.lightbulb, color: Colors.yellow.withOpacity(0.7)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      step.tip!,
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIngredients() {
    return ListView.builder(
      itemCount: analysis.recipe.ingredients.length,
      itemBuilder: (context, index) {
        final ingredient = analysis.recipe.ingredients[index];
        return ListTile(
          leading: const Icon(Icons.check_circle_outline, color: Colors.white),
          title: Text(
            ingredient.item,
            style: const TextStyle(color: Colors.white),
          ),
          subtitle: Text(
            '${ingredient.amount} ${ingredient.unit}${ingredient.notes != null ? ' - ${ingredient.notes}' : ''}',
            style: TextStyle(color: Colors.white.withOpacity(0.7)),
          ),
        );
      },
    );
  }

  Widget _buildEquipment() {
    return ListView.builder(
      itemCount: analysis.recipe.equipment.length,
      itemBuilder: (context, index) {
        return ListTile(
          leading: const Icon(Icons.kitchen, color: Colors.white),
          title: Text(
            analysis.recipe.equipment[index],
            style: const TextStyle(color: Colors.white),
          ),
        );
      },
    );
  }

  Widget _buildAllSteps(RecipeStep currentStep) {
    return ListView.builder(
      itemCount: analysis.recipe.steps.length,
      itemBuilder: (context, index) {
        final step = analysis.recipe.steps[index];
        final isCurrentStep = step.number == currentStep.number;

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: isCurrentStep
                ? Colors.white.withOpacity(0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isCurrentStep
                      ? Colors.blue
                      : Colors.white.withOpacity(0.3),
                ),
                child: Center(
                  child: Text(
                    step.number.toString(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  step.instruction,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight:
                        isCurrentStep ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
