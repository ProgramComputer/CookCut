import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../../theme/app_theme.dart';

/// A platform-aware page widget that adapts between Material and Cupertino styling
class PlatformPage extends StatelessWidget {
  final String title;
  final List<Widget>? actions;
  final Widget body;
  final Widget? floatingActionButton;
  final bool useCupertino;
  final Color? backgroundColor;
  final Widget? leading;
  final bool automaticallyImplyLeading;

  const PlatformPage({
    super.key,
    required this.title,
    required this.body,
    this.actions,
    this.floatingActionButton,
    this.useCupertino = false,
    this.backgroundColor,
    this.leading,
    this.automaticallyImplyLeading = true,
  });

  @override
  Widget build(BuildContext context) {
    if (useCupertino) {
      return _buildCupertinoPage(context);
    } else {
      return _buildMaterialPage(context);
    }
  }

  Widget _buildCupertinoPage(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
      navigationBar: CupertinoNavigationBar(
        middle: Text(title),
        leading: leading ?? (automaticallyImplyLeading ? _buildBackButton(context) : null),
        trailing: actions != null && actions!.isNotEmpty
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: actions!,
              )
            : null,
        backgroundColor: backgroundColor ?? Theme.of(context).scaffoldBackgroundColor,
        border: null, // Remove the bottom border for a cleaner look
      ),
      child: SafeArea(
        child: Stack(
          children: [
            body,
            if (floatingActionButton != null)
              Positioned(
                right: AppTheme.spaceLG,
                bottom: AppTheme.spaceLG,
                child: floatingActionButton!,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMaterialPage(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(title),
        actions: actions,
        leading: leading,
        automaticallyImplyLeading: automaticallyImplyLeading,
      ),
      body: body,
      floatingActionButton: floatingActionButton,
    );
  }

  Widget? _buildBackButton(BuildContext context) {
    final ModalRoute<dynamic>? parentRoute = ModalRoute.of(context);
    if (parentRoute?.canPop ?? false) {
      return CupertinoButton(
        padding: EdgeInsets.zero,
        child: const Icon(CupertinoIcons.back),
        onPressed: () => Navigator.of(context).maybePop(),
      );
    }
    return null;
  }
} 