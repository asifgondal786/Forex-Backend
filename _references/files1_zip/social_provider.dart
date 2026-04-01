import 'package:flutter/foundation.dart';

// ─── Models ───────────────────────────────────────────────────────────────────

class LeaderEntry {
  final String userId;
  final String username;
  final int rank;
  final double totalPnl;
  final double winRate;
  final int totalTrades;
  final int followers;
  bool isFollowing;

  LeaderEntry({
    required this.userId,
    required this.username,
    required this.rank,
    required this.totalPnl,
    required this.winRate,
    required this.totalTrades,
    required this.followers,
    this.isFollowing = false,
  });

  LeaderEntry copyWith({bool? isFollowing, int? followers}) => LeaderEntry(
        userId: userId,
        username: username,
        rank: rank,
        totalPnl: totalPnl,
        winRate: winRate,
        totalTrades: totalTrades,
        followers: followers ?? this.followers,
        isFollowing: isFollowing ?? this.isFollowing,
      );
}

// ─── Provider ─────────────────────────────────────────────────────────────────

class SocialProvider extends ChangeNotifier {
  bool _isLoading = false;
  String? _error;
  String _searchQuery = '';
  List<LeaderEntry> _leaderboard = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;

  /// Full leaderboard (all entries).
  List<LeaderEntry> get leaderboard => List.unmodifiable(_leaderboard);

  /// Leaderboard filtered by [_searchQuery].
  List<LeaderEntry> get filteredLeaderboard {
    if (_searchQuery.isEmpty) return _leaderboard;
    final q = _searchQuery.toLowerCase();
    return _leaderboard
        .where((e) => e.username.toLowerCase().contains(q))
        .toList();
  }

  /// Traders the current user is following.
  List<LeaderEntry> get following =>
      _leaderboard.where((e) => e.isFollowing).toList();

  /// Count of followed traders.
  int get followingCount => following.length;

  // ─── Init ─────────────────────────────────────────────────────────────────

  Future<void> load(String token) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      // TODO: replace with real GET /api/social/leaderboard using [token]
      await Future.delayed(const Duration(milliseconds: 600));
      _leaderboard = _mockLeaderboard();
    } catch (e) {
      _error = 'Failed to load leaderboard: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─── Search ───────────────────────────────────────────────────────────────

  void setSearch(String query) {
    if (_searchQuery == query) return;
    _searchQuery = query;
    notifyListeners();
  }

  void clearSearch() => setSearch('');

  // ─── Follow / Unfollow ────────────────────────────────────────────────────

  /// Toggle follow state for a trader. Optimistic update with server sync.
  Future<void> toggleFollow(String userId, String token) async {
    final idx = _leaderboard.indexWhere((e) => e.userId == userId);
    if (idx == -1) return;

    final entry = _leaderboard[idx];
    final nowFollowing = !entry.isFollowing;

    // Optimistic update
    final updated = List<LeaderEntry>.from(_leaderboard);
    updated[idx] = entry.copyWith(
      isFollowing: nowFollowing,
      followers: entry.followers + (nowFollowing ? 1 : -1),
    );
    _leaderboard = updated;
    notifyListeners();

    try {
      // TODO: POST /api/social/follow or DELETE /api/social/follow
      // Body: { userId, token }
      await Future.delayed(const Duration(milliseconds: 300));
    } catch (_) {
      // Revert optimistic update on failure
      final revert = List<LeaderEntry>.from(_leaderboard);
      revert[idx] = entry; // restore original
      _leaderboard = revert;
      notifyListeners();
    }
  }

  /// Returns true if the current user is following [userId].
  bool isFollowing(String userId) =>
      _leaderboard.any((e) => e.userId == userId && e.isFollowing);

  // ─── Mock data (replace with API) ─────────────────────────────────────────

  List<LeaderEntry> _mockLeaderboard() => [
        LeaderEntry(
          userId: 'u_001',
          username: 'AlphaTrader',
          rank: 1,
          totalPnl: 48200,
          winRate: 74.5,
          totalTrades: 312,
          followers: 1840,
          isFollowing: true,
        ),
        LeaderEntry(
          userId: 'u_002',
          username: 'PipHunter99',
          rank: 2,
          totalPnl: 36750,
          winRate: 68.2,
          totalTrades: 289,
          followers: 1203,
        ),
        LeaderEntry(
          userId: 'u_003',
          username: 'FxWhisperer',
          rank: 3,
          totalPnl: 29100,
          winRate: 71.0,
          totalTrades: 178,
          followers: 894,
          isFollowing: true,
        ),
        LeaderEntry(
          userId: 'u_004',
          username: 'GoldBull_Zahid',
          rank: 4,
          totalPnl: 22400,
          winRate: 65.8,
          totalTrades: 244,
          followers: 571,
        ),
        LeaderEntry(
          userId: 'u_005',
          username: 'ScalpKing',
          rank: 5,
          totalPnl: 18900,
          winRate: 79.1,
          totalTrades: 621,
          followers: 449,
        ),
        LeaderEntry(
          userId: 'u_006',
          username: 'SwingMaster_AK',
          rank: 6,
          totalPnl: 14300,
          winRate: 60.4,
          totalTrades: 130,
          followers: 320,
        ),
        LeaderEntry(
          userId: 'u_007',
          username: 'Trend_Rider',
          rank: 7,
          totalPnl: 11750,
          winRate: 58.9,
          totalTrades: 198,
          followers: 214,
        ),
        LeaderEntry(
          userId: 'u_008',
          username: 'NightOwlFX',
          rank: 8,
          totalPnl: 9200,
          winRate: 62.3,
          totalTrades: 105,
          followers: 167,
        ),
      ];
}
