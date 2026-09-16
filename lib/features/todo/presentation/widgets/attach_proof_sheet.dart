import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/widgets/form_controls.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../group/data/group_repository.dart';
import '../../data/todo_models.dart';

/// 오늘 탭에서 바로 올리는 인증샷.
///
/// 그룹 탭까지 들어가지 않아도 되게 여기서 끝낸다. 끝낸 직후가 사진을 올리는
/// 순간이라, 완료 체크 옆에 두는 게 동선이 가장 짧다.
///
/// 사진 한 장이 **선언한 그룹 전부에** 올라간다. 같은 일을 두 그룹에 약속했으면
/// 양쪽에 같은 증거가 필요하다. 어디로 가는지는 시트 위에 그룹 이름으로 적어 둔다.
class AttachProofSheet extends ConsumerStatefulWidget {
  const AttachProofSheet({required this.todo, super.key});

  final Todo todo;

  /// 올렸으면 true. 취소하면 null.
  static Future<bool?> show(BuildContext context, Todo todo) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => AttachProofSheet(todo: todo),
    );
  }

  @override
  ConsumerState<AttachProofSheet> createState() => _AttachProofSheetState();
}

class _AttachProofSheetState extends ConsumerState<AttachProofSheet> {
  final _captionController = TextEditingController();
  final _picker = ImagePicker();

  File? _photo;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(
        source: source,
        // 원본 그대로 올리면 10MB 를 넘는다. 인증에 필요한 건 해상도가 아니다.
        maxWidth: 1600,
        imageQuality: 85,
      );
      if (picked == null || !mounted) return;
      setState(() {
        _photo = File(picked.path);
        _error = null;
      });
    } on Exception {
      if (mounted) {
        setState(() => _error = '사진을 가져오지 못했어요. 권한을 확인해 주세요.');
      }
    }
  }

  Future<void> _submit() async {
    final photo = _photo;
    if (photo == null) return;

    setState(() {
      _busy = true;
      _error = null;
    });

    final repository = ref.read(groupRepositoryProvider);
    final caption = _captionController.text.trim();

    try {
      // 한 번만 올리고 file_key 를 그룹마다 재사용한다. 같은 사진이니까.
      final fileKey = await repository.uploadImage(photo);
      for (final target in widget.todo.pendingProofTargets) {
        await repository.createProof(
          target.groupId,
          declarationItemId: target.declarationItemId,
          fileKey: fileKey,
          caption: caption.isEmpty ? null : caption,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = error.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final targets = widget.todo.pendingProofTargets;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.screenH,
            AppSpacing.s20,
            AppSpacing.screenH,
            AppSpacing.s20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('해낸 걸 남겨요', style: AppTypography.titleL),
              const SizedBox(height: AppSpacing.s4),
              Text(
                widget.todo.title,
                style: AppTypography.body.copyWith(color: AppColors.inkSub),
              ),
              const SizedBox(height: AppSpacing.s12),
              Wrap(
                spacing: AppSpacing.s4,
                runSpacing: AppSpacing.s4,
                children: [
                  for (final target in targets)
                    StatusChip(
                      label: target.groupName,
                      tone: ChipTone.active,
                      icon: Icons.groups_rounded,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.s4),
              Text(
                targets.length > 1
                    ? '사진 한 장이 ${targets.length}개 그룹에 함께 올라가요.'
                    : '선언한 그룹의 피드에 올라가요.',
                style: AppTypography.caption.copyWith(color: AppColors.muted),
              ),
              const SizedBox(height: AppSpacing.s20),
              if (_error != null) ...[
                FormErrorBanner(message: _error!),
                const SizedBox(height: AppSpacing.s16),
              ],
              _PhotoSlot(photo: _photo, onTap: _busy ? null : _showSourceMenu),
              const SizedBox(height: AppSpacing.s16),
              TextField(
                controller: _captionController,
                enabled: !_busy,
                maxLength: 200,
                minLines: 1,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: '한마디 (선택)',
                  hintText: '3km 완주했어요',
                  counterText: '',
                ),
              ),
              const SizedBox(height: AppSpacing.s20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _photo == null || _busy ? null : _submit,
                  child: Text(
                    _busy
                        ? '올리는 중'
                        : _photo == null
                            ? '사진을 골라 주세요'
                            : '인증하기',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSourceMenu() {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: const Text('사진 찍기'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _pick(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('앨범에서 고르기'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _pick(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// 사진 자리. 비어 있을 때도 같은 크기를 차지해 누르면 뭐가 들어올지 보이게 한다.
class _PhotoSlot extends StatelessWidget {
  const _PhotoSlot({required this.photo, required this.onTap});

  final File? photo;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.r8),
      child: AspectRatio(
        aspectRatio: 4 / 3,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadius.r8),
          child: photo == null
              ? const ColoredBox(
                  color: AppColors.fill,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_a_photo_rounded,
                        size: 28,
                        color: AppColors.muted,
                      ),
                      SizedBox(height: AppSpacing.s8),
                      Text('사진 추가'),
                    ],
                  ),
                )
              : Image.file(photo!, fit: BoxFit.cover),
        ),
      ),
    );
  }
}
