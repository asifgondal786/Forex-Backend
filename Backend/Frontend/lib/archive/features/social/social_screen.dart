import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/social_provider.dart';

class SocialScreen extends StatefulWidget {
  const SocialScreen({super.key});

  @override
  State<SocialScreen> createState() => _SocialScreenState();
}

class _SocialScreenState extends State<SocialScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabs;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<SocialProvider>().load('demo_token');
    });
  }

  @override
  void dispose() {
    _tabs.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        elevation: 0,
        title: Text(
          'Social Trading',
          style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurface),
        ),
        bottom: TabBar(
          controller: _tabs,
          labelColor: scheme.primary,
          unselectedLabelColor: scheme.onSurface.withOpacity(0.5),
          indicatorColor: scheme.primary,
          tabs: const [
            Tab(text: 'Leaderboard'),
            Tab(text: 'Following'),
          ],
        ),
      ),
      body: Consumer<SocialProvider>(
        builder: (context, prov, _) {
          if (prov.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          return Column(
            children: [
              _SearchBar(prov: prov, ctrl: _searchCtrl, scheme: scheme),
              Expanded(
                child: TabBarView(
                  controller: _tabs,
                  children: [
                    _LeaderboardTab(prov: prov, scheme: scheme),
                    _FollowingTab(prov: prov, scheme: scheme),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  final SocialProvider prov;
  final TextEditingController ctrl;
  final ColorScheme scheme;

  const _SearchBar(
      {required this.prov, required this.ctrl, required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        controller: ctrl,
        onChanged: prov.setSearch,
        decoration: InputDecoration(
          hintText: 'Search traders...',
          hintStyle:
              TextStyle(color: scheme.onSurface.withOpacity(0.4), fontSize: 14),
          prefixIcon: Icon(Icons.search_rounded,
              color: scheme.onSurface.withOpacity(0.4)),
          suffixIcon: ctrl.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear_rounded),
                  onPressed: () {
                    ctrl.clear();
                    prov.setSearch('');
                  },
                )
              : null,
          filled: true,
          fillColor: scheme.surfaceContainerHighest,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }
}

class _LeaderboardTab extends StatelessWidget {
  final SocialProvider prov;
  final ColorScheme scheme;

  const _LeaderboardTab({required this.prov, required this.scheme});

  @override
  Widget build(BuildContext context) {
    final list = prov.filteredLeaderboard;
    if (list.isEmpty) {
      return Center(
        child: Text(
          'No traders found.',
          style: TextStyle(color: scheme.onSurface.withOpacity(0.4)),
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => prov.load('demo_token'),
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        itemCount: list.length,
        itemBuilder: (context, i) =>
            _TraderCard(entry: list[i], prov: prov, scheme: scheme),
      ),
    );
  }
}

class _FollowingTab extends StatelessWidget {
  final SocialProvider prov;
  final ColorScheme scheme;

  const _FollowingTab({required this.prov, required this.scheme});

  @override
  Widget build(BuildContext context) {
    if (prov.following.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline_rounded,
                size: 64, color: scheme.onSurface.withOpacity(0.15)),
            const SizedBox(height: 16),
            Text(
              'Not following anyone yet',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface),
            ),
            const SizedBox(height: 8),
            Text(
              'Follow top traders from the Leaderboard\nto copy their strategies.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: scheme.onSurface.withOpacity(0.5), fontSize: 14),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      itemCount: prov.following.length,
      itemBuilder: (context, i) =>
          _TraderCard(entry: prov.following[i], prov: prov, scheme: scheme),
    );
  }
}

class _TraderCard extends StatelessWidget {
  final LeaderEntry entry;
  final SocialProvider prov;
  final ColorScheme scheme;

  const _TraderCard(
      {required this.entry, required this.prov, required this.scheme});

  Color _rankColor() {
    if (entry.rank == 1) return const Color(0xFFFFD700);
    if (entry.rank == 2) return const Color(0xFFC0C0C0);
    if (entry.rank == 3) return const Color(0xFFCD7F32);
    return scheme.onSurface.withOpacity(0.3);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          // Rank
          SizedBox(
            width: 32,
            child: Text(
              '#${entry.rank}',
              style: TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 15,
                color: _rankColor(),
              ),
            ),
          ),
          // Avatar
          CircleAvatar(
            radius: 20,
            backgroundColor: scheme.primary.withOpacity(0.2),
            child: Text(
              entry.username[0].toUpperCase(),
              style: TextStyle(
                color: scheme.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.username,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _StatPill('${entry.winRate.toStringAsFixed(1)}% WR',
                        Colors.green),
                    const SizedBox(width: 6),
                    _StatPill('${entry.totalTrades} trades', Colors.blue),
                  ],
                ),
              ],
            ),
          ),
          // P&L + Follow
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '+\$${(entry.totalPnl / 1000).toStringAsFixed(1)}k',
                style: const TextStyle(
                  color: Colors.green,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () => prov.toggleFollow(entry.userId, 'demo_token'),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                  decoration: BoxDecoration(
                    color: entry.isFollowing
                        ? scheme.primary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: entry.isFollowing
                          ? scheme.primary
                          : scheme.outline.withOpacity(0.4),
                    ),
                  ),
                  child: Text(
                    entry.isFollowing ? 'Following' : 'Follow',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: entry.isFollowing
                          ? scheme.onPrimary
                          : scheme.onSurface,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String text;
  final Color color;

  const _StatPill(this.text, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

