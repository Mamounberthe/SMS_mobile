import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/analytics_service.dart';
import '../theme.dart';
import '../widgets/app_card.dart';
import '../widgets/page_header.dart';
import '../widgets/skeleton.dart';

/// Écran des statistiques d'utilisation
class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  late final AnalyticsService _analyticsService;
  Map<String, dynamic>? _sessionStats;
  List<Map<String, dynamic>>? _events;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _analyticsService = context.read<AnalyticsService>();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      final stats = await _analyticsService.getSessionStats();
      final events = await _analyticsService.getEvents();
      setState(() {
        _sessionStats = stats;
        _events = events;
        _loading = false;
      });
    } catch (e) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppSurface.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistiques'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              await _analyticsService.clearEvents();
              _loadData();
            },
          ),
        ],
      ),
      body: _loading
          ? const SkeletonList()
          : _sessionStats == null
              ? const Center(child: Text('Erreur lors du chargement des statistiques'))
              : RefreshIndicator(
                  onRefresh: _loadData,
                  child: ListView(
                    padding: const EdgeInsets.all(Insets.xl),
                    children: [
                      PageHeader(
                        title: 'Statistiques de session',
                        actions: [
                          Text(
                            'Session: ${_sessionStats!['session_id']?.toString().substring(0, 8)}...',
                            style: TextStyle(color: s.muted, fontSize: 12),
                          ),
                        ],
                      ),
                      const SizedBox(height: Insets.xl),

                      // Stats principales
                      _buildStatsGrid(s),
                      const SizedBox(height: Insets.xl),

                      // Événements récents
                      Text('Événements récents',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: s.muted)),
                      const SizedBox(height: Insets.md),
                      if (_events != null && _events!.isEmpty)
                        AppCard(
                          child: Padding(
                            padding: const EdgeInsets.all(Insets.lg),
                            child: Center(
                              child: Text('Aucun événement enregistré', style: TextStyle(color: s.muted)),
                            ),
                          ),
                        )
                      else
                        ...(_events?.reversed.take(20).toList() ?? []).map((event) => _buildEventCard(event, s)),
                    ],
                  ),
                ),
    );
  }

  Widget _buildStatsGrid(AppSurface s) {
    final stats = _sessionStats!;
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: Insets.lg,
      crossAxisSpacing: Insets.lg,
      childAspectRatio: 1.3,
      children: [
        _buildStatCard('Durée de session', '${stats['session_duration']}s', Icons.timer, Colors.blue, s),
        _buildStatCard('Vues d\'écran', '${stats['screen_views']}', Icons.visibility, Colors.green, s),
        _buildStatCard('Actions utilisateur', '${stats['user_actions']}', Icons.touch_app, Colors.orange, s),
        _buildStatCard('Erreurs', '${stats['errors']}', Icons.error, Colors.red, s),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, AppSurface s) {
    return AppCard(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(Radii.md),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(height: Insets.md),
          Text(
            value,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(color: s.muted, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEventCard(Map<String, dynamic> event, AppSurface s) {
    final eventName = event['event_name'] as String?;
    final timestamp = event['timestamp'] as String?;
    final properties = event.keys.where((k) => k != 'event_name' && k != 'timestamp' && k != 'user_id' && k != 'session_id' && k != 'timestamp');

    return Padding(
      padding: const EdgeInsets.only(bottom: Insets.sm),
      child: AppCard(
        padding: const EdgeInsets.all(Insets.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _getEventIcon(eventName),
                  size: 16,
                  color: _getEventColor(eventName),
                ),
                const SizedBox(width: Insets.sm),
                Expanded(
                  child: Text(
                    eventName ?? 'Unknown',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  _formatTimestamp(timestamp),
                  style: TextStyle(color: s.muted, fontSize: 11),
                ),
              ],
            ),
            if (properties.isNotEmpty) ...[
              const SizedBox(height: Insets.sm),
              ...properties.map((prop) => Padding(
                    padding: const EdgeInsets.only(left: 24, top: 2),
                    child: Text(
                      '$prop: ${event[prop]}',
                      style: TextStyle(color: s.muted, fontSize: 11),
                    ),
                  )),
            ],
          ],
        ),
      ),
    );
  }

  IconData _getEventIcon(String? eventName) {
    switch (eventName) {
      case 'app_open':
        return Icons.phone_android;
      case 'screen_view':
        return Icons.visibility;
      case 'user_action':
        return Icons.touch_app;
      case 'sync':
        return Icons.sync;
      case 'error':
        return Icons.error;
      default:
        return Icons.event;
    }
  }

  Color _getEventColor(String? eventName) {
    switch (eventName) {
      case 'app_open':
        return Colors.blue;
      case 'screen_view':
        return Colors.green;
      case 'user_action':
        return Colors.orange;
      case 'sync':
        return Colors.purple;
      case 'error':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _formatTimestamp(String? timestamp) {
    if (timestamp == null) return '';
    try {
      final dt = DateTime.parse(timestamp);
      return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}:${dt.second.toString().padLeft(2, '0')}';
    } catch (_) {
      return '';
    }
  }
}
