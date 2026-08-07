import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import '../legal_content.dart';
import 'legal_dialog.dart';

/// "I agree to the Privacy Policy and Terms of Service" checkbox where the two
/// policy names are tappable and open the full text in an in-app dialog.
class TermsCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const TermsCheckbox({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Checkbox(
          value: value,
          onChanged: (v) => onChanged(v ?? false),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 13.5,
                  color: theme.colorScheme.onSurface,
                  height: 1.4,
                ),
                children: [
                  const TextSpan(text: 'I agree to the '),
                  TextSpan(
                    text: 'Privacy Policy',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => showLegalDialog(
                            context,
                            title: 'Privacy Policy',
                            sections: privacyPolicySections,
                          ),
                  ),
                  const TextSpan(text: ' and '),
                  TextSpan(
                    text: 'Terms of Service',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.underline,
                    ),
                    recognizer: TapGestureRecognizer()
                      ..onTap = () => showLegalDialog(
                            context,
                            title: 'Terms of Service',
                            sections: termsSections,
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
