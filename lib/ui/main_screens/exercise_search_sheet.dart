import 'package:flutter/material.dart';
import '../../services/exercise_service.dart';

class ExerciseSearchSheet extends StatefulWidget {
  final String? preselectedMuscle;
  final String userLocation;
  final void Function(Map<String, dynamic>) onExerciseSelected;

  const ExerciseSearchSheet({
    super.key,
    this.preselectedMuscle,
    required this.userLocation,
    required this.onExerciseSelected,
  });

  @override
  State<ExerciseSearchSheet> createState() => _ExerciseSearchSheetState();
}

class _ExerciseSearchSheetState extends State<ExerciseSearchSheet> {
  late String _selectedMuscle;
  final _searchController = TextEditingController();
  List<Map<String, dynamic>> _exercises = [];
  bool _isLoading = true;
  int? _expandedIndex;

  @override
  void initState() {
    super.initState();
    _selectedMuscle = widget.preselectedMuscle ?? 'Todos';
    _load();
    _searchController.addListener(() => _load());
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _isLoading = true);
    final results = await ExerciseService.instance.getExercises(
      muscleGroup: _selectedMuscle == 'Todos' ? null : _selectedMuscle,
      query: _searchController.text.trim().isEmpty
          ? null
          : _searchController.text.trim(),
    );
    if (mounted) {
      setState(() {
        _exercises = results;
        _isLoading = false;
        _expandedIndex = null;
      });
    }
  }

  void _selectMuscle(String muscle) {
    setState(() {
      _selectedMuscle = muscle;
      _expandedIndex = null;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Buscar ejercicio',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.black54),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.grey[100],
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: Colors.black38,
                    size: 20,
                  ),
                  hintText: 'Buscar ejercicio...',
                  hintStyle: const TextStyle(color: Colors.black38, fontSize: 14),
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            SizedBox(
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: ExerciseService.muscleGroups.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) {
                  final m = ExerciseService.muscleGroups[i];
                  final isActive = m == _selectedMuscle;
                  return GestureDetector(
                    onTap: () => _selectMuscle(m),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isActive
                            ? const Color(0xFF00BFFF)
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(20),
                        border: isActive
                            ? null
                            : Border.all(color: Colors.grey[200]!),
                      ),
                      child: Text(
                        m,
                        style: TextStyle(
                          color: isActive ? Colors.white : Colors.black54,
                          fontSize: 13,
                          fontWeight: isActive
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _isLoading
                      ? 'Cargando...'
                      : '$_selectedMuscle — ${_exercises.length} ejercicios',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Colors.black45,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF00BFFF),
                      ),
                    )
                  : _exercises.isEmpty
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.search_off_rounded,
                                color: Colors.black26,
                                size: 48,
                              ),
                              SizedBox(height: 12),
                              Text(
                                'Sin ejercicios para este filtro',
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.black38,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          controller: scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _exercises.length,
                          itemBuilder: (_, i) {
                            final ex = _exercises[i];
                            final isExpanded = _expandedIndex == i;
                            return _ExerciseItem(
                              exercise: ex,
                              isExpanded: isExpanded,
                              onTap: () => setState(
                                () => _expandedIndex = isExpanded ? null : i,
                              ),
                              onAdd: (sets, reps) {
                                Navigator.pop(context);
                                widget.onExerciseSelected({
                                  ...ex,
                                  '_sets': sets,
                                  '_reps': reps,
                                });
                              },
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExerciseItem extends StatefulWidget {
  final Map<String, dynamic> exercise;
  final bool isExpanded;
  final VoidCallback onTap;
  final void Function(int sets, String reps) onAdd;

  const _ExerciseItem({
    required this.exercise,
    required this.isExpanded,
    required this.onTap,
    required this.onAdd,
  });

  @override
  State<_ExerciseItem> createState() => _ExerciseItemState();
}

class _ExerciseItemState extends State<_ExerciseItem> {
  int _sets = 3;
  String _reps = '8-12 reps';
  static const _repsOptions = [
    '6-8 reps',
    '8-12 reps',
    '12-15 reps',
    '15-20 reps',
  ];

  @override
  Widget build(BuildContext context) {
    final ex = widget.exercise;
    final tags = <String>[];
    if (ex['location'] == 'gym') tags.add('Gym');
    if (ex['location'] == 'home') tags.add('Casa');
    if (ex['location'] == 'both') {
      tags.add('Gym');
      tags.add('Casa');
    }
    final equipment = (ex['equipment'] as List?)?.cast<String>() ?? [];
    if (equipment.isNotEmpty) tags.add(equipment.first);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00BFFF).withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.fitness_center,
                      color: Color(0xFF00BFFF),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ex['name_es'] as String,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          ex['muscle_group_primary'] as String,
                          style: const TextStyle(
                            color: Color(0xFF00BFFF),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 4,
                          children: tags
                              .map(
                                (t) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    t,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.black54,
                                    ),
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: widget.onTap,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      widget.isExpanded ? 'Cerrar' : '+ Agregar',
                      style: const TextStyle(
                        color: Color(0xFF00BFFF),
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (widget.isExpanded) ...[
            Divider(color: Colors.grey[200], height: 1),
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Series',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black45,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(
                                    Icons.remove_circle_outline,
                                    color: Colors.black38,
                                  ),
                                  onPressed: _sets > 1
                                      ? () => setState(() => _sets--)
                                      : null,
                                  constraints: const BoxConstraints(
                                    minWidth: 36,
                                    minHeight: 36,
                                  ),
                                ),
                                SizedBox(
                                  width: 32,
                                  child: Text(
                                    '$_sets',
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.add_circle_outline,
                                    color: Color(0xFF00BFFF),
                                  ),
                                  onPressed: _sets < 6
                                      ? () => setState(() => _sets++)
                                      : null,
                                  constraints: const BoxConstraints(
                                    minWidth: 36,
                                    minHeight: 36,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Repeticiones',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black45,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            DropdownButtonFormField<String>(
                              value: _reps,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.grey[200],
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                              ),
                              items: _repsOptions
                                  .map(
                                    (r) => DropdownMenuItem(
                                      value: r,
                                      child: Text(
                                        r,
                                        style: const TextStyle(fontSize: 13),
                                      ),
                                    ),
                                  )
                                  .toList(),
                              onChanged: (v) => setState(() => _reps = v!),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () =>
                          widget.onAdd(_sets, _reps.replaceAll(' reps', '')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00BFFF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: const Text(
                        'Agregar a mi rutina',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
