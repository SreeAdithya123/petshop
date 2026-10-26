import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../theme/app_theme.dart';
import '../../widgets/content_width.dart';
import '../../widgets/role_shell.dart';
import '../../widgets/shared_widgets.dart';
import 'legal_text.dart';

/// A full-screen reader for a [LegalDocument]: title, effective date, the
/// sections, and links to the sibling document and to Support.
class LegalDocumentScreen extends StatelessWidget {
  final LegalDocument document;

  /// Label and route of the "other" legal page, shown as a link at the end.
  final String otherLabel;
  final String otherPath;

  const LegalDocumentScreen({
    super.key,
    required this.document,
    required this.otherLabel,
    required this.otherPath,
  });

  @override
  Widget build(BuildContext context) {
    return RoleShell(
      title: document.title,
      child: SingleChildScrollView(
        padding: kScreenPadding,
        child: ContentWidth(
          maxWidth: 680,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(
                header: true,
                child: Text(document.title, style: AppTheme.display(fontSize: 26, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 4),
              Text(
                'Effective $kLegalEffectiveDate',
                style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft),
              ),
              const SizedBox(height: 16),
              Text(document.intro, style: AppTheme.body(fontSize: 15.5)),
              for (final section in document.sections) _SectionView(section: section),
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                ),
                child: Text(kLegalReviewNote, style: AppTheme.body(fontSize: 13, color: AppColors.inkSoft)),
              ),
              const SizedBox(height: 12),
              Wrap(
                children: [
                  TextButton(
                    onPressed: () => context.push(otherPath),
                    style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                    child: Text(otherLabel),
                  ),
                  TextButton(
                    onPressed: () => context.push('/support'),
                    style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                    child: const Text('Contact support'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionView extends StatelessWidget {
  final LegalSection section;
  const _SectionView({required this.section});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(section.heading, style: AppTheme.display(fontSize: 18)),
          ),
          for (final paragraph in section.paragraphs)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(paragraph, style: AppTheme.body(fontSize: 15, color: AppColors.ink)),
            ),
          for (final bullet in section.bullets)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 8, right: 10, left: 4),
                    child: ExcludeSemantics(child: Icon(Icons.circle, size: 6, color: AppColors.inkSoft)),
                  ),
                  Expanded(child: Text(bullet, style: AppTheme.body(fontSize: 15, color: AppColors.ink))),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
