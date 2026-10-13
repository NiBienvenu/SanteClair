import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_theme.dart';
import '../../core/widgets/app_bars.dart';
import '../../core/widgets/common.dart';
import '../../data/models/doctor.dart';
import '../../data/providers.dart';
import '../../router/app_router.dart';
import 'patient_home_screen.dart';

class DoctorSearchScreen extends ConsumerStatefulWidget {
  const DoctorSearchScreen({
    super.key,
    this.initialQuery = '',
    this.specialty,
    this.video = false,
  });

  final String initialQuery;
  final String? specialty;
  final bool video;

  @override
  ConsumerState<DoctorSearchScreen> createState() => _DoctorSearchScreenState();
}

class _DoctorSearchScreenState extends ConsumerState<DoctorSearchScreen> {
  static const _filters = {
    null: 'Tous',
    'generaliste': 'Généraliste',
    'cardiologue': 'Cardiologue',
    'dermatologue': 'Dermatologue',
    'dentiste': 'Dentiste',
    'pediatre': 'Pédiatre',
  };

  late final TextEditingController _controller = TextEditingController(text: widget.initialQuery);
  late String _query = widget.initialQuery;
  late String? _specialty = widget.specialty;
  late bool _video = widget.video;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => setState(() => _query = value.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final DoctorQuery query = (query: _query, specialty: _specialty, video: _video);
    final results = ref.watch(doctorSearchProvider(query));
    return Scaffold(
      appBar: const BackAppBar(title: 'Trouver un praticien'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              controller: _controller,
              autofocus: widget.initialQuery.isEmpty && widget.specialty == null && !widget.video,
              onChanged: _onChanged,
              decoration: const InputDecoration(
                hintText: 'Médecin, spécialité, ville...',
                prefixIcon: Icon(Icons.search),
              ),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: const Text('Vidéo'),
                    avatar: const Icon(Icons.videocam_outlined, size: 16),
                    selected: _video,
                    onSelected: (v) => setState(() => _video = v),
                  ),
                ),
                for (final entry in _filters.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(entry.value),
                      selected: _specialty == entry.key,
                      onSelected: (_) => setState(() => _specialty = entry.key),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: AsyncValueView<List<Doctor>>(
              value: results,
              onRetry: () => ref.invalidate(doctorSearchProvider(query)),
              builder: (doctors) => doctors.isEmpty
                  ? const Center(
                      child: Text('Aucun praticien ne correspond à votre recherche.',
                          style: TextStyle(color: AppColors.textSecondary)),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: doctors.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => DoctorRow(
                        doctor: doctors[i],
                        showFee: true,
                        action: FilledButton(
                          style: FilledButton.styleFrom(
                            minimumSize: const Size(0, 34),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          onPressed: () => context.push(Routes.booking(doctors[i].id)),
                          child: const Text('Prendre RDV'),
                        ),
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
