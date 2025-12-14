import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../repositories/face_repository.dart';

class AttendanceHistoryScreen extends StatefulWidget {
  const AttendanceHistoryScreen({super.key});

  @override
  State<AttendanceHistoryScreen> createState() =>
      _AttendanceHistoryScreenState();
}

class _AttendanceHistoryScreenState extends State<AttendanceHistoryScreen> {
  final FaceRepository _repository = FaceRepository();
  List<Map<String, dynamic>> _attendanceHistory = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAttendanceHistory();
  }

  Future<void> _loadAttendanceHistory() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final userId = _repository.getCurrentUserId();
      if (userId == null) {
        throw Exception('Not logged in');
      }

      final history = await _repository.getAttendanceHistory(userId);
      setState(() {
        _attendanceHistory = history;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null) return '-';
    try {
      final date = DateTime.parse(dateString).toLocal();
      return DateFormat('EEE, MMM d, yyyy').format(date);
    } catch (e) {
      return dateString;
    }
  }

  String _formatTime(String? dateString) {
    if (dateString == null) return '-';
    try {
      final date = DateTime.parse(dateString).toLocal();
      return DateFormat('h:mm a').format(date);
    } catch (e) {
      return dateString;
    }
  }

  String _calculateDuration(String? checkIn, String? checkOut) {
    if (checkIn == null || checkOut == null) return '-';
    try {
      final inTime = DateTime.parse(checkIn).toLocal();
      final outTime = DateTime.parse(checkOut).toLocal();

      final duration = outTime.difference(inTime);

      final hours = duration.inHours;
      final minutes = duration.inMinutes % 60;

      if (hours > 0) {
        return '${hours}h ${minutes}m';
      } else {
        return '${minutes}m';
      }
    } catch (e) {
      return '-';
    }
  }

  Color _getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case 'present':
        return Colors.green;
      case 'late':
        return Colors.orange;
      case 'absent':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'Attendance History',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w300,
            letterSpacing: 1.2,
          ),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadAttendanceHistory,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : _error != null
              ? _buildErrorView()
              : _attendanceHistory.isEmpty
                  ? _buildEmptyView()
                  : _buildHistoryList(),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.white38,
            ),
            const SizedBox(height: 24),
            Text(
              _error ?? 'An error occurred',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadAttendanceHistory,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Colors.black,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.1),
              ),
              child: const Icon(
                Icons.history,
                size: 48,
                color: Colors.white54,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'No Attendance Records',
              style: TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w300,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Your attendance history will appear here\nafter you check in.',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 14,
                fontWeight: FontWeight.w300,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryList() {
    // Group by date
    final Map<String, List<Map<String, dynamic>>> groupedHistory = {};
    for (final record in _attendanceHistory) {
      final dateKey = _formatDate(record['check_in_time']);
      if (!groupedHistory.containsKey(dateKey)) {
        groupedHistory[dateKey] = [];
      }
      groupedHistory[dateKey]!.add(record);
    }

    return RefreshIndicator(
      onRefresh: _loadAttendanceHistory,
      color: Colors.white,
      backgroundColor: Colors.grey[900],
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: groupedHistory.length,
        itemBuilder: (context, index) {
          final dateKey = groupedHistory.keys.elementAt(index);
          final records = groupedHistory[dateKey]!;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Date header
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        dateKey,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const Expanded(
                      child: Divider(
                        color: Colors.white12,
                        indent: 12,
                      ),
                    ),
                  ],
                ),
              ),
              // Records for this date
              ...records.map((record) => _buildRecordCard(record)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRecordCard(Map<String, dynamic> record) {
    final status = record['status'] as String?;
    final checkInTime = record['check_in_time'] as String?;
    final checkOutTime = record['check_out_time'] as String?;
    final location = record['location'] as String?;
    final faceVerified = record['face_verified'] == true;
    final similarityScore = record['face_similarity_score'] as num?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Main content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Status and verification row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _getStatusColor(status).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: _getStatusColor(status),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            (status ?? 'Unknown').toUpperCase(),
                            style: TextStyle(
                              color: _getStatusColor(status),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Face verification badge
                    if (faceVerified)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.face,
                              size: 14,
                              color: Colors.green,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              similarityScore != null
                                  ? '${(similarityScore * 100).toStringAsFixed(0)}%'
                                  : '✓',
                              style: const TextStyle(
                                color: Colors.green,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 20),
                // Check-in and Check-out times
                Row(
                  children: [
                    Expanded(
                      child: _buildTimeColumn(
                        'CHECK IN',
                        _formatTime(checkInTime),
                        Icons.login,
                        Colors.green,
                      ),
                    ),
                    Container(
                      height: 40,
                      width: 1,
                      color: Colors.white12,
                    ),
                    Expanded(
                      child: _buildTimeColumn(
                        'CHECK OUT',
                        _formatTime(checkOutTime),
                        Icons.logout,
                        checkOutTime != null ? Colors.orange : Colors.white38,
                      ),
                    ),
                    Container(
                      height: 40,
                      width: 1,
                      color: Colors.white12,
                    ),
                    Expanded(
                      child: _buildTimeColumn(
                        'DURATION',
                        _calculateDuration(checkInTime, checkOutTime),
                        Icons.timer_outlined,
                        Colors.blue,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Location footer
          if (location != null && location.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    size: 14,
                    color: Colors.white38,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      location,
                      style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        fontWeight: FontWeight.w300,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTimeColumn(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Icon(
          icon,
          size: 20,
          color: color.withValues(alpha: 0.7),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: value == '-' ? Colors.white38 : Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white38,
            fontSize: 9,
            fontWeight: FontWeight.w400,
            letterSpacing: 1,
          ),
        ),
      ],
    );
  }
}
