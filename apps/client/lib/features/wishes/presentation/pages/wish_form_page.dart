import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphoricons_flutter/phosphoricons_flutter.dart';

import '../../../../app/router/routes.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_sizes.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/link_preview/link_preview.dart';
import '../../../../core/media/remote_image.dart';
import '../../../../l10n/l10n.dart';
import '../../../../shared/ui/ui.dart';
import '../../../session/presentation/providers/app_session_controller.dart';
import '../../../sharing/data/incoming_share.dart';
import '../../data/wish_photo_picker.dart';
import '../../data/wish_repository.dart';
import '../../domain/wish.dart';
import '../../domain/wish_draft.dart';
import '../providers/wish_form_controller.dart';
import '../widgets/wish_photo_tile.dart';
import '../widgets/wish_priority_selector.dart';

/// Экран формы желания — создание и редактирование в одном компоненте.
///
/// Режимы:
/// * создание первого желания ([isFirstWish] = `true`): приветственный
///   заголовок, кнопка «Пропустить», после сохранения flow отмечается
///   пройденным;
/// * создание обычного желания: X → назад на список;
/// * редактирование ([existing] != `null`): поля предзаполнены,
///   сохранение обновляет желание и возвращает на детали;
/// * импорт по ссылке ([draft] != `null`, входящий share): поле
///   ссылки предзаполнено, OG-экстракция дозаполняет остальные поля.
class WishFormPage extends ConsumerStatefulWidget {
  const WishFormPage({
    super.key,
    this.isFirstWish = false,
    this.existing,
    this.draft,
  });

  final bool isFirstWish;

  /// Желание для редактирования. Если `null` — режим создания.
  final Wish? existing;

  /// Черновик из входящего шеринга (`ACTION_SEND`) — ссылка на
  /// товар для импорта метаданных.
  final WishDraft? draft;

  @override
  ConsumerState<WishFormPage> createState() => _WishFormPageState();
}

class _WishFormPageState extends ConsumerState<WishFormPage> {
  late final TextEditingController _titleController;
  late final TextEditingController _priceController;
  late final TextEditingController _linkController;
  late final TextEditingController _imageController;
  late final TextEditingController _descController;
  String? _titleError;
  String? _priceError;

  /// Поля, которые пользователь трогал — результаты импорта
  /// их не перезаписывают.
  final Set<String> _touched = {};
  bool _programmatic = false;
  bool _importing = false;
  bool _importFailed = false;

  /// Редактируемый набор фото (только режим редактирования):
  /// первый элемент — primary (`image_url`), остальные — строки
  /// `wish_images` или новые локальные файлы.
  final List<_PhotoEntry> _photos = [];

  /// Доп.изображения прочитаны из локальной БД. Пока `false`
  /// (ещё не дочитали/ошибка) — при сохранении `images` не
  /// отправляется и набор на сервере не затирается пустым.
  bool _photosLoaded = false;

  /// Приоритет желания — при редактировании предзагружается
  /// из сущности, при создании — `normal` по умолчанию.
  late WishPriority _priority;

  bool get _isEditing => widget.existing != null;

  late final LinkPreviewExtractor _extractor;

  @override
  void initState() {
    super.initState();
    // ref в dispose недоступен — держим ссылку заранее.
    _extractor = ref.read(linkPreviewExtractorProvider);
    final w = widget.existing;
    final d = widget.draft;
    _titleController = TextEditingController(
      text: _truncate(w?.title ?? d?.title, 100),
    );
    _priceController = TextEditingController(
      text: w?.price?.toString() ?? d?.price?.toString() ?? '',
    );
    _linkController = TextEditingController(text: w?.link ?? d?.link);
    _imageController = TextEditingController(text: w?.imageUrl ?? d?.imagePath);
    _descController = TextEditingController(
      text: w?.description ?? d?.description,
    );
    _priority = w?.priority ?? d?.priority ?? WishPriority.normal;

    // Следим за ручным вводом — программные записи (_set) не считаем.
    _track(_titleController, 'title');
    _track(_priceController, 'price');
    _track(_linkController, 'link');
    _track(_imageController, 'image');
    _track(_descController, 'description');

    // Редактирование: primary — сразу из сущности, доп.строки
    // дочитываем из локальной БД (формы держат редактируемый
    // snapshot — изменения коммитятся только через «Сохранить»).
    if (_isEditing) {
      final w = widget.existing!;
      final src = w.imageDisplaySource;
      if (src != null && src.isNotEmpty) {
        _photos.add(
          _PhotoEntry(
            src: src,
            remote: Wish.isRemoteImageRef(w.imageUrl) ? w.imageUrl : null,
          ),
        );
      }
    }

    // Откладываем за кадр: setState/модификация провайдеров в initState
    // запрещены.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Контроллер общий с AddWishSheet — сбрасываем устаревшие
      // error/loading от прошлой сессии формы.
      ref.read(wishFormControllerProvider.notifier).reset();
      if (_isEditing) _loadPhotos();
      // Импорт по входящей ссылке — только для нового желания и
      // только если экстракция ещё не выполнялась (previewDone
      // приходит из AddWishSheet при переходе «Редактировать»).
      final link = widget.draft?.link;
      if (link != null && !_isEditing && widget.draft?.previewDone != true) {
        _startImport(link);
      }
    });
  }

  /// Доп.изображения желания — разовое чтение из локальной БД.
  /// Ошибка чтения не блокирует форму: `_photosLoaded` остаётся
  /// `false` и сохранение не трогает серверный набор (безопасная
  /// семантика «поле не передано»).
  Future<void> _loadPhotos() async {
    final wishId = widget.existing?.id;
    if (wishId == null) return;
    try {
      // Одноразовый snapshot — форма держит редактируемую копию;
      // реактивный стрим здесь не нужен (правки коммитятся только
      // через «Сохранить»).
      final images = await ref
          .read(wishRepositoryProvider)
          .getWishImages(wishId);
      if (!mounted) return;
      setState(() {
        _photos.addAll([
          for (final i in images)
            if (i.displaySource != null)
              _PhotoEntry(
                src: i.displaySource!,
                imageId: i.id,
                remote: i.remoteUrl,
              ),
        ]);
        _photosLoaded = true;
      });
    } catch (_) {
      // оставляем _photosLoaded = false
    }
  }

  // --- Фото (режим редактирования) ---------------------------------

  Future<void> _addPhotoFromCamera() async {
    // Клавиатура убирается до открытия камеры.
    FocusScope.of(context).unfocus();
    try {
      final path = await ref.read(wishPhotoPickerProvider).capture();
      if (path != null && mounted) {
        setState(() => _photos.add(_PhotoEntry(src: path)));
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
        setState(() {
          _photos.addAll([for (final p in paths) _PhotoEntry(src: p)]);
        });
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

  /// Long-press drag: первое фото в списке — обложка, поэтому
  /// переупорядочивание тайлов меняет и primary-изображение.
  /// `onReorderItem` даёт уже скорректированный newIndex.
  void _reorderPhoto(int oldIndex, int newIndex) {
    setState(() {
      _photos.insert(newIndex, _photos.removeAt(oldIndex));
    });
  }

  void _track(TextEditingController c, String field) {
    // Listener срабатывает и на смену selection (autofocus и т.п.) —
    // считаем поле тронутым только при реальном изменении текста.
    var last = c.text;
    c.addListener(() {
      if (c.text == last) return;
      last = c.text;
      if (!_programmatic) _touched.add(field);
    });
  }

  /// Записать значение программно, не помечая поле как «тронутое».
  void _set(TextEditingController c, String value) {
    _programmatic = true;
    c.text = value;
    _programmatic = false;
  }

  static String? _truncate(String? s, int max) =>
      s == null ? null : (s.length > max ? s.substring(0, max) : s);

  /// Заполнить поле результатом импорта, если его не трогал
  /// пользователь и оно пустое.
  void _applyIfFree(String field, TextEditingController c, String? value) {
    if (value == null || value.isEmpty) return;
    if (_touched.contains(field) || c.text.trim().isNotEmpty) return;
    _set(c, value);
  }

  /// OG-экстракция по ссылке товара. Ошибки не блокируют форму —
  /// ссылка уже стоит в поле, желание можно сохранить вручную.
  Future<void> _startImport(String url) async {
    setState(() => _importing = true);
    try {
      final preview = await _extractor.extract(url);
      if (!mounted) return;
      if (preview == null || preview.isEmpty) {
        setState(() => _importFailed = true);
        return;
      }
      // Backend принимает title до 100 символов.
      _applyIfFree('title', _titleController, _truncate(preview.title, 100));
      _applyIfFree('description', _descController, preview.description);
      _applyIfFree('price', _priceController, preview.price?.toString());

      // og:image — внешняя ссылка, а не загруженное фото: качаем и
      // кладём в media-пайплайн (ADR-015), иначе оставляем пустым.
      final imageUrl = preview.imageUrl;
      if (imageUrl != null && !_touched.contains('image')) {
        final local = await ref
            .read(remoteImageFetcherProvider)
            .fetchForWish(imageUrl);
        if (local != null && mounted) {
          _applyIfFree('image', _imageController, local);
        }
      }
    } catch (_) {
      if (mounted) setState(() => _importFailed = true);
    } finally {
      if (mounted) setState(() => _importing = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _priceController.dispose();
    _linkController.dispose();
    _imageController.dispose();
    _descController.dispose();
    // Отменяем импорт — закрытая форма не должна дожидаться WebView.
    _extractor.cancel();
    super.dispose();
  }

  bool _validate() {
    final l10n = context.l10n;
    final title = _titleController.text.trim();
    final priceText = _priceController.text.trim();
    String? titleError;
    String? priceError;

    if (title.isEmpty) {
      titleError = l10n.wishTitleRequired;
    } else if (title.length > 100) {
      titleError = l10n.wishTitleTooLong(100);
    }

    if (priceText.isNotEmpty &&
        int.tryParse(priceText.replaceAll(' ', '')) == null) {
      priceError = l10n.wishPriceInvalid;
    }

    setState(() {
      _titleError = titleError;
      _priceError = priceError;
    });
    return titleError == null && priceError == null;
  }

  Future<void> _save() async {
    if (!_validate()) return;

    final controller = ref.read(wishFormControllerProvider.notifier);
    final wish = await controller.save(
      title: _titleController.text.trim(),
      description: _descController.text.trim().isEmpty
          ? null
          : _descController.text.trim(),
      price: _priceController.text.trim().isEmpty
          ? null
          : int.parse(_priceController.text.trim().replaceAll(' ', '')),
      link: _linkController.text.trim().isEmpty
          ? null
          : _linkController.text.trim(),
      // Редактирование: набор фото — primary = первый элемент
      // (remote-URL известных изображений уходит как есть, локальный
      // файл — как путь до upload). Создание/импорт — текстовое поле.
      imageUrl: _isEditing
          ? (_photos.isEmpty ? null : _photos.first.remote ?? _photos.first.src)
          : _imageController.text.trim().isEmpty
          ? null
          : _imageController.text.trim(),
      // Набор доп.изображений передаётся только если он дочитан —
      // иначе серверная семантика «поле не передано = не трогать».
      images: _isEditing && _photosLoaded
          ? [
              for (final e in _photos.skip(1))
                e.imageId != null
                    ? WishImageInput.existing(e.imageId!)
                    : e.remote != null
                    ? WishImageInput.remote(e.remote!)
                    : WishImageInput.newFile(e.src),
            ]
          : null,
      priority: _priority,
      existing: widget.existing,
    );
    if (wish == null || !mounted) return;

    // Отмечаем flow первого желания как пройденный.
    if (widget.isFirstWish) {
      await ref.read(appSessionControllerProvider.notifier).onWishCreated();
      if (!mounted) return;
      context.go(AppRoutes.home);
    } else if (_isEditing) {
      context.go(AppRoutes.wishDetails(wish.id));
    } else {
      context.go(AppRoutes.home);
    }
  }

  /// Закрыть экран без сохранения.
  ///
  /// Маршруты открываются через `context.go()`, поэтому в стеке обычно
  /// ничего нет — `pop()` не сработает. Используем `canPop()` с
  /// fallback на `go()`: при редактировании — на детали, при
  /// создании — на список.
  void _close() {
    if (context.canPop()) {
      context.pop();
      return;
    }
    final existing = widget.existing;
    context.go(
      existing != null ? AppRoutes.wishDetails(existing.id) : AppRoutes.home,
    );
  }

  void _skip() {
    if (widget.isFirstWish) {
      ref.read(appSessionControllerProvider.notifier).skipFirstWish();
    }
    context.go(AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final t = AppTypography.of(context);
    final l10n = context.l10n;
    final state = ref.watch(wishFormControllerProvider);

    // Share пришёл при открытой форме — не затираем ввод молча:
    // предлагаем открыть импорт в AddWishSheet действием в snackbar
    // (sheet стекуется поверх формы, ввод сохраняется).
    ref.listen<String?>(shareWhileFormOpenProvider, (_, url) {
      if (url == null || !mounted) return;
      ref.read(shareWhileFormOpenProvider.notifier).value = null;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.wishImportNewLink),
          action: SnackBarAction(
            label: l10n.open,
            onPressed: () => ref.read(importRequestProvider.notifier).value =
                WishDraft(link: url),
          ),
        ),
      );
    });
    final isLoading = state is WishFormLoading;
    final error = state is WishFormIdle && state.error != null
        ? wishErrorMessage(l10n, state.error!)
        : null;

    return PopScope(
      // Если страница открыта через `go()`, в стеке ничего нет —
      // системный Back вернёт пользователя назад, а не закроет приложение.
      // На first-wish flow Back намеренно игнорируется (есть «Пропустить»).
      canPop: !widget.isFirstWish && context.canPop(),
      onPopInvokedWithResult: (didPop, _) {
        if (didPop || widget.isFirstWish) return;
        _close();
      },
      child: Scaffold(
        backgroundColor: colors.background,
        appBar: AppShellBar(
          leading: widget.isFirstWish
              ? null
              : AppIconButton(
                  icon: const Icon(PhosphorIconsRegular.x),
                  variant: AppIconButtonVariant.subtle,
                  semanticLabel: l10n.close,
                  tooltip: l10n.close,
                  onPressed: _close,
                ),
          trailing: widget.isFirstWish
              ? TextButton(onPressed: _skip, child: Text(l10n.onboardingSkip))
              : null,
        ),
        body: SafeArea(
          child: Column(
            children: [
              if (!widget.isFirstWish)
                AppScreenTitle(
                  title: _isEditing ? l10n.wishEditTitle : l10n.wishNewTitle,
                ),
              Expanded(
                child: GestureDetector(
                  onTap: () => FocusScope.of(context).unfocus(),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.screenPaddingHorizontal,
                      vertical: AppSpacing.sm,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (widget.isFirstWish) ...[
                          Icon(
                            PhosphorIconsRegular.sparkle,
                            size: 40,
                            color: colors.primary,
                          ),
                          const SizedBox(height: AppSpacing.sm),
                          Text(l10n.firstWishTitle, style: t.screenTitle),
                          const SizedBox(height: AppSpacing.xxs),
                          Text(l10n.firstWishDescription, style: t.secondary),
                        ],
                        const SizedBox(height: AppSpacing.xl),

                        AppTextField(
                          controller: _titleController,
                          label: l10n.wishTitleLabel,
                          hint: l10n.wishTitleHint,
                          errorText: _titleError,
                          enabled: !isLoading,
                          autofocus: !_isEditing,
                          textInputAction: TextInputAction.next,
                          semanticsLabel: l10n.wishTitleSemantic,
                          onChanged: (_) {
                            if (_titleError != null) {
                              setState(() => _titleError = null);
                            }
                          },
                        ),
                        const SizedBox(height: AppSpacing.betweenFields),
                        AppTextField(
                          controller: _priceController,
                          label: l10n.wishPriceLabel,
                          hint: l10n.wishPriceHint,
                          errorText: _priceError,
                          enabled: !isLoading,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.next,
                          semanticsLabel: l10n.wishPriceSemantic,
                          onChanged: (_) {
                            if (_priceError != null) {
                              setState(() => _priceError = null);
                            }
                          },
                        ),
                        const SizedBox(height: AppSpacing.betweenFields),
                        AppTextField(
                          controller: _linkController,
                          label: l10n.wishLinkLabel,
                          hint: l10n.urlHint,
                          enabled: !isLoading,
                          keyboardType: TextInputType.url,
                          textInputAction: TextInputAction.next,
                          semanticsLabel: l10n.wishLinkSemantic,
                        ),
                        if (_importing) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Row(
                            children: [
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Expanded(
                                child: Text(
                                  l10n.wishImportLoading,
                                  style: t.caption,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (_importFailed) ...[
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            l10n.wishImportFailed,
                            style: t.caption.copyWith(color: colors.error),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.betweenFields),
                        // Редактирование: управление набором фото
                        // (первое — обложка; тайлы + камера/галерея).
                        // Создание/импорт — текстовое поле URL.
                        if (_isEditing) ...[
                          Text(
                            l10n.wishPhotosSection,
                            style: t.caption.copyWith(
                              color: colors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          if (_photos.isNotEmpty) ...[
                            SizedBox(
                              height: AppSizes.sheetPhotoTileSize,
                              // Long-press drag меняет порядок —
                              // первый тайл становится обложкой.
                              child: ReorderableListView.builder(
                                scrollDirection: Axis.horizontal,
                                padding: EdgeInsets.zero,
                                itemCount: _photos.length,
                                onReorderItem: _reorderPhoto,
                                itemBuilder: (context, index) {
                                  final photo = _photos[index];
                                  return Padding(
                                    key: ObjectKey(photo),
                                    padding: EdgeInsets.only(
                                      left: index == 0 ? 0 : AppSpacing.xs,
                                    ),
                                    child: WishPhotoTile(
                                      src: photo.src,
                                      onRemove: isLoading
                                          ? null
                                          : () => _removePhoto(index),
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                          ],
                          Row(
                            children: [
                              Expanded(
                                child: Semantics(
                                  button: true,
                                  label: l10n.wishCameraActionSemantic,
                                  child: AppButton(
                                    label: l10n.wishCameraAction,
                                    variant: AppButtonVariant.outline,
                                    size: AppButtonSize.sm,
                                    expand: true,
                                    leading: const Icon(
                                      PhosphorIconsRegular.camera,
                                    ),
                                    enabled: !isLoading,
                                    onPressed: _addPhotoFromCamera,
                                  ),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.xs),
                              Expanded(
                                child: Semantics(
                                  button: true,
                                  label: l10n.wishGalleryActionSemantic,
                                  child: AppButton(
                                    label: l10n.wishGalleryAction,
                                    variant: AppButtonVariant.outline,
                                    size: AppButtonSize.sm,
                                    expand: true,
                                    leading: const Icon(
                                      PhosphorIconsRegular.image,
                                    ),
                                    enabled: !isLoading,
                                    onPressed: _addPhotosFromGallery,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ] else
                          AppTextField(
                            controller: _imageController,
                            label: l10n.wishImageLabel,
                            hint: l10n.urlHint,
                            enabled: !isLoading,
                            keyboardType: TextInputType.url,
                            textInputAction: TextInputAction.next,
                            semanticsLabel: l10n.wishImageSemantic,
                          ),
                        const SizedBox(height: AppSpacing.betweenFields),
                        AppTextField(
                          controller: _descController,
                          label: l10n.wishNoteLabel,
                          hint: l10n.wishNoteHint,
                          maxLines: 4,
                          minLines: 2,
                          enabled: !isLoading,
                          textInputAction: TextInputAction.newline,
                          semanticsLabel: l10n.wishNoteSemantic,
                        ),
                        const SizedBox(height: AppSpacing.betweenFields),
                        WishPrioritySelector(
                          value: _priority,
                          enabled: !isLoading,
                          onChanged: (p) => setState(() => _priority = p),
                        ),
                        const SizedBox(height: AppSpacing.lg),

                        if (error != null) ...[
                          AppFeedback(
                            type: AppFeedbackType.error,
                            title: error,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                        ],

                        AppButton(
                          label: _isEditing ? l10n.saveChanges : l10n.wishSave,
                          expand: true,
                          isLoading: isLoading,
                          enabled: !isLoading,
                          leading: const Icon(PhosphorIconsRegular.check),
                          onPressed: _save,
                        ),
                        const SizedBox(height: AppSpacing.md),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Элемент редактируемого набора фото (режим редактирования):
/// первый в списке — primary (`image_url`), остальные —
/// additional (`wish_images`) или новые локальные файлы.
class _PhotoEntry {
  const _PhotoEntry({required this.src, this.imageId, this.remote});

  /// Источник отображения: локальный путь или remote URL.
  final String src;

  /// Id существующей строки `wish_images` (`null` — новый файл
  /// или primary, у которого строки нет).
  final String? imageId;

  /// Server-facing remote URL для уже загруженных изображений
  /// (`null` у локальных файлов — до upload в API уходит путь).
  final String? remote;
}
