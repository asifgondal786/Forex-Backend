import 'package:flutter/material.dart';
import '../../../services/live_updates_service.dart';
import '../../../core/theme/app_colors.dart';

class LiveUpdatesPanel extends StatefulWidget {
  final String userId;
  
  const LiveUpdatesPanel({
    Key? key,
    required this.userId,
  }) : super(key: key);

  @override
  State<LiveUpdatesPanel> createState() => _LiveUpdatesPanelState();
}

class _LiveUpdatesPanelState extends State<LiveUpdatesPanel> {
  late LiveUpdatesService _liveService;
  final List<String> _watchedPairs = [
    'USD/PKR',
    'EUR/USD',
    'GBP/USD',
    'USD/JPY',
    'AUD/USD',
  ];
  
  final Map<String, dynamic> _latestUpdates = {};

  @override
  void initState() {
    super.initState();
    _liveService = LiveUpdatesService();
    _initializeLiveUpdates();
  }

  void _initializeLiveUpdates() async {
    await _liveService.connect(widget.userId);
    _liveService.subscribeToPairs(_watchedPairs);
    
    _liveService.updates.listen((update) {
      if (mounted) {
        setState(() {
          _latestUpdates[update.pair] = update;
        });
      }
    });
  }

  @override
  void dispose() {
    _liveService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: const BoxDecoration(
                  color: Colors.green,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Live Market Updates',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              StreamBuilder<bool>(
                stream: _liveService.connectionStatus,
                builder: (context, snapshot) {
                  final isConnected = snapshot.data ?? false;
                  return Text(
                    isConnected ? '🔴 Live' : '⚪ Offline',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isConnected ? Colors.green : Colors.grey,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        
        // Scrollable prices list
        SizedBox(
          height: 280,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _watchedPairs.length,
            itemBuilder: (context, index) {
              final pair = _watchedPairs[index];
              final update = _latestUpdates[pair];
              
              return _buildPriceCard(pair, update);
            },
          ),
        ),
      ],
    );
  }
  
  Widget _buildPriceCard(String pair, dynamic update) {
    final isPositive = update?.changePercent ?? 0 >= 0;
    final trendIcon = update?.trend == 'UP' 
        ? '📈' 
        : update?.trend == 'DOWN' 
        ? '📉' 
        : '➡️';
    
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPositive 
              ? Colors.green.withOpacity(0.3)
              : Colors.red.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Pair name
          Row(
            children: [
              Expanded(
                child: Text(
                  pair,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                trendIcon,
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Price
          Text(
            '${update?.price.toStringAsFixed(4) ?? '--'}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          
          // Change
          Row(
            children: [
              Icon(
                isPositive ? Icons.trending_up : Icons.trending_down,
                color: isPositive ? Colors.green : Colors.red,
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                '${isPositive ? '+' : ''}${update?.changePercent.toStringAsFixed(2) ?? '--'}%',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isPositive ? Colors.green : Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Update time
          Text(
            'Updated now',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[500],
            ),
          ),
          
          // Action button
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                // Trade action
                debugPrint('Trading $pair');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Trade',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
