import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/design/design.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/http_providers.dart';
import '../../data/description_api.dart';
import '../../domain/event.dart';

final descriptionApiProvider = Provider<DescriptionApi>((ref) => DescriptionApi(ref.watch(authenticatedDioProvider)));

/// Lo que el formulario le da a la IA para redactar la descripción.
class DescriptionRequest {
  const DescriptionRequest({
    required this.name,
    required this.location,
    required this.category,
    this.startsAt,
    this.notes,
    this.merchantId,
  });

  final String name;
  final String location;
  final EventCategory category;
  final DateTime? startsAt;
  final String? notes;
  final String? merchantId;
}

/// Botón «Generar con IA» del formulario de evento (RF9, SCRUM-101 y SCRUM-103).
///
/// La IA propone y la persona decide: el texto llega al campo de descripción, donde se puede revisar,
/// editar o pedir otra versión antes de publicar, y un aviso lo marca como generado con IA.
class AiDescriptionAssistant extends ConsumerStatefulWidget {
  const AiDescriptionAssistant({
    super.key,
    required this.buildRequest,
    required this.onGenerated,
    this.generated = false,
  });

  /// Devuelve lo que se sabe del evento, o null si todavía falta el nombre o el lugar.
  final DescriptionRequest? Function() buildRequest;

  /// Recibe el texto generado para ponerlo en el campo de descripción.
  final ValueChanged<String> onGenerated;

  /// Si la descripción que hay en el campo ya viene de la IA.
  final bool generated;

  @override
  ConsumerState<AiDescriptionAssistant> createState() => _AiDescriptionAssistantState();
}

class _AiDescriptionAssistantState extends ConsumerState<AiDescriptionAssistant> {
  static const tooManyRequestsMessage = 'Vas muy rápido. Espera un momento e intenta de nuevo.';
  static const missingDataMessage = 'Escribe el nombre y el lugar del evento para que la IA pueda redactarlo.';

  bool _loading = false;
  String? _error;

  Future<void> _generate() async {
    if (_loading) return;
    final request = widget.buildRequest();
    if (request == null) {
      setState(() => _error = missingDataMessage);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final text = await ref
          .read(descriptionApiProvider)
          .generate(
            name: request.name,
            location: request.location,
            category: request.category,
            startsAt: request.startsAt,
            notes: request.notes,
            merchantId: request.merchantId,
          );
      if (!mounted) return;
      setState(() => _loading = false);
      widget.onGenerated(text);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = switch (e.statusCode) {
          429 => tooManyRequestsMessage,
          _ => e.message,
        };
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'No pudimos leer la respuesta. Intenta de nuevo.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            key: const Key('eventForm.aiGenerate'),
            onPressed: _loading ? null : _generate,
            icon: _loading
                ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.auto_awesome),
            label: Text(widget.generated ? 'Generar otra versión con IA' : 'Generar con IA'),
          ),
        ),
        if (widget.generated)
          Container(
            key: const Key('eventForm.aiNotice'),
            margin: const EdgeInsets.only(top: FestaSpace.xs),
            padding: const EdgeInsets.all(FestaSpace.xs),
            decoration: BoxDecoration(color: FestaColors.bgIa, borderRadius: BorderRadius.circular(FestaRadius.sm)),
            child: Text(
              'Texto generado con IA. Revísalo y edítalo antes de publicar: la IA sugiere, tú decides.',
              style: theme.textTheme.bodySmall?.copyWith(color: FestaColors.textPrimary),
            ),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: FestaSpace.xs),
            child: Text(
              _error!,
              key: const Key('eventForm.aiError'),
              style: theme.textTheme.bodySmall?.copyWith(color: FestaColors.textError),
            ),
          ),
      ],
    );
  }
}
