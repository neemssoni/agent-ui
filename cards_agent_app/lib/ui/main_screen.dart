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
  
  // Tracks which tool variant is currently active for display/demo purposes
  String _selectedVariant = 'list_cards';

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
        appBar: AppBar(
          title: Text("Banking Cards Agent (${_selectedVariant == 'list_cards_v2' ? 'v2 View' : 'v1 View'})"),
          actions: [
            // Tool Variant Selector Popup Menu
            PopupMenuButton<String>(
              icon: const Icon(Icons.tune),
              tooltip: 'Select Tool Variant',
              onSelected: (variant) {
                setState(() {
                  _selectedVariant = variant;
                });
                // Automatically request card list with the chosen variant
                bloc.sendMessageWithVariant("Show my cards", variant);
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'list_cards',
                  child: Text('Variant: list_cards (Standard)'),
                ),
                const PopupMenuItem(
                  value: 'list_cards_v2',
                  child: Text('Variant: list_cards_v2 (Modern View)'),
                ),
              ],
            ),
          ],
        ),
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
                  height: 140,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: state.cards.length,
                    itemBuilder: (context, idx) {
                      final card = state.cards[idx];
                      final isBlocked = card.status == 'blocked';
                      
                      // ==========================================
                      // DIFFERENT UI STYLING FOR v2 vs v1
                      // ==========================================
                      if (_selectedVariant == 'list_cards_v2') {
                        // V2 UI: Modern Gradient Card with VIP / Platinum Styling
                        return Container(
                          width: 220,
                          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isBlocked 
                                  ? [Colors.grey.shade600, Colors.grey.shade800]
                                  : [Colors.deepPurple.shade700, Colors.indigo.shade900],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(card.name, style: const TextStyle(color: Colors.amberAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                                  const Icon(Icons.contactless, color: Colors.white70, size: 18),
                                ],
                              ),
                              Text("•••• ${card.lastFour}", style: const TextStyle(color: Colors.white, fontSize: 16, letterSpacing: 2)),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.amber.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text("v2 PLATINUM", style: TextStyle(color: Colors.amberAccent, fontSize: 8, fontWeight: FontWeight.bold)),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: isBlocked ? Colors.red : Colors.teal,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(card.status.toUpperCase(), style: const TextStyle(color: Colors.white, fontSize: 9)),
                                  ),
                                ],
                              )
                            ],
                          ),
                        );
                      }

                      // V1 UI: Classic Solid Color Card Style
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
                                  // Send message using the currently selected variant
                                  bloc.sendMessageWithVariant(txt, _selectedVariant);
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