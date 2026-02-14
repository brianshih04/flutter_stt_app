import 'package:flutter/material.dart';

class RecordingButton extends StatelessWidget {
  final bool isListening;
  final VoidCallback onPressed;
  final bool isEnabled;

  const RecordingButton({
    super.key,
    required this.isListening,
    required this.onPressed,
    this.isEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isEnabled ? onPressed : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color:
              isListening ? Colors.red : Theme.of(context).colorScheme.primary,
          boxShadow: isListening
              ? [
                  BoxShadow(
                    color: Colors.red.withValues(alpha: 0.5),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ]
              : [
                  BoxShadow(
                    color: Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.3),
                    blurRadius: 10,
                    spreadRadius: 2,
                  ),
                ],
        ),
        child: Icon(
          isListening ? Icons.stop : Icons.mic,
          size: 40,
          color: Colors.white,
        ),
      ),
    );
  }
}
