import 'package:flutter/material.dart';
import '../../../../core/network/api_exception.dart';

class TodoRenameDialog extends StatefulWidget {
  const TodoRenameDialog({
    required this.title,
    required this.onSave,
    super.key,
  });
  final String title;
  final Future<void> Function(String) onSave;
  @override
  State<TodoRenameDialog> createState() => _TodoRenameDialogState();
}

class _TodoRenameDialogState extends State<TodoRenameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.title,
  );
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final title = _controller.text.trim();
    if (title.isEmpty) {
      setState(() => _error = '이름을 입력해 주세요.');
      return;
    }
    if (title == widget.title) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(title);
      if (mounted) Navigator.pop(context);
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '저장하지 못했어요. 다시 시도해 주세요.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: const Text('이름 수정'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        enabled: !_saving,
        maxLength: 100,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _save(),
        decoration: InputDecoration(labelText: '할 일 이름', errorText: _error),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? '저장 중…' : '저장'),
        ),
      ],
    ),
  );
}
