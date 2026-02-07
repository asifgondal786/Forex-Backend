import 'package:flutter/material.dart';
import 'package:forex_companion/config/theme.dart';
import 'package:provider/provider.dart';
import '../../../providers/task_provider.dart';
import '../../../core/models/task.dart';

class CreateTaskDialog extends StatefulWidget {
  const CreateTaskDialog({super.key});

  @override
  State<CreateTaskDialog> createState() => _CreateTaskDialogState();
}

class _CreateTaskDialogState extends State<CreateTaskDialog> {
  final _formKey = GlobalKey<FormState>();
  
  String _title = '';
  String _description = '';
  TaskPriority _priority = TaskPriority.medium;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        children: [
          Icon(Icons.auto_awesome, color: Theme.of(context).primaryColor),
          const SizedBox(width: 8),
          const Text('Assign New AI Task'),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Create a new AI-powered task',
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 20),
              
              // Title field
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Task Title',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.title),
                ),
                onChanged: (value) => _title = value,
                validator: (value) => 
                    value?.isEmpty ?? true ? 'Title is required' : null,
              ),
              
              const SizedBox(height: 16),
              
              // Description field
              TextFormField(
                decoration: const InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.description),
                ),
                maxLines: 3,
                onChanged: (value) => _description = value,
              ),
              
              const SizedBox(height: 16),
              
              // Priority dropdown
              DropdownButtonFormField<TaskPriority>(
                value: _priority,
                decoration: const InputDecoration(
                  labelText: 'Priority',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.flag),
                ),
                items: TaskPriority.values.map((priority) {
                  return DropdownMenuItem(
                    value: priority,
                    child: Text(priority.name.toUpperCase()),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() => _priority = value);
                  }
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _submitTask,
          icon: const Icon(Icons.rocket_launch),
          label: const Text('Start Task'),
          style: AppTheme.glassElevatedButtonStyle(
            tintColor: const Color(0xFF10B981),
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }

  Future<void> _submitTask() async {
    if (!_formKey.currentState!.validate()) return;
    
    try {
      final taskProvider = context.read<TaskProvider>();
      
      await taskProvider.createTask(
        title: _title.isEmpty ? 'Market Analysis Task' : _title,
        description: _description.isEmpty 
            ? 'AI-powered market analysis' 
            : _description,
        priority: _priority,
      );
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('? Task started! Watch Live Updates panel'),
            backgroundColor: Color(0xFF10B981),
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('? Error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
