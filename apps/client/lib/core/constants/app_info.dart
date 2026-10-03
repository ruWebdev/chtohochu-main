/// Сведения о приложении для экрана «О приложении».
///
/// `version` синхронизирована с `version` в `pubspec.yaml`
/// (без build number). При релизах обновлять вместе.
class AppInfo {
  const AppInfo._();

  /// Название приложения.
  static const String name = 'ЧтоХочу';

  /// Версия приложения.
  static const String version = '2.0.0';
}
