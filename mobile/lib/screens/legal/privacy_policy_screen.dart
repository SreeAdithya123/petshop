import 'package:flutter/material.dart';

import 'legal_document_view.dart';
import 'legal_text.dart';

/// PETSTA's Privacy Policy (route /legal/privacy). The text lives in
/// legal_text.dart.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const LegalDocumentScreen(
      document: privacyPolicyDocument,
      otherLabel: 'Read the Terms of Use',
      otherPath: '/legal/terms',
    );
  }
}
