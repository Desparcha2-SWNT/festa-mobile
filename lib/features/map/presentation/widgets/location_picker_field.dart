import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../../location/application/user_location_provider.dart';
import '../../../location/domain/geo_point.dart';
import '../../../location/domain/user_location.dart';
import '../map_view.dart';

/// Campo de formulario para elegir un lugar tocando un mapa pequeño (Figma «3e» y «5»).
///
/// Así la app manda las coordenadas exactas y no hace falta geocodificar la dirección escrita.
/// Sin valor inicial, el mapa arranca en la ubicación del usuario (o en la Escuela).
class LocationPickerField extends FormField<GeoPoint> {
  LocationPickerField({super.key, super.initialValue, super.onSaved, ValueChanged<GeoPoint>? onChanged})
    : super(
        validator: (point) => point == null ? 'Toca el mapa para fijar la ubicación.' : null,
        builder: (field) => _LocationPicker(
          value: field.value,
          errorText: field.errorText,
          onPicked: (point) {
            field.didChange(point);
            onChanged?.call(point);
          },
        ),
      );
}

class _LocationPicker extends ConsumerStatefulWidget {
  const _LocationPicker({required this.value, required this.errorText, required this.onPicked});

  final GeoPoint? value;
  final String? errorText;
  final ValueChanged<GeoPoint> onPicked;

  @override
  ConsumerState<_LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends ConsumerState<_LocationPicker> {
  final _camera = MapCameraController();

  @override
  void dispose() {
    _camera.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final value = widget.value;
    final center = value ?? ref.watch(userLocationProvider).value?.point ?? pilotLocation;
    final buildMapView = ref.watch(mapViewBuilderProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            key: const Key('locationPicker.map'),
            height: 180,
            child: buildMapView(
              MapViewConfig(
                initialCenter: center,
                showUserLocation: false,
                camera: _camera,
                markers: [if (value != null) MapMarker(id: 'picked', point: value, color: FestaTheme.brand)],
                onMapTap: widget.onPicked,
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          widget.errorText ?? 'Toca el mapa para fijar la ubicación exacta del lugar.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: widget.errorText == null ? theme.colorScheme.onSurfaceVariant : theme.colorScheme.error,
          ),
        ),
      ],
    );
  }
}
