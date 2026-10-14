import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radii.dart';
import '../../../../app/theme/app_sizes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/link_preview/link_preview.dart';
import '../../../../core/media/remote_image.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/ui/ui.dart';
import '../../data/wish_photo_picker.dart';
import '../../domain/wish.dart';
import '../../domain/wish_draft.dart';
import '../providers/wish_form_controller.dart';
import 'wish_photo_tile.dart';
import 'wish_priority_selector.dart';

/// Открывает sheet быстрого добавления желания.
///
/// Механика роута — стандартная (`showModalBottomSheet` даёт
/// barrier, back и drag-dismiss), визуальная поверхность —
/// собственный компонент [AddWishSheet] в дизайн-системе.
///
/// С [draft] sheet открывается в режиме импорта: по ссылке
/// запускается OG-экстракция и показывается компактное превью.
Future<void> showAddWishSheet(BuildContext context, {WishDraft? draft}) {
  final colors = context.appColors;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    barrierColor: colors.scrim,
    builder: (_) => AddWishSheet(draft: draft),
  );
}

/// Sheet быстрого добавления желания.
///
/// Два режима:
/// * quick-capture ([draft] == `null`): одно текстовое поле,
///   опциональные URL и фото с камеры;
/// * импорт ([draft] != `null`, входящий share): OG-экстракция
///   по ссылке, компактное превью (фото/название/цена/ссылка),
///   «Добавить желание» или переход в полную форму.
///
/// Желание сохраняется через существующий offline-first
/// `WishFormController` → repository → outbox в обоих режимах.
class AddWishSheet extends ConsumerStatefulWidget {
  const AddWishSheet({super.key, this.draft});

  /// Черновик из входящего шеринга. `null` — обычное создание.
  final WishDraft? draft;

  @override
  ConsumerState<AddWishSheet> createState() => _AddWishSheetState();
}

class _AddWishSheetState extends ConsumerState<AddWishSheet> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _urlController = TextEditingController();
  final List<String> _photos = [];
  WishPriority _priority = WishPriority.normal;
  bool _urlFieldVisible = false;
  String? _urlError;
  bool _allowPop = false;

  bool get _isImport => widget.draft != null;

  /// Поля, которые пользователь трогал — результаты импорта
  /// их не перезаписывают.
  final Set<String> _touched = {};
  bool _programmatic = false;
  bool _photoAddedByUser = false;

  /// Состояние импорта (только режим draft).
  late final LinkPreviewExtractor _extractor;
  LinkPreview? _preview;
  bool _importing = false;
  bool _importFailed = false;
  bool _importCancelled = false;

  @override
  void initState() {
    super.initState();
    // ref в dispose недоступен — держим ссылку заранее.
    _extractor = ref.read(linkPreviewExtractorProvider);
    _urlController.text = widget.draft?.link ?? '';
    // Обновляем enabled-состояние «Добавить» и следим за ручным
    // вводом — программные записи (_set) не считаем тронутыми.
    _track(_titleController, 'title');
    _track(_urlController, 'url');

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Контроллер общий с WishFormPage — сбрасываем устаревшие
      // error/loading от прошлой сессии формы.
      ref.read(wishFormControllerProvider.notifier).reset();
      if (_isImport) _startImport();
    });
  }

  void _track(TextEditingController c, String field) {
    // Listener срабатывает и на смену selection — считаем поле
    // тронутым только при реальном изменении текста.
    var last = c.text;
    c.addListener(() {
      if (c.text == last) return;
      last = c.text;
      _onChanged();
      if (!_programmatic) _touched.add(field);
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _urlController.dispose();
    // Отменяем импорт — закрытый sheet не ждёт WebView.
    _extractor.cancel();
    super.dispose();
  }

  void _onChanged() => setState(() {
    if (_urlError != null) _urlError = null;
  });

  /// Записать значение программно, не помечая поле как «тронутое».
  void _set(TextEditingController c, String value) {
    _programmatic = true;
    c.text = value;
    _programmatic = false;
  }

  /// Заполнить поле результатом импорта, если его не трогал
  /// пользователь и оно пустое.
  void _applyIfFree(String field, TextEditingController c, String? value) {
    if (value == null || value.isEmpty) return;
    if (_touched.contains(field) || c.text.trim().isNotEmpty) return;
    _set(c, value);
  }

  /// Есть содержимое для сохранения.
  bool get _hasContent =>
      _titleController.text.isNotEmpty ||
      _urlController.text.isNotEmpty ||
      _photos.isNotEmpty;

  /// Пользователь реально что-то ввёл — только тогда при закрытии
  /// спрашиваем подтверждение. Программный импорт вводом не считается.
  bool get _hasUserInput => _touched.isNotEmpty || _photoAddedByUser;

  bool get _canSubmit => _hasContent;

  /// Нормализованный URL или `null` (пустой / некорректный).
  String? get _normalizedUrl {
    final v = _urlController.text.trim();
    if (v.isEmpty) return null;
    final withScheme = v.contains('://') ? v : 'https://$v';
    final uri = Uri.tryParse(withScheme);
    if (uri == null || !uri.hasAbsolutePath && uri.host.isEmpty) {
      return null;
    }
    if (uri.host.isEmpty || !uri.host.contains('.')) return null;
    return uri.toString();
  }

  /// Название желания: текст пользователя → хост ссылки → «Фотография».
  String _resolvedTitle(String? link) {
    final title = _titleController.text.trim();
    if (title.isNotEmpty) {
      // Backend принимает максимум 100 символов.
      return title.length > 100 ? title.substring(0, 100) : title;
    }
    if (link != null) {
      return Uri.parse(link).host;
    }
    return context.l10n.wishPhotoFallbackTitle;
  }

  static String? _truncate(String? s, int max) =>
      s == null ? null : (s.length > max ? s.substring(0, max) : s);

  /// «3217» → «3 217 ₽».
  static String _formatPrice(int price) {
    final s = price.toString();
    final buf = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
      buf.write(s[i]);
    }
    return '$buf ₽';
  }

  // --- Импорт по ссылке --------------------------------------------------

  /// OG-экстракция по ссылке черновика. Ошибки не блокируют sheet —
  /// ссылка уже стоит в поле, желание можно сохранить вручную.
  Future<void> _startImport() async {
    setState(() => _importing = true);
    try {
      final preview = await _extractor.extract(widget.draft!.link);
      if (!mounted) return;
      if (preview == null || preview.isEmpty) {
        if (!_importCancelled) _failImport();
        return;
      }
      _preview = preview;
      _applyIfFree('title', _titleController, _truncate(preview.title, 100));

      // og:image — внешняя ссылка: качаем в media-пайплайн (ADR-015).
      final imageUrl = preview.imageUrl;
      if (imageUrl != null && _photos.isEmpty) {
        final local = await ref
            .read(remoteImageFetcherProvider)
            .fetchForWish(imageUrl);
        if (local != null && mounted && _photos.isEmpty) {
          setState(() => _photos.add(local));
        }
      }
    } catch (_) {
      if (mounted) _failImport();
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  /// Импорт не удался / данных нет → ручной ввод со ссылкой на месте.
  void _failImport() {
    setState(() {
      _importFailed = true;
      _urlFieldVisible = true;
    });
  }

  /// Отменить экстракцию — ручной ввод, исходная ссылка сохраняется.
  void _cancelImport() {
    _extractor.cancel();
    setState(() {
      _importing = false;
      _importCancelled = true;
      _urlFieldVisible = true;
    });
  }

  /// Переход в полную форму с уже полученными данными —
  /// повторная экстракция не нужна (`previewDone`).
  void _openFullForm() {
    final draft = WishDraft(
      link: widget.draft!.link,
      title: _titleController.text.trim(),
      description: _preview?.description,
      price: _preview?.price,
      imagePath: _photos.isNotEmpty ? _photos.first : null,
      priority: _priority,
      previewDone: true,
    );
    final router = GoRouter.of(context);
    setState(() => _allowPop = true);
    Navigator.of(context).pop();
    router.go(AppRoutes.newWish, extra: draft);
  }

  // --- Фото --------------------------------------------------------------

  Future<void> _addPhotoFromCamera() async {
    // Клавиатура убирается до открытия камеры — без борьбы
    // за focus между полем и системным экраном съёмки.
    FocusScope.of(context).unfocus();
    try {
      final path = await ref.read(wishPhotoPickerProvider).capture();
      if (path != null && mounted) {
        _photoAddedByUser = true;
        setState(() => _photos.add(path));
      }
    } catch (_) {
      _showPhotoError();
    }
  }

  Future<void> _addPhotosFromGallery() async {
    FocusScope.of(context).unfocus();
    try {
      final paths = await ref.read(wishPhotoPickerProvider).pickFromGallery();
      if (paths.isNotEmpty && mounted) {
        _photoAddedByUser = true;
        setState(() => _photos.addAll(paths));
      }
    } catch (_) {
      _showPhotoError();
    }
  }

  void _showPhotoError() {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.wishPhotoError)));
  }

  void _removePhoto(int index) => setState(() => _photos.removeAt(index));

  // --- Сохранение --------------------------------------------------------

  Future<void> _submit() async {
    final link = _normalizedUrl;
    if (_urlController.text.trim().isNotEmpty && link == null) {
      setState(() => _urlError = context.l10n.wishUrlInvalid);
      return;
    }
    if (!_canSubmit) return;

    final wish = await ref
        .read(wishFormControllerProvider.notifier)
        .save(
          title: _resolvedTitle(link),
          link: link,
          price: _isImport ? _preview?.price : null,
          // Первое фото — primary (image_url), остальные —
          // дополнительные строки wish_images в порядке добавления.
          imageUrl: _photos.isEmpty ? null : _photos.first,
          priority: _priority,
          additionalImagePaths: _photos.length > 1
              ? _photos.sublist(1)
              : const [],
        );
    if (wish == null || !mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _confirmDiscard() async {
    final l10n = context.l10n;
    final confirmed = await showAppConfirmDialog(
      context,
      title: l10n.wishDiscardTitle,
      message: l10n.wishDiscardMessage,
      confirmLabel: l10n.close,
    );
    if (confirmed == true && mounted) {
      setState(() => _allowPop = true);
      Navigator.of(context).pop();
    }
  }

  // --- UI ----------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final t = AppTypography.of(context);
    final l10n = context.l10n;
    final formState = ref.watch(wishFormControllerProvider);
    final isLoading = formState is WishFormLoading;
    final error = formState is WishFormIdle && formState.error != null
        ? wishErrorMessage(l10n, formState.error!)
        : null;

    return PopScope(
      // Данные не теряем бездумно: при наличии ввода спрашиваем
      // подтверждение — действует для ×, системного Back,
      // tap по barrier и drag-down. Программный импорт вводом
      // не считается.
      canPop: !_hasUserInput || _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmDiscard();
      },
      child: AnimatedPadding(
        // Клавиатура поднимает sheet, не перекрывая «Добавить».
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: Container(
          decoration: BoxDecoration(
            color: colors.surfaceElevated,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(AppRadii.xl),
            ),
            border: Border(
              top: BorderSide(color: colors.border.withValues(alpha: 0.6)),
            ),
          ),
          child: SafeArea(
            top: false,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.xs,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Drag indicator — визуальная метка sheet.
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: colors.border,
                        borderRadius: BorderRadius.circular(AppRadii.full),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _isImport ? l10n.wishImportTitle : l10n.wishAdd,
                          style: t.title,
                        ),
                      ),
                      AppIconButton(
                        icon: const Icon(PhosphorIconsRegular.x),
                        onPressed: () => Navigator.of(context).maybePop(),
                        semanticLabel: l10n.close,
                        tooltip: l10n.close,
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),

                  if (_isImport) ...[
                    _buildImportContent(colors, t, isLoading),
                  ] else ...[
                    _buildQuickContent(colors, t, isLoading, error),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Контент режима импорта: индикатор → превью → ручной ввод.
  Widget _buildImportContent(
    AppThemeColors colors,
    AppTypographyStyles t,
    bool isLoading,
  ) {
    final l = context.l10n;
    if (_importing) {
      // Не показываем пустую форму во время извлечения.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: AppSpacing.xs),
              Expanded(child: Text(l.wishImportLoading, style: t.caption)),
            ],
          ),
          const SizedBox(height: AppSpacing.xxs),
          Text(
            widget.draft!.link,
            style: t.caption.copyWith(color: colors.textMuted),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: AppSpacing.sm),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(onPressed: _cancelImport, child: Text(l.cancel)),
          ),
        ],
      );
    }

    // Успех: превью + редактируемое название + действия.
    final preview = _preview;
    if (preview != null && !_importFailed && !_importCancelled) {
      final price = preview.price;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: colors.surfaceMuted,
              borderRadius: BorderRadius.circular(AppRadii.md),
            ),
            child: Row(
              children: [
                if (_photos.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                    child: AppImage(
                      src: _photos.first,
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                      errorWidget: const SizedBox.shrink(),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (price != null)
                        Text(_formatPrice(price), style: t.title),
                      Text(
                        Uri.parse(widget.draft!.link).host,
                        style: t.caption.copyWith(color: colors.textMuted),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          AppTextField(
            controller: _titleController,
            hint: l.wishQuickHint,
            enabled: !isLoading,
            textInputAction: TextInputAction.done,
            semanticsLabel: l.wishTitleSemantic,
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: AppSpacing.md),
          WishPrioritySelector(
            value: _priority,
            enabled: !isLoading,
            onChanged: (p) => setState(() => _priority = p),
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton(
            label: l.wishAdd,
            expand: true,
            size: AppButtonSize.lg,
            enabled: _canSubmit && !isLoading,
            isLoading: isLoading,
            leading: const Icon(PhosphorIconsRegular.plus),
            onPressed: _submit,
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(onPressed: _openFullForm, child: Text(l.edit)),
          ),
        ],
      );
    }

    // Не удалось / отменено — ручной ввод, ссылка сохранена.
    return _buildManualContent(colors, t, isLoading);
  }

  /// Ручной ввод при ошибке/отмене импорта: ошибка (если была),
  /// поля названия и ссылки, стандартные вторичные действия.
  Widget _buildManualContent(
    AppThemeColors colors,
    AppTypographyStyles t,
    bool isLoading,
  ) {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_importFailed) ...[
          AppFeedback(type: AppFeedbackType.error, title: l.wishImportFailed),
          const SizedBox(height: AppSpacing.sm),
        ],
        AppTextField(
          controller: _titleController,
          hint: l.wishQuickHint,
          enabled: !isLoading,
          textInputAction: TextInputAction.next,
          semanticsLabel: l.wishTitleSemantic,
        ),
        const SizedBox(height: AppSpacing.sm),
        AppTextField(
          controller: _urlController,
          label: l.wishUrlLabel,
          hint: l.urlHint,
          errorText: _urlError,
          enabled: !isLoading,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.done,
          semanticsLabel: l.wishUrlActionSemantic,
          leading: const Icon(PhosphorIconsRegular.link),
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: Semantics(
                button: true,
                label: l.wishCameraActionSemantic,
                child: AppButton(
                  label: l.wishCameraAction,
                  variant: AppButtonVariant.outline,
                  size: AppButtonSize.sm,
                  expand: true,
                  leading: const Icon(PhosphorIconsRegular.camera),
                  enabled: !isLoading,
                  onPressed: _addPhotoFromCamera,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Semantics(
                button: true,
                label: l.wishGalleryActionSemantic,
                child: AppButton(
                  label: l.wishGalleryAction,
                  variant: AppButtonVariant.outline,
                  size: AppButtonSize.sm,
                  expand: true,
                  leading: const Icon(PhosphorIconsRegular.image),
                  enabled: !isLoading,
                  onPressed: _addPhotosFromGallery,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        WishPrioritySelector(
          value: _priority,
          enabled: !isLoading,
          onChanged: (p) => setState(() => _priority = p),
        ),
        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: l.add,
          expand: true,
          size: AppButtonSize.lg,
          enabled: _canSubmit && !isLoading,
          isLoading: isLoading,
          leading: const Icon(PhosphorIconsRegular.plus),
          onPressed: _submit,
        ),
      ],
    );
  }

  /// Обычный quick-capture — исходная разметка без изменений.
  Widget _buildQuickContent(
    AppThemeColors colors,
    AppTypographyStyles t,
    bool isLoading,
    String? error,
  ) {
    final l = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppTextField(
          controller: _titleController,
          hint: l.wishQuickHint,
          autofocus: true,
          enabled: !isLoading,
          textInputAction: TextInputAction.done,
          semanticsLabel: l.wishTitleSemantic,
          onSubmitted: (_) => _submit(),
        ),

        // URL-поле появляется по нажатию «+ URL».
        AnimatedSize(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          alignment: Alignment.topCenter,
          child: _urlFieldVisible
              ? Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: AppTextField(
                    controller: _urlController,
                    label: l.wishUrlLabel,
                    hint: l.urlHint,
                    errorText: _urlError,
                    enabled: !isLoading,
                    keyboardType: TextInputType.url,
                    textInputAction: TextInputAction.done,
                    semanticsLabel: l.wishUrlActionSemantic,
                    leading: const Icon(PhosphorIconsRegular.link),
                    trailing: GestureDetector(
                      onTap: () => setState(() {
                        _urlController.clear();
                        _urlFieldVisible = false;
                      }),
                      child: const Icon(PhosphorIconsRegular.x),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                )
              : const SizedBox.shrink(),
        ),

        // Фото: плитки в порядке добавления.
        if (_photos.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: AppSizes.sheetPhotoTileSize,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _photos.length,
              separatorBuilder: (_, _) => const SizedBox(width: AppSpacing.xs),
              itemBuilder: (context, index) => WishPhotoTile(
                src: _photos[index],
                onRemove: () => _removePhoto(index),
              ),
            ),
          ),
        ],

        const SizedBox(height: AppSpacing.md),
        // Вторичные источники — равная доля ширины каждой.
        Row(
          children: [
            if (!_urlFieldVisible) ...[
              Expanded(
                child: AppButton(
                  label: l.wishUrlAction,
                  variant: AppButtonVariant.outline,
                  size: AppButtonSize.sm,
                  expand: true,
                  leading: const Icon(PhosphorIconsRegular.plus),
                  enabled: !isLoading,
                  onPressed: () => setState(() => _urlFieldVisible = true),
                ),
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
            Expanded(
              child: Semantics(
                button: true,
                label: l.wishCameraActionSemantic,
                child: AppButton(
                  label: l.wishCameraAction,
                  variant: AppButtonVariant.outline,
                  size: AppButtonSize.sm,
                  expand: true,
                  leading: const Icon(PhosphorIconsRegular.camera),
                  enabled: !isLoading,
                  onPressed: _addPhotoFromCamera,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Semantics(
                button: true,
                label: l.wishGalleryActionSemantic,
                child: AppButton(
                  label: l.wishGalleryAction,
                  variant: AppButtonVariant.outline,
                  size: AppButtonSize.sm,
                  expand: true,
                  leading: const Icon(PhosphorIconsRegular.image),
                  enabled: !isLoading,
                  onPressed: _addPhotosFromGallery,
                ),
              ),
            ),
          ],
        ),

        if (error != null) ...[
          const SizedBox(height: AppSpacing.sm),
          AppFeedback(type: AppFeedbackType.error, title: error),
        ],

        const SizedBox(height: AppSpacing.md),
        WishPrioritySelector(
          value: _priority,
          enabled: !isLoading,
          onChanged: (p) => setState(() => _priority = p),
        ),

        const SizedBox(height: AppSpacing.md),
        AppButton(
          label: l.add,
          expand: true,
          size: AppButtonSize.lg,
          enabled: _canSubmit && !isLoading,
          isLoading: isLoading,
          leading: const Icon(PhosphorIconsRegular.plus),
          onPressed: _submit,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          l.wishAddLaterHint,
          style: t.caption.copyWith(color: colors.textMuted),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
