import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:murmur/core/utils/app_settings_storage.dart';
import 'package:murmur/l10n/app_localizations.dart';

final localeProvider =
    StateNotifierProvider<LocaleNotifier, Locale>((ref) => LocaleNotifier());

class LocaleNotifier extends StateNotifier<Locale> {
  LocaleNotifier() : super(AppSettingsStorage.appLocale);

  Future<void> setLanguageCode(String languageCode) async {
    final Locale locale = Locale(languageCode);
    if (locale == state) {
      return;
    }
    await AppSettingsStorage.setAppLocale(languageCode);
    state = locale;
    AppLocalizationsBinding.instance = AppLocalizations(locale);
  }
}
