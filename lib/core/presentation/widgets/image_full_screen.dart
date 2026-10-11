import 'package:flutter/material.dart';
import 'package:opennutritracker/core/presentation/widgets/food_image.dart';
import 'package:opennutritracker/core/utils/food_image_loader.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';

class ImageFullScreen extends StatelessWidget {
  static const fullScreenHeroTag = 'fullScreenTag';
  const ImageFullScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final args =
        ModalRoute.of(context)!.settings.arguments as ImageFullScreenArguments;
    return Scaffold(
      appBar: AppBar(backgroundColor: Colors.transparent),
      body: SafeArea(
        top: false,
        child: Semantics(
          identifier: 'food-image-fullscreen',
          child: InteractiveViewer(
            child: Hero(
              tag: fullScreenHeroTag,
              child: FoodImage(
                meal: args.meal,
                mode: FoodImageMode.fullSize,
                width: double.infinity,
                height: double.infinity,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ImageFullScreenArguments {
  final MealEntity meal;
  ImageFullScreenArguments(this.meal);
}
