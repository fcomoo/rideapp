import 'package:flutter_test/flutter_test.dart';
import 'package:fake_async/fake_async.dart';
import 'package:rideapp_client/core/antigravity/kill_switch.dart';
import 'package:rideapp_client/domain/entities/trip.dart';
import 'package:rideapp_client/core/antigravity/profile.dart';

void main() {
  group('KillSwitch Tests (Pure Dart)', () {
    late KillSwitch killSwitch;
    late Trip mockTrip;

    setUp(() {
      killSwitch = KillSwitch();
      mockTrip = Trip(
        id: 'test-trip-uuid',
        clientId: 'client-123',
        status: TripStatus.requested,
        route: [], // Usamos lista vacía o Coordinates
      );
    });

    tearDown(() {
      killSwitch.cancel();
    });

    test('Should trigger onTimeout after 60 seconds (default profile)', () {
      fakeAsync((async) {
        bool triggered = false;

        killSwitch.startSearchTimeout(
          trip: mockTrip,
          onTimeout: () {
            triggered = true;
          },
        );

        async.elapse(AntigravityProfile.searchTimeout - const Duration(seconds: 1));
        expect(triggered, isFalse);

        async.elapse(const Duration(seconds: 1));
        expect(triggered, isTrue);
      });
    });

    test('Should NOT trigger if cancelled before timeout', () {
      fakeAsync((async) {
        bool triggered = false;

        killSwitch.startSearchTimeout(
          trip: mockTrip,
          onTimeout: () {
            triggered = true;
          },
        );

        async.elapse(AntigravityProfile.searchTimeout ~/ 2);
        killSwitch.cancel();

        async.elapse(AntigravityProfile.searchTimeout); 
        expect(triggered, isFalse);
      });
    });
  });
}
