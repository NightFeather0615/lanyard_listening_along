import 'package:flutter/material.dart';


class ErrorMessage extends StatelessWidget {
  const ErrorMessage({
    super.key,
    required this.title,
    this.description,
    this.actionName = "Refresh",
    this.onAction
  });

  final String title;
  final InlineSpan? description;
  final String actionName;
  final void Function()? onAction;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16
              ),
            ),
            if (description != null) Text.rich(
              description!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14
              ),
            ),
            if (onAction != null) Padding(
              padding: const EdgeInsets.only(top: 10),
              child: OutlinedButton(
                onPressed: onAction,
                child: Text(
                  actionName,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14
                  ),
                )
              ),
            )
          ],
        ),
      ),
    );
  }
}
