import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../services/food_service.dart';

enum _ScanState { scanning, loading, notFound, errorNet, nonFood }

class BarcodeScannerScreen extends StatefulWidget {
  const BarcodeScannerScreen({super.key});

  @override
  State<BarcodeScannerScreen> createState() => _BarcodeScannerScreenState();
}

class _BarcodeScannerScreenState extends State<BarcodeScannerScreen>
    with SingleTickerProviderStateMixin {
  static const _viewerW = 280.0;
  static const _viewerH = 180.0;

  late final MobileScannerController _controller;
  late final AnimationController _animCtrl;
  late final Animation<double> _lineAnim;

  _ScanState _state = _ScanState.scanning;
  bool _torchOn = false;
  bool _processed = false;

  @override
  void initState() {
    super.initState();
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.noDuplicates,
    );
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
    _lineAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animCtrl, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processed) return;
    final barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    final raw = barcodes.first.rawValue;
    if (raw == null || raw.isEmpty) return;

    _processed = true;
    HapticFeedback.mediumImpact();
    await _controller.stop();

    setState(() => _state = _ScanState.loading);

    try {
      final food = await FoodService.instance.lookupBarcode(raw);
      if (!mounted) return;

      if (food == null) {
        setState(() => _state = _ScanState.notFound);
        return;
      }

      final name = food.name.trim();
      final hasNutriments = food.kcalPer100g != null;
      if (name.isEmpty || !hasNutriments) {
        setState(() => _state = _ScanState.nonFood);
        return;
      }

      if (mounted) Navigator.pop(context, food);
    } catch (_) {
      if (mounted) setState(() => _state = _ScanState.errorNet);
    }
  }

  Future<void> _restart() async {
    _processed = false;
    await _controller.start();
    if (mounted) setState(() => _state = _ScanState.scanning);
  }

  void _toggleTorch() {
    _controller.toggleTorch();
    setState(() => _torchOn = !_torchOn);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          _buildOverlay(context),
          if (_state != _ScanState.scanning && _state != _ScanState.loading)
            _buildStateOverlay(context),
          if (_state == _ScanState.loading)
            _buildLoadingOverlay(),
        ],
      ),
    );
  }

  Widget _buildOverlay(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final left = centerX - _viewerW / 2;
    final top = centerY - _viewerH / 2;

    return Stack(
      children: [
        // Zonas oscuras alrededor del visor
        Positioned(top: 0, left: 0, right: 0, height: top,
            child: const ColoredBox(color: Color(0x99000000))),
        Positioned(bottom: 0, left: 0, right: 0,
            height: size.height - top - _viewerH,
            child: const ColoredBox(color: Color(0x99000000))),
        Positioned(top: top, left: 0, width: left, height: _viewerH,
            child: const ColoredBox(color: Color(0x99000000))),
        Positioned(top: top, right: 0,
            width: size.width - left - _viewerW, height: _viewerH,
            child: const ColoredBox(color: Color(0x99000000))),

        // Marco con esquinas en L
        Positioned(
          left: left,
          top: top,
          child: SizedBox(
            width: _viewerW,
            height: _viewerH,
            child: CustomPaint(painter: _CornerPainter()),
          ),
        ),

        // Linea animada de escaneo
        Positioned(
          left: left,
          top: top,
          width: _viewerW,
          height: _viewerH,
          child: AnimatedBuilder(
            animation: _lineAnim,
            builder: (_, __) {
              return CustomPaint(
                painter: _ScanLinePainter(_lineAnim.value),
              );
            },
          ),
        ),

        // AppBar transparente
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          child: Container(
            color: Colors.black54,
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                height: 56,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                    const Expanded(
                      child: Text(
                        'Escanear alimento',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(
                        _torchOn ? Icons.flash_on : Icons.flash_off,
                        color: Colors.white,
                      ),
                      onPressed: _toggleTorch,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Texto instruccion debajo del visor
        Positioned(
          top: top + _viewerH + 20,
          left: 0,
          right: 0,
          child: const Text(
            'Apunta al codigo de barras del producto',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70, fontSize: 14),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.75),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: Color(0xFF00BFFF)),
            SizedBox(height: 20),
            Text(
              'Buscando producto...',
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStateOverlay(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.75),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: switch (_state) {
            _ScanState.notFound => _NotFoundOverlay(
                onScanAgain: _restart,
                onSearchByName: () => Navigator.pop(context),
              ),
            _ScanState.errorNet => _ErrorNetOverlay(onRetry: _restart),
            _ScanState.nonFood => _NonFoodOverlay(onScanAgain: _restart),
            _ => const SizedBox.shrink(),
          },
        ),
      ),
    );
  }
}

class _CornerPainter extends CustomPainter {
  static const _cornerLen = 24.0;
  static const _strokeW = 3.0;
  static const _color = Color(0xFF00BFFF);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _color
      ..strokeWidth = _strokeW
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.square;

    final w = size.width;
    final h = size.height;

    // Top-left
    canvas.drawLine(const Offset(0, _cornerLen), Offset.zero, paint);
    canvas.drawLine(Offset.zero, const Offset(_cornerLen, 0), paint);
    // Top-right
    canvas.drawLine(Offset(w - _cornerLen, 0), Offset(w, 0), paint);
    canvas.drawLine(Offset(w, 0), Offset(w, _cornerLen), paint);
    // Bottom-left
    canvas.drawLine(Offset(0, h - _cornerLen), Offset(0, h), paint);
    canvas.drawLine(Offset(0, h), Offset(_cornerLen, h), paint);
    // Bottom-right
    canvas.drawLine(Offset(w - _cornerLen, h), Offset(w, h), paint);
    canvas.drawLine(Offset(w, h), Offset(w, h - _cornerLen), paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ScanLinePainter extends CustomPainter {
  final double progress;
  const _ScanLinePainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * progress;
    final paint = Paint()
      ..color = const Color(0xFF00BFFF).withValues(alpha: 0.85)
      ..strokeWidth = 2.0;
    canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
  }

  @override
  bool shouldRepaint(covariant _ScanLinePainter old) => old.progress != progress;
}

class _NotFoundOverlay extends StatelessWidget {
  final VoidCallback onScanAgain;
  final VoidCallback onSearchByName;

  const _NotFoundOverlay({
    required this.onScanAgain,
    required this.onSearchByName,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.search_off, color: Colors.white, size: 48),
        const SizedBox(height: 16),
        const Text(
          'Producto no encontrado',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          'No encontramos informacion nutricional\npara este codigo de barras.',
          style: TextStyle(color: Colors.white70, fontSize: 14),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onScanAgain,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00BFFF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('Escanear de nuevo',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: onSearchByName,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.white54),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('Buscar por nombre',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }
}

class _ErrorNetOverlay extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorNetOverlay({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.wifi_off_outlined, color: Colors.white, size: 48),
        const SizedBox(height: 16),
        const Text(
          'Error de conexion',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          'No pudimos conectar con la base de datos.\nRevisa tu conexion e intenta de nuevo.',
          style: TextStyle(color: Colors.white70, fontSize: 14),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00BFFF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('Reintentar',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }
}

class _NonFoodOverlay extends StatelessWidget {
  final VoidCallback onScanAgain;
  const _NonFoodOverlay({required this.onScanAgain});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.no_food_outlined,
            color: Color(0xFFFFD700), size: 48),
        const SizedBox(height: 16),
        const Text(
          'Producto sin datos nutricionales',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          'Este producto no tiene informacion\nnutricional registrada.',
          style: TextStyle(color: Colors.white70, fontSize: 14),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: onScanAgain,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00BFFF),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('Escanear otro',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
  }
}
