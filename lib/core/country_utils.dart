import 'dart:ui' as ui;

class CountryUtils {
  CountryUtils._();

  static const defaultCountry = 'CL';

  static String normalize(String? raw, {String fallback = defaultCountry}) {
    final value = raw?.trim().toUpperCase();
    if (value != null && RegExp(r'^[A-Z]{2}$').hasMatch(value)) {
      return value;
    }
    return fallback;
  }

  static String detectDeviceCountry({String fallback = defaultCountry}) {
    return normalize(ui.PlatformDispatcher.instance.locale.countryCode,
        fallback: fallback);
  }

  static String languageFor(String countryCode) {
    final code = normalize(countryCode);
    return switch (code) {
      'US' || 'GB' || 'CA' || 'AU' => 'en',
      'BR' || 'PT' => 'pt',
      _ => 'es',
    };
  }

  static String labelFor(String countryCode) {
    return switch (normalize(countryCode)) {
      'AR' => 'Argentina',
      'BR' => 'Brasil',
      'CL' => 'Chile',
      'CO' => 'Colombia',
      'ES' => 'Espana',
      'MX' => 'Mexico',
      'PE' => 'Peru',
      'US' => 'EE.UU.',
      'VE' => 'Venezuela',
      _ => 'Local',
    };
  }

  static String openFoodFactsCountryTag(String countryCode) {
    return switch (normalize(countryCode)) {
      'AR' => 'argentina',
      'BR' => 'brazil',
      'CL' => 'chile',
      'CO' => 'colombia',
      'ES' => 'spain',
      'MX' => 'mexico',
      'PE' => 'peru',
      'US' => 'united-states',
      'VE' => 'venezuela',
      _ => '',
    };
  }
}
