import 'package:flutter/material.dart';
import '../legal_content.dart';

/// Shows a full legal document (Privacy Policy / Terms of Service) in a
/// scrollable in-app dialog with a close button — the user reads it right
/// there, without leaving the flow.
Future<void> showLegalDialog(
  BuildContext context, {
  required String title,
  required List<LegalSection> sections,
}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: double.maxFinite,
        child: Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: sections.length,
            separatorBuilder: (_, _) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final section = sections[i];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    section.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    section.body,
                    style: const TextStyle(fontSize: 13.5, height: 1.45),
                  ),
                ],
              );
            },
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}
