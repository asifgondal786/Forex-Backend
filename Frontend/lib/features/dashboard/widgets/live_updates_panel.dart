import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/models/live_update.dart';
import '../../../services/live_update_service.dart';
import '../../../core/theme/app_colors.dart';

class LiveUpdatesPanel extends StatefulWidget {
  final String taskId;

  const LiveUpdatesPanel({
    super.key,
    required this.taskId,
  });

  @override
  State<LiveUpdatesPanel> createState() => _LiveUpdatesPanelState();
}

class _LiveUpdatesPanelState extends State<LiveUpdatesPanel> {
  final LiveUpdateService _liveUpdateService = LiveUpdateService();
  final List<LiveUpdate> _updates = [];
  final ScrollController _scrollController = ScrollController();
  ConnectionStatus _connectionStatus = ConnectionStatus.disconnected;

  @override
  void initState() {
    super.initState();
    _connectToUpdates();
  }

  void _connectToUpdates() {
    // Listen to connection status
    _liveUpdateService.connectionStatus.listen((status) {
      if (mounted) {
        setState(() {
          _connectionStatus = status;
        });
      }
    });

    // Listen to updates
    _liveUpdateService.updates.listen((update) {
      if (mounted && update.taskId == widget.taskId) {
        setState(() {
          _updates.insert(0, update);
          // Keep only last 50 updates
          if (_updates.length > 50) {
            _updates.removeLast();
          }
        });
        
        // Auto-scroll to top when new update arrives
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      }
    });

    // Connect to the task
    _liveUpdateService.connect(widget.taskId);
  }

  @override
  void didUpdateWidget(LiveUpdatesPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.taskId != widget.taskId) {
      _updates.clear();
      _liveUpdateService.connect(widget.taskId);
    }
  }

  @override
  void dispose() {
    _liveUpdateService.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Live Updates',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Row(
                  children: [
                    _buildConnectionIndicator(),
                    const SizedBox(width: 12),
                    IconButton(
                      icon: const Icon(Icons.more_vert, size: 20),
                      onPressed: () {},
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Updates List
          Container(
            height: 400,
            padding: const EdgeInsets.all(16),
            child: _updates.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: _updates.length,
                    itemBuilder: (context, index) {
                      final update = _updates[index];
                      return _UpdateItem(update: update);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionIndicator() {
    Color color;
    String label;
    
    switch (_connectionStatus) {
      case ConnectionStatus.connected:
        color = Colors.green;
        label = 'Connected';
        break;
      case ConnectionStatus.connecting:
        color = Colors.orange;
        label = 'Connecting';
        break;
      case ConnectionStatus.reconnecting:
        color = Colors.orange;
        label = 'Reconnecting';
        break;
      case ConnectionStatus.disconnected:
        color = Colors.red;
        label = 'Disconnected';
        break;
    }

    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none,
            size: 48,
            color: Colors.grey.shade400,
          ),
          const SizedBox(height: 16),
          Text(
            'No updates yet',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Updates will appear here as the task progresses',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }
}

class _UpdateItem extends StatelessWidget {
  final LiveUpdate update;

  const _UpdateItem({required this.update});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildIcon(),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  update.message,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatTime(update.timestamp),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                if (update.progress != null) ...[
                  const SizedBox(height: 8),
                  _buildProgressBar(update.progress!),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIcon() {
    IconData icon;
    Color color;

    switch (update.type) {
      case UpdateType.success:
        icon = Icons.check_circle;
        color = Colors.green;
        break;
      case UpdateType.error:
        icon = Icons.error;
        color = Colors.red;
        break;
      case UpdateType.warning:
        icon = Icons.warning;
        color = Colors.orange;
        break;
      case UpdateType.progress:
        icon = Icons.hourglass_empty;
        color = Colors.blue;
        break;
      case UpdateType.info:
      default:
        icon = Icons.info;
        color = Colors.blue;
        break;
    }

    return Icon(icon, color: color, size: 20);
  }

  Widget _buildProgressBar(double progress) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey.shade200,
            valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primaryGreen),
            minHeight: 6,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${(progress * 100).toInt()}%',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inSeconds < 60) {
      return 'Just now';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else {
      return '${timestamp.day}/${timestamp.month} ${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    }
  }
}