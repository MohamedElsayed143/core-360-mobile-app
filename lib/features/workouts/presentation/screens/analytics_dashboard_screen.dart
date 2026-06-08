import 'dart:ui' as ui;
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
  String? _selectedMuscleKey;

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
          state.totalVolume.toStringAsFixed(0),
          'KG',
          AppTheme.cyberCyan,
          Icons.fitness_center_outlined,
        ),
        _buildKpiCard(
          'SESSIONS',
          state.completedSessions.toString(),
          'LOGGED',
          AppTheme.electricBlue,
          Icons.emoji_events_outlined,
        ),
        _buildKpiCard(
          'FORM ACCURACY',
          state.completedSessions == 0 ? 'N/A' : state.averageAccuracy.toStringAsFixed(1),
          '%',
          AppTheme.warningAmber,
          Icons.camera_enhance_outlined,
        ),
        _buildKpiCard(
          'MINUTES TRAINED',
          state.totalMinutes.toString(),
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
    final anteriorMuscles = [
      ('chest', 'Pecs / Chest'),
      ('abs', 'Abdominals'),
      ('biceps', 'Biceps'),
      ('front_deltoids', 'Front Delts'),
      ('quadriceps', 'Quads / Thighs'),
    ];
    final posteriorMuscles = [
      ('upper_back', 'Traps / Upper Back'),
      ('lower_back', 'Lats / Lower Back'),
      ('triceps', 'Triceps'),
      ('gluteal', 'Glutes / Hip'),
      ('hamstring', 'Hamstrings'),
      ('calves', 'Calves'),
    ];
    final muscles = _isAnteriorView ? anteriorMuscles : posteriorMuscles;

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
          // ── Header ────────────────────────────────────────────────
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
          const SizedBox(height: 20),

          // ── Body model + list (side-by-side) ──────────────────────
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Left: Interactive vector body ──────────────────────
              Expanded(
                flex: 5,
                child: Column(
                  children: [
                    // Model viewport
                    GestureDetector(
                      onTapUp: (details) => _onBodyTap(details.localPosition, state),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 350),
                        curve: Curves.easeInOut,
                        height: _selectedMuscleKey != null ? 280 : 240,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: CustomPaint(
                            painter: _BodyModelPainter(
                              isAnterior: _isAnteriorView,
                              muscleStats: state.muscleStats,
                              selectedKey: _selectedMuscleKey,
                            ),
                            child: const SizedBox.expand(),
                          ),
                        ),
                      ),
                    ),

                    // ── Zoom-in Stats Overlay Card ─────────────────────
                    if (_selectedMuscleKey != null) ...[
                      const SizedBox(height: 12),
                      _buildMuscleZoomCard(
                        state,
                        muscles.firstWhere(
                          (m) => m.$1 == _selectedMuscleKey,
                          orElse: () => (_selectedMuscleKey!, _selectedMuscleKey!),
                        ),
                      ),
                    ],

                    // Tap-hint caption
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _selectedMuscleKey != null
                              ? Icons.touch_app
                              : Icons.touch_app_outlined,
                          color: AppTheme.cyberCyan.withValues(alpha: 0.5),
                          size: 12,
                        ),
                        const SizedBox(width: 5),
                        Text(
                          _selectedMuscleKey != null
                              ? 'Tap empty area to reset'
                              : 'Tap a muscle to zoom & inspect',
                          style: GoogleFonts.outfit(
                            color: AppTheme.textMuted,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),

              // ── Right: Muscle list ─────────────────────────────────
              Expanded(
                flex: 4,
                child: Column(
                  children: muscles
                      .map((m) => _buildMuscleRowItem(state, m.$1, m.$2))
                      .toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Tap handler for body model ────────────────────────────────────
  void _onBodyTap(Offset localPos, AnalyticsState state) {
    // Map relative position (0..1) in the 240/280-height container
    final containerH = _selectedMuscleKey != null ? 280.0 : 240.0;
    final relY = localPos.dy / containerH;
    final relX = localPos.dx; // absolute x in px (container is full width)

    String? hit;
    if (_isAnteriorView) {
      if (relY < 0.20) {
        hit = 'front_deltoids';
      } else if (relY < 0.38) {
        hit = 'chest';
      } else if (relY < 0.56) {
        hit = 'abs';
      } else if (relY < 0.72) {
        hit = 'quadriceps';
      } else if (relX < 80 || relX > 160) {
        hit = 'biceps';
      }
    } else {
      if (relY < 0.22) {
        hit = 'upper_back';
      } else if (relY < 0.45) {
        hit = 'lower_back';
      } else if (relY < 0.60) {
        hit = 'gluteal';
      } else if (relY < 0.78) {
        hit = 'hamstring';
      } else if (relY < 0.92) {
        hit = 'calves';
      } else {
        hit = 'triceps';
      }
    }

    setState(() {
      _selectedMuscleKey = (_selectedMuscleKey == hit) ? null : hit;
    });
  }

  Widget _buildMuscleZoomCard(AnalyticsState state, (String, String) muscle) {
    final key = muscle.$1;
    final name = muscle.$2;
    final stat = state.muscleStats[key];
    final sets = stat?.totalSets ?? 0;
    final vol = stat?.totalVolume ?? 0.0;
    final exercises = stat?.topExercises ?? [];

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: 1.0,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.cyberCyan.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: AppTheme.cyberCyan.withValues(alpha: 0.35),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.cyberCyan.withValues(alpha: 0.08),
              blurRadius: 20,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics_outlined,
                    color: AppTheme.cyberCyan, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name.toUpperCase(),
                    style: GoogleFonts.outfit(
                      color: AppTheme.cyberCyan,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() => _selectedMuscleKey = null),
                  child: const Icon(Icons.close,
                      color: AppTheme.textMuted, size: 16),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildZoomStat('SETS', '$sets'),
                const SizedBox(width: 16),
                _buildZoomStat('VOLUME', '${vol.toStringAsFixed(0)} kg'),
              ],
            ),
            if (exercises.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                'TOP EXERCISES',
                style: GoogleFonts.outfit(
                  color: AppTheme.textMuted,
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
              const SizedBox(height: 6),
              ...exercises.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('›  ',
                          style: TextStyle(
                              color: AppTheme.cyberCyan, fontSize: 11)),
                      Expanded(
                        child: Text(
                          e,
                          style: GoogleFonts.outfit(
                              color: AppTheme.textSub, fontSize: 10),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else
              Text(
                'No exercises logged yet.',
                style: GoogleFonts.outfit(
                    color: AppTheme.textMuted, fontSize: 10),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildZoomStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: GoogleFonts.outfit(
                color: AppTheme.textMuted,
                fontSize: 9,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(value,
            style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold)),
      ],
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
            onTap: () => setState(() {
              _isAnteriorView = true;
              _selectedMuscleKey = null;
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: _isAnteriorView
                    ? AppTheme.cyberCyan.withValues(alpha: 0.08)
                    : Colors.transparent,
              ),
              child: Text(
                'FRONT',
                style: GoogleFonts.outfit(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: _isAnteriorView
                      ? AppTheme.cyberCyan
                      : AppTheme.textMuted,
                ),
              ),
            ),
          ),
          GestureDetector(
            onTap: () => setState(() {
              _isAnteriorView = false;
              _selectedMuscleKey = null;
            }),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: !_isAnteriorView
                    ? AppTheme.cyberCyan.withValues(alpha: 0.08)
                    : Colors.transparent,
              ),
              child: Text(
                'BACK',
                style: GoogleFonts.outfit(
                  fontSize: 9,
                  fontWeight: FontWeight.bold,
                  color: !_isAnteriorView
                      ? AppTheme.cyberCyan
                      : AppTheme.textMuted,
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
    final isSelected = _selectedMuscleKey == key;

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
      onTap: () => setState(() {
        _selectedMuscleKey = isSelected ? null : key;
      }),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.only(bottom: 8),
        padding: EdgeInsets.symmetric(
            horizontal: 12, vertical: isSelected ? 12 : 9),
        decoration: BoxDecoration(
          color: isSelected
              ? neonColor.withValues(alpha: 0.12)
              : neonColor.withValues(alpha: opacity),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? neonColor.withValues(alpha: 0.6)
                : sets > 0
                    ? neonColor.withValues(alpha: opacity + 0.1)
                    : AppTheme.cardBorderColor,
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: neonColor.withValues(alpha: 0.15),
                    blurRadius: 12,
                    spreadRadius: 1,
                  )
                ]
              : [],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                name,
                style: GoogleFonts.outfit(
                  fontSize: 11,
                  fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.w600,
                  color: sets > 0 || isSelected
                      ? Colors.white
                      : AppTheme.textMuted,
                ),
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
                const SizedBox(width: 3),
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

}

// ─── BODY MODEL PAINTER ──────────────────────────────────────────────────────
// Draws a vector silhouette of the human body (anterior / posterior) and
// colour-codes each muscle zone with a neon-cyan glow proportional to
// training volume.  The selected zone receives an animated pulse ring.

class _BodyModelPainter extends CustomPainter {
  final bool isAnterior;
  final Map<String, MuscleStat> muscleStats;
  final String? selectedKey;

  _BodyModelPainter({
    required this.isAnterior,
    required this.muscleStats,
    required this.selectedKey,
  });

  // Returns glow alpha [0..1] for a given muscle key
  double _alpha(String key) {
    final s = muscleStats[key]?.totalSets ?? 0;
    if (s >= 12) return 0.85;
    if (s >= 8) return 0.65;
    if (s >= 4) return 0.42;
    if (s >= 1) return 0.22;
    return 0.06;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // ── Background grid ────────────────────────────────────────────
    final gridPaint = Paint()
      ..color = const Color(0xFF00F5FF).withValues(alpha: 0.04)
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    const gridStep = 20.0;
    for (double x = 0; x < w; x += gridStep) {
      canvas.drawLine(Offset(x, 0), Offset(x, h), gridPaint);
    }
    for (double y = 0; y < h; y += gridStep) {
      canvas.drawLine(Offset(0, y), Offset(w, y), gridPaint);
    }

    // ── Silhouette base ────────────────────────────────────────────
    final silhouettePaint = Paint()
      ..color = const Color(0xFF00F5FF).withValues(alpha: 0.07)
      ..style = PaintingStyle.fill;

    final outlinePaint = Paint()
      ..color = const Color(0xFF00F5FF).withValues(alpha: 0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    // Whole-body silhouette (simplified polygon centred in canvas)
    final cx = w / 2;
    final headR = h * 0.065;

    // HEAD
    canvas.drawCircle(Offset(cx, h * 0.075), headR, silhouettePaint);
    canvas.drawCircle(Offset(cx, h * 0.075), headR, outlinePaint);

    // NECK
    _drawRect(canvas, cx - w * 0.055, h * 0.135, w * 0.11, h * 0.045,
        silhouettePaint, outlinePaint);

    // TORSO
    _drawRRect(canvas, cx - w * 0.185, h * 0.175, w * 0.37, h * 0.34,
        8.0, silhouettePaint, outlinePaint);

    // HIPS
    _drawRRect(canvas, cx - w * 0.175, h * 0.50, w * 0.35, h * 0.10,
        6.0, silhouettePaint, outlinePaint);

    // LEFT ARM
    _drawRRect(canvas, cx - w * 0.30, h * 0.175, w * 0.10, h * 0.33,
        14.0, silhouettePaint, outlinePaint);
    // RIGHT ARM
    _drawRRect(canvas, cx + w * 0.20, h * 0.175, w * 0.10, h * 0.33,
        14.0, silhouettePaint, outlinePaint);

    // LEFT FOREARM
    _drawRRect(canvas, cx - w * 0.30, h * 0.505, w * 0.085, h * 0.24,
        12.0, silhouettePaint, outlinePaint);
    // RIGHT FOREARM
    _drawRRect(canvas, cx + w * 0.215, h * 0.505, w * 0.085, h * 0.24,
        12.0, silhouettePaint, outlinePaint);

    // LEFT THIGH
    _drawRRect(canvas, cx - w * 0.175, h * 0.59, w * 0.155, h * 0.23,
        12.0, silhouettePaint, outlinePaint);
    // RIGHT THIGH
    _drawRRect(canvas, cx + w * 0.02, h * 0.59, w * 0.155, h * 0.23,
        12.0, silhouettePaint, outlinePaint);

    // LEFT CALF
    _drawRRect(canvas, cx - w * 0.165, h * 0.815, w * 0.13, h * 0.18,
        10.0, silhouettePaint, outlinePaint);
    // RIGHT CALF
    _drawRRect(canvas, cx + w * 0.035, h * 0.815, w * 0.13, h * 0.18,
        10.0, silhouettePaint, outlinePaint);

    // ── Muscle zone glows ──────────────────────────────────────────
    if (isAnterior) {
      _glowZone(canvas, 'chest', cx - w * 0.185, h * 0.175, w * 0.37,
          h * 0.155, 8.0);
      _glowZone(canvas, 'abs', cx - w * 0.155, h * 0.325, w * 0.31,
          h * 0.175, 8.0);
      _glowZone(canvas, 'front_deltoids', cx - w * 0.30, h * 0.175,
          w * 0.10, h * 0.11, 10.0);
      _glowZone(canvas, 'front_deltoids', cx + w * 0.20, h * 0.175,
          w * 0.10, h * 0.11, 10.0, mirror: true);
      _glowZone(canvas, 'biceps', cx - w * 0.30, h * 0.285, w * 0.10,
          h * 0.21, 10.0);
      _glowZone(canvas, 'biceps', cx + w * 0.20, h * 0.285, w * 0.10,
          h * 0.21, 10.0, mirror: true);
      _glowZone(canvas, 'quadriceps', cx - w * 0.175, h * 0.59,
          w * 0.155, h * 0.23, 12.0);
      _glowZone(canvas, 'quadriceps', cx + w * 0.02, h * 0.59,
          w * 0.155, h * 0.23, 12.0, mirror: true);
    } else {
      _glowZone(canvas, 'upper_back', cx - w * 0.185, h * 0.175,
          w * 0.37, h * 0.145, 8.0);
      _glowZone(canvas, 'lower_back', cx - w * 0.155, h * 0.315,
          w * 0.31, h * 0.175, 8.0);
      _glowZone(canvas, 'triceps', cx - w * 0.30, h * 0.285, w * 0.10,
          h * 0.22, 10.0);
      _glowZone(canvas, 'triceps', cx + w * 0.20, h * 0.285, w * 0.10,
          h * 0.22, 10.0, mirror: true);
      _glowZone(canvas, 'gluteal', cx - w * 0.175, h * 0.59,
          w * 0.155, h * 0.11, 12.0);
      _glowZone(canvas, 'gluteal', cx + w * 0.02, h * 0.59,
          w * 0.155, h * 0.11, 12.0, mirror: true);
      _glowZone(canvas, 'hamstring', cx - w * 0.175, h * 0.70,
          w * 0.155, h * 0.12, 12.0);
      _glowZone(canvas, 'hamstring', cx + w * 0.02, h * 0.70,
          w * 0.155, h * 0.12, 12.0, mirror: true);
      _glowZone(canvas, 'calves', cx - w * 0.165, h * 0.815,
          w * 0.13, h * 0.18, 10.0);
      _glowZone(canvas, 'calves', cx + w * 0.035, h * 0.815,
          w * 0.13, h * 0.18, 10.0, mirror: true);
    }

    // ── Selected zone pulse ring ───────────────────────────────────
    if (selectedKey != null) {
      _drawSelectionRing(canvas, selectedKey!, w, h, cx);
    }

    // ── Scan-line overlay ──────────────────────────────────────────
    final scanPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF00F5FF).withValues(alpha: 0.00),
          const Color(0xFF00F5FF).withValues(alpha: 0.03),
          const Color(0xFF00F5FF).withValues(alpha: 0.00),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawRect(Rect.fromLTWH(0, 0, w, h), scanPaint);

    // ── Side label ─────────────────────────────────────────────────
    final labelPainter = TextPainter(
      text: TextSpan(
        text: isAnterior ? 'ANTERIOR' : 'POSTERIOR',
        style: const TextStyle(
          color: Color(0xFF00F5FF),
          fontSize: 7.5,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.5,
        ),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    labelPainter.paint(
        canvas, Offset((w - labelPainter.width) / 2, h - 14));
  }

  // Draws a glowing rounded-rect for a muscle zone
  void _glowZone(Canvas canvas, String key, double x, double y, double zw,
      double zh, double radius,
      {bool mirror = false}) {
    final a = _alpha(key);
    final bool isSelected = selectedKey == key;
    final glowAlpha = isSelected ? (a + 0.25).clamp(0.0, 1.0) : a;

    final fillPaint = Paint()
      ..color = const Color(0xFF00F5FF).withValues(alpha: glowAlpha * 0.28)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, isSelected ? 14 : 8)
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = const Color(0xFF00F5FF).withValues(alpha: glowAlpha * 0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = isSelected ? 1.8 : 0.8;

    final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, zw, zh), Radius.circular(radius));
    canvas.drawRRect(rect, fillPaint);
    canvas.drawRRect(rect, borderPaint);
  }

  // Draws a pulsing selection ring around the selected zone
  void _drawSelectionRing(
      Canvas canvas, String key, double w, double h, double cx) {
    Rect zone;
    switch (key) {
      case 'chest':
        zone = Rect.fromLTWH(cx - w * 0.185, h * 0.175, w * 0.37, h * 0.155);
        break;
      case 'abs':
        zone = Rect.fromLTWH(cx - w * 0.155, h * 0.325, w * 0.31, h * 0.175);
        break;
      case 'front_deltoids':
        zone = Rect.fromLTWH(cx - w * 0.30, h * 0.175, w * 0.70, h * 0.11);
        break;
      case 'biceps':
        zone = Rect.fromLTWH(cx - w * 0.31, h * 0.28, w * 0.62, h * 0.22);
        break;
      case 'quadriceps':
        zone = Rect.fromLTWH(cx - w * 0.175, h * 0.59, w * 0.35, h * 0.23);
        break;
      case 'upper_back':
        zone = Rect.fromLTWH(cx - w * 0.185, h * 0.175, w * 0.37, h * 0.145);
        break;
      case 'lower_back':
        zone = Rect.fromLTWH(cx - w * 0.155, h * 0.315, w * 0.31, h * 0.175);
        break;
      case 'triceps':
        zone = Rect.fromLTWH(cx - w * 0.31, h * 0.28, w * 0.62, h * 0.22);
        break;
      case 'gluteal':
        zone = Rect.fromLTWH(cx - w * 0.175, h * 0.59, w * 0.35, h * 0.11);
        break;
      case 'hamstring':
        zone = Rect.fromLTWH(cx - w * 0.175, h * 0.70, w * 0.35, h * 0.12);
        break;
      case 'calves':
        zone = Rect.fromLTWH(cx - w * 0.165, h * 0.815, w * 0.30, h * 0.18);
        break;
      default:
        return;
    }

    // Outer glow ring
    final ringPaint = Paint()
      ..color = const Color(0xFF00F5FF).withValues(alpha: 0.55)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawRRect(
        RRect.fromRectAndRadius(
            zone.inflate(5), const Radius.circular(10)),
        ringPaint);

    // Corner accent lines
    final accentPaint = Paint()
      ..color = const Color(0xFF00F5FF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    const cl = 8.0; // corner line length
    final r = zone.inflate(5);
    // Top-left
    canvas.drawLine(r.topLeft, r.topLeft + const Offset(cl, 0), accentPaint);
    canvas.drawLine(r.topLeft, r.topLeft + const Offset(0, cl), accentPaint);
    // Top-right
    canvas.drawLine(r.topRight, r.topRight + const Offset(-cl, 0), accentPaint);
    canvas.drawLine(r.topRight, r.topRight + const Offset(0, cl), accentPaint);
    // Bottom-left
    canvas.drawLine(
        r.bottomLeft, r.bottomLeft + const Offset(cl, 0), accentPaint);
    canvas.drawLine(
        r.bottomLeft, r.bottomLeft + const Offset(0, -cl), accentPaint);
    // Bottom-right
    canvas.drawLine(
        r.bottomRight, r.bottomRight + const Offset(-cl, 0), accentPaint);
    canvas.drawLine(
        r.bottomRight, r.bottomRight + const Offset(0, -cl), accentPaint);
  }

  void _drawRect(Canvas canvas, double x, double y, double rw, double rh,
      Paint fill, Paint stroke) {
    final rect = Rect.fromLTWH(x, y, rw, rh);
    canvas.drawRect(rect, fill);
    canvas.drawRect(rect, stroke);
  }

  void _drawRRect(Canvas canvas, double x, double y, double rw, double rh,
      double r, Paint fill, Paint stroke) {
    final rect =
        RRect.fromRectAndRadius(Rect.fromLTWH(x, y, rw, rh), Radius.circular(r));
    canvas.drawRRect(rect, fill);
    canvas.drawRRect(rect, stroke);
  }

  @override
  bool shouldRepaint(_BodyModelPainter oldDelegate) =>
      oldDelegate.isAnterior != isAnterior ||
      oldDelegate.selectedKey != selectedKey ||
      oldDelegate.muscleStats != muscleStats;
}
