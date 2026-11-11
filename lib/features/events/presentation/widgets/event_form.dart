import 'package:flutter/material.dart';

import '../../../location/domain/geo_point.dart';
import '../../../map/presentation/widgets/location_picker_field.dart';
import '../../domain/event.dart';
import '../../domain/event_draft.dart';
import '../event_formatters.dart';

/// Campos de un evento con sus validaciones (RF4). Lo usan crear (SCRUM-63, Figma «5») y editar
/// (SCRUM-67, Figma «25»): cada pantalla pone su título, el texto del botón y sus acciones extra.
class EventForm extends StatefulWidget {
  const EventForm({
    super.key,
    required this.initial,
    required this.submitLabel,
    required this.onSubmit,
    this.submitting = false,
    this.header,
    this.footer,
  });

  final EventDraft initial;
  final String submitLabel;
  final ValueChanged<EventDraft> onSubmit;
  final bool submitting;

  /// Va arriba de los campos (por ejemplo, «Paso 1 de 2» o un mensaje de error).
  final Widget? header;

  /// Va debajo del botón principal (por ejemplo, «Cancelar evento»).
  final Widget? footer;

  @override
  State<EventForm> createState() => _EventFormState();
}

class _EventFormState extends State<EventForm> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _venueName;
  late final TextEditingController _venueAddress;
  late final TextEditingController _capacity;
  late final TextEditingController _description;
  late GeoPoint _location;
  late EventCategory _category;
  late DateTime _date;
  late TimeOfDay _startTime;
  late TimeOfDay _endTime;
  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;

  @override
  void initState() {
    super.initState();
    final draft = widget.initial;
    _title = TextEditingController(text: draft.title);
    _venueName = TextEditingController(text: draft.venueName);
    _venueAddress = TextEditingController(text: draft.venueAddress);
    _capacity = TextEditingController(text: draft.capacity?.toString());
    _description = TextEditingController(text: draft.description);
    _location = draft.location;
    _category = draft.category;
    _date = DateUtils.dateOnly(draft.startsAt);
    _startTime = TimeOfDay.fromDateTime(draft.startsAt);
    _endTime = TimeOfDay.fromDateTime(draft.endsAt);
  }

  @override
  void dispose() {
    _title.dispose();
    _venueName.dispose();
    _venueAddress.dispose();
    _capacity.dispose();
    _description.dispose();
    super.dispose();
  }

  DateTime _at(TimeOfDay time) => DateTime(_date.year, _date.month, _date.day, time.hour, time.minute);

  /// Como en el Figma, el evento empieza y termina el mismo día; un evento que pase la medianoche
  /// queda por fuera de este formulario por ahora.
  String? _scheduleError() {
    final startsAt = _at(_startTime);
    final endsAt = _at(_endTime);
    if (!endsAt.isAfter(startsAt)) return 'La hora de fin debe ser después de la de inicio.';
    if (!endsAt.isAfter(DateTime.now())) return 'El evento debe terminar en el futuro.';
    return null;
  }

  void _submit() {
    final valid = _formKey.currentState!.validate();
    if (!valid || _scheduleError() != null) {
      setState(() => _autovalidateMode = AutovalidateMode.onUserInteraction);
      return;
    }
    final capacity = _capacity.text.trim();
    widget.onSubmit(
      EventDraft(
        title: _title.text.trim(),
        venueName: _venueName.text.trim(),
        venueAddress: _venueAddress.text.trim(),
        location: _location,
        startsAt: _at(_startTime),
        endsAt: _at(_endTime),
        category: _category,
        description: _description.text.trim(),
        capacity: capacity.isEmpty ? null : int.parse(capacity),
      ),
    );
  }

  Future<void> _pickDate() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isBefore(today) ? today : _date,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime({required bool start}) async {
    final picked = await showTimePicker(context: context, initialTime: start ? _startTime : _endTime);
    if (picked == null) return;
    setState(() => start ? _startTime = picked : _endTime = picked);
  }

  static String? _required(String? value, String message) => (value ?? '').trim().isEmpty ? message : null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheduleError = _autovalidateMode == AutovalidateMode.disabled ? null : _scheduleError();
    return Form(
      key: _formKey,
      autovalidateMode: _autovalidateMode,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(24),
              children: [
                if (widget.header != null) ...[widget.header!, const SizedBox(height: 16)],
                TextFormField(
                  key: const Key('eventForm.title'),
                  controller: _title,
                  maxLength: 120,
                  textCapitalization: TextCapitalization.sentences,
                  validator: (value) =>
                      (value ?? '').trim().length < 3 ? 'Escribe un nombre de al menos 3 letras.' : null,
                  decoration: const InputDecoration(labelText: 'Nombre del evento'),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  key: const Key('eventForm.venueName'),
                  controller: _venueName,
                  maxLength: 120,
                  validator: (value) => _required(value, 'Escribe el lugar del evento.'),
                  decoration: const InputDecoration(labelText: 'Lugar', hintText: 'Ej.: Bloque I, auditorio'),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  key: const Key('eventForm.venueAddress'),
                  controller: _venueAddress,
                  maxLength: 200,
                  validator: (value) => _required(value, 'Escribe la dirección.'),
                  decoration: const InputDecoration(labelText: 'Dirección'),
                ),
                const SizedBox(height: 8),
                LocationPickerField(initialValue: _location, onChanged: (point) => _location = point),
                const SizedBox(height: 16),
                _PickerTile(
                  key: const Key('eventForm.date'),
                  label: 'Fecha',
                  value: EventFormatters.date(_date),
                  icon: Icons.calendar_today_outlined,
                  onTap: _pickDate,
                ),
                Row(
                  children: [
                    Expanded(
                      child: _PickerTile(
                        key: const Key('eventForm.startTime'),
                        label: 'Empieza',
                        value: EventFormatters.time(_at(_startTime)),
                        icon: Icons.schedule,
                        onTap: () => _pickTime(start: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _PickerTile(
                        key: const Key('eventForm.endTime'),
                        label: 'Termina',
                        value: EventFormatters.time(_at(_endTime)),
                        icon: Icons.schedule,
                        onTap: () => _pickTime(start: false),
                      ),
                    ),
                  ],
                ),
                if (scheduleError != null)
                  Text(scheduleError, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error)),
                const SizedBox(height: 16),
                Text('Tipo de actividad', style: theme.textTheme.titleSmall),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final category in EventCategory.values)
                      ChoiceChip(
                        label: Text(category.label),
                        selected: _category == category,
                        onSelected: (_) => setState(() => _category = category),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('eventForm.capacity'),
                  controller: _capacity,
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    final text = (value ?? '').trim();
                    if (text.isEmpty) return null;
                    final capacity = int.tryParse(text);
                    return capacity == null || capacity < 1 ? 'Escribe un número de personas mayor que 0.' : null;
                  },
                  decoration: const InputDecoration(labelText: 'Cupo (opcional)', suffixText: 'personas'),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const Key('eventForm.description'),
                  controller: _description,
                  minLines: 3,
                  maxLines: 8,
                  maxLength: 2000,
                  validator: (value) => _required(value, 'Cuéntale a la gente de qué se trata el plan.'),
                  decoration: const InputDecoration(labelText: 'Descripción', alignLabelWithHint: true),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  FilledButton(
                    key: const Key('eventForm.submit'),
                    onPressed: widget.submitting ? null : _submit,
                    child: widget.submitting
                        ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(widget.submitLabel),
                  ),
                  ?widget.footer,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Campo de solo lectura que abre un selector (fecha u hora) al tocarlo.
class _PickerTile extends StatelessWidget {
  const _PickerTile({super.key, required this.label, required this.value, required this.icon, required this.onTap});

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, suffixIcon: Icon(icon)),
        child: Text(value),
      ),
    ),
  );
}
