/// Dedup de operaciones asíncronas "en vuelo" por clave.
///
/// Si se piden varias ejecuciones para la MISMA clave mientras una sigue
/// corriendo, todas comparten el mismo Future en vez de disparar la operación
/// (cara) varias veces. Cuando termina, la clave queda libre para reintentos.
///
/// Caso de uso: evitar ráfagas de llamadas a la IA al generar el plan semanal
/// (abrir la pantalla + tocar varios días mientras la edge tarda ~30-47s
/// disparaba una invocación por cada toque).
class SingleFlight<K> {
  final Map<K, Future<void>> _inFlight = {};

  /// ¿Hay una operación en vuelo para [key]?
  bool isInFlight(K key) => _inFlight.containsKey(key);

  /// Ejecuta [action] para [key], o reusa la que ya esté en vuelo para esa
  /// misma clave. Devuelve el Future compartido.
  Future<void> run(K key, Future<void> Function() action) {
    final existing = _inFlight[key];
    if (existing != null) return existing;
    final future = action();
    _inFlight[key] = future;
    return future.whenComplete(() {
      if (identical(_inFlight[key], future)) {
        _inFlight.remove(key);
      }
    });
  }
}
