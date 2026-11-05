import 'package:flutter/material.dart';

import 'app_settings.dart';
import 'l10n/l10n.dart';
import 'money.dart';
import 'settings_page.dart' show pickCurrency;

/// First-run welcome: pick a language and currency, then three short cards
/// that explain the promise (every coin traceable) in plain words.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({
    required this.settings,
    required this.onDone,
    super.key,
  });

  final AppSettings settings;
  final VoidCallback onDone;

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _pages = PageController();
  int _index = 0;

  static const _pageCount = 4;

  @override
  void dispose() {
    _pages.dispose();
    super.dispose();
  }

  Future<void> _finish() async {
    await widget.settings.completeOnboarding();
    widget.onDone();
  }

  void _next() {
    if (_index == _pageCount - 1) {
      _finish();
      return;
    }
    _pages.nextPage(
      duration: widget.settings.reduceMotion
          ? const Duration(milliseconds: 1)
          : const Duration(milliseconds: 280),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: widget.settings,
      builder: (context, _) => Scaffold(
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                children: [
                  Align(
                    alignment: AlignmentDirectional.centerEnd,
                    child: TextButton(
                      onPressed: _finish,
                      child: Text(tr('Lewati')),
                    ),
                  ),
                  Expanded(
                    child: PageView(
                      controller: _pages,
                      onPageChanged: (index) => setState(() => _index = index),
                      children: [
                        _WelcomeSetup(settings: widget.settings),
                        _InfoCard(
                          icon: Icons.groups_2_outlined,
                          title: tr('Satu buku kas untuk seluruh rombongan'),
                          body: tr(
                            'Catat iuran, sponsor, dan pengeluaran di satu tempat. Target per orang dihitung otomatis dari peserta yang aktif.',
                          ),
                        ),
                        _InfoCard(
                          icon: Icons.receipt_long_outlined,
                          title: tr('Setiap rupiah bisa ditelusuri'),
                          body: tr(
                            'Tidak ada yang dihapus. Kesalahan dikoreksi dengan alasan, dan foto nota bisa dilampirkan pada pengeluaran.',
                          ),
                        ),
                        _InfoCard(
                          icon: Icons.share_outlined,
                          title: tr('Terbuka untuk semua peserta'),
                          body: tr(
                            'Bagikan laporan PDF, teks WhatsApp, atau tautan baca-saja agar peserta bisa memeriksa sendiri tanpa perlu akun.',
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        for (var i = 0; i < _pageCount; i++)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            width: i == _index ? 24 : 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: i == _index
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.outlineVariant,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                    child: SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        key: const Key('onboarding-next'),
                        onPressed: _next,
                        child: Text(
                          _index == _pageCount - 1 ? tr('Mulai') : tr('Lanjut'),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WelcomeSetup extends StatelessWidget {
  const _WelcomeSetup({required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      children: [
        Icon(
          Icons.account_balance_wallet_outlined,
          size: 72,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          tr('Selamat datang di Wargakas'),
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        Text(
          tr(
            'Buku kas bersama untuk acara komunitas: jujur, rapi, dan mudah dibagikan.',
          ),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),
        Text(tr('Bahasa'), style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          key: const Key('onboarding-language'),
          initialValue: settings.languageCode ?? '',
          isExpanded: true,
          items: [
            DropdownMenuItem(
              value: '',
              child: Text(
                tr('Ikuti bahasa ponsel ({language})', {
                  'language': L10n.languageFor(L10n.code).nativeName,
                }),
              ),
            ),
            for (final language in L10n.languages)
              DropdownMenuItem(
                value: language.code,
                child: Text(language.nativeName),
              ),
          ],
          onChanged: (value) => settings.setLanguage(
            value == null || value.isEmpty ? null : value,
          ),
        ),
        const SizedBox(height: 16),
        Text(tr('Mata uang'), style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const Key('onboarding-currency'),
          onPressed: () async {
            final code = await pickCurrency(
              context,
              selected: settings.defaultCurrency,
            );
            if (code != null) await settings.setDefaultCurrency(code);
          },
          icon: const Icon(Icons.payments_outlined),
          label: Text(
            '${settings.defaultCurrency} · ${currencySpec(settings.defaultCurrency).name}',
          ),
        ),
        const SizedBox(height: 16),
        Text(tr('Ukuran teks'), style: theme.textTheme.titleMedium),
        Slider(
          value: textScaleOptions
              .indexOf(settings.textScale)
              .toDouble()
              .clamp(0, textScaleOptions.length - 1),
          min: 0,
          max: (textScaleOptions.length - 1).toDouble(),
          divisions: textScaleOptions.length - 1,
          label: '${(settings.textScale * 100).round()}%',
          onChanged: (value) =>
              settings.setTextScale(textScaleOptions[value.round()]),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      children: [
        Container(
          height: 160,
          decoration: BoxDecoration(
            color: theme.colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Icon(
            icon,
            size: 88,
            color: theme.colorScheme.onPrimaryContainer,
          ),
        ),
        const SizedBox(height: 32),
        Semantics(
          header: true,
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          body,
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge,
        ),
      ],
    );
  }
}
