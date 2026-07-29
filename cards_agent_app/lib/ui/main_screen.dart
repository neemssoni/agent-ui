import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cards_agent_app/bloc/agui_bloc.dart';
import 'package:cards_agent_app/services/agui_client.dart';
import 'package:cards_agent_app/ui/block_card_dialog.dart';


class MainBankingScreen extends StatelessWidget {
  final AgUiClient client;

  const MainBankingScreen({super.key, required this.client});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AgentBloc(client),
      child: const BankingView(),
    );
  }
}

class BankingView extends StatefulWidget {
  const BankingView({super.key});

  @override
  State<BankingView> createState() => _BankingViewState();
}

class _BankingViewState extends State<BankingView> {
  final TextEditingController _promptController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<AgentBloc>();

    return BlocListener<AgentBloc, AgentState>(
      listenWhen: (prev, curr) => prev.activeInterrupt != curr.activeInterrupt,
      listener: (context, state) {
        if (state.activeInterrupt != null) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (dialogCtx) => BlockCardApprovalDialog(
              interrupt: state.activeInterrupt!,
              threadId: state.threadId ?? '',
              client: bloc.client,
              onSuccess: (token) {
                Navigator.of(dialogCtx).pop();
                bloc.resolveInterrupt(token);
              },
              onCancel: () {
                bloc.cancelInterrupt();
              },
            ),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(title: const Text("Banking Cards Agent")),
        body: Column(
          children: [
            BlocBuilder<AgentBloc, AgentState>(
              builder: (context, state) {
                if (state.cards.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text("No cards loaded yet. Try typing 'Show my cards'"),
                  );
                }
                return SizedBox(
                  height: 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: state.cards.length,
                    itemBuilder: (context, idx) {
                      final card = state.cards[idx];
                      final isBlocked = card.status == 'blocked';
                      return Container(
                        width: 200,
                        margin: const EdgeInsets.all(8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isBlocked ? Colors.grey.shade400 : Colors.indigo.shade600,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(card.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                            Text("•••• ${card.lastFour}", style: const TextStyle(color: Colors.white70)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: isBlocked ? Colors.red : Colors.green,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                card.status.toUpperCase(),
                                style: const TextStyle(color: Colors.white, fontSize: 10),
                              ),
                            )
                          ],
                        ),
                      );
                    },
                  ),
                );
              },
            ),
            const Divider(),
            Expanded(
              child: BlocBuilder<AgentBloc, AgentState>(
                builder: (context, state) {
                  return ListView.builder(
                    itemCount: state.messages.length,
                    itemBuilder: (context, idx) {
                      final msg = state.messages[idx];
                      final isUser = msg.role == 'user';
                      return Align(
                        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isUser ? Colors.blue.shade100 : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(msg.content),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            BlocBuilder<AgentBloc, AgentState>(
              builder: (context, state) {
                return Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _promptController,
                          enabled: !state.isRunning && state.activeInterrupt == null,
                          decoration: const InputDecoration(
                            hintText: "Type 'Show my cards' or 'Block card 4242'",
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: state.isRunning 
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)) 
                            : const Icon(Icons.send),
                        onPressed: (!state.isRunning && state.activeInterrupt == null)
                            ? () {
                                final txt = _promptController.text.trim();
                                if (txt.isNotEmpty) {
                                  _promptController.clear();
                                  bloc.sendMessage(txt);
                                }
                              }
                            : null,
                      ),
                    ],
                  ),
                );
              },
            )
          ],
        ),
      ),
    );
  }
}