import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/analytics_provider.dart';

class AnalyticsDashboardScreen extends ConsumerStatefulWidget {
  const AnalyticsDashboardScreen({super.key});

  @override
  ConsumerState<AnalyticsDashboardScreen> createState() => _AnalyticsDashboardScreenState();
}

class _AnalyticsDashboardScreenState extends ConsumerState<AnalyticsDashboardScreen> {
  bool _isAnteriorView = true;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(analyticsProvider);

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: AppTheme.darkBackground,
        elevation: 0,
        centerTitle: true,
        title: Text(
          'ANALYTICS ENGINE',
          style: GoogleFonts.outfit(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.5,
            color: Colors.white,
            fontSize: 16,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: AppTheme.textSub, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.textMuted),
            onPressed: () => ref.read(analyticsProvider.notifier).refresh(),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Ambient Glows
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.cyberCyan.withValues(alpha: 0.04),
              ),
            ),
          ),
          Positioned(
            bottom: 50,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.amethystPurple.withValues(alpha: 0.04),
              ),
            ),
          ),

          state.isLoading
              ? const Center(child: CircularProgressIndicator(color: AppTheme.cyberCyan))
              : SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // ─── TIME TOGGLE BAR ──────────────────────────────────
                      _buildTimeToggleBar(state),
                      const SizedBox(height: 24),

                      // ─── KPI METRICS GRID ─────────────────────────────────
                      _buildKpiMetricsGrid(state),
                      const SizedBox(height: 24),

                      // ─── VOLUME TREND LINE CHART ──────────────────────────
                      _buildVolumeLineChartCard(state),
                      const SizedBox(height: 24),

                      // ─── FORM ACCURACY BAR CHART ──────────────────────────
                      _buildAccuracyBarChartCard(state),
                      const SizedBox(height: 24),

                      // ─── ANATOMICAL MUSCLE MATRIX Heatmap ─────────────────
                      _buildMuscleMatrixCard(state),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildTimeToggleBar(AnalyticsState state) {
    final is7Days = state.lookbackDays == 7;
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorderColor, width: 1.0),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => ref.read(analyticsProvider.notifier).setLookbackDays(7),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: is7Days ? AppTheme.cyberCyan.withValues(alpha: 0.08) : Colors.transparent,
                  border: Border.all(
                    color: is7Days ? AppTheme.cyberCyan.withValues(alpha: 0.3) : Colors.transparent,
                    width: 1.0,
                  ),
                ),
                child: Text(
                  '7-DAY PERFORMANCE',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: is7Days ? AppTheme.cyberCyan : AppTheme.textMuted,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => ref.read(analyticsProvider.notifier).setLookbackDays(30),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: !is7Days ? AppTheme.cyberCyan.withValues(alpha: 0.08) : Colors.transparent,
                  border: Border.all(
                    color: !is7Days ? AppTheme.cyberCyan.withValues(alpha: 0.3) : Colors.transparent,
                    width: 1.0,
                  ),
                ),
                child: Text(
                  '30-DAY CALIBRATION',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: !is7Days ? AppTheme.cyberCyan : AppTheme.textMuted,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiMetricsGrid(AnalyticsState state) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 14,
      mainAxisSpacing: 14,
      childAspectRatio: 1.35,
      children: [
        _buildKpiCard(
          'TOTAL VOLUME',
          '${state.totalVolume.toStringAsFixed(0)}',
          'KG',
          AppTheme.cyberCyan,
          Icons.fitness_center_outlined,
        ),
        _buildKpiCard(
          'SESSIONS',
          '${state.completedSessions}',
          'LOGGED',
          AppTheme.electricBlue,
          Icons.emoji_events_outlined,
        ),
        _buildKpiCard(
          'FORM ACCURACY',
          state.completedSessions == 0 ? 'N/A' : '${state.averageAccuracy.toStringAsFixed(1)}',
          '%',
          AppTheme.warningAmber,
          Icons.camera_enhance_outlined,
        ),
        _buildKpiCard(
          'MINUTES TRAINED',
          '${state.totalMinutes}',
          'MINS',
          AppTheme.amethystPurple,
          Icons.timer_outlined,
        ),
      ],
    );
  }

  Widget _buildKpiCard(String label, String value, String unit, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.cardBorderColor, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: GoogleFonts.outfit(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textMuted,
                  letterSpacing: 1.0,
                ),
              ),
              Icon(icon, color: color.withValues(alpha: 0.4), size: 16),
            ],
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: GoogleFonts.outfit(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                unit,
                style: GoogleFonts.outfit(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVolumeLineChartCard(AnalyticsState state) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.cardBorderColor, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'VOLUME DYNAMICS',
                    style: GoogleFonts.outfit(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textMuted,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'TOTAL WEIGHT LIFTED (KG)',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const Icon(Icons.show_chart, color: AppTheme.cyberCyan, size: 20),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            child: state.volumeHistory.isEmpty
                ? Center(
                    child: Text(
                      'No completed sessions logged.',
                      style: GoogleFonts.outfit(color: AppTheme.textMuted, fontSize: 12),
                    ),
                  )
                : LineChart(
                    _getLineChartData(state.volumeHistory),
                  ),
          ),
        ],
      ),
    );
  }

  LineChartData _getLineChartData(List<MapEntry<DateTime, double>> history) {
    final spots = <FlSpot>[];
    for (int i = 0; i < history.length; i++) {
      spots.add(FlSpot(i.toDouble(), history[i].value));
    }

    return LineChartData(
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (value) => FlLine(
          color: Colors.white.withValues(alpha: 0.03),
          strokeWidth: 1.0,
        ),
      ),
      titlesData: FlTitlesData(
        show: true,
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 22,
            interval: 1.0,
            getTitlesWidget: (value, meta) {
              final idx = value.toInt();
              if (idx < 0 || idx >= history.length) return const SizedBox();
              
              // Only display titles for start, mid, end nodes to keep bottom clean
              if (history.length > 5 && idx % (history.length ~/ 3) != 0) {
                return const SizedBox();
              }
              
              final date = history[idx].key;
              final formatted = DateFormat('MM/dd').format(date);
              return Padding(
                padding: const EdgeInsets.only(top: 6.0),
                child: Text(
                  formatted,
                  style: GoogleFonts.outfit(color: AppTheme.textMuted, fontSize: 8),
                ),
              );
            },
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: true,
          gradient: const LinearGradient(
            colors: [AppTheme.cyberCyan, AppTheme.electricBlue],
          ),
          barWidth: 3.5,
          isStrokeCapRound: true,
          dotData: FlDotData(
            show: true,
            getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
              radius: 4,
              color: AppTheme.darkBackground,
              strokeWidth: 2.0,
              strokeColor: AppTheme.cyberCyan,
            ),
          ),
          belowBarData: BarAreaData(
            show: true,
            gradient: LinearGradient(
              colors: [
                AppTheme.cyberCyan.withValues(alpha: 0.12),
                AppTheme.cyberCyan.withValues(alpha: 0.00),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
        ),
      ],
      lineTouchData: LineTouchData(
        touchTooltipData: LineTouchTooltipData(
          tooltipBgColor: AppTheme.darkSurface,
          tooltipBorder: const BorderSide(color: AppTheme.cardBorderColor),
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((spot) {
              final idx = spot.x.toInt();
              final date = history[idx].key;
              final formatted = DateFormat('EEEE, MMM d').format(date);
              return LineTooltipItem(
                '$formatted\n',
                GoogleFonts.outfit(
                  color: AppTheme.textSub,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                ),
                children: [
                  TextSpan(
                    text: '${spot.y.toStringAsFixed(0)} kg',
                    style: GoogleFonts.outfit(
                      color: AppTheme.cyberCyan,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              );
            }).toList();
          },
        ),
      ),
    );
  }

  Widget _buildAccuracyBarChartCard(AnalyticsState state) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.cardBorderColor, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'FORM PRECISION',
                    style: GoogleFonts.outfit(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textMuted,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'ACCURACY PER EXERCISE TYPE (%)',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const Icon(Icons.bar_chart, color: AppTheme.amethystPurple, size: 20),
            ],
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 180,
            child: state.accuracyPerExercise.isEmpty
                ? Center(
                    child: Text(
                      'No neural pose results compiled.',
                      style: GoogleFonts.outfit(color: AppTheme.textMuted, fontSize: 12),
                    ),
                  )
                : BarChart(
                    _getBarChartData(state.accuracyPerExercise),
                  ),
          ),
        ],
      ),
    );
  }

  BarChartData _getBarChartData(List<MapEntry<String, double>> history) {
    final groups = <BarChartGroupData>[];
    for (int i = 0; i < history.length; i++) {
      groups.add(
        BarChartGroupData(
          x: i,
          barRods: [
            BarChartRodData(
              toY: history[i].value,
              color: AppTheme.amethystPurple,
              width: 14,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(6),
                topRight: Radius.circular(6),
              ),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: 100.0,
                color: Colors.white.withValues(alpha: 0.02),
              ),
            ),
          ],
        ),
      );
    }

    return BarChartData(
      gridData: const FlGridData(show: false),
      titlesData: FlTitlesData(
        show: true,
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 24,
            getTitlesWidget: (value, meta) {
              final idx = value.toInt();
              if (idx < 0 || idx >= history.length) return const SizedBox();
              return Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  history[idx].key.toUpperCase(),
                  style: GoogleFonts.outfit(color: AppTheme.textMuted, fontSize: 8, fontWeight: FontWeight.bold),
                ),
              );
            },
          ),
        ),
      ),
      borderData: FlBorderData(show: false),
      barGroups: groups,
      barTouchData: BarTouchData(
        touchTooltipData: BarTouchTooltipData(
          tooltipBgColor: AppTheme.darkSurface,
          tooltipBorder: const BorderSide(color: AppTheme.cardBorderColor),
          getTooltipItem: (group, groupIndex, rod, rodIndex) {
            return BarTooltipItem(
              '${history[groupIndex].key.toUpperCase()}\n',
              GoogleFonts.outfit(
                color: AppTheme.textSub,
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
              children: [
                TextSpan(
                  text: '${rod.toY.toStringAsFixed(1)}%',
                  style: GoogleFonts.outfit(
                    color: AppTheme.amethystPurple,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMuscleMatrixCard(AnalyticsState state) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.cardBorderColor, width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Matrix Header & anterior/posterior toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'MUSCLE DENSITY MAP',
                    style: GoogleFonts.outfit(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textMuted,
                      letterSpacing: 1.0,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'ANATOMICAL HIGHLIGHTER',
                    style: GoogleFonts.outfit(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              _buildAnatomicalToggle(),
            ],
          ),
          const SizedBox(height: 24),

          // Side-by-side or Toggled view layout
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Visual Body outline illustration representing matrix zones
              Expanded(
                flex: 1,
                child: SizedBox(
                  height: 240,
                  child: Center(
                    child: Image.asset(
                      _isAnteriorView
                          ? 'assets/images/body_front_blueprint.png'
                          : 'assets/images/body_back_blueprint.png',
                      color: AppTheme.cyberCyan.withValues(alpha: 0.12),
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        // Fallback vector-like mockup in case image is missing
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppTheme.textMuted),
                            borderRadius: BorderRadius.circular(16),
                            color: Colors.black.withValues(alpha: 0.2),
                          ),
                          child: Icon(
                            Icons.accessibility_new_outlined,
                            color: AppTheme.cyberCyan.withValues(alpha: 0.35),
                            size: 64,
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Interactive muscle groups grid cards
              Expanded(
                flex: 1,
                child: Column(
                  children: _isAnteriorView
                      ? [
                          _buildMuscleRowItem(state, 'chest', 'Pecs / Chest'),
                          _buildMuscleRowItem(state, 'abs', 'Abdominals'),
                          _buildMuscleRowItem(state, 'biceps', 'Biceps'),
                          _buildMuscleRowItem(state, 'front_deltoids', 'Front Delts'),
                          _buildMuscleRowItem(state, 'quadriceps', 'Quads / Thighs'),
                        ]
                      : [
                          _buildMuscleRowItem(state, 'upper_back', 'Traps / Upper Back'),
                          _buildMuscleRowItem(state, 'lower_back', 'Lats / Lower Back'),
                          _buildMuscleRowItem(state, 'triceps', 'Triceps'),
                          _buildMuscleRowItem(state, 'gluteal', 'Glutes / Hip'),
                          _buildMuscleRowItem(state, 'hamstring', 'Hamstrings'),
                          _buildMuscleRowItem(state, 'calves', 'Calves'),
                        ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnatomicalToggle() {
    return Container(
      height: 32,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => setState(() => _isAnteriorView = true),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: _isAnteriorView ? AppTheme.cyberCyan.withValues(alpha: 0.08) : Colors.transparent,
              ),
              child: Text(
                'FRONT',
                style: GoogleFonts.outfit(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: _isAnteriorView ? AppTheme.cyberCyan : AppTheme.textMuted,
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _isAnteriorView = false),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: !_isAnteriorView ? AppTheme.cyberCyan.withValues(alpha: 0.08) : Colors.transparent,
              ),
              child: Text(
                'BACK',
                style: GoogleFonts.outfit(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: !_isAnteriorView ? AppTheme.cyberCyan : AppTheme.textMuted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMuscleRowItem(AnalyticsState state, String key, String name) {
    final stat = state.muscleStats[key];
    final sets = stat?.totalSets ?? 0;

    // Shade configuration proportional to sets intensity
    Color neonColor = AppTheme.cyberCyan;
    double opacity = 0.03;
    if (sets >= 9) {
      opacity = 0.45;
    } else if (sets >= 4) {
      opacity = 0.24;
    } else if (sets >= 1) {
      opacity = 0.12;
    }

    return GestureDetector(
      onTap: () => _showMuscleTooltip(name, stat),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: neonColor.withValues(alpha: opacity),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: sets > 0 ? neonColor.withValues(alpha: opacity + 0.1) : AppTheme.cardBorderColor,
            width: 1.0,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              name,
              style: GoogleFonts.outfit(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: sets > 0 ? Colors.white : AppTheme.textMuted,
              ),
            ),
            Row(
              children: [
                Text(
                  '$sets',
                  style: GoogleFonts.outfit(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: sets > 0 ? neonColor : AppTheme.textMuted,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'SETS',
                  style: GoogleFonts.outfit(
                    fontSize: 8,
                    color: AppTheme.textMuted,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showMuscleTooltip(String name, MuscleStat? stat) {
    final sets = stat?.totalSets ?? 0;
    final vol = stat?.totalVolume ?? 0.0;
    final exercises = stat?.topExercises ?? [];

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppTheme.cardBorderColor),
        ),
        title: Row(
          children: [
            const Icon(Icons.analytics_outlined, color: AppTheme.cyberCyan, size: 20),
            const SizedBox(width: 10),
            Text(
              name.toUpperCase(),
              style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('TOTAL SETS:', style: GoogleFonts.outfit(color: AppTheme.textMuted, fontSize: 11)),
                Text('$sets SETS', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('TOTAL VOLUME:', style: GoogleFonts.outfit(color: AppTheme.textMuted, fontSize: 11)),
                Text('${vol.toStringAsFixed(0)} KG', style: GoogleFonts.outfit(color: AppTheme.cyberCyan, fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              'TOP EXERCISES LOGGED:',
              style: GoogleFonts.outfit(color: AppTheme.textMuted, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5),
            ),
            const SizedBox(height: 8),
            exercises.isEmpty
                ? Text('No exercises logged yet for this group.', style: GoogleFonts.outfit(color: AppTheme.textMuted, fontSize: 11))
                : Column(
                    children: exercises.map((e) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('• ', style: TextStyle(color: AppTheme.cyberCyan)),
                            Expanded(
                              child: Text(
                                e,
                                style: GoogleFonts.outfit(color: AppTheme.textSub, fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'CLOSE',
              style: GoogleFonts.outfit(
                color: AppTheme.textMuted,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
