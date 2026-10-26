import 'package:flutter/material.dart';

import 'legal_document_view.dart';
import 'legal_text.dart';

/// PETSTA's Terms of Use (route /legal/terms). The text lives in
/// legal_text.dart.
class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalDocumentScreen(
      document: termsDocument,
      otherLabel: 'Read the Privacy Policy',
      otherPath: '/legal/privacy',
    );
  }
}
