// lib/presentation/screens/session_history_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_constants.dart';
import '../../data/models/session_model.dart';
import '../providers/session_provider.dart';

class SessionHistoryScreen extends StatefulWidget {
  const SessionHistoryScreen({super.key});

  @override
  State<SessionHistoryScreen> createState() => _SessionHistoryScreenState();
}

class _SessionHistoryScreenState extends State<SessionHistoryScreen> {
  String _searchQuery = '';
  String _filterPersonality = 'All';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Session History'),
        backgroundColor: AppConstants.primaryColor,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<SessionProvider>().refresh();
            },
            tooltip: 'Refresh',
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            tooltip: 'Filter',
            onSelected: (value) {
              setState(() {
                _filterPersonality = value;
              });
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'All', child: Text('All Sessions')),
              const PopupMenuItem(value: 'Tutor', child: Text('Tutor Mode')),
              const PopupMenuItem(value: 'Classmate', child: Text('Classmate Mode')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(AppConstants.spacingM),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search sessions...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(AppConstants.radiusM),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),

          // Statistics Card
          Consumer<SessionProvider>(
            builder: (context, provider, _) {
              final stats = provider.getSessionStatistics();
              return Container(
                margin: const EdgeInsets.symmetric(
                  horizontal: AppConstants.spacingM,
                  vertical: AppConstants.spacingS,
                ),
                padding: const EdgeInsets.all(AppConstants.spacingM),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppConstants.primaryColor,
                      AppConstants.primaryColor.withOpacity(0.7),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(AppConstants.radiusM),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _StatItem(
                      icon: Icons.chat_bubble_outline,
                      label: 'Total Sessions',
                      value: stats['total_sessions'].toString(),
                    ),
                    _StatItem(
                      icon: Icons.school,
                      label: 'Tutor',
                      value: stats['tutor_sessions'].toString(),
                    ),
                    _StatItem(
                      icon: Icons.people,
                      label: 'Classmate',
                      value: stats['classmate_sessions'].toString(),
                    ),
                  ],
                ),
              );
            },
          ),

          // Sessions List
          Expanded(
            child: Consumer<SessionProvider>(
              builder: (context, provider, _) {
                if (provider.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }

                var sessions = provider.savedSessions;

                // Apply filters
                if (_filterPersonality != 'All') {
                  sessions = sessions
                      .where((s) => s.personalityUsed == _filterPersonality)
                      .toList();
                }

                // Apply search
                if (_searchQuery.isNotEmpty) {
                  sessions = sessions
                      .where((s) =>
                          s.topic.toLowerCase().contains(_searchQuery) ||
                          s.personalityUsed.toLowerCase().contains(_searchQuery))
                      .toList();
                }

                if (sessions.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.history,
                          size: 64,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _searchQuery.isNotEmpty || _filterPersonality != 'All'
                              ? 'No sessions found'
                              : 'No session history yet',
                          style: TextStyle(
                            fontSize: 18,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _searchQuery.isNotEmpty || _filterPersonality != 'All'
                              ? 'Try adjusting your filters'
                              : 'Start chatting to create your first session!',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () => provider.refresh(),
                  child: ListView.builder(
                    padding: const EdgeInsets.all(AppConstants.spacingM),
                    itemCount: sessions.length,
                    itemBuilder: (context, index) {
                      final session = sessions[index];
                      return _SessionCard(
                        session: session,
                        onTap: () => _showSessionDetails(session),
                        onDelete: () => _deleteSession(session.id),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: Consumer<SessionProvider>(
        builder: (context, provider, _) {
          if (provider.savedSessions.isEmpty) return const SizedBox();
          
          return FloatingActionButton.extended(
            onPressed: () => _clearAllSessions(),
            backgroundColor: Colors.red,
            icon: const Icon(Icons.delete_sweep),
            label: const Text('Clear All'),
          );
        },
      ),
    );
  }

  void _showSessionDetails(SessionModel session) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return _SessionDetailsView(
            session: session,
            scrollController: scrollController,
          );
        },
      ),
    );
  }

  Future<void> _deleteSession(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Session?'),
        content: const Text('This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await context.read<SessionProvider>().deleteSession(id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Session deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting session: $e')),
          );
        }
      }
    }
  }

  Future<void> _clearAllSessions() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Sessions?'),
        content: const Text('This will delete all saved sessions. This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Clear All', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      try {
        await context.read<SessionProvider>().clearAllSessions();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('All sessions cleared')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error clearing sessions: $e')),
          );
        }
      }
    }
  }
}

// ========== Session Card Widget ==========
class _SessionCard extends StatelessWidget {
  final SessionModel session;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const _SessionCard({
    required this.session,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final isTutor = session.personalityUsed == 'Tutor';
    final color = isTutor ? AppConstants.tutorColor : AppConstants.classmateColor;
    final lightColor = isTutor ? AppConstants.tutorLightColor : AppConstants.classmateLightColor;

    return Card(
      margin: const EdgeInsets.only(bottom: AppConstants.spacingM),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppConstants.radiusM),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppConstants.radiusM),
        child: Padding(
          padding: const EdgeInsets.all(AppConstants.spacingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: lightColor,
                      borderRadius: BorderRadius.circular(AppConstants.radiusS),
                    ),
                    child: Icon(
                      isTutor ? Icons.school : Icons.people,
                      color: color,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: AppConstants.spacingM),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.topic,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          session.personalityUsed,
                          style: TextStyle(
                            fontSize: 12,
                            color: color,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.red),
                    onPressed: onDelete,
                    tooltip: 'Delete',
                  ),
                ],
              ),
              const SizedBox(height: AppConstants.spacingS),
              const Divider(),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _InfoChip(
                    icon: Icons.access_time,
                    label: session.formattedDate,
                  ),
                  _InfoChip(
                    icon: Icons.timer_outlined,
                    label: session.formattedDuration,
                  ),
                  _InfoChip(
                    icon: Icons.chat_bubble_outline,
                    label: '${session.messageCount} msgs',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ========== Info Chip Widget ==========
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _InfoChip({
    required this.icon,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 14, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }
}

// ========== Stat Item Widget ==========
class _StatItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: Colors.white, size: 28),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

// ========== Session Details View ==========
class _SessionDetailsView extends StatelessWidget {
  final SessionModel session;
  final ScrollController scrollController;

  const _SessionDetailsView({
    required this.session,
    required this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppConstants.spacingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AppConstants.spacingL),

          // Header
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      session.topic,
                      style: AppConstants.headingStyle,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${session.personalityUsed} Mode • ${session.formattedDate}',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy),
                onPressed: () => _copyTranscript(context),
                tooltip: 'Copy Transcript',
              ),
            ],
          ),
          const SizedBox(height: AppConstants.spacingL),
          const Divider(),
          const SizedBox(height: AppConstants.spacingM),

          // Transcript
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              itemCount: session.transcript.length,
              itemBuilder: (context, index) {
                final message = session.transcript[index];
                if (message.isError) return const SizedBox();

                return Padding(
                  padding: const EdgeInsets.only(bottom: AppConstants.spacingM),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            message.isUser ? Icons.person : Icons.smart_toy,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            message.isUser ? 'Student' : session.personalityUsed,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _formatTime(message.timestamp),
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[500],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(AppConstants.spacingM),
                        decoration: BoxDecoration(
                          color: message.isUser
                              ? AppConstants.primaryColor.withOpacity(0.1)
                              : Colors.grey[100],
                          borderRadius: BorderRadius.circular(AppConstants.radiusS),
                        ),
                        child: Text(
                          message.content,
                          style: const TextStyle(fontSize: 15),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _copyTranscript(BuildContext context) {
    final buffer = StringBuffer();
    buffer.writeln('Session: ${session.topic}');
    buffer.writeln('Mode: ${session.personalityUsed}');
    buffer.writeln('Date: ${session.formattedDate}');
    buffer.writeln('Duration: ${session.formattedDuration}');
    buffer.writeln('Messages: ${session.messageCount}');
    buffer.writeln(''.padLeft(50, '='));
    buffer.writeln();

    for (final message in session.transcript) {
      if (message.isError) continue;
      
      final speaker = message.isUser ? 'Student' : session.personalityUsed;
      buffer.writeln('[$speaker]:');
      buffer.writeln(message.content);
      buffer.writeln();
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Transcript copied to clipboard')),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}