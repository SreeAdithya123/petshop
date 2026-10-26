import 'package:flutter/material.dart';

import '../core/app_error.dart';
import '../theme/app_theme.dart';

/// Reusable building blocks so screen widgets don't each reinvent loading /
/// empty / error states. Mirrors the intent of the web app's EmptyState.jsx
/// and the ad-hoc "Loading…" / error strings used across its pages.

class LoadingView extends StatelessWidget {
  final String label;
  const LoadingView({super.key, this.label = 'Loading…'});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Semantics(
          liveRegion: true,
          label: label,
          child: ExcludeSemantics(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                ),
                const SizedBox(height: 12),
                Text(label, style: AppTheme.body(color: AppColors.inkSoft), textAlign: TextAlign.center),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Error state: an icon, a friendly [message] and (when [onRetry] is given) a
/// Retry button. Existing call sites that pass only `message:` keep working.
class ErrorView extends StatelessWidget {
  final String message;

  /// Shows a Retry button when non-null.
  final VoidCallback? onRetry;
  final String retryLabel;
  final IconData icon;

  const ErrorView({
    super.key,
    required this.message,
    this.onRetry,
    this.retryLabel = 'Retry',
    this.icon = Icons.error_outline,
  });

  /// Builds the view from a thrown [error], turning it into friendly text
  /// (and a wifi-off icon for connectivity problems).
  factory ErrorView.fromError(Object error, {Key? key, VoidCallback? onRetry, String retryLabel = 'Retry'}) {
    return ErrorView(
      key: key,
      message: friendlyError(error),
      onRetry: onRetry,
      retryLabel: retryLabel,
      icon: isNetworkError(error) ? Icons.wifi_off_rounded : Icons.error_outline,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Semantics(
          container: true,
          liveRegion: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 36, color: AppColors.inkSoft),
              const SizedBox(height: 12),
              Text(
                message,
                style: AppTheme.body(color: AppColors.error),
                textAlign: TextAlign.center,
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: Text(retryLabel),
                  style: OutlinedButton.styleFrom(minimumSize: const Size(0, 48)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final String title;
  final String? description;
  final Widget? action;

  const EmptyState({
    super.key,
    required this.title,
    this.description,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              container: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: AppTheme.display(fontSize: 18),
                    textAlign: TextAlign.center,
                  ),
                  if (description != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      description!,
                      style: AppTheme.body(color: AppColors.inkSoft),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 20),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

class StatusPill extends StatelessWidget {
  final String status;
  final Color color;
  const StatusPill({super.key, required this.status, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status.replaceAll('_', ' '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AppTheme.body(fontSize: 12, fontWeight: FontWeight.w600, color: color),
      ),
    );
  }
}

/// Section heading used at the top of most screens.
class ScreenHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const ScreenHeader({super.key, required this.title, this.subtitle, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(title, style: AppTheme.display(fontSize: 24, fontWeight: FontWeight.w700)),
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(subtitle!, style: AppTheme.body(color: AppColors.inkSoft)),
              ],
            ],
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

const kScreenPadding = EdgeInsets.fromLTRB(16, 20, 16, 32);
