import 'package:flutter/material.dart';
import 'package:frontend_flutter/utils/media-query/size_config.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';

class LoadingAnim extends StatelessWidget {
  const LoadingAnim({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: LoadingAnimationWidget.halfTriangleDot(
        color: Theme.of(context).colorScheme.primary,
        size: SizeConfig.height * 0.06,
      ),
    );
  }
}
