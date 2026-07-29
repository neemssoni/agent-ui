import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cards_agent_app/services/agui_client.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class CardModel {
  final String id;
  final String name;
  final String lastFour;
  final String network;
  final String status;
  final String color;

  CardModel({
    required this.id,
    required this.name,
    required this.lastFour,
    required this.network,
    required this.status,
    required this.color,
  });

  factory CardModel.fromJson(Map<String, dynamic> json) {
    return CardModel(
      id: json['id'],
      name: json['name'],
      lastFour: json['lastFour'],
      network: json['network'],
      status: json['status'],
      color: json['color'],
    );
  }
}

class MessageModel {
  final String id;
  final String role;
  String content;

  MessageModel({required this.id, required this.role, required this.content});
}

class InterruptModel {
  final String id;
  final String toolCallId;
  final String message;
  final String lastFour;

  InterruptModel({
    required this.id,
    required this.toolCallId,
    required this.message,
    required this.lastFour,
  });
}

class AgentState {
  final List<CardModel> cards;
  final List<MessageModel> messages;
  final bool isRunning;
  final InterruptModel? activeInterrupt;
  final String? threadId;

  AgentState({
    this.cards = const [],
    this.messages = const [],
    this.isRunning = false,
    this.activeInterrupt,
    this.threadId,
  });

  AgentState copyWith({
    List<CardModel>? cards,
    List<MessageModel>? messages,
    bool? isRunning,
    InterruptModel? activeInterrupt,
    bool clearInterrupt = false,
    String? threadId,
  }) {
    return AgentState(
      cards: cards ?? this.cards,
      messages: messages ?? this.messages,
      isRunning: isRunning ?? this.isRunning,
      activeInterrupt: clearInterrupt ? null : (activeInterrupt ?? this.activeInterrupt),
      threadId: threadId ?? this.threadId,
    );
  }
}

class AgentBloc extends Cubit<AgentState> {
  final AgUiClient client;

  AgentBloc(this.client) : super(AgentState());

  void sendMessage(String text) async {
  final trimmedText = text.trim();
  if (trimmedText.isEmpty) return;

  final userMsg = MessageModel(
    id: DateTime.now().millisecondsSinceEpoch.toString(),
    role: 'user',
    content: trimmedText,
  );
  final updatedMessages = List<MessageModel>.from(state.messages)..add(userMsg);

  // Keep the SAME threadId across the session
  final activeThread = (state.threadId != null && state.threadId!.trim().isNotEmpty)
      ? state.threadId!
      : 'thread-1';

  // Generate a UNIQUE runId for every single prompt
  final uniqueRunId = 'run-${DateTime.now().millisecondsSinceEpoch}';

  emit(state.copyWith(
    messages: updatedMessages,
    threadId: activeThread,
    isRunning: true,
  ));

  try {
    final stream = client.sendRun(
      threadId: activeThread,
      runId: uniqueRunId, // UNIQUE per request
      userPrompt: trimmedText,
    );
    await _processSseStream(stream);
  } catch (e) {
    print("AG-UI Stream Error: $e");
    emit(state.copyWith(isRunning: false));
  }
}

  Future<void> _processSseStream(Stream<Map<String, dynamic>> stream) async {
    await for (final event in stream) {
      final type = event['type'];

      switch (type) {
        case 'RUN_STARTED':
          final serverThreadId = event['threadId'] as String?;
          emit(state.copyWith(
            isRunning: true,
            threadId: (serverThreadId != null && serverThreadId.isNotEmpty) 
                ? serverThreadId 
                : state.threadId,
          ));
          break;

        case 'STATE_SNAPSHOT':
          final cardList = (event['snapshot']['cards'] as List)
              .map((c) => CardModel.fromJson(c))
              .toList();
          emit(state.copyWith(cards: cardList));
          break;

        case 'TEXT_MESSAGE_START':
          final newMsg = MessageModel(id: event['messageId'], role: 'assistant', content: '');
          emit(state.copyWith(messages: List.from(state.messages)..add(newMsg)));
          break;

        case 'TEXT_MESSAGE_CONTENT':
          final delta = event['delta'] as String;
          final currentMsgs = List<MessageModel>.from(state.messages);
          if (currentMsgs.isNotEmpty) {
            final lastMsg = currentMsgs.last;
            currentMsgs[currentMsgs.length - 1] = MessageModel(
              id: lastMsg.id,
              role: lastMsg.role,
              content: lastMsg.content + delta,
            );
            emit(state.copyWith(messages: currentMsgs));
          }
          break;

        case 'RUN_FINISHED':
          final outcome = event['outcome'];
          if (outcome != null && outcome['type'] == 'interrupt') {
            final interrupts = outcome['interrupts'] as List;
            if (interrupts.isNotEmpty) {
              final rawInt = interrupts.first;
              final interrupt = InterruptModel(
                id: rawInt['id'],
                toolCallId: rawInt['toolCallId'],
                message: rawInt['message'],
                lastFour: rawInt['metadata']['lastFour'] ?? '4242',
              );
              emit(state.copyWith(isRunning: false, activeInterrupt: interrupt));
              return;
            }
          }
          emit(state.copyWith(isRunning: false, clearInterrupt: true));
          break;
      }
    }
  }

  void resolveInterrupt(String confirmationToken) async {
  final interrupt = state.activeInterrupt;
  if (interrupt == null) return;

  emit(state.copyWith(isRunning: true, clearInterrupt: true));

  final resumePayload = [
    {
      'interruptId': interrupt.id,
      'status': 'resolved',
      'payload': {'confirmationToken': confirmationToken}
    }
  ];

  final uniqueRunId = 'run-${DateTime.now().millisecondsSinceEpoch}';

  final stream = client.sendRun(
    threadId: state.threadId,
    runId: uniqueRunId, // UNIQUE per resume
    resumePayload: resumePayload,
  );
  await _processSseStream(stream);
}

void cancelInterrupt() async {
  final interrupt = state.activeInterrupt;
  if (interrupt == null) return;

  emit(state.copyWith(clearInterrupt: true));

  final resumePayload = [
    {
      'interruptId': interrupt.id,
      'status': 'cancelled',
    }
  ];

  final uniqueRunId = 'run-${DateTime.now().millisecondsSinceEpoch}';

  final stream = client.sendRun(
    threadId: state.threadId,
    runId: uniqueRunId, // UNIQUE per cancel
    resumePayload: resumePayload,
  );
  await _processSseStream(stream);
}

}