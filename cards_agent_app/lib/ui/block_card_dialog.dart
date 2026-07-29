import 'package:flutter/material.dart';
import 'package:pinput/pinput.dart';
import 'package:cards_agent_app/bloc/agui_bloc.dart';
import 'package:cards_agent_app/services/agui_client.dart';

class BlockCardApprovalDialog extends StatefulWidget {
  final InterruptModel interrupt;
  final String threadId;
  final AgUiClient client;
  final Function(String token) onSuccess;
  final VoidCallback onCancel;

  const BlockCardApprovalDialog({
    super.key,
    required this.interrupt,
    required this.threadId,
    required this.client,
    required this.onSuccess,
    required this.onCancel,
  });

  @override
  State<BlockCardApprovalDialog> createState() => _BlockCardApprovalDialogState();
}

class _BlockCardApprovalDialogState extends State<BlockCardApprovalDialog> {
  final TextEditingController _pinController = TextEditingController();
  bool _isVerifying = false;
  bool _isDisabled = false;
  String? _errorMessage;

  void _verifyMpin(String mpin) async {
    if (mpin.length < 4) return;

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    final result = await widget.client.verifyMpin(
      threadId: widget.threadId,
      interruptId: widget.interrupt.id,
      mpin: mpin,
    );

    final statusCode = result['statusCode'];
    final body = result['body'];

    setState(() => _isVerifying = false);

    if (statusCode == 200) {
      final token = body['confirmationToken'];
      widget.onSuccess(token);
    } else if (statusCode == 401) {
      setState(() {
        _errorMessage = body['error']['message'] ?? 'Verification failed';
      });
    } else if (statusCode == 429) {
      setState(() {
        _isDisabled = true;
        _errorMessage = body['error']['message'] ?? 'Too many verification attempts';
      });
    } else {
      setState(() {
        _errorMessage = 'An unexpected error occurred ($statusCode)';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Confirm Card Block"),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Are you sure you want to block the card ending in ${widget.interrupt.lastFour}?",
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Pinput(
            controller: _pinController,
            length: 4,
            obscureText: true,
            enabled: !_isVerifying && !_isDisabled,
            forceErrorState: _errorMessage != null,
            onChanged: (_) {
              if (_errorMessage != null) {
                setState(() => _errorMessage = null);
              }
            },
            onCompleted: _verifyMpin,
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: const TextStyle(color: Colors.red, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
          if (_isVerifying) ...[
            const SizedBox(height: 12),
            const CircularProgressIndicator(),
          ]
        ],
      ),
      actions: [
        TextButton(
          onPressed: _isVerifying
              ? null
              : () {
                  widget.onCancel();
                  Navigator.of(context).pop();
                },
          child: const Text("Cancel"),
        ),
        ElevatedButton(
          onPressed: (_pinController.text.length == 4 && !_isVerifying && !_isDisabled)
              ? () => _verifyMpin(_pinController.text)
              : null,
          child: const Text("Confirm"),
        ),
      ],
    );
  }
}