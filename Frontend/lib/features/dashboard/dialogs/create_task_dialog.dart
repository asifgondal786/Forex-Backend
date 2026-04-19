import 'package:flutter/material.dart';

class CreateTaskDialog extends StatefulWidget {
  const CreateTaskDialog({super.key});

  @override
  State<CreateTaskDialog> createState() => _CreateTaskDialogState();
}

class _CreateTaskDialogState extends State<CreateTaskDialog> {
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Task Creation Removed'),
      content: const Text(
        'Task creation was archived in the minimal rebuild. Use the Agent tab for automation controls instead.',
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

