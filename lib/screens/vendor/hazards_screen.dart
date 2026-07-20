import 'package:flutter/material.dart';
import '../../models/route_hazard.dart';
import '../../services/hazard_service.dart';
import '../../utils/constants.dart';
import '../../widgets/custom_button.dart';

/// Lets the vendor build up her own knowledge of problem spots on campus —
/// the one route factor no API can supply. Feeds straight into
/// route_optimizer_service.dart's cost function.
class HazardsScreen extends StatefulWidget {
  const HazardsScreen({super.key});

  @override
  State<HazardsScreen> createState() => _HazardsScreenState();
}

class _HazardsScreenState extends State<HazardsScreen> {
  final _hazardService = HazardService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Route Hazards'),
        backgroundColor: Colors.deepPurple,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showReportDialog(context),
        child: const Icon(Icons.add),
      ),
      body: StreamBuilder<List<RouteHazard>>(
        stream: _hazardService.streamActiveHazards(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final hazards = snapshot.data!;
          if (hazards.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No hazards reported yet. Tap + to flag a problem spot '
                  '(a flooded path, a gate that closes early, etc.) — the '
                  'route planner will factor it in from now on.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: hazards.length,
            itemBuilder: (context, index) {
              final hazard = hazards[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: Icon(
                    Icons.warning_amber_rounded,
                    color: switch (hazard.severity) {
                      HazardSeverity.low => Colors.amber,
                      HazardSeverity.medium => Colors.orange,
                      HazardSeverity.high => Colors.red,
                    },
                  ),
                  title: Text(hazard.description),
                  subtitle: Text(_conditionLabel(hazard.activeWhen)),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _hazardService.deactivateHazard(hazard.id),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _conditionLabel(HazardCondition condition) {
    return switch (condition) {
      HazardCondition.always => 'Always active',
      HazardCondition.duringRain => 'Only when it rains',
      HazardCondition.atNight => 'Only at night',
    };
  }

  Future<void> _showReportDialog(BuildContext context) async {
    final descriptionController = TextEditingController();
    var selectedBuilding = CampusLocations.buildings.first;
    var selectedSeverity = HazardSeverity.medium;
    var selectedCondition = HazardCondition.always;

    await showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: const Text('Report a hazard'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'What\'s the problem?',
                    hintText: 'e.g. "Path floods badly when it rains"',
                  ),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<dynamic>(
                  initialValue: selectedBuilding,
                  decoration: const InputDecoration(
                    labelText: 'Near which building',
                  ),
                  items: CampusLocations.buildings
                      .map(
                        (b) => DropdownMenuItem(value: b, child: Text(b.name)),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setDialogState(() => selectedBuilding = value),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<HazardSeverity>(
                  initialValue: selectedSeverity,
                  decoration: const InputDecoration(labelText: 'Severity'),
                  items: HazardSeverity.values
                      .map(
                        (s) => DropdownMenuItem(value: s, child: Text(s.name)),
                      )
                      .toList(),
                  onChanged: (value) =>
                      setDialogState(() => selectedSeverity = value!),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<HazardCondition>(
                  initialValue: selectedCondition,
                  decoration: const InputDecoration(
                    labelText: 'When does this apply?',
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: HazardCondition.always,
                      child: Text('Always'),
                    ),
                    DropdownMenuItem(
                      value: HazardCondition.duringRain,
                      child: Text('Only when raining'),
                    ),
                    DropdownMenuItem(
                      value: HazardCondition.atNight,
                      child: Text('Only at night'),
                    ),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => selectedCondition = value!),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            CustomButton(
              label: 'Report',
              onPressed: () {
                if (descriptionController.text.trim().isEmpty) return;
                _hazardService.reportHazard(
                  RouteHazard(
                    id: '',
                    description: descriptionController.text.trim(),
                    latitude: selectedBuilding.latitude,
                    longitude: selectedBuilding.longitude,
                    severity: selectedSeverity,
                    activeWhen: selectedCondition,
                    reportedAt: DateTime.now(),
                  ),
                );
                Navigator.pop(dialogContext);
              },
            ),
          ],
        ),
      ),
    );
  }
}
