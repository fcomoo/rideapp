import 'package:flutter_test/flutter_test.dart';
import 'package:fake_async/fake_async.dart';

void main() {
  group('MapTracker Throttle Logic Tests', () {
    test('Manual Throttle: should filter events emitted within 1000ms', () {
      fakeAsync((async) {
        int processedCount = 0;
        int? lastEmitMs;

        bool shouldProcess() {
          final nowMs = async.elapsed.inMilliseconds;
          if (lastEmitMs == null || (nowMs - lastEmitMs!) >= 1000) {
            lastEmitMs = nowMs;
            return true;
          }
          return false;
        }

        // t=0ms: primer evento — debe procesarse
        if (shouldProcess()) processedCount++;
        expect(processedCount, equals(1));

        // t=500ms: segundo evento — debe descartarse
        async.elapse(const Duration(milliseconds: 500));
        if (shouldProcess()) processedCount++;
        expect(processedCount, equals(1));

        // t=1500ms: tercer evento — debe procesarse
        async.elapse(const Duration(milliseconds: 1000));
        if (shouldProcess()) processedCount++;
        expect(
          processedCount,
          equals(2),
          reason: 'Evento en t=1500ms debe pasar',
        );
      });
    });
  });
}
