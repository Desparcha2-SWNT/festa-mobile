import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/network/http_providers.dart';
import '../../location/application/user_location_provider.dart';
import '../data/chat_api.dart';
import '../domain/chat_models.dart';

final chatApiProvider = Provider<ChatApi>((ref) => ChatApi(ref.watch(authenticatedDioProvider)));

/// Lo que muestra la pantalla del chat.
class ChatState {
  const ChatState({this.messages = const [], this.sending = false, this.error, this.sessionId, this.disclaimer});

  final List<ChatMessage> messages;
  final bool sending;

  /// Último error, para mostrarlo bajo la conversación. Se limpia al mandar otro mensaje.
  final String? error;

  /// Conversación abierta en ai-service. La respuesta del primer turno la crea.
  final String? sessionId;

  /// Aviso de sugerencia automatizada (RN6) de la última respuesta.
  final String? disclaimer;

  ChatState copyWith({
    List<ChatMessage>? messages,
    bool? sending,
    String? Function()? error,
    String? sessionId,
    String? disclaimer,
  }) => ChatState(
    messages: messages ?? this.messages,
    sending: sending ?? this.sending,
    error: error != null ? error() : this.error,
    sessionId: sessionId ?? this.sessionId,
    disclaimer: disclaimer ?? this.disclaimer,
  );
}

/// La conversación vive solo mientras la pantalla está abierta (`autoDispose`): otra cuenta que entre
/// en el mismo teléfono no ve la conversación de la anterior.
final chatControllerProvider = NotifierProvider.autoDispose<ChatController, ChatState>(ChatController.new);

class ChatController extends Notifier<ChatState> {
  static const maxLength = 500;
  static const tooManyRequestsMessage = 'Vas muy rápido. Espera un momento e intenta de nuevo.';

  @override
  ChatState build() => const ChatState();

  /// Manda [text] a la IA. Devuelve false si no se mandó (vacío, demasiado largo o ya hay uno en curso),
  /// para que la pantalla conserve lo escrito.
  Future<bool> send(String text) async {
    final message = text.trim();
    if (message.isEmpty || message.length > maxLength || state.sending) return false;

    state = state.copyWith(
      messages: [
        ...state.messages,
        ChatMessage(role: ChatRole.user, text: message),
      ],
      sending: true,
      error: () => null,
    );

    try {
      // Solo la ubicación real y con consentimiento: sin ella no se manda nada, no la del piloto.
      final location = await ref.read(userLocationProvider.future);
      final reply = await ref
          .read(chatApiProvider)
          .send(message, sessionId: state.sessionId, location: location.isFallback ? null : location.point);
      if (!ref.mounted) return true;
      state = state.copyWith(
        messages: [
          ...state.messages,
          ChatMessage(role: ChatRole.assistant, text: reply.reply, events: reply.events),
        ],
        sending: false,
        sessionId: reply.sessionId,
        disclaimer: reply.disclaimer,
      );
    } on ApiException catch (e) {
      if (!ref.mounted) return true;
      state = state.copyWith(sending: false, error: () => e.statusCode == 429 ? tooManyRequestsMessage : e.message);
    } catch (_) {
      if (!ref.mounted) return true;
      state = state.copyWith(sending: false, error: () => 'No pudimos leer la respuesta. Intenta de nuevo.');
    }
    return true;
  }
}
