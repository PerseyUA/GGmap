import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../mgrs/mgrs_coordinate.dart';
import '../mgrs/mgrs_parser.dart';

/// Bottom sheet for entering an MGRS record. Returns the confirmed
/// coordinate, or null if the user cancelled.
Future<MgrsCoordinate?> showGotoSheet(BuildContext context) {
  return showModalBottomSheet<MgrsCoordinate>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => const _GotoSheet(),
  );
}

class _GotoSheet extends StatefulWidget {
  const _GotoSheet();

  @override
  State<_GotoSheet> createState() => _GotoSheetState();
}

class _GotoSheetState extends State<_GotoSheet> {
  final _controller = TextEditingController();
  MgrsParseResult? _result;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _validate(String text) {
    setState(
        () => _result = text.trim().isEmpty ? null : MgrsParser.parse(text));
  }

  Future<void> _paste() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? '';
    _controller.text = text;
    _validate(text);
  }

  void _applySuggestion(String suggestion) {
    _controller.text = suggestion;
    _validate(suggestion);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = _result;
    final coordinate = result?.coordinate;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        16,
        0,
        16,
        16 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Перейти до координат', style: theme.textTheme.titleLarge),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              labelText: 'MGRS',
              hintText: '37U DQ 12345 67890',
              border: const OutlineInputBorder(),
              suffixIcon: IconButton(
                tooltip: 'Вставити з буфера',
                icon: const Icon(Icons.content_paste),
                onPressed: _paste,
              ),
            ),
            onChanged: _validate,
          ),
          const SizedBox(height: 12),
          if (result != null && !result.isOk) ...[
            Text(
              result.error!.message,
              style: TextStyle(color: theme.colorScheme.error),
            ),
            if (result.suggestion != null) ...[
              const SizedBox(height: 8),
              Text('Можливо, ви мали на увазі: ${result.suggestion}'),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => _applySuggestion(result.suggestion!),
                  child: const Text('Застосувати виправлення'),
                ),
              ),
            ],
          ],
          if (coordinate != null) ...[
            Text(coordinate.display, style: theme.textTheme.titleMedium),
            Text(
              '${coordinate.cellSizeLabel} · точка — центр комірки',
              style: theme.textTheme.bodySmall,
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Скасувати'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: coordinate == null
                      ? null
                      : () => Navigator.of(context).pop(coordinate),
                  child: const Text('Перейти'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
