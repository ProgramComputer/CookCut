import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../../../core/theme/app_theme.dart';

class LoadingOverlay extends StatelessWidget {
  final Widget child;
  final bool isLoading;
  final String? message;
  final bool useCupertino;

  const LoadingOverlay({
    super.key,
    required this.child,
    required this.isLoading,
    this.message,
    this.useCupertino = false,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        child,
        if (isLoading)
          Container(
            color: CupertinoColors.systemBackground.withOpacity(0.7),
            child: Center(
              child: useCupertino
                  ? CupertinoPopupSurface(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spaceLG,
                          vertical: AppTheme.spaceMD,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CupertinoActivityIndicator(radius: 16),
                            if (message != null) ...[
                              const SizedBox(height: AppTheme.spaceMD),
                              Text(
                                message!,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: CupertinoColors.label,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    )
                  : Card(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spaceLG,
                          vertical: AppTheme.spaceMD,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const CircularProgressIndicator(),
                            if (message != null) ...[
                              const SizedBox(height: AppTheme.spaceMD),
                              Text(message!),
                            ],
                          ],
                        ),
                      ),
                    ),
            ),
          ),
      ],
    );
  }
}
