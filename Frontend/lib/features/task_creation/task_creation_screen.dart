import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/models/task.dart';
import '../../providers/task_provider.dart';
import '../../services/gemini_service.dart';
import '../../core/widgets/custom_snackbar.dart';

class TaskCreationScreen extends StatefulWidget {
  const TaskCreationScreen({super.key});

  @override
  State<TaskCreationScreen> createState() => _TaskCreationScreenState();
}

class _TaskCreationScreenState extends State<TaskCreationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final GeminiService _geminiService = GeminiService();
  
  TaskPriority _selectedPriority = TaskPriority.medium;
  bool _isLoading = false;
  bool _isAiEnhancing = false;
  Map<String, dynamic>? _aiSuggestion;

  Future<void> _getAiSuggestion() async {
    if (_titleController.text.trim().isEmpty) {
      if (mounted) {
        CustomSnackbar.warning(context, 'Please enter a task title first');
      }
      return;
    }

    setState(() => _isAiEnhancing = true);

    try {
      final suggestion =
          await _geminiService.generateTaskSuggestion(_titleController.text.trim());

      if (mounted) {
        setState(() {
          _aiSuggestion = suggestion;
          if (suggestion['description'] != null) {
            _descriptionController.text = suggestion['description'];
          }
          if (suggestion['priority'] != null) {
            final priority = suggestion['priority'].toLowerCase();
            if (priority == 'high') {
              _selectedPriority = TaskPriority.high;
            } else if (priority == 'low') {
              _selectedPriority = TaskPriority.low;
            } else {
              _selectedPriority = TaskPriority.medium;
            }
          }
        });
        CustomSnackbar.success(context, 'AI enhanced your task!');
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.error(context, 'AI enhancement failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() => _isAiEnhancing = false);
      }
    }
  }

  Future<void> _createTask() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final taskProvider = context.read<TaskProvider>();
      await taskProvider.createTask(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        priority: _selectedPriority,
        steps: _aiSuggestion?['steps']?.cast<String>(),
      );

      if (mounted) {
        CustomSnackbar.success(context, 'Task created successfully!');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        CustomSnackbar.error(context, 'Failed to create task: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.darkBlue, AppColors.lightBlue],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTitleField(),
                        const SizedBox(height: 24),
                        _buildAiEnhanceButton(),
                        const SizedBox(height: 24),
                        _buildDescriptionField(),
                        const SizedBox(height: 24),
                        _buildPrioritySelector(),
                        if (_aiSuggestion != null) ...[
                          const SizedBox(height: 24),
                          _buildAiInsights(),
                        ],
                        const SizedBox(height: 32),
                        _buildExampleTasks(),
                        const SizedBox(height: 32),
                        _buildCreateButton(),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(26),
        border: Border(bottom: BorderSide(color: Colors.white.withAlpha(51))),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(width: 12),
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Create New Task',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'AI-powered task creation',
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTitleField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Task Title',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _titleController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'e.g., Analyze EUR/USD trend',
            hintStyle: TextStyle(color: Colors.white.withAlpha(128)),
            filled: true,
            fillColor: Colors.white.withAlpha(26),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withAlpha(51)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withAlpha(51)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2),
            ),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter a task title';
            }
            if (value.trim().length < 3) {
              return 'Title must be at least 3 characters';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildAiEnhanceButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _isAiEnhancing ? null : _getAiSuggestion,
        icon: _isAiEnhancing
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.auto_awesome, size: 20),
        label: Text(_isAiEnhancing ? 'AI is analyzing...' : '✨ Enhance with AI'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: const BorderSide(color: AppColors.primaryGreen),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildDescriptionField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Description',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: _descriptionController,
          style: const TextStyle(color: Colors.white),
          maxLines: 4,
          decoration: InputDecoration(
            hintText: 'Describe what this task should accomplish...',
            hintStyle: TextStyle(color: Colors.white.withAlpha(128)),
            filled: true,
            fillColor: Colors.white.withAlpha(26),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withAlpha(51)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.white.withAlpha(51)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primaryGreen, width: 2),
            ),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter a description';
            }
            if (value.trim().length < 10) {
              return 'Description must be at least 10 characters';
            }
            return null;
          },
        ),
      ],
    );
  }

  Widget _buildPrioritySelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Priority',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _buildPriorityChip(TaskPriority.low, 'Low', AppColors.priorityLow),
            const SizedBox(width: 12),
            _buildPriorityChip(TaskPriority.medium, 'Medium', AppColors.priorityMedium),
            const SizedBox(width: 12),
            _buildPriorityChip(TaskPriority.high, 'High', AppColors.priorityHigh),
          ],
        ),
      ],
    );
  }

  Widget _buildPriorityChip(TaskPriority priority, String label, Color color) {
    final isSelected = _selectedPriority == priority;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedPriority = priority),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? color : Colors.white.withAlpha(26),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? color : Colors.white.withAlpha(51),
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAiInsights() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primaryGreen.withAlpha(26),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryGreen.withAlpha(77)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.lightbulb, color: AppColors.primaryGreen, size: 20),
              const SizedBox(width: 8),
              const Text(
                'AI Insights',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (_aiSuggestion?['recommendation'] != null) ...[
            const SizedBox(height: 12),
            Text(
              _aiSuggestion!['recommendation'],
              style: const TextStyle(color: Colors.white70, height: 1.4),
            ),
          ],
          if (_aiSuggestion?['estimatedDuration'] != null) ...[
            const SizedBox(height: 8),
            Text(
              '⏱️ Estimated: ${_aiSuggestion!['estimatedDuration']}',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
          if (_aiSuggestion?['riskLevel'] != null) ...[
            const SizedBox(height: 4),
            Text(
              '⚠️ Risk Level: ${_aiSuggestion!['riskLevel']}',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExampleTasks() {
    final examples = [
      'Analyze GBP/JPY for swing trading',
      'Monitor USD/CHF support levels',
      'Generate daily EUR/USD signals',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Example Tasks',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        ...examples.map((example) => Padding( // This part cannot be const due to `_getAiSuggestion`
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () {
                  _titleController.text = example;
                  _getAiSuggestion();
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(13),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withAlpha(26)),
                  ),
                  child: Row(
                    children: [ // This part cannot be const due to `example`
                      Icon(Icons.lightbulb_outline,
                          color: Colors.white.withAlpha(128), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          example,
                          style: TextStyle(color: Colors.white.withAlpha(179)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )),
      ],
    );
  }

  Widget _buildCreateButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _createTask,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryGreen,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(Colors.white),
                ),
              )
            : const Text(
                'Create Task',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}