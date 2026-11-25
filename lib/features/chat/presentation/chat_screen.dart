import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/design/design.dart';
import '../../../app/routes.dart';
import '../../plans/presentation/plan_formatters.dart';
import '../application/chat_controller.dart';
import '../domain/chat_models.dart';

/// Chat de recomendaciones con Festi, la IA de Festa (RF8). La IA sugiere y la persona decide: solo
/// recomienda eventos reales del catálogo y la pantalla lo avisa siempre (RN6, sugerencia automatizada).
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _input = TextEditingController();
  final _scroll = ScrollController();

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text;
    final sent = await ref.read(chatControllerProvider.notifier).send(text);
    if (sent) _input.clear();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.jumpTo(_scroll.position.maxScrollExtent);
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(chatControllerProvider);
    ref.listen(chatControllerProvider.select((s) => s.messages.length), (_, _) => _scrollToEnd());

    return Scaffold(
      appBar: AppBar(title: const Text('Festi, tu guía de planes')),
      body: Column(
        children: [
          _Disclaimer(text: state.disclaimer ?? ChatReply.defaultDisclaimer),
          Expanded(
            child: state.messages.isEmpty
                ? const _EmptyView()
                : ListView.separated(
                    key: const Key('chat.list'),
                    controller: _scroll,
                    padding: const EdgeInsets.all(FestaSpace.md),
                    itemCount: state.messages.length + (state.sending ? 1 : 0),
                    separatorBuilder: (_, _) => const SizedBox(height: FestaSpace.sm),
                    itemBuilder: (context, i) {
                      if (i == state.messages.length) return const _TypingBubble();
                      return _MessageBubble(message: state.messages[i]);
                    },
                  ),
          ),
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: FestaSpace.md, vertical: FestaSpace.xs),
              child: Text(
                state.error!,
                key: const Key('chat.error'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: FestaColors.textError),
              ),
            ),
          _InputBar(controller: _input, sending: state.sending, onSend: _send),
        ],
      ),
    );
  }
}

class _Disclaimer extends StatelessWidget {
  const _Disclaimer({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
    key: const Key('chat.disclaimer'),
    width: double.infinity,
    color: FestaColors.bgIa,
    padding: const EdgeInsets.symmetric(horizontal: FestaSpace.md, vertical: FestaSpace.xs),
    child: Row(
      children: [
        const Icon(Icons.auto_awesome, size: 16, color: FestaColors.textPrimary),
        const SizedBox(width: FestaSpace.xs),
        Expanded(
          child: Text(text, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: FestaColors.textPrimary)),
        ),
      ],
    ),
  );
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(FestaSpace.xl),
      child: Text(
        'Cuéntame qué plan buscas: música, comida, deporte o algo cultural. Te sugiero eventos reales de Bogotá.',
        key: const Key('chat.empty'),
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: FestaColors.textSecondary),
      ),
    ),
  );
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final mine = message.role == ChatRole.user;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.82),
        child: Column(
          crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(FestaSpace.sm),
              decoration: BoxDecoration(
                color: mine ? FestaColors.bgBrandSoft : FestaColors.bgMuted,
                borderRadius: BorderRadius.circular(FestaRadius.md),
              ),
              child: Text(message.text, style: Theme.of(context).textTheme.bodyMedium),
            ),
            for (final event in message.events) ...[const SizedBox(height: FestaSpace.xs), _EventCard(event: event)],
          ],
        ),
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({required this.event});

  final RecommendedEvent event;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    return Material(
      color: FestaColors.bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(FestaRadius.md),
        side: const BorderSide(color: FestaColors.border),
      ),
      child: InkWell(
        key: Key('chat.event.${event.eventId}'),
        borderRadius: BorderRadius.circular(FestaRadius.md),
        onTap: () => context.push(Routes.eventDetail(event.eventId)),
        child: Padding(
          padding: const EdgeInsets.all(FestaSpace.sm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(event.title, style: theme.titleSmall),
              const SizedBox(height: FestaSpace.xxs),
              Text(formatPlanDate(event.startsAt), style: theme.bodySmall?.copyWith(color: FestaColors.textSecondary)),
              if (event.venueName.isNotEmpty)
                Text(event.venueName, style: theme.bodySmall?.copyWith(color: FestaColors.textSecondary)),
              const SizedBox(height: FestaSpace.xxs),
              Text(
                event.isFree ? 'Gratis' : formatCop(event.priceCents),
                style: theme.labelMedium?.copyWith(
                  color: event.isFree ? FestaColors.textSuccess : FestaColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// «$ 35.000» a partir de centavos de peso.
String formatCop(int cents) {
  final pesos = (cents / 100).round().toString();
  final grouped = pesos.replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');
  return '\$ $grouped';
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) => const Align(
    alignment: Alignment.centerLeft,
    child: Padding(
      padding: EdgeInsets.all(FestaSpace.xs),
      child: SizedBox(key: Key('chat.typing'), width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
    ),
  );
}

class _InputBar extends StatelessWidget {
  const _InputBar({required this.controller, required this.sending, required this.onSend});

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(FestaSpace.md, FestaSpace.xs, FestaSpace.xs, FestaSpace.xs),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              key: const Key('chat.input'),
              controller: controller,
              maxLength: ChatController.maxLength,
              maxLines: 3,
              minLines: 1,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              decoration: const InputDecoration(hintText: 'Escribe lo que buscas', counterText: ''),
            ),
          ),
          IconButton(
            key: const Key('chat.send'),
            tooltip: 'Enviar',
            icon: const Icon(Icons.send),
            onPressed: sending ? null : onSend,
          ),
        ],
      ),
    ),
  );
}
