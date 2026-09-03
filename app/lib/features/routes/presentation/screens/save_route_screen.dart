import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/database/daos/ride_point_dao.dart';
import '../../../../shared/widgets/editorial.dart';
import '../../../../shared/widgets/ride_route_map.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../social/data/repositories/route_repository.dart';
import '../providers/route_providers.dart';

/// "Save this ride as a route" — reached from the end-of-ride share step.
///
/// Re-derives the ride's trail from [RidePointDao] rather than having it
/// threaded through the router, the same way RideShareScreen does.
class SaveRouteScreen extends ConsumerStatefulWidget {
  final String rideId;
  const SaveRouteScreen({super.key, required this.rideId});

  @override
  ConsumerState<SaveRouteScreen> createState() => _SaveRouteScreenState();
}

class _SaveRouteScreenState extends ConsumerState<SaveRouteScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  List<LatLng> _polyline = [];
  bool _loadingTrail = true;
  bool _isPublic = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadPolyline();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPolyline() async {
    final points = await RidePointDao().getForRide(widget.rideId);
    if (!mounted) return;
    setState(() {
      _polyline = points
          .map((p) => LatLng(p['lat'] as double, p['lng'] as double))
          .toList();
      _loadingTrail = false;
    });
  }

  /// Route length from the trail itself, so it always matches the line being
  /// saved even if the ride's own aggregate was computed differently.
  double get _distanceKm {
    if (_polyline.length < 2) return 0;
    const distance = Distance();
    var metres = 0.0;
    for (var i = 0; i + 1 < _polyline.length; i++) {
      metres += distance.as(LengthUnit.Meter, _polyline[i], _polyline[i + 1]);
    }
    return metres / 1000;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final uid = ref.read(currentUserProvider)?.uid;
    if (uid == null) return;

    if (_polyline.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('This ride has no track to save as a route.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final repo = RouteRepository();
      final routeId = await repo.saveRoute(
        userId: uid,
        name: _nameCtrl.text.trim(),
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        distanceKm: _distanceKm,
        polyline: _polyline,
      );
      // saveRoute always writes isPublic:false; publishing is a second step so
      // the rider's choice here can't be lost if the first write succeeds and
      // the second fails.
      if (_isPublic) {
        await repo.setPublic(uid, routeId, true);
      }
      if (!mounted) return;
      ref.invalidate(myRoutesProvider);
      if (_isPublic) ref.invalidate(publicRoutesProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Route saved')),
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not save route: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('Save as route'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppDimensions.paddingMd),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_loadingTrail)
                SizedBox(
                  height: 180,
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                )
              else
                RideRouteMap(polyline: _polyline, height: 180),
              const SizedBox(height: 8),
              Text(
                _loadingTrail
                    ? 'Loading track…'
                    : '${_distanceKm.toStringAsFixed(1)} km · ${_polyline.length} points',
                style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
              ),
              const SizedBox(height: 24),
              const EditorialLabel('Route name'),
              const SizedBox(height: 10),
              TextFormField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                style: TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'e.g. Dhaka – Mawa morning run',
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Give the route a name' : null,
              ),
              const SizedBox(height: 20),
              const EditorialLabel('Description (optional)'),
              const SizedBox(height: 10),
              TextFormField(
                controller: _descCtrl,
                maxLines: 3,
                style: TextStyle(color: AppColors.textPrimary),
                decoration: const InputDecoration(
                  hintText: 'Road surface, best time to ride, where to stop…',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
                  border: Border.all(color: AppColors.border),
                ),
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _isPublic,
                  activeThumbColor: AppColors.primary,
                  onChanged: (v) => setState(() => _isPublic = v),
                  title: Text(
                    _isPublic ? 'Public' : 'Private',
                    style: TextStyle(fontSize: 14, color: AppColors.textPrimary),
                  ),
                  subtitle: Text(
                    _isPublic
                        ? 'Any rider can find and ride this route'
                        : 'Only you can see this route',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: (_saving || _loadingTrail) ? null : _save,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Save route'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
