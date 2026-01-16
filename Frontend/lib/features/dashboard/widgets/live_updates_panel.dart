import 'package:flutter/material.dart';
import 'package:tajir/core/models/live_update.dart';
import 'package:tajir/services/live_update_service.dart';
import 'package:tajir/core/theme/app_colors.dart';

// This widget is now stateful to manage the LiveUpdateService lifecycle.
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
  // The service is now part of the widget's state.
  late final LiveUpdateService _liveUpdateService;
  final List<LiveUpdate> _updates = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Initialize the service and connect to the WebSocket.
    _liveUpdateService = LiveUpdateService();
    _liveUpdateService.connect(widget.taskId);

    // Listen to the stream of updates.
    _liveUpdateService.updates.listen((update) {
      if (mounted) {
        setState(() {
          // Add new updates to the top of the list.
          _updates.insert(0, update);
        });
        // Animate to the top of the list when a new message arrives.
        _scrollToTop();
      }
    });
  }

  @override
  void didUpdateWidget(covariant LiveUpdatesPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the taskId changes (e.g., user selects a different task),
    // reconnect the service to the new task.
    if (widget.taskId != oldWidget.taskId) {
      _liveUpdateService.connect(widget.taskId);
      // Clear old updates when switching tasks.
      setState(() {
        _updates.clear();
      });
    }
  }

  @override
  void dispose() {
    // It's crucial to dispose of the service to close connections and timers.
    _liveUpdateService.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.sidebarDark.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with reactive connection status
          StreamBuilder<ConnectionStatus>(
            stream: _liveUpdateService.connectionStatus,
            builder: (context, snapshot) {
              final status = snapshot.data ?? ConnectionStatus.disconnected;
              return _buildHeader(status);
            },
          ),
          const SizedBox(height: 16),
          const Divider(color: Colors.white24),
          const SizedBox(height: 16),
          // List of live updates
          Expanded(
            child: _updates.isEmpty
                ? const Center(
                    child: Text(
                      'Waiting for live updates...',
                      style: TextStyle(color: Colors.white70),
                    ),
                  )
                : ListView.builder(
                    controller: _scrollController,
                    itemCount: _updates.length,
                    itemBuilder: (context, index) {
                      return _buildUpdateTile(_updates[index]);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(ConnectionStatus status) {
    IconData icon;
    Color color;
    String text;

    switch (status) {
      case ConnectionStatus.connected:
        icon = Icons.check_circle;
        color = AppColors.primaryGreen;
        text = 'Live';
        break;
      case ConnectionStatus.connecting:
      case ConnectionStatus.reconnecting:
        icon = Icons.sync;
        color = Colors.orange;
        text = 'Connecting';
        break;
      case ConnectionStatus.disconnected:
        icon = Icons.error_outline;
        color = AppColors.stopButton;
        text = 'Disconnected';
        break;
    }

    return Row(
      children: [
        const Text(
          'Live Updates',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 16),
              const SizedBox(width: 6),
              Text(
                text,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUpdateTile(LiveUpdate update) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_getIconForType(update.type), color: Colors.white54, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  update.message,
                  style: const TextStyle(color: Colors.white, height: 1.4),
                ),
                const SizedBox(height: 4),
                Text(
                  // A helper to format time nicely would be good here
                  '${DateTime.now().difference(update.timestamp).inSeconds}s ago',
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _getIconForType(UpdateType type) {
    switch (type) {
      case UpdateType.progress:
        return Icons.hourglass_empty;
      case UpdateType.success:
        return Icons.check_circle_outline;
      case UpdateType.error:
        return Icons.error_outline;
      case UpdateType.warning:
        return Icons.warning_amber_outlined;
      case UpdateType.info:
      default:
        return Icons.info_outline;
    }
  }
}