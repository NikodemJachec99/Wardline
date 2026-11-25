import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/state/providers.dart';
import '../../../core/theme/wl_tokens.dart';
import '../../../core/widgets/wl/wl.dart';
import '../../../data/demo/demo_seed.dart';
import '../../../domain/models.dart';
import 'wardline_logo.dart';

enum _LoginError { none, wrongCredentials, noConnection }

/// `/login` (Login artboard): default · signing in · wrong credentials ·
/// no connection. The router sends a signed-in user to the dashboard.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _email = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final FocusNode _passwordFocus = FocusNode();
  bool _obscure = true;
  bool _busy = false;
  _LoginError _error = _LoginError.none;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_busy) return; // one request per intent
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = _LoginError.none;
    });
    try {
      final ok = await ref
          .read(sessionProvider.notifier)
          .signIn(_email.text, _password.text);
      if (ok) {
        TextInput.finishAutofillContext();
        // The router redirect takes over from here.
        if (mounted) setState(() => _busy = false);
        return;
      }
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _LoginError.wrongCredentials;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = _LoginError.noConnection;
      });
    }
  }

  void _fillDemo(StaffMember member) {
    if (_busy) return;
    setState(() {
      _email.text = member.email ?? '';
      _password.text = DemoSeed.demoPassword;
      _error = _LoginError.none;
    });
  }

  void _clearError() {
    if (_error != _LoginError.none) setState(() => _error = _LoginError.none);
  }

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final staff = ref.watch(hospitalProvider.select((s) => s.staff));
    final demo = [
      for (final role in UserRole.values)
        ?staff.where((s) => s.role == role && s.email != null).firstOrNull,
    ];
    final wrong = _error == _LoginError.wrongCredentials;

    return Scaffold(
      backgroundColor: c.page,
      body: SafeArea(
        child: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 440),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: t.space.lg),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(height: t.space.xxl + t.space.sm),
                        const Center(child: WardlineLogo()),
                        SizedBox(height: t.space.sm + 2),
                        Semantics(
                          header: true,
                          child: Text(
                            'Wardline',
                            textAlign: TextAlign.center,
                            style: t.typography.title1.copyWith(
                              color: c.text,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Text(
                          'Hospital patient tracking',
                          textAlign: TextAlign.center,
                          style: t.typography.subhead.copyWith(
                            color: c.textSecondary,
                          ),
                        ),
                        SizedBox(height: t.space.xxl - t.space.xxs),
                        AutofillGroup(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _Field(
                                label: 'Work email',
                                controller: _email,
                                enabled: !_busy,
                                hint: 'name@wardline.test',
                                keyboardType: TextInputType.emailAddress,
                                autofillHints: const [
                                  AutofillHints.username,
                                  AutofillHints.email,
                                ],
                                textInputAction: TextInputAction.next,
                                onChanged: (_) => _clearError(),
                                onSubmitted: (_) =>
                                    _passwordFocus.requestFocus(),
                              ),
                              SizedBox(height: t.space.md),
                              _Field(
                                label: 'Password',
                                controller: _password,
                                focusNode: _passwordFocus,
                                enabled: !_busy,
                                hint: 'Enter your password',
                                obscure: _obscure,
                                error: wrong,
                                autofillHints: const [AutofillHints.password],
                                textInputAction: TextInputAction.done,
                                onChanged: (_) => _clearError(),
                                onSubmitted: (_) => _signIn(),
                                suffix: IconButton(
                                  tooltip: _obscure
                                      ? 'Show password'
                                      : 'Hide password',
                                  onPressed: () =>
                                      setState(() => _obscure = !_obscure),
                                  icon: Icon(
                                    _obscure ? WlIcons.eye : LucideIcons.eyeOff,
                                    size: 20,
                                    color: c.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (wrong) ...[
                          SizedBox(height: t.space.xs - 2),
                          const _InlineError('Email or password is incorrect.'),
                        ],
                        if (_error == _LoginError.noConnection) ...[
                          SizedBox(height: t.space.md),
                          const _NoConnection(),
                        ],
                        SizedBox(height: t.space.lg),
                        WlButton(
                          label: 'Sign in',
                          loading: _busy,
                          loadingLabel: 'Signing in…',
                          onPressed: _signIn,
                        ),
                        SizedBox(height: t.space.md),
                        Text(
                          'Forgot your password? Ask your ward admin.',
                          textAlign: TextAlign.center,
                          style: t.typography.caption.copyWith(
                            color: c.textSecondary,
                            fontWeight: FontWeight.w400,
                            fontSize: 13,
                          ),
                        ),
                        if (demo.isNotEmpty) ...[
                          SizedBox(height: t.space.lg),
                          _DemoAccounts(
                            accounts: demo,
                            current: _email.text.trim().toLowerCase(),
                            onPick: _fillDemo,
                          ),
                        ],
                        const Spacer(),
                        SizedBox(height: t.space.lg),
                        const Center(child: _SimulationNote()),
                        SizedBox(height: t.space.md),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Label above a 52dp field (`.fl` / `.in` on the artboard).
class _Field extends StatefulWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.enabled,
    required this.hint,
    required this.autofillHints,
    required this.textInputAction,
    this.focusNode,
    this.keyboardType,
    this.obscure = false,
    this.error = false,
    this.suffix,
    this.onChanged,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool enabled;
  final String hint;
  final List<String> autofillHints;
  final TextInputAction textInputAction;
  final TextInputType? keyboardType;
  final bool obscure;
  final bool error;
  final Widget? suffix;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  @override
  State<_Field> createState() => _FieldState();
}

class _FieldState extends State<_Field> {
  FocusNode? _own;
  FocusNode get _focus => widget.focusNode ?? (_own ??= FocusNode());
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(_onFocus);
  }

  void _onFocus() => setState(() => _focused = _focus.hasFocus);

  @override
  void dispose() {
    _focus.removeListener(_onFocus);
    _own?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    final borderColor = widget.error
        ? c.danger
        : _focused
        ? c.primary
        : c.borderStrong;
    final ring = widget.error
        ? c.dangerBg
        : _focused
        ? c.primarySoft
        : null;
    final border = OutlineInputBorder(
      borderRadius: t.radius.inputBr,
      borderSide: BorderSide(color: borderColor),
    );
    return Opacity(
      opacity: widget.enabled ? 1 : 0.6,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.label,
            style: t.typography.subhead.copyWith(
              color: c.text,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: t.space.xs - 2),
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: t.radius.inputBr,
              boxShadow: ring == null
                  ? null
                  : [BoxShadow(color: ring, spreadRadius: 3)],
            ),
            child: TextField(
              controller: widget.controller,
              focusNode: _focus,
              enabled: widget.enabled,
              obscureText: widget.obscure,
              autocorrect: false,
              enableSuggestions: !widget.obscure,
              keyboardType: widget.keyboardType,
              textInputAction: widget.textInputAction,
              autofillHints: widget.autofillHints,
              onChanged: widget.onChanged,
              onSubmitted: widget.onSubmitted,
              style: t.typography.body.copyWith(color: c.text),
              cursorColor: c.primaryInk,
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: t.typography.body.copyWith(color: c.textDisabled),
                filled: true,
                fillColor: widget.enabled ? c.surface : c.subtle,
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: t.space.sm + 2,
                  vertical: t.space.sm + 2,
                ),
                suffixIcon: widget.suffix,
                border: border,
                enabledBorder: border,
                disabledBorder: border,
                focusedBorder: border,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    return Semantics(
      liveRegion: true,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(WlIcons.error, size: 16, color: c.danger),
          ),
          SizedBox(width: t.space.xs - 2),
          Expanded(
            child: Text(
              text,
              style: t.typography.subhead.copyWith(
                color: c.danger,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// No connection while signing in (screens.md "no connection" state).
class _NoConnection extends StatelessWidget {
  const _NoConnection();

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        padding: EdgeInsets.all(t.space.sm),
        decoration: BoxDecoration(
          color: c.warningBg,
          borderRadius: t.radius.inputBr,
          border: Border.all(color: c.warningBorder),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(WlIcons.wifiOff, size: 20, color: c.warningFg),
            SizedBox(width: t.space.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "You're offline",
                    style: t.typography.callout.copyWith(
                      color: c.warningFg,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    'Signing in needs a connection. Try again when '
                    "you're back online.",
                    style: t.typography.subhead.copyWith(color: c.warningFg),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Simulation only: one tap fills a fictional demo account.
class _DemoAccounts extends StatelessWidget {
  const _DemoAccounts({
    required this.accounts,
    required this.current,
    required this.onPick,
  });

  final List<StaffMember> accounts;
  final String current;
  final ValueChanged<StaffMember> onPick;

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Demo accounts',
          style: t.typography.overline.copyWith(color: c.textSecondary),
        ),
        WlFilterChips(
          padding: EdgeInsets.zero,
          chips: [
            for (final a in accounts)
              WlFilterChipData(
                label: a.roleLabel,
                selected: a.email == current,
                onTap: () => onPick(a),
              ),
          ],
        ),
        Text(
          'Fills in a fictional account. Password: ${DemoSeed.demoPassword}',
          style: t.typography.caption.copyWith(
            color: c.textSecondary,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

class _SimulationNote extends StatelessWidget {
  const _SimulationNote();

  @override
  Widget build(BuildContext context) {
    final t = WlTokens.of(context);
    final c = t.colors;
    return Container(
      constraints: const BoxConstraints(minHeight: 28),
      padding: EdgeInsets.symmetric(horizontal: t.space.sm - 2, vertical: 4),
      decoration: BoxDecoration(
        color: c.subtle,
        borderRadius: BorderRadius.circular(t.radius.full),
        border: Border.all(color: c.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(WlIcons.info, size: 14, color: c.textSecondary),
          SizedBox(width: t.space.xxs + 2),
          Flexible(
            child: Text(
              'Simulation · fictional data',
              style: t.typography.caption.copyWith(
                color: c.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
