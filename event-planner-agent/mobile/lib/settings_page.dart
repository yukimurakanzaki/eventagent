import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_settings.dart';
import 'l10n/l10n.dart';
import 'money.dart';

/// Public links. Override at build time for a white-label deployment.
const privacyPolicyUrl = String.fromEnvironment(
  'WARGAKAS_PRIVACY_URL',
  defaultValue: 'https://github.com/yukimurakanzaki/eventagent/blob/main/event-planner-agent/docs/privacy-policy.md',
);
const termsUrl = String.fromEnvironment(
  'WARGAKAS_TERMS_URL',
  defaultValue: 'https://github.com/yukimurakanzaki/eventagent/blob/main/event-planner-agent/docs/terms-of-service.md',
);
const supportUrl = String.fromEnvironment(
  'WARGAKAS_SUPPORT_URL',
  defaultValue: 'https://github.com/yukimurakanzaki/eventagent/issues',
);
const appVersion = String.fromEnvironment(
  'WARGAKAS_VERSION',
  defaultValue: '2.0.0',
);

Future<void> openSettings(BuildContext context, {AppSettings? settings}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => SettingsPage(settings: settings ?? AppSettings.instance),
    ),
  );
}

Future<void> openExternalLink(BuildContext context, String url) async {
  var opened = false;
  try {
    opened = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
  } catch (_) {
    opened = false;
  }
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(tr('Tidak dapat membuka tautan: {url}', {'url': url})),
      ),
    );
  }
}

class SettingsPage extends StatelessWidget {
  const SettingsPage({required this.settings, super.key});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) {
        final theme = Theme.of(context);
        final languageCode = settings.languageCode;
        return Scaffold(
          appBar: AppBar(title: Text(tr('Pengaturan'))),
          body: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    _Header(tr('Bahasa')),
                    ListTile(
                      key: const Key('settings-language'),
                      leading: const Icon(Icons.translate),
                      title: Text(tr('Bahasa aplikasi')),
                      subtitle: Text(
                        languageCode == null
                            ? tr('Ikuti bahasa ponsel ({language})', {
                                'language': L10n.languageFor(L10n.code)
                                    .nativeName,
                              })
                            : L10n.languageFor(languageCode).nativeName,
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _pickLanguage(context),
                    ),
                    _Header(tr('Tampilan')),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: SegmentedButton<ThemeMode>(
                        segments: [
                          ButtonSegment(
                            value: ThemeMode.system,
                            icon: const Icon(Icons.brightness_auto_outlined),
                            label: Text(tr('Otomatis')),
                          ),
                          ButtonSegment(
                            value: ThemeMode.light,
                            icon: const Icon(Icons.light_mode_outlined),
                            label: Text(tr('Terang')),
                          ),
                          ButtonSegment(
                            value: ThemeMode.dark,
                            icon: const Icon(Icons.dark_mode_outlined),
                            label: Text(tr('Gelap')),
                          ),
                        ],
                        selected: {settings.themeMode},
                        onSelectionChanged: (value) =>
                            settings.setThemeMode(value.first),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.text_fields),
                      title: Text(tr('Ukuran teks')),
                      subtitle: Text(
                        tr('Contoh: Saldo kas sekarang'),
                        textScaler: TextScaler.noScaling,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          fontSize: 18 * settings.textScale,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Slider(
                        key: const Key('settings-text-scale'),
                        value: textScaleOptions
                            .indexOf(settings.textScale)
                            .toDouble()
                            .clamp(0, textScaleOptions.length - 1),
                        min: 0,
                        max: (textScaleOptions.length - 1).toDouble(),
                        divisions: textScaleOptions.length - 1,
                        label: '${(settings.textScale * 100).round()}%',
                        semanticFormatterCallback: (value) =>
                            '${(textScaleOptions[value.round()] * 100).round()}%',
                        onChanged: (value) => settings.setTextScale(
                          textScaleOptions[value.round()],
                        ),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.palette_outlined),
                      title: Text(tr('Warna utama')),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          for (var i = 0; i < accentColors.length; i++)
                            Semantics(
                              button: true,
                              selected: settings.accentIndex == i,
                              label: tr('Warna {number}', {'number': i + 1}),
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () => settings.setAccentIndex(i),
                                child: Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    color: accentColors[i],
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: settings.accentIndex == i
                                          ? theme.colorScheme.onSurface
                                          : Colors.transparent,
                                      width: 3,
                                    ),
                                  ),
                                  child: settings.accentIndex == i
                                      ? const Icon(
                                          Icons.check,
                                          color: Colors.white,
                                        )
                                      : null,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    SwitchListTile(
                      secondary: const Icon(Icons.contrast),
                      title: Text(tr('Kontras tinggi')),
                      subtitle: Text(
                        tr('Garis dan teks lebih tegas agar mudah dibaca.'),
                      ),
                      value: settings.highContrast,
                      onChanged: settings.setHighContrast,
                    ),
                    SwitchListTile(
                      secondary: const Icon(Icons.motion_photos_off_outlined),
                      title: Text(tr('Kurangi animasi')),
                      value: settings.reduceMotion,
                      onChanged: settings.setReduceMotion,
                    ),
                    _Header(tr('Uang')),
                    ListTile(
                      key: const Key('settings-currency'),
                      leading: const Icon(Icons.payments_outlined),
                      title: Text(tr('Mata uang untuk acara baru')),
                      subtitle: Text(
                        '${settings.defaultCurrency} · ${currencySpec(settings.defaultCurrency).name}',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        final code = await pickCurrency(
                          context,
                          selected: settings.defaultCurrency,
                        );
                        if (code != null) {
                          await settings.setDefaultCurrency(code);
                        }
                      },
                    ),
                    _Header(tr('Tentang')),
                    ListTile(
                      leading: const Icon(Icons.privacy_tip_outlined),
                      title: Text(tr('Kebijakan privasi')),
                      trailing: const Icon(Icons.open_in_new),
                      onTap: () => openExternalLink(context, privacyPolicyUrl),
                    ),
                    ListTile(
                      leading: const Icon(Icons.gavel_outlined),
                      title: Text(tr('Syarat penggunaan')),
                      trailing: const Icon(Icons.open_in_new),
                      onTap: () => openExternalLink(context, termsUrl),
                    ),
                    ListTile(
                      leading: const Icon(Icons.support_agent_outlined),
                      title: Text(tr('Bantuan & masukan')),
                      trailing: const Icon(Icons.open_in_new),
                      onTap: () => openExternalLink(context, supportUrl),
                    ),
                    ListTile(
                      leading: const Icon(Icons.info_outline),
                      title: Text(tr('Versi aplikasi')),
                      subtitle: const Text('Wargakas $appVersion'),
                      onTap: () => showLicensePage(
                        context: context,
                        applicationName: 'Wargakas',
                        applicationVersion: appVersion,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _pickLanguage(BuildContext context) async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.8,
          ),
          child: ListView(
            shrinkWrap: true,
            children: [
              _LanguageTile(
                title: tr('Ikuti bahasa ponsel'),
                subtitle: null,
                selected: settings.languageCode == null,
                onTap: () => Navigator.pop(context, ''),
              ),
              for (final language in L10n.languages)
                _LanguageTile(
                  title: language.nativeName,
                  subtitle: language.englishName,
                  selected: settings.languageCode == language.code,
                  onTap: () => Navigator.pop(context, language.code),
                ),
            ],
          ),
        ),
      ),
    );
    if (chosen == null) return;
    await settings.setLanguage(chosen.isEmpty ? null : chosen);
  }
}

class _LanguageTile extends StatelessWidget {
  const _LanguageTile({
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing: selected ? const Icon(Icons.check) : null,
      selected: selected,
      onTap: onTap,
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Semantics(
        header: true,
        child: Text(
          text,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

/// Searchable currency picker. Returns the chosen ISO code.
Future<String?> pickCurrency(BuildContext context, {String? selected}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => _CurrencySheet(selected: selected),
  );
}

class _CurrencySheet extends StatefulWidget {
  const _CurrencySheet({this.selected});

  final String? selected;

  @override
  State<_CurrencySheet> createState() => _CurrencySheetState();
}

class _CurrencySheetState extends State<_CurrencySheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final query = _query.toLowerCase();
    final matches = supportedCurrencies
        .where(
          (spec) =>
              query.isEmpty ||
              spec.code.toLowerCase().contains(query) ||
              spec.name.toLowerCase().contains(query) ||
              spec.symbol.toLowerCase().contains(query),
        )
        .toList();
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  autofocus: false,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    labelText: tr('Cari mata uang'),
                  ),
                  onChanged: (value) => setState(() => _query = value.trim()),
                ),
              ),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: matches.length,
                  itemBuilder: (context, index) {
                    final spec = matches[index];
                    final selected = spec.code == widget.selected;
                    return ListTile(
                      leading: SizedBox(
                        width: 48,
                        child: Text(
                          spec.symbol,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      title: Text('${spec.code} · ${spec.name}'),
                      trailing: selected ? const Icon(Icons.check) : null,
                      selected: selected,
                      onTap: () => Navigator.pop(context, spec.code),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
