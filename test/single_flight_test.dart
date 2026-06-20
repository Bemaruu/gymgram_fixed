import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:gymgram_beta/services/single_flight.dart';

void main() {
  group('SingleFlight', () {
    test('colapsa N llamadas concurrentes de la MISMA clave en 1 ejecución',
        () async {
      final flight = SingleFlight<int>();
      var invocations = 0;
      final gate = Completer<void>();

      Future<void> action() async {
        invocations++;
        await gate.future; // mantiene la operación "en vuelo"
      }

      // 15 disparos concurrentes para el mismo week_index (= 15 toques de día
      // mientras la edge tarda). Debe ejecutarse UNA sola vez.
      final futures = List.generate(15, (_) => flight.run(7, action));

      expect(invocations, 1, reason: 'solo 1 invocación a la IA');
      expect(flight.isInFlight(7), isTrue);

      gate.complete();
      await Future.wait(futures);

      expect(flight.isInFlight(7), isFalse, reason: 'la clave queda libre');
    });

    test('claves distintas (semanas distintas) NO se deduplican entre sí',
        () async {
      final flight = SingleFlight<int>();
      var invocations = 0;
      final gate = Completer<void>();

      Future<void> action() async {
        invocations++;
        await gate.future;
      }

      final a = flight.run(7, action);
      final b = flight.run(8, action);

      expect(invocations, 2);

      gate.complete();
      await Future.wait([a, b]);
    });

    test('tras completar, una nueva llamada SÍ vuelve a ejecutar (reintento)',
        () async {
      final flight = SingleFlight<int>();
      var invocations = 0;

      Future<void> action() async => invocations++;

      await flight.run(7, action);
      await flight.run(7, action);

      expect(invocations, 2);
    });

    test('si la operación falla, la clave se libera para reintentar', () async {
      final flight = SingleFlight<int>();
      var invocations = 0;

      Future<void> action() async {
        invocations++;
        throw StateError('edge 502');
      }

      await expectLater(flight.run(7, action), throwsStateError);
      expect(flight.isInFlight(7), isFalse);

      await expectLater(flight.run(7, action), throwsStateError);
      expect(invocations, 2);
    });
  });
}
