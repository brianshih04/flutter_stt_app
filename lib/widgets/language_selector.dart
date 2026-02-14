import 'package:flutter/material.dart';
import '../constants/languages.dart';

class LanguageSelector extends StatelessWidget {
  final String currentLanguage;
  final Function(String) onLanguageChanged;

  const LanguageSelector({
    super.key,
    required this.currentLanguage,
    required this.onLanguageChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: DropdownButton<String>(
        value: currentLanguage,
        underline: const SizedBox(),
        icon: const Icon(Icons.language, size: 20),
        dropdownColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        isExpanded: true, // This prevents overflow
        isDense: true, // More compact
        items: Languages.all.map((language) {
          return DropdownMenuItem<String>(
            value: language.code,
            child: Text(
              language.displayName,
              style: const TextStyle(fontSize: 14),
              overflow: TextOverflow.ellipsis, // Prevent text overflow
            ),
          );
        }).toList(),
        onChanged: (value) {
          if (value != null) {
            onLanguageChanged(value);
          }
        },
      ),
    );
  }
}
