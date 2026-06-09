import 'package:flutter_test/flutter_test.dart';
import 'package:core_360_app/features/workouts/presentation/providers/ai_planner_provider.dart';

void main() {
  group('parseWorkoutWeightValue', () {
    test('returns 0 for bodyweight values', () {
      expect(parseWorkoutWeightValue('Bodyweight'), 0.0);
      expect(parseWorkoutWeightValue('body'), 0.0);
    });

    test('normalizes volume-like values to the per-set weight', () {
      expect(normalizeRoutineWeightValue(200.0, 10), 20.0);
      expect(normalizeRoutineWeightValue(180.0, 10), 18.0);
    });

    test('uses the provided value when the weight is constant across sets', () {
      expect(parseWorkoutWeightValue('20'), 20.0);
      expect(parseWorkoutWeightValue('20 kg'), 20.0);
    });

    test('uses the highest value when multiple weights are supplied', () {
      expect(parseWorkoutWeightValue('20-25 kg'), 25.0);
      expect(parseWorkoutWeightValue('20 / 25 kg'), 25.0);
      expect(parseWorkoutWeightValue('15, 20, 25 kg'), 25.0);
    });
  });
}
