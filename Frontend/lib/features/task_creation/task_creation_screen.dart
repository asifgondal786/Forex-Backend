import 'package:flutter/material.dart';
import 'package:forex_companion/config/theme.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/widgets/app_background.dart';
import '../../core/models/task.dart';
import '../../providers/task_provider.dart';
import '../../services/gemini_service.dart';

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
        debugPrint('⚠️ Please enter a task title first');
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
        debugPrint('✅ AI enhanced your task!');
      }
    } catch (e) {
      if (mounted) {
        debugPrint('❌ AI enhancement failed: $e');
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
      );

      if (mounted) {
        debugPrint('✅ Task created successfully!');
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        debugPrint('❌ Failed to create task: $e');
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 720;
    final isWide = screenWidth >= 1100;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AppBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                _buildHeader(isMobile),
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 16 : 24,
                        vertical: 24,
                      ),
                      child: Form(
                        key: _formKey,
                        child: isWide
                            ? Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(child: _buildFormColumn()),
                                  const SizedBox(width: 24),
                                  SizedBox(
                                    width: 360,
                                    child: _buildAiCompanionPanel(),
                                  ),
                                ],
                              )
                            : Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildFormColumn(),
                                  const SizedBox(height: 24),
                                  _buildAiCompanionPanel(),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 16 : 24,
        vertical: 18,
      ),
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
          const SizedBox(width: 8),
          Container(
            width: isMobile ? 44 : 56,
            height: isMobile ? 44 : 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryBlue.withOpacity(0.35),
                  blurRadius: 14,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.asset(
                'assets/images/companion_logo.png',
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Create New Task',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'U Sleep, I Work (Earn) For U · AI-powered task creation',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ],
            ),
          ),
          if (!isMobile)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.white.withOpacity(0.12)),
              ),
              child: Row(
                children: const [
                  Icon(Icons.auto_awesome, size: 16, color: Colors.white70),
                  SizedBox(width: 6),
                  Text(
                    'ML + DL Enabled',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFormColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionIntro(),
        const SizedBox(height: 16),
        _buildSectionCard(
          title: 'Task Blueprint',
          subtitle: 'Define what the companion should watch and execute.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTitleField(),
              const SizedBox(height: 16),
              _buildAiEnhanceButton(),
              const SizedBox(height: 16),
              _buildDescriptionField(),
              const SizedBox(height: 16),
              _buildPrioritySelector(),
            ],
          ),
        ),
        if (_aiSuggestion != null) ...[
          const SizedBox(height: 16),
          _buildAiInsights(),
        ],
        const SizedBox(height: 16),
        _buildSectionCard(
          title: 'Example Tasks',
          subtitle: 'Tap to auto-fill with AI enhancement.',
          child: _buildExampleTasksBody(),
        ),
        const SizedBox(height: 20),
        _buildCreateButton(),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildSectionIntro() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(18),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withAlpha(28)),
      ),
      child: Row(
        children: const [
          Icon(Icons.psychology_alt, color: Colors.white70),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Tell the AI what to watch, learn, and execute. It will monitor charts, news, and signals in real time.',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.08),
            Colors.white.withOpacity(0.03),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(
              color: Colors.white.withOpacity(0.7),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 16),
          child,
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
      child: ElevatedButton.icon(
        onPressed: _isAiEnhancing ? null : _getAiSuggestion,
        icon: _isAiEnhancing
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Icons.auto_awesome, size: 20),
        label: Text(_isAiEnhancing ? 'AI is analyzing...' : '✨ Enhance with AI'),
        style: AppTheme.glassElevatedButtonStyle(
          tintColor: const Color(0xFF3B82F6),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          borderRadius: 12,
          elevation: 4,
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
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _buildPriorityChip(TaskPriority.low, 'Low', AppColors.priorityLow),
            _buildPriorityChip(
              TaskPriority.medium,
              'Medium',
              AppColors.priorityMedium,
            ),
            _buildPriorityChip(TaskPriority.high, 'High', AppColors.priorityHigh),
          ],
        ),
      ],
    );
  }

  Widget _buildPriorityChip(TaskPriority priority, String label, Color color) {
    final isSelected = _selectedPriority == priority;
    return GestureDetector(
      onTap: () => setState(() => _selectedPriority = priority),
      child: Container(
        constraints: const BoxConstraints(minWidth: 110),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 18),
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
        _buildExampleTasksBody(),
      ],
    );
  }

  Widget _buildExampleTasksBody() {
    final examples = [
      'Analyze GBP/JPY for swing trading',
      'Monitor USD/CHF support levels',
      'Generate daily EUR/USD signals',
      'Track news impact on EUR/USD sentiment',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white.withAlpha(26)),
                  ),
                  child: Row(
                    children: [ // This part cannot be const due to `example`
                      Icon(Icons.lightbulb_outline,
                          color: Colors.white.withAlpha(160), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          example,
                          style: TextStyle(color: Colors.white.withAlpha(200)),
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

  Widget _buildAiCompanionPanel() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'AI Companion Mode',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'ML + DL engines track charts, news, and learning signals so you stay ahead.',
            style: TextStyle(color: Colors.white.withOpacity(0.7), height: 1.4),
          ),
          const SizedBox(height: 16),
          _buildCapabilityRow(Icons.auto_graph, 'Adaptive signal scoring'),
          _buildCapabilityRow(Icons.radar, 'Real-time volatility watch'),
          _buildCapabilityRow(Icons.newspaper, 'News impact detection'),
          _buildCapabilityRow(Icons.school_outlined, 'Forex.com learning monitor'),
          _buildCapabilityRow(Icons.shield_outlined, 'Risk guardrails & alerts'),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF10B981).withOpacity(0.3),
              ),
            ),
            child: const Text(
              'U Sleep, I Work: The companion stays active and notifies you when markets shift.',
              style: TextStyle(
                color: Color(0xFF9AE6B4),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCapabilityRow(IconData icon, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: Colors.white70),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreateButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _isLoading ? null : _createTask,
        style: AppTheme.glassElevatedButtonStyle(
          tintColor: AppColors.primaryGreen,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          borderRadius: 12,
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
