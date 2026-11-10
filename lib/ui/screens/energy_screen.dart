import 'package:flutter/material.dart';

import '../../state/home_store.dart';
import '../theme.dart';
import '../widgets.dart';

/// Live power for the house and per circuit (dSM). Polls every 5 s while [active].
class EnergyScreen extends StatefulWidget {
  const EnergyScreen({super.key, required this.active});

  final bool active;

  @override
  State<EnergyScreen> createState() => _EnergyScreenState();
}

class _EnergyScreenState extends State<EnergyScreen> {
  HomeStore? _store;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _store ??= StoreScope.read(context);
    _store!.watchEnergy(widget.active);
  }

  @override
  void didUpdateWidget(EnergyScreen old) {
    super.didUpdateWidget(old);
    if (old.active != widget.active) _store?.watchEnergy(widget.active);
  }

  @override
  void dispose() {
    _store?.watchEnergy(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = StoreScope.of(context);
    final circuits = store.circuits;
    final max = circuits.isEmpty ? 1.0 : circuits.map((c) => c.watts).reduce((a, b) => a > b ? a : b).clamp(1, double.infinity);
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          const Padding(padding: EdgeInsets.fromLTRB(4, 0, 0, 12), child: Text('Energie', style: bigTitle)),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            decoration: BoxDecoration(color: AppColors.text, borderRadius: BorderRadius.circular(24)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                      color: store.online ? const Color(0xFF5BD18B) : AppColors.danger, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text(store.online ? 'Live · ganzes Haus' : 'Keine Verbindung',
                    style: const TextStyle(color: Color(0xFFC9CBD0), fontSize: 13)),
              ]),
              const SizedBox(height: 4),
              Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                Text(store.totalWatts?.round().toString() ?? '–',
                    style: const TextStyle(
                        color: Colors.white, fontSize: 64, fontWeight: FontWeight.w700, letterSpacing: -2)),
                const SizedBox(width: 6),
                const Text('W', style: TextStyle(color: Color(0xFFC9CBD0), fontSize: 22, fontWeight: FontWeight.w600)),
              ]),
            ]),
          ),
          const SizedBox(height: 12),
          Card2(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('STROMKREISE', style: sectionLabel),
              const SizedBox(height: 8),
              if (circuits.isEmpty) const Text('Lädt …', style: TextStyle(color: AppColors.text2)),
              for (final c in circuits)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Semantics(
                    label: '${c.name}: ${c.watts.round()} Watt',
                    child: ExcludeSemantics(
                      child: Column(children: [
                        Row(children: [
                          Expanded(child: Text(c.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500))),
                          Text('${c.watts.round()} W',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                        ]),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(5),
                          child: LinearProgressIndicator(
                            value: (c.watts / max).clamp(0.02, 1.0),
                            minHeight: 10,
                            color: AppColors.blind,
                            backgroundColor: AppColors.track,
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
            ]),
          ),
        ],
      ),
    );
  }
}
