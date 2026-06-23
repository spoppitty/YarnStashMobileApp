import 'dart:async';
import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'app_style.dart';
import 'components.dart';
import 'data/firestore_paths.dart';
import 'data/models/app_user.dart';
import 'data/models/ravelry_yarn.dart';
import 'data/models/stash_folder.dart';
import 'data/models/yarn.dart';
import 'data/repositories/ravelry_yarn_catalog_repository.dart';
import 'data/repositories/stash_folder_repository.dart';
import 'data/repositories/user_repository.dart';
import 'data/repositories/yarn_repository.dart';
import 'data/services/auth_service.dart';

import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'data/services/yarn_image_storage_service.dart';

const _imgMerino = 'https://source.unsplash.com/420x420/?merino,yarn,skein';
const _maxYarnImageCount = 8;

const _allStashFilter = 'All';
const _colorFamilyOptions = [
  'White',
  'Red',
  'Orange',
  'Yellow',
  'Green',
  'Blue',
  'Purple',
  'Pink',
  'Brown',
  'Black',
  'Grey',
  'Multicolor',
];

enum _StashSort { recentlyAdded, price, amountOwned }

enum _StashSortDirection { ascending, descending }

String _stashSortLabel(_StashSort sort) => switch (sort) {
  _StashSort.recentlyAdded => 'Recently added',
  _StashSort.price => 'Price',
  _StashSort.amountOwned => 'Amount owned',
};

String _stashSortDirectionMenuLabel(
  _StashSort sort,
  _StashSortDirection direction,
) =>
    '${_stashSortLabel(sort)}(${switch (direction) {
      _StashSortDirection.ascending => 'Asc.',
      _StashSortDirection.descending => 'Desc.',
    }})';

FaIconData _stashSortDirectionIcon(_StashSortDirection direction) =>
    switch (direction) {
      _StashSortDirection.ascending => FontAwesomeIcons.arrowUp,
      _StashSortDirection.descending => FontAwesomeIcons.arrowDown,
    };

class InfoItem {
  const InfoItem(this.label, this.value);

  final String label;
  final String value;
}

class _StashYarnItem {
  const _StashYarnItem({
    required this.yarn,
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    required this.fallbackColor,
    required this.filters,
    required this.recentlyAddedRank,
    required this.priceCents,
    required this.amountOwned,
  });

  final Yarn yarn;
  final String imageUrl;
  final String title;
  final String subtitle;
  final Color fallbackColor;
  final Set<String> filters;
  final int recentlyAddedRank;
  final int priceCents;
  final int amountOwned;
}

class _StashFilterOptions {
  const _StashFilterOptions({
    required this.weights,
    required this.fibers,
    required this.colors,
    required this.statuses,
  });

  final List<String> weights;
  final List<String> fibers;
  final List<String> colors;
  final List<String> statuses;

  Set<String> get availableFilters {
    return {...weights, ...fibers, ...colors, ...statuses};
  }

  List<String> get orderedFilters {
    return [...weights, ...fibers, ...colors, ...statuses];
  }
}

_StashYarnItem _stashItemFromYarn(Yarn yarn) {
  final colorway = yarn.colorway?.trim();
  final skeins = yarn.skeinCount == 1 ? '1 skein' : '${yarn.skeinCount} skeins';
  final fiberFilters = _fiberTagsForYarn(yarn);
  final weight = _normalizeWeightName(yarn.weightCategory);
  final colorFamily = _cleanText(yarn.colorFamily);
  final subtitleParts = [
    if (colorway != null && colorway.isNotEmpty) colorway,
    skeins,
  ];
  final filters = <String>{
    ?weight,
    ...fiberFilters,
    ?colorFamily,
    switch (yarn.status) {
      YarnStatus.inStash => 'In stash',
      YarnStatus.usedUp => 'Used up',
      YarnStatus.inProject => 'In project',
      YarnStatus.destashed => 'Destashed',
    },
  };

  return _StashYarnItem(
    yarn: yarn,
    imageUrl: yarn.imageUrls.isEmpty ? '' : yarn.imageUrls.first,
    title: yarn.name.trim().isEmpty ? yarn.brandName : yarn.name,
    subtitle: subtitleParts.isEmpty
        ? yarn.brandName
        : subtitleParts.join(' - '),
    fallbackColor: _fallbackColorForYarn(yarn),
    filters: filters,
    recentlyAddedRank: yarn.createdAt.millisecondsSinceEpoch,
    priceCents: yarn.priceCents ?? 0,
    amountOwned: yarn.skeinCount,
  );
}

Set<String> _fiberTagsForYarn(Yarn yarn) {
  if (yarn.fiberContents.isNotEmpty) {
    return {
      for (final fiberContent in yarn.fiberContents)
        if (_normalizeFiberName(fiberContent.fiber) != null)
          _normalizeFiberName(fiberContent.fiber)!,
    };
  }

  final legacy = _cleanText(yarn.fiberContent);
  if (legacy == null) return const {};

  final parsedTags = <String>{};
  for (final part in legacy.split(',')) {
    final match = RegExp(r'^\s*(\d+)\s*%\s*(.+?)\s*$').firstMatch(part);
    if (match == null) continue;

    final label = _normalizeFiberName(match.group(2));
    if (label != null) {
      parsedTags.add(label);
    }
  }

  return parsedTags.isEmpty ? {_normalizeFiberName(legacy) ?? legacy} : parsedTags;
}

_StashFilterOptions _filterOptionsForYarns(List<Yarn> yarns) {
  return _StashFilterOptions(
    weights: _sortedBreakdownLabels(_weightBreakdown(yarns)),
    fibers: _sortedBreakdownLabels(_fiberBreakdown(yarns)),
    colors: _sortedFilterLabels({
      for (final yarn in yarns)
        if (_cleanText(yarn.colorFamily) != null) _cleanText(yarn.colorFamily)!,
    }),
    statuses: _sortedBreakdownLabels(_statusBreakdown(yarns)),
  );
}

List<String> _sortedBreakdownLabels(Map<String, double> breakdown) {
  final entries =
      breakdown.entries.where((entry) => entry.key != ' ').toList()
        ..sort((a, b) {
          final valueComparison = b.value.compareTo(a.value);
          if (valueComparison != 0) return valueComparison;
          return a.key.toLowerCase().compareTo(b.key.toLowerCase());
        });

  return entries.map((entry) => entry.key).toList(growable: false);
}

List<String> _sortedFilterLabels(Set<String> labels) {
  final sorted = labels.toList()
    ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
  return sorted;
}

Color _fallbackColorForYarn(Yarn yarn) {
  return switch (yarn.colorFamily?.toLowerCase()) {
    'green' => AppColors.sageSoft,
    'pink' || 'red' => AppColors.rose,
    'yellow' || 'orange' || 'brown' => AppColors.goldSoft,
    'purple' => AppColors.lavenderSoft,
    'white' => AppColors.cream,
    _ => const Color(0xFFB8D6E8),
  };
}

FaIconData _folderIconForKey(String iconKey) {
  return switch (iconKey) {
    'shirt' => FontAwesomeIcons.shirt,
    'socks' => FontAwesomeIcons.socks,
    'sun' => FontAwesomeIcons.sun,
    'boxArchive' => FontAwesomeIcons.boxArchive,
    'circleCheck' => FontAwesomeIcons.circleCheck,
    _ => FontAwesomeIcons.folder,
  };
}

Color _folderBackgroundColor(StashFolder folder) {
  return Color(folder.colorValue);
}

Color _folderForegroundColor(Color background) {
  return background.computeLuminance() > 0.55 ? AppColors.ink : Colors.white;
}

List<Yarn> _yarnsForFolder(StashFolder folder, List<Yarn> yarns) {
  final folderYarnIds = folder.yarnIds.toSet();
  return yarns
      .where((yarn) {
        if (folderYarnIds.contains(yarn.id) ||
            yarn.folderIds.contains(folder.id)) {
          return true;
        }

        if (folder.isDefaultUsedUp && yarn.status == YarnStatus.usedUp) {
          return true;
        }

        final folderName = _cleanText(yarn.folderName);
        return folderName != null && folderName == folder.name;
      })
      .toList(growable: false);
}

int _totalYardageForYarns(List<Yarn> yarns) {
  return yarns.fold(0, (total, yarn) {
    final yardage = yarn.yardage;
    return total + (yardage == null ? 0 : yardage * yarn.skeinCount);
  });
}

String _folderSubtitle(StashFolder folder, List<Yarn> yarns) {
  final count = yarns.length;
  final countLabel = count == 1 ? '1 yarn' : '$count yarns';
  final yards = _totalYardageForYarns(yarns);

  if (yards > 0) {
    return '$countLabel - $yards yd';
  }

  return folder.isSystem ? '$countLabel - locked' : countLabel;
}

String _folderYarnSubtitle(Yarn yarn) {
  final colorway = _cleanText(yarn.colorway);
  final brandName = _cleanText(yarn.brandName);
  final skeins = yarn.skeinCount == 1 ? '1 skein' : '${yarn.skeinCount} skeins';
  return [?colorway, ?brandName, skeins].join(' - ');
}

String _folderYarnDetail(Yarn yarn) {
  final yardage = yarn.yardage;
  if (yardage == null) return _statusLabel(yarn.status);
  return '${yardage * yarn.skeinCount} m total';
}

String? _requiredAuthValue(String? value, String label) {
  if (value == null || value.trim().isEmpty) {
    return '$label is required';
  }
  return null;
}

String? _emailValidator(String? value) {
  final requiredMessage = _requiredAuthValue(value, 'Email');
  if (requiredMessage != null) return requiredMessage;

  final email = value!.trim();
  if (!email.contains('@') || !email.contains('.')) {
    return 'Enter a valid email';
  }
  return null;
}

String? _passwordValidator(String? value) {
  final requiredMessage = _requiredAuthValue(value, 'Password');
  if (requiredMessage != null) return requiredMessage;

  if (value!.length < 6) {
    return 'Password must be at least 6 characters';
  }
  return null;
}

String _authErrorMessage(FirebaseAuthException error) {
  return switch (error.code) {
    'email-already-in-use' => 'That email is already connected to an account.',
    'invalid-credential' ||
    'user-not-found' ||
    'wrong-password' => 'The email or password is incorrect.',
    'invalid-email' => 'Enter a valid email address.',
    'network-request-failed' => 'Check your connection and try again.',
    'operation-not-allowed' =>
      'Email/password sign-in is not enabled for this Firebase project.',
    'requires-recent-login' =>
      'Log out and log back in before changing this profile.',
    'too-many-requests' => 'Too many attempts. Try again later.',
    'user-disabled' => 'This account has been disabled.',
    'weak-password' => 'Use a stronger password with at least 6 characters.',
    _ => error.message ?? 'Something went wrong. Try again.',
  };
}

class _AuthMessage extends StatelessWidget {
  const _AuthMessage({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? AppColors.danger : AppColors.accentDark;
    final background = isError ? const Color(0xFFFFF1F1) : AppColors.sageSoft;
    final icon = isError
        ? FontAwesomeIcons.triangleExclamation
        : FontAwesomeIcons.circleCheck;

    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FaIcon(icon, size: 15, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: color,
                fontSize: 14,
                height: 1.3,
                fontWeight: FontWeight.w800,
                letterSpacing: tightLetterSpacing,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.authService,
    required this.onLogin,
    required this.onSignUp,
    required this.onForgotPassword,
  });

  final AuthService authService;
  final VoidCallback onLogin;
  final VoidCallback onSignUp;
  final VoidCallback onForgotPassword;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  bool _isSubmitting = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await widget.authService.signInWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
      );
      await widget.authService.ensureSignedInUserProfile();
      if (!mounted) return;
      widget.onLogin();
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = _authErrorMessage(error));
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Unable to log in. Try again.');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          const SizedBox(height: 14),
          const _AuthBrand(title: 'Welcome back'),
          const SizedBox(height: 64),
          const Center(
            child: FaIcon(
              FontAwesomeIcons.basketShopping,
              color: AppColors.accentDark,
              size: 60,
            ),
          ),
          const SizedBox(height: 32),
          AuthField(
            label: 'Email',
            controller: _emailController,
            hintText: 'you@example.com',
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            validator: _emailValidator,
            enabled: !_isSubmitting,
          ),
          const SizedBox(height: 12),
          AuthField(
            label: 'Password',
            controller: _passwordController,
            hintText: 'Password',
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
            validator: _passwordValidator,
            enabled: !_isSubmitting,
            suffixIcon: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _isSubmitting
                  ? null
                  : () => setState(() => _obscurePassword = !_obscurePassword),
              child: SizedBox(
                width: 24,
                height: 24,
                child: Center(
                  child: FaIcon(
                    _obscurePassword
                        ? FontAwesomeIcons.eye
                        : FontAwesomeIcons.eyeSlash,
                    size: 14,
                    color: AppColors.muted,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.center,
            child: LinkText(
              text: 'Forgot Password?',
              onTap: _isSubmitting ? null : widget.onForgotPassword,
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            _AuthMessage(message: _errorMessage!, isError: true),
          ],
          const SizedBox(height: 16),
          PrimaryButton(
            label: _isSubmitting ? 'Logging in...' : 'Log in',
            icon: FontAwesomeIcons.arrowRightToBracket,
            onTap: _isSubmitting ? null : _submit,
          ),
          const SizedBox(height: 24),
          const _AuthDivider(),
          const SizedBox(height: 20),
          const SecondaryButton(
            label: 'Continue with Google',
            icon: FontAwesomeIcons.google,
          ),
          const SizedBox(height: 24),
          _AuthSwitchLine(
            prefix: 'New to Yarn Stash?',
            action: 'Create account',
            onTap: _isSubmitting ? null : widget.onSignUp,
          ),
        ],
      ),
    );
  }
}

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({
    super.key,
    required this.authService,
    required this.onBack,
    required this.onCreateAccount,
    required this.onLogin,
  });

  final AuthService authService;
  final VoidCallback onBack;
  final VoidCallback onCreateAccount;
  final VoidCallback onLogin;

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _usernameController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  bool _isSubmitting = false;
  bool _obscurePassword = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController();
    _emailController = TextEditingController();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await widget.authService.createUserWithEmailAndPassword(
        email: _emailController.text,
        password: _passwordController.text,
        displayName: _usernameController.text,
      );
      if (!mounted) return;
      widget.onCreateAccount();
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = _authErrorMessage(error));
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Unable to create account. Try again.');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          NavRow(
            leading: CircleIconButton(
              icon: FontAwesomeIcons.chevronLeft,
              onTap: _isSubmitting ? null : widget.onBack,
            ),
          ),
          const SizedBox(height: 14),
          const _AuthBrand(title: 'Create account'),
          const SizedBox(height: 18),
          AuthField(
            label: 'Username',
            controller: _usernameController,
            hintText: 'Your name',
            textInputAction: TextInputAction.next,
            validator: (value) => _requiredAuthValue(value, 'Username'),
            enabled: !_isSubmitting,
          ),
          const SizedBox(height: 12),
          AuthField(
            label: 'Email',
            controller: _emailController,
            hintText: 'you@example.com',
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            validator: _emailValidator,
            enabled: !_isSubmitting,
          ),
          const SizedBox(height: 12),
          AuthField(
            label: 'Password',
            controller: _passwordController,
            hintText: 'Create a password',
            obscureText: _obscurePassword,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
            validator: _passwordValidator,
            enabled: !_isSubmitting,
            suffixIcon: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _isSubmitting
                  ? null
                  : () => setState(() => _obscurePassword = !_obscurePassword),
              child: SizedBox(
                width: 24,
                height: 24,
                child: Center(
                  child: FaIcon(
                    _obscurePassword
                        ? FontAwesomeIcons.eye
                        : FontAwesomeIcons.eyeSlash,
                    size: 14,
                    color: AppColors.muted,
                  ),
                ),
              ),
            ),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            _AuthMessage(message: _errorMessage!, isError: true),
          ],
          const SizedBox(height: 20),
          PrimaryButton(
            label: _isSubmitting ? 'Creating...' : 'Create account',
            icon: FontAwesomeIcons.userPlus,
            onTap: _isSubmitting ? null : _submit,
          ),
          const SizedBox(height: 24),
          const _AuthDivider(),
          const SizedBox(height: 20),
          const SecondaryButton(
            label: 'Sign up with Google',
            icon: FontAwesomeIcons.google,
          ),
          const SizedBox(height: 24),
          _AuthSwitchLine(
            prefix: 'Already have an account?',
            action: 'Log in',
            onTap: _isSubmitting ? null : widget.onLogin,
          ),
        ],
      ),
    );
  }
}

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({
    super.key,
    required this.authService,
    required this.onBack,
    required this.onSend,
  });

  final AuthService authService;
  final VoidCallback onBack;
  final VoidCallback onSend;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await widget.authService.sendPasswordResetEmail(_emailController.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset email sent.')),
      );
      widget.onSend();
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = _authErrorMessage(error));
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Unable to send reset email. Try again.');
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 28),
        children: [
          NavRow(
            leading: CircleIconButton(
              icon: FontAwesomeIcons.chevronLeft,
              onTap: _isSubmitting ? null : widget.onBack,
            ),
          ),
          const SizedBox(height: 14),
          const _AuthBrand(
            title: 'Reset password',
            icon: FontAwesomeIcons.lockOpen,
          ),
          const SizedBox(height: 18),
          const Text(
            'Yarn Stash will send a secure reset link to the email on your account.',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 16,
              height: 1.45,
              fontWeight: FontWeight.w700,
              letterSpacing: tightLetterSpacing,
            ),
          ),
          const SizedBox(height: 18),
          AuthField(
            label: 'Email',
            controller: _emailController,
            hintText: 'you@example.com',
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
            validator: _emailValidator,
            enabled: !_isSubmitting,
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            _AuthMessage(message: _errorMessage!, isError: true),
          ],
          const SizedBox(height: 20),
          PrimaryButton(
            label: _isSubmitting ? 'Sending...' : 'Send reset link',
            icon: FontAwesomeIcons.paperPlane,
            onTap: _isSubmitting ? null : _submit,
          ),
          const SizedBox(height: 20),
          const CardSurface(
            padding: EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconBadge(
                  icon: FontAwesomeIcons.envelope,
                  background: AppColors.sageSoft,
                  foreground: Color(0xFF587456),
                  size: 40,
                  iconSize: 16,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Check your inbox',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          letterSpacing: tightLetterSpacing,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Reset links expire after 30 minutes for account security.',
                        style: TextStyle(
                          color: AppColors.muted,
                          fontSize: 14,
                          height: 1.35,
                          fontWeight: FontWeight.w800,
                          letterSpacing: tightLetterSpacing,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _AuthSwitchLine(
            prefix: 'Remembered it?',
            action: 'Back to login',
            onTap: _isSubmitting ? null : widget.onBack,
          ),
        ],
      ),
    );
  }
}

class CollectionScreen extends StatefulWidget {
  const CollectionScreen({
    super.key,
    required this.userId,
    required this.onYarnTap,
    required this.onAddYarn,
    this.yarnRepository,
  });

  final String userId;
  final ValueChanged<Yarn> onYarnTap;
  final VoidCallback onAddYarn;
  final YarnRepository? yarnRepository;

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  late final YarnRepository _yarnRepository;
  late final TextEditingController _searchController;

  Set<String> _activeFilters = const {_allStashFilter};
  _StashSort _activeSort = _StashSort.recentlyAdded;
  _StashSortDirection _sortDirection = _StashSortDirection.descending;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _yarnRepository = widget.yarnRepository ?? YarnRepository();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesSearch(_StashYarnItem item) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return true;

    final yarn = item.yarn;
    final searchableText = [
      item.title,
      item.subtitle,
      yarn.name,
      yarn.brandName,
      yarn.colorway,
      yarn.colorFamily,
      yarn.weightCategory,
      yarn.dyeLot,
      yarn.notes,
      yarn.fiberContent,
      ...yarn.fiberContents.map((fiber) => fiber.fiber),
    ].whereType<String>().join(' ').toLowerCase();

    return searchableText.contains(query);
  }

  bool get _hasActiveFilters => !_activeFilters.contains(_allStashFilter);

  Set<String> _validActiveFilters(_StashFilterOptions options) {
    if (!_hasActiveFilters) {
      return const {_allStashFilter};
    }

    final availableFilters = options.availableFilters;
    final validFilters = _activeFilters
        .where(availableFilters.contains)
        .toSet();

    return validFilters.isEmpty ? const {_allStashFilter} : validFilters;
  }

  bool _hasActiveFiltersForOptions(_StashFilterOptions options) {
    return !_validActiveFilters(options).contains(_allStashFilter);
  }

  List<String> _filterChips(_StashFilterOptions options) {
    final activeFilters = _validActiveFilters(options);
    if (activeFilters.contains(_allStashFilter)) {
      return const [];
    }
    return options.orderedFilters
        .where((filter) => activeFilters.contains(filter))
        .toList(growable: false);
  }

  List<_StashYarnItem> _filteredItems(
    List<Yarn> yarns,
    _StashFilterOptions options,
  ) {
    final stashItems = yarns.map(_stashItemFromYarn).toList(growable: false);
    final activeFilters = _validActiveFilters(options);
    final filteredByChips = activeFilters.contains(_allStashFilter)
        ? List<_StashYarnItem>.of(stashItems)
        : stashItems
        .where(
          (item) => _matchesActiveFilters(item, options, activeFilters),
    )
        .toList(growable: false);

    final searchedItems = filteredByChips
        .where(_matchesSearch)
        .toList(growable: false);

    return _sortItems(searchedItems);
  }

  bool _matchesActiveFilters(
    _StashYarnItem item,
    _StashFilterOptions options,
    Set<String> activeFilters,
  ) {
    return _matchesFilterGroup(item, options.weights, activeFilters) &&
        _matchesFilterGroup(item, options.fibers, activeFilters) &&
        _matchesFilterGroup(item, options.colors, activeFilters) &&
        _matchesFilterGroup(item, options.statuses, activeFilters);
  }

  bool _matchesFilterGroup(
    _StashYarnItem item,
    List<String> filters,
    Set<String> activeFilters,
  ) {
    final selectedFilters = filters.where(activeFilters.contains);
    if (selectedFilters.isEmpty) {
      return true;
    }
    return selectedFilters.any((filter) => item.filters.contains(filter));
  }

  List<_StashYarnItem> _sortItems(List<_StashYarnItem> items) {
    return items..sort((a, b) {
      final comparison = switch (_activeSort) {
        _StashSort.recentlyAdded => a.recentlyAddedRank.compareTo(
          b.recentlyAddedRank,
        ),
        _StashSort.price => a.priceCents.compareTo(b.priceCents),
        _StashSort.amountOwned => a.amountOwned.compareTo(b.amountOwned),
      };
      return _sortDirection == _StashSortDirection.ascending
          ? comparison
          : -comparison;
    });
  }

  Future<void> _openFilters(_StashFilterOptions options) async {
    final updatedFilters = await showDialog<Set<String>>(
      context: context,
      barrierColor: AppColors.ink.withValues(alpha: 0.35),
      builder: (context) => _StashFilterDialog(
        initialFilters: Set<String>.of(_validActiveFilters(options)),
        options: options,
      ),
    );

    if (updatedFilters != null) {
      setState(() => _activeFilters = updatedFilters);
    }
  }

  void _resetFilters() {
    setState(() => _activeFilters = const {_allStashFilter});
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<Yarn>>(
      stream: _yarnRepository.watchYarns(uid: widget.userId),
      builder: (context, snapshot) {
        final yarns = snapshot.data ?? const <Yarn>[];
        final filterOptions = _filterOptionsForYarns(yarns);
        final hasActiveFilters = _hasActiveFiltersForOptions(filterOptions);
        final isLoading =
            snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData;

        return ListView(
          padding: const EdgeInsets.only(bottom: 18),
          children: [
            NavRow(
              title: 'Stash',
              trailing: CircleIconButton(
                icon: FontAwesomeIcons.sliders,
                label: 'Filter stash',
                backgroundColor: hasActiveFilters
                    ? AppColors.accent
                    : AppColors.card,
                foregroundColor: hasActiveFilters
                    ? Colors.white
                    : AppColors.ink,
                borderColor: hasActiveFilters
                    ? AppColors.accent
                    : AppColors.line,
                onTap: yarns.isEmpty ? null : () => _openFilters(filterOptions),
              ),
            ),
            const SizedBox(height: 16),
            SearchBox(
              text: 'Search your collection',
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  _searchQuery = value;
                });
              },
            ),
            const SizedBox(height: 12),
            _StashControlStrip(
              activeSort: _activeSort,
              activeDirection: _sortDirection,
              allSelected: !hasActiveFilters,
              filterLabels: _filterChips(filterOptions),
              onSortSelected: (sort, direction) => setState(() {
                _activeSort = sort;
                _sortDirection = direction;
              }),
              onClearFilters: _resetFilters,
            ),
            const SizedBox(height: 20),
            if (snapshot.hasError)
              const _StashLoadErrorState()
            else if (isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 42),
                  child: CircularProgressIndicator(color: AppColors.accent),
                ),
              )
            else if (yarns.isEmpty)
              _EmptyStashState(onAddYarn: widget.onAddYarn)
            else
              _StashCollectionGrid(
                items: _filteredItems(yarns, filterOptions),
                onYarnTap: widget.onYarnTap,
                onResetFilters: _resetFilters,
              ),
          ],
        );
      },
    );
  }
}

class _StashCollectionGrid extends StatelessWidget {
  const _StashCollectionGrid({
    required this.items,
    required this.onYarnTap,
    required this.onResetFilters,
  });

  final List<_StashYarnItem> items;
  final ValueChanged<Yarn> onYarnTap;
  final VoidCallback onResetFilters;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return _EmptyFilterState(onReset: onResetFilters);
    }

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      mainAxisExtent: 218,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (final item in items)
          _YarnGridCard(
            imageUrl: item.imageUrl,
            title: item.title,
            subtitle: item.subtitle,
            fallbackColor: item.fallbackColor,
            onTap: () => onYarnTap(item.yarn),
          ),
      ],
    );
  }
}

class _StashFilterDialog extends StatefulWidget {
  const _StashFilterDialog({
    required this.initialFilters,
    required this.options,
  });

  final Set<String> initialFilters;
  final _StashFilterOptions options;

  @override
  State<_StashFilterDialog> createState() => _StashFilterDialogState();
}

class _StashFilterDialogState extends State<_StashFilterDialog> {
  late Set<String> _filters;

  @override
  void initState() {
    super.initState();
    _filters = Set<String>.of(widget.initialFilters);
    if (_filters.isEmpty) {
      _filters.add(_allStashFilter);
    }
  }

  bool get _isDefault => _filters.contains(_allStashFilter);

  void _selectAll() {
    setState(() => _filters = {_allStashFilter});
  }

  void _toggleFilter(String filter) {
    setState(() {
      final updated = Set<String>.of(_filters)..remove(_allStashFilter);
      if (updated.contains(filter)) {
        updated.remove(filter);
      } else {
        updated.add(filter);
      }
      _filters = updated.isEmpty ? {_allStashFilter} : updated;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ModalCard(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.78,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Filter stash',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: tightLetterSpacing,
                      ),
                    ),
                  ),
                  CircleIconButton(
                    icon: FontAwesomeIcons.xmark,
                    size: 36,
                    iconSize: 15,
                    onTap: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerLeft,
                child: _FilterChipButton(
                  label: _allStashFilter,
                  selected: _isDefault,
                  onTap: _selectAll,
                ),
              ),
              const SizedBox(height: 18),
              _FilterSection(
                label: 'Weight',
                options: widget.options.weights,
                selectedFilters: _filters,
                onSelected: _toggleFilter,
              ),
              const SizedBox(height: 16),
              _FilterSection(
                label: 'Fiber',
                options: widget.options.fibers,
                selectedFilters: _filters,
                onSelected: _toggleFilter,
              ),
              const SizedBox(height: 16),
              _FilterSection(
                label: 'Color family',
                options: widget.options.colors,
                selectedFilters: _filters,
                onSelected: _toggleFilter,
              ),
              const SizedBox(height: 16),
              _FilterSection(
                label: 'Status',
                options: widget.options.statuses,
                selectedFilters: _filters,
                onSelected: _toggleFilter,
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: SecondaryButton(label: 'Reset', onTap: _selectAll),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: PrimaryButton(
                      label: 'Apply',
                      icon: FontAwesomeIcons.check,
                      height: 48,
                      onTap: () =>
                          Navigator.pop(context, Set<String>.of(_filters)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterSection extends StatelessWidget {
  const _FilterSection({
    required this.label,
    required this.options,
    required this.selectedFilters,
    required this.onSelected,
  });

  final String label;
  final List<String> options;
  final Set<String> selectedFilters;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(label),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final option in options)
              _FilterChipButton(
                label: option,
                selected: selectedFilters.contains(option),
                onTap: () => onSelected(option),
              ),
          ],
        ),
      ],
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? AppColors.accentDark : AppColors.muted;
    return Material(
      color: selected ? AppColors.cream : AppColors.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.accentDark : AppColors.line,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selected) ...[
                FaIcon(FontAwesomeIcons.check, color: color, size: 12),
                const SizedBox(width: 7),
              ],
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: tightLetterSpacing,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StashControlStrip extends StatelessWidget {
  const _StashControlStrip({
    required this.activeSort,
    required this.activeDirection,
    required this.allSelected,
    required this.filterLabels,
    required this.onSortSelected,
    required this.onClearFilters,
  });

  final _StashSort activeSort;
  final _StashSortDirection activeDirection;
  final bool allSelected;
  final List<String> filterLabels;
  final void Function(_StashSort sort, _StashSortDirection direction)
  onSortSelected;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          Semantics(
            button: true,
            selected: allSelected,
            label: 'Clear stash filters',
            child: GestureDetector(
              onTap: onClearFilters,
              child: StashChip(label: _allStashFilter, active: allSelected),
            ),
          ),
          const SizedBox(width: 8),
          for (final sort in _StashSort.values) ...[
            _SortChip(
              sort: sort,
              selected: activeSort == sort,
              activeDirection: activeDirection,
              onSelected: (direction) => onSortSelected(sort, direction),
            ),
            const SizedBox(width: 8),
          ],
          for (var i = 0; i < filterLabels.length; i++) ...[
            StashChip(label: filterLabels[i], active: true),
            if (i < filterLabels.length - 1) const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _SortChip extends StatelessWidget {
  const _SortChip({
    required this.sort,
    required this.selected,
    required this.activeDirection,
    required this.onSelected,
  });

  final _StashSort sort;
  final bool selected;
  final _StashSortDirection activeDirection;
  final ValueChanged<_StashSortDirection> onSelected;

  @override
  Widget build(BuildContext context) {
    final label = _stashSortLabel(sort);
    return Semantics(
      button: true,
      selected: selected,
      label: 'Sort by $label',
      child: PopupMenuButton<_StashSortDirection>(
        tooltip: 'Sort by $label',
        color: AppColors.card,
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        initialValue: selected ? activeDirection : null,
        onSelected: onSelected,
        itemBuilder: (context) => [
          for (final direction in _StashSortDirection.values)
            PopupMenuItem(
              value: direction,
              child: Row(
                children: [
                  SizedBox(
                    width: 18,
                    child: selected && activeDirection == direction
                        ? const FaIcon(
                            FontAwesomeIcons.check,
                            size: 12,
                            color: AppColors.accentDark,
                          )
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _stashSortDirectionMenuLabel(sort, direction),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 10),
                  FaIcon(
                    _stashSortDirectionIcon(direction),
                    size: 12,
                    color: AppColors.muted,
                  ),
                ],
              ),
            ),
        ],
        child: StashChip(
          label: label,
          active: selected,
          trailingIcon: FontAwesomeIcons.chevronDown,
        ),
      ),
    );
  }
}

class _EmptyFilterState extends StatelessWidget {
  const _EmptyFilterState({required this.onReset});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return CardSurface(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const IconBadge(
            icon: FontAwesomeIcons.sliders,
            background: AppColors.goldSoft,
            foreground: AppColors.accentDark,
          ),
          const SizedBox(height: 14),
          const Text(
            'No yarn matches these filters',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: tightLetterSpacing,
            ),
          ),
          const SizedBox(height: 14),
          SecondaryButton(
            label: 'Reset filters',
            icon: FontAwesomeIcons.rotateLeft,
            onTap: onReset,
          ),
        ],
      ),
    );
  }
}

class _EmptyStashState extends StatelessWidget {
  const _EmptyStashState({required this.onAddYarn});

  final VoidCallback onAddYarn;

  @override
  Widget build(BuildContext context) {
    return CardSurface(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const IconBadge(
            icon: FontAwesomeIcons.basketShopping,
            background: AppColors.rose,
            foreground: AppColors.accentDark,
          ),
          const SizedBox(height: 14),
          const Text(
            'Your stash is empty',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: tightLetterSpacing,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Add yarn to start building your collection.',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 14,
              height: 1.35,
              fontWeight: FontWeight.w800,
              letterSpacing: tightLetterSpacing,
            ),
          ),
          const SizedBox(height: 14),
          PrimaryButton(
            label: 'Add yarn',
            icon: FontAwesomeIcons.plus,
            onTap: onAddYarn,
          ),
        ],
      ),
    );
  }
}

class _StashLoadErrorState extends StatelessWidget {
  const _StashLoadErrorState();

  @override
  Widget build(BuildContext context) {
    return const CardSurface(
      padding: EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(
            icon: FontAwesomeIcons.triangleExclamation,
            background: Color(0xFFFFF1F1),
            foreground: AppColors.danger,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Text(
              'Unable to load your stash right now.',
              style: TextStyle(
                color: AppColors.danger,
                fontSize: 14,
                height: 1.35,
                fontWeight: FontWeight.w800,
                letterSpacing: tightLetterSpacing,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SearchCatalogScreen extends StatefulWidget {
  const SearchCatalogScreen({
    super.key,
    required this.onAddYarn,
    required this.onAddCustomYarn,
    this.catalogRepository,
  });

  final ValueChanged<RavelryYarnCatalogItem> onAddYarn;
  final VoidCallback onAddCustomYarn;
  final RavelryYarnCatalogRepository? catalogRepository;

  @override
  State<SearchCatalogScreen> createState() => _SearchCatalogScreenState();
}

class _SearchCatalogScreenState extends State<SearchCatalogScreen> {
  late final RavelryYarnCatalogRepository _catalogRepository;
  late final TextEditingController _searchController;
  Timer? _debounce;
  List<RavelryYarnCatalogItem> _results = const [];
  bool _isSearching = false;
  bool _hasSearched = false;
  bool _isOpeningCatalogYarn = false;
  String? _errorMessage;
  String _activeQuery = '';

  @override
  void initState() {
    super.initState();
    _catalogRepository =
        widget.catalogRepository ?? RavelryYarnCatalogRepository();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _handleQueryChanged(String value) {
    _debounce?.cancel();
    final query = value.trim();

    if (query.length < 2) {
      setState(() {
        _activeQuery = query;
        _results = const [];
        _isSearching = false;
        _hasSearched = false;
        _errorMessage = null;
      });
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 350), () {
      _search(query);
    });
  }

  Future<void> _search(String query) async {
    setState(() {
      _activeQuery = query;
      _isSearching = true;
      _hasSearched = true;
      _errorMessage = null;
    });

    try {
      final results = await _catalogRepository.searchYarns(query: query);
      if (!mounted || _activeQuery != query) return;
      setState(() {
        _results = results;
        _isSearching = false;
      });
    } on RavelryCatalogException catch (error) {
      if (!mounted || _activeQuery != query) return;
      setState(() {
        _results = const [];
        _isSearching = false;
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted || _activeQuery != query) return;
      setState(() {
        _results = const [];
        _isSearching = false;
        _errorMessage = 'Unable to search the Ravelry catalog right now.';
      });
    }
  }

  Future<void> _openCatalogYarn(RavelryYarnCatalogItem yarn) async {
    if (_isOpeningCatalogYarn) return;

    final yarnId = yarn.id;

    if (yarnId == null) {
      widget.onAddYarn(yarn);
      return;
    }

    setState(() {
      _isOpeningCatalogYarn = true;
      _errorMessage = null;
    });

    try {
      final detailedYarn = await _catalogRepository.getYarn(yarnId);

      if (!mounted) return;
      widget.onAddYarn(detailedYarn);
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Unable to load full Ravelry details. Opening basic yarn info.',
          ),
        ),
      );

      widget.onAddYarn(yarn);
    } finally {
      if (mounted) {
        setState(() => _isOpeningCatalogYarn = false);
      }
    }
  }

  Widget _buildCatalogContent() {
    if (_isSearching) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 36),
          child: CircularProgressIndicator(color: AppColors.accent),
        ),
      );
    }

    if (_errorMessage != null) {
      return _CatalogMessageState(
        icon: FontAwesomeIcons.triangleExclamation,
        title: 'Catalog unavailable',
        message: _errorMessage!,
      );
    }

    if (!_hasSearched) {
      return const _CatalogMessageState(
        icon: FontAwesomeIcons.magnifyingGlass,
        title: 'Search Ravelry',
        message: 'Type at least two characters to search the yarn catalog.',
      );
    }

    if (_results.isEmpty) {
      return const _CatalogMessageState(
        icon: FontAwesomeIcons.circleInfo,
        title: 'No matches',
        message: 'Try a brand, base name, or alternate spelling.',
      );
    }

    return Column(
      children: [
        for (var index = 0; index < _results.length; index++) ...[
          _YarnListCard(
            imageUrl: _results[index].imageUrl ?? '',
            title: _results[index].name,
            subtitle: _results[index].brandName,
            chips: _results[index].chips,
            detail: _catalogDetail(_results[index]),
            onAction: () => _openCatalogYarn(_results[index]),
            fallbackColor: _catalogFallbackColor(index),
          ),
          if (index != _results.length - 1) const SizedBox(height: 12),
        ],
      ],
    );
  }

  String? _catalogDetail(RavelryYarnCatalogItem yarn) {
    final details = [
      if (yarn.yardage != null) '${yarn.yardage} yd',
      if (yarn.unitWeightGrams != null) '${yarn.unitWeightGrams} g',
    ];
    return details.isEmpty ? null : details.join(' - ');
  }

  Color _catalogFallbackColor(int index) {
    return switch (index % 4) {
      0 => AppColors.rose,
      1 => AppColors.goldSoft,
      2 => AppColors.sageSoft,
      _ => AppColors.lavenderSoft,
    };
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 18),
      children: [
        const NavRow(title: 'Find yarn'),
        const SizedBox(height: 16),
        SearchBox(
          text: 'Search by name or brand',
          controller: _searchController,
          onChanged: _handleQueryChanged,
        ),
        const SizedBox(height: 24),
        const Text(
          'Catalog matches',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w900,
            letterSpacing: tightLetterSpacing,
          ),
        ),
        const SizedBox(height: 12),
        _buildCatalogContent(),
        const SizedBox(height: 20),
        SecondaryButton(
          label: "Can't find your yarn? Add your own",
          onTap: widget.onAddCustomYarn,
        ),
      ],
    );
  }
}

class _CatalogMessageState extends StatelessWidget {
  const _CatalogMessageState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final FaIconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return CardSurface(
      padding: const EdgeInsets.all(18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(
            icon: icon,
            background: AppColors.cream,
            foreground: AppColors.accentDark,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: tightLetterSpacing,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 14,
                    height: 1.35,
                    fontWeight: FontWeight.w800,
                    letterSpacing: tightLetterSpacing,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class YarnDetailScreen extends StatelessWidget {
  const YarnDetailScreen({
    super.key,
    required this.userId,
    required this.collectionId,
    required this.yarnId,
    required this.onBack,
    required this.onEdit,
    this.yarnRepository,
  });

  final String userId;
  final String collectionId;
  final String? yarnId;
  final VoidCallback onBack;
  final VoidCallback onEdit;
  final YarnRepository? yarnRepository;

  @override
  Widget build(BuildContext context) {
    final selectedYarnId = yarnId;
    if (selectedYarnId == null) {
      return _YarnDetailMessageState(
        onBack: onBack,
        title: 'No yarn selected',
        message: 'Choose a yarn from your stash to view its saved details.',
      );
    }

    final repository = yarnRepository ?? YarnRepository();
    return StreamBuilder<Yarn?>(
      stream: repository.watchYarn(
        uid: userId,
        collectionId: collectionId,
        yarnId: selectedYarnId,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _YarnDetailMessageState(
            onBack: onBack,
            title: 'Unable to load yarn',
            message: 'Try returning to your stash and opening it again.',
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return ListView(
            padding: const EdgeInsets.only(bottom: 28),
            children: [
              NavRow(
                leading: CircleIconButton(
                  icon: FontAwesomeIcons.chevronLeft,
                  onTap: onBack,
                ),
              ),
              const SizedBox(height: 96),
              const Center(
                child: CircularProgressIndicator(color: AppColors.accent),
              ),
            ],
          );
        }

        final yarn = snapshot.data;
        if (yarn == null) {
          return _YarnDetailMessageState(
            onBack: onBack,
            title: 'Yarn not found',
            message: 'This yarn may have been removed from your stash.',
          );
        }

        return _YarnDetailContent(yarn: yarn, onBack: onBack, onEdit: onEdit);
      },
    );
  }
}

class _YarnDetailContent extends StatelessWidget {
  const _YarnDetailContent({
    required this.yarn,
    required this.onBack,
    required this.onEdit,
  });

  final Yarn yarn;
  final VoidCallback onBack;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 28),
      children: [
        NavRow(
          leading: CircleIconButton(
            icon: FontAwesomeIcons.chevronLeft,
            onTap: onBack,
          ),
          trailing: CircleIconButton(
            icon: FontAwesomeIcons.penToSquare,
            onTap: onEdit,
          ),
        ),
        const SizedBox(height: 16),
        PhotoSlideshow(
          imageUrls: yarn.imageUrls,
          fallbackColor: _fallbackColorForYarn(yarn),
          fit: BoxFit.contain,
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _yarnTitle(yarn),
                    style: const TextStyle(
                      fontSize: 30,
                      height: 1.08,
                      fontWeight: FontWeight.w900,
                      letterSpacing: tightLetterSpacing,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _yarnSubtitle(yarn),
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: tightLetterSpacing,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            StashChip(label: _statusLabel(yarn.status), active: true),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: StatCard(
                value: yarn.skeinCount.toString(),
                label: 'Skeins',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(value: _totalWeightStat(yarn), label: 'Grams'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(value: _totalYardageStat(yarn), label: 'Yards'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const SectionTitle('Fiber content'),
        const SizedBox(height: 12),
        _FiberContentSummary(yarn: yarn),
        const SizedBox(height: 24),
        const SectionTitle('Details'),
        const SizedBox(height: 12),
        _InfoGrid(items: _detailItemsForYarn(yarn)),
        const SizedBox(height: 16),
        CardSurface(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const FieldLabel('Notes'),
              const SizedBox(height: 8),
              Text(
                _valueOrFallback(yarn.notes, fallback: 'No notes yet.'),
                style: const TextStyle(
                  color: Color(0xFF5F5148),
                  fontSize: 15,
                  height: 1.35,
                  fontWeight: FontWeight.w700,
                  letterSpacing: tightLetterSpacing,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _FiberContentSummary extends StatelessWidget {
  const _FiberContentSummary({required this.yarn});

  final Yarn yarn;

  @override
  Widget build(BuildContext context) {
    final legacyFiberContent = yarn.fiberContent?.trim();

    return CardSurface(
      radius: 20,
      padding: const EdgeInsets.all(16),
      child: yarn.fiberContents.isEmpty
          ? Text(
              legacyFiberContent != null && legacyFiberContent.isNotEmpty
                  ? legacyFiberContent
                  : ' ',
              style: const TextStyle(
                color: AppColors.ink,
                fontSize: 16,
                fontWeight: FontWeight.w800,
                letterSpacing: tightLetterSpacing,
              ),
            )
          : Column(
              children: [
                for (var index = 0; index < yarn.fiberContents.length; index++)
                  Padding(
                    padding: EdgeInsets.only(
                      bottom: index == yarn.fiberContents.length - 1 ? 0 : 14,
                    ),
                    child: _FiberContentDisplayRow(
                      fiberContent: yarn.fiberContents[index],
                      color: _fiberDisplayColor(index),
                    ),
                  ),
              ],
            ),
    );
  }
}

class _FiberContentDisplayRow extends StatelessWidget {
  const _FiberContentDisplayRow({
    required this.fiberContent,
    required this.color,
  });

  final YarnFiberContent fiberContent;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final widthFactor = fiberContent.percentage.clamp(0, 100) / 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                fiberContent.fiber,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  letterSpacing: tightLetterSpacing,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${fiberContent.percentage}%',
                style: TextStyle(
                  color: color,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  letterSpacing: tightLetterSpacing,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Container(
            height: 8,
            color: AppColors.line,
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: widthFactor.toDouble(),
              child: Container(color: color),
            ),
          ),
        ),
      ],
    );
  }
}

class _YarnDetailMessageState extends StatelessWidget {
  const _YarnDetailMessageState({
    required this.onBack,
    required this.title,
    required this.message,
  });

  final VoidCallback onBack;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 28),
      children: [
        NavRow(
          leading: CircleIconButton(
            icon: FontAwesomeIcons.chevronLeft,
            onTap: onBack,
          ),
        ),
        const SizedBox(height: 96),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: tightLetterSpacing,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: tightLetterSpacing,
          ),
        ),
      ],
    );
  }
}

String _yarnTitle(Yarn yarn) {
  final name = yarn.name.trim();
  if (name.isNotEmpty) return name;

  final brandName = yarn.brandName.trim();
  return brandName.isEmpty ? 'Unnamed yarn' : brandName;
}

String _yarnSubtitle(Yarn yarn) {
  final colorway = _cleanText(yarn.colorway);
  final brandName = _cleanText(yarn.brandName);
  final parts = [?colorway, ?brandName];

  return parts.isEmpty ? 'No brand saved' : parts.join(' - ');
}

String _statusLabel(YarnStatus status) {
  return switch (status) {
    YarnStatus.inStash => 'In stash',
    YarnStatus.inProject => 'In project',
    YarnStatus.usedUp => 'Used up',
    YarnStatus.destashed => 'Destashed',
  };
}

List<InfoItem> _detailItemsForYarn(Yarn yarn) {
  return [
    InfoItem('Weight', _valueOrFallback(yarn.weightCategory)),
    InfoItem('WPI', yarn.wpi?.toString() ?? ' '),
    InfoItem('Yardage', _yardageText(yarn.yardage)),
    InfoItem('Grams', _unitWeightText(yarn.unitWeightGrams)),
    InfoItem('Needle Size', _valueOrFallback(yarn.needleSize)),
    InfoItem('Gauge(sts)', _valueOrFallback(yarn.gauge)),
    InfoItem('Color family', _valueOrFallback(yarn.colorFamily)),
    InfoItem('Colorway', _valueOrFallback(yarn.colorway)),
    InfoItem('Dye lot', _valueOrFallback(yarn.dyeLot)),
    InfoItem('Skeins', yarn.skeinCount.toString()),
    InfoItem('Price', _priceText(yarn.priceCents)),
  ];
}

String _totalYardageStat(Yarn yarn) {
  final yardage = yarn.yardage;
  if (yardage == null) return '--';
  return (yardage * yarn.skeinCount).toString();
}

String _totalWeightStat(Yarn yarn) {
  final grams = yarn.unitWeightGrams;
  if (grams == null) return '--';
  return '${grams * yarn.skeinCount}';
}

String _yardageText(int? yardage) {
  return yardage == null ? ' ' : '$yardage yd';
}

String _unitWeightText(int? grams) {
  return grams == null ? ' ' : '$grams g';
}

String _priceText(int? priceCents) {
  if (priceCents == null) return ' ';
  return '\$${(priceCents / 100).toStringAsFixed(2)}';
}

String _valueOrFallback(String? value, {String fallback = ' '}) {
  return _cleanText(value) ?? fallback;
}

String? _cleanText(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
}

String? _normalizeFiberName(String? value) {
  final cleaned = _cleanText(value);
  if (cleaned == null) return null;

  return cleaned
      .split(RegExp(r'\s+'))
      .map((word) {
    if (word.isEmpty) return word;
    return word[0].toUpperCase() + word.substring(1).toLowerCase();
  })
      .join(' ');
}

String? _normalizeWeightName(String? value) {
  final cleaned = _cleanText(value);
  if (cleaned == null) return null;

  return cleaned
      .split(RegExp(r'\s+'))
      .map((word) {
    if (word.isEmpty) return word;
    return word[0].toUpperCase() + word.substring(1).toLowerCase();
  })
      .join(' ');
}

String _profileNameFromEmail(String email) {
  return email.split('@').first;
}

String _profileDisplayName(AppUser? appUser, String fallbackDisplayName) {
  return _cleanText(appUser?.displayName) ??
      _cleanText(fallbackDisplayName) ??
      'Your stash';
}

class _SettingsProfile {
  const _SettingsProfile({
    required this.displayName,
    required this.hasExplicitDisplayName,
    required this.email,
  });

  final String displayName;
  final bool hasExplicitDisplayName;
  final String email;

  String get accountSummary {
    if (hasExplicitDisplayName && email.isNotEmpty) {
      return '$displayName / $email';
    }

    if (email.isNotEmpty) {
      return email;
    }

    return displayName;
  }
}

_SettingsProfile _settingsProfile({
  required AppUser? appUser,
  required String? authDisplayName,
  required String? authEmail,
}) {
  final displayName =
      _cleanText(appUser?.displayName) ?? _cleanText(authDisplayName);
  final email = _cleanText(appUser?.email) ?? _cleanText(authEmail) ?? '';

  return _SettingsProfile(
    displayName:
        displayName ??
        (email.isEmpty ? 'Your stash' : _profileNameFromEmail(email)),
    hasExplicitDisplayName: displayName != null,
    email: email,
  );
}

Color _fiberDisplayColor(int index) {
  return switch (index % 4) {
    0 => AppColors.accentDark,
    1 => const Color(0xFF587456),
    2 => const Color(0xFF6D579A),
    _ => const Color(0xFFA87523),
  };
}

class YarnFormScreen extends StatefulWidget {
  const YarnFormScreen({
    super.key,
    required this.isEditing,
    required this.userId,
    required this.onBack,
    required this.onPrimary,
    this.onDelete,
    this.startBlank = false,
    this.collectionId,
    this.yarnId,
    this.catalogYarn,
    this.yarnRepository,
    this.folderRepository,
  });

  final bool isEditing;
  final String userId;
  final VoidCallback onBack;
  final VoidCallback onPrimary;
  final VoidCallback? onDelete;
  final bool startBlank;
  final String? collectionId;
  final String? yarnId;
  final RavelryYarnCatalogItem? catalogYarn;
  final YarnRepository? yarnRepository;
  final StashFolderRepository? folderRepository;

  @override
  State<YarnFormScreen> createState() => _YarnFormScreenState();
}

class _YarnFormScreenState extends State<YarnFormScreen> {
  late final YarnRepository _yarnRepository;
  late final StashFolderRepository _folderRepository;
  late final TextEditingController _yarnNameController;
  late final TextEditingController _brandController;
  late final TextEditingController _weightController;
  late final TextEditingController _wpiController;
  late final TextEditingController _lengthController;
  late final TextEditingController _unitWeightController;
  late final TextEditingController _needleController;
  late final TextEditingController _gaugeController;
  late final TextEditingController _colorwayController;
  late final TextEditingController _dyeLotController;
  late final TextEditingController _ballsController;
  late final TextEditingController _priceController;
  late final TextEditingController _notesController;
  final List<_FiberContentInput> _fiberRows = [];

  String? _colorFamily;
  late String _folder;
  String? _selectedFolderId;
  Yarn? _editingYarn;
  String? _populatedYarnId;
  final List<String> _selectedImageUrls = [];
  late final TextEditingController _imageUrlController;
  bool _isSaving = false;
  String? _errorMessage;

  final _imagePicker = ImagePicker();
  final _imageStorage = YarnImageStorageService();

  final List<File> _selectedImageFiles = [];  String? _existingImageUrl;
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    _yarnRepository = widget.yarnRepository ?? YarnRepository();
    _folderRepository = widget.folderRepository ?? StashFolderRepository();
    _colorFamily = null;
    _folder = 'No folder';
    _yarnNameController = TextEditingController();
    _brandController = TextEditingController();
    _weightController = TextEditingController();
    _wpiController = TextEditingController();
    _lengthController = TextEditingController();
    _unitWeightController = TextEditingController();
    _needleController = TextEditingController();
    _gaugeController = TextEditingController();
    _colorwayController = TextEditingController();
    _dyeLotController = TextEditingController();
    _ballsController = TextEditingController();
    _priceController = TextEditingController();
    _notesController = TextEditingController();
    _imageUrlController = TextEditingController();

    if (widget.isEditing) {
      _replaceFiberRows([_FiberContentInput()]);
    } else {
      _seedCreateForm();
    }
  }

  @override
  void didUpdateWidget(covariant YarnFormScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isEditing != oldWidget.isEditing ||
        widget.startBlank != oldWidget.startBlank ||
        widget.collectionId != oldWidget.collectionId ||
        widget.yarnId != oldWidget.yarnId ||
        widget.catalogYarn?.catalogKey != oldWidget.catalogYarn?.catalogKey) {
      _errorMessage = null;
      _isSaving = false;
      if (widget.isEditing) {
        _editingYarn = null;
        _populatedYarnId = null;
        _selectedImageUrls.clear();
        _imageUrlController.clear();
        _colorFamily = null;
        _folder = 'No folder';
        _selectedFolderId = null;
        _clearControllers();
        _replaceFiberRows([_FiberContentInput()]);
      } else {
        _seedCreateForm();
      }
    }
  }

  int? _parseFirstInt(String value) {
    final match = RegExp(r'\d+').firstMatch(value);
    if (match == null) return null;
    return int.tryParse(match.group(0)!);
  }

  int? _parsePriceCents(String value) {
    final cleaned = value.replaceAll(RegExp(r'[^0-9.]'), '');
    if (cleaned.isEmpty) return null;
    final parsed = double.tryParse(cleaned);
    if (parsed == null) return null;
    return (parsed * 100).round();
  }

  String? _trimmedOrNull(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  int get _selectedImageCount {
    return _selectedImageUrls.length + _selectedImageFiles.length;
  }

  List<String> _imageUrlsForSave() {
    return _selectedImageUrls
        .map((url) => url.trim())
        .where((url) => url.isNotEmpty)
        .take(_maxYarnImageCount)
        .toList(growable: false);
  }

  void _addImageUrl() {
    final imageUrl = _imageUrlController.text.trim();

    if (imageUrl.isEmpty) {
      setState(() {
        _errorMessage = 'Enter an image URL before adding it.';
      });
      return;
    }

    if (_selectedImageUrls.length >= _maxYarnImageCount) {
      setState(() {
        _errorMessage = 'You can add up to $_maxYarnImageCount images.';
      });
      return;
    }

    if (_selectedImageUrls.contains(imageUrl)) {
      setState(() {
        _errorMessage = 'This image has already been added.';
      });
      return;
    }

    setState(() {
      _selectedImageUrls.add(imageUrl);
      _imageUrlController.clear();
      _errorMessage = null;
    });
  }

  void _removeImageUrl(int index) {
    setState(() {
      _selectedImageUrls.removeAt(index);
    });
  }

  void _removeSelectedImageFile(int index) {
    setState(() {
      _selectedImageFiles.removeAt(index);
    });
  }

  Future<void> _deleteStorageImageIfPossible(String imageUrl) async {
    if (imageUrl.trim().isEmpty) return;

    try {
      await _imageStorage.deleteImageByUrl(imageUrl);
    } catch (_) {
      // Ignore delete failures because some images may be external URLs
      // like Ravelry, Unsplash, or pasted web image URLs.
    }
  }

  String get _coverImageUrl {
    return _selectedImageUrls.isEmpty ? '' : _selectedImageUrls.first;
  }

  Widget _imagePickerField() {
    final canAddMore = _selectedImageCount < _maxYarnImageCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),

        GestureDetector(
          onTap: _isSaving || !canAddMore ? null : _pickImage,
          child: Container(
            height: 96,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.cream,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.line,
                width: 1.5,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FaIcon(
                  FontAwesomeIcons.camera,
                  color: canAddMore ? AppColors.accent : AppColors.muted,
                  size: 24,
                ),
                const SizedBox(height: 8),
                Text(
                  canAddMore ? 'Add image' : 'Image limit reached',
                  style: TextStyle(
                    color: canAddMore ? AppColors.accent : AppColors.muted,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    letterSpacing: tightLetterSpacing,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 8),

        Text(
          '$_selectedImageCount / $_maxYarnImageCount images',
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: tightLetterSpacing,
          ),
        ),

        if (_selectedImageUrls.isNotEmpty || _selectedImageFiles.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (var index = 0; index < _selectedImageUrls.length; index++)
                _SelectedImagePreview(
                  imageUrl: _selectedImageUrls[index],
                  fallbackColor: widget.startBlank
                      ? AppColors.cream
                      : const Color(0xFFB8D6E8),
                  onRemove: () => _removeImageUrl(index),
                ),

              for (var index = 0; index < _selectedImageFiles.length; index++)
                _SelectedLocalImagePreview(
                  imageFile: _selectedImageFiles[index],
                  onRemove: () => _removeSelectedImageFile(index),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Future<void> _pickImage() async {
    if (_selectedImageCount >= _maxYarnImageCount) {
      setState(() {
        _errorMessage = 'You can add up to $_maxYarnImageCount images.';
      });
      return;
    }

    final pickedImage = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1200,
    );

    if (pickedImage == null) return;

    setState(() {
      _selectedImageFiles.add(File(pickedImage.path));
      _errorMessage = null;
    });
  }

  String _optionalIntInputText(int? value, String suffix) {
    return value == null ? '' : '$value $suffix';
  }

  String _priceInputText(int? priceCents) {
    return priceCents == null
        ? ''
        : '\$${(priceCents / 100).toStringAsFixed(2)}';
  }

  List<String> get _colorFamilyItems {
    final colorFamily = _colorFamily;
    if (colorFamily == null || _colorFamilyOptions.contains(colorFamily)) {
      return _colorFamilyOptions;
    }
    return [colorFamily, ..._colorFamilyOptions];
  }

  List<String> _folderOptions(List<StashFolder> folders) {
    final names = [
      for (final folder in folders)
        if (folder.name.trim().isNotEmpty) folder.name.trim(),
    ];
    final options = <String>[
      ...names,
      if (_folder != 'No folder' && !names.contains(_folder)) _folder,
      'No folder',
    ];
    return options.toSet().toList(growable: false);
  }

  StashFolder? _selectedFolder(List<StashFolder> folders) {
    final selectedFolderId = _selectedFolderId;
    if (selectedFolderId != null) {
      for (final folder in folders) {
        if (folder.id == selectedFolderId) return folder;
      }
    }

    for (final folder in folders) {
      if (folder.name == _folder) return folder;
    }

    return null;
  }

  bool _selectedFolderIsUsedUp(List<StashFolder> folders) {
    final selectedFolder = _selectedFolder(folders);

    if (selectedFolder != null) {
      return selectedFolder.isDefaultUsedUp ||
          selectedFolder.name.trim().toLowerCase() == 'used up';
    }

    return _folder.trim().toLowerCase() == 'used up';
  }

  StashFolder? _usedUpFolder(List<StashFolder> folders) {
    for (final folder in folders) {
      if (folder.isDefaultUsedUp ||
          folder.name.trim().toLowerCase() == 'used up') {
        return folder;
      }
    }

    return null;
  }

  void _selectFolder(String? folderName, List<StashFolder> folders) {
    final name = folderName ?? _folder;
    final folder = folders.cast<StashFolder?>().firstWhere(
      (folder) => folder?.name == name,
      orElse: () => null,
    );

    setState(() {
      _folder = name;
      _selectedFolderId = folder?.id;
      if (name == 'No folder') {
        _selectedFolderId = null;
      }
    });
  }

  void _syncSelectedFolderName(List<StashFolder> folders) {
    final selectedFolderId = _selectedFolderId;
    if (selectedFolderId == null) return;

    for (final folder in folders) {
      if (folder.id == selectedFolderId) {
        _folder = folder.name;
        return;
      }
    }
  }

  void _clearControllers() {
    _yarnNameController.clear();
    _brandController.clear();
    _weightController.clear();
    _wpiController.clear();
    _lengthController.clear();
    _unitWeightController.clear();
    _needleController.clear();
    _gaugeController.clear();
    _colorwayController.clear();
    _dyeLotController.clear();
    _ballsController.clear();
    _priceController.clear();
    _notesController.clear();
  }

  void _replaceFiberRows(List<_FiberContentInput> rows) {
    for (final row in _fiberRows) {
      row.dispose();
    }
    _fiberRows
      ..clear()
      ..addAll(rows.isEmpty ? [_FiberContentInput()] : rows);
  }

  String _catalogOptionalIntInputText(
    int? value,
    String suffix, {
    required String fallback,
  }) {
    return value == null ? fallback : '$value $suffix';
  }

  List<_FiberContentInput> _catalogFiberRows(
    RavelryYarnCatalogItem? catalogYarn,
    bool seedFallback,
  ) {
    if (catalogYarn != null && catalogYarn.fiberContents.isNotEmpty) {
      return [
        for (final fiberContent in catalogYarn.fiberContents)
          _FiberContentInput(
            fiber: fiberContent.fiber,
            percentage: fiberContent.percentage.toString(),
          ),
      ];
    }

    if (catalogYarn != null) {
      final fiberContent = _cleanText(catalogYarn.fiberContent);
      return [_FiberContentInput(fiber: fiberContent ?? '', percentage: '')];
    }

    return [
      _FiberContentInput(
        fiber: seedFallback ? 'Merino' : '',
        percentage: seedFallback ? '100' : '',
      ),
    ];
  }

  void _seedCreateForm() {
    final catalogYarn = widget.catalogYarn;
    final seedCatalogYarn = catalogYarn != null || !widget.startBlank;
    final seedExampleYarn = catalogYarn == null && seedCatalogYarn;
    _editingYarn = null;
    _populatedYarnId = null;
    _selectedImageUrls
      ..clear()
      ..addAll([
        if ((catalogYarn?.imageUrl ?? '').trim().isNotEmpty)
          catalogYarn!.imageUrl!.trim()
        else if (seedExampleYarn)
          _imgMerino,
      ]);
    _imageUrlController.clear();
    _colorFamily = seedExampleYarn ? 'White' : null;
    _folder = 'No folder';
    _selectedFolderId = null;
    _yarnNameController.text =
        catalogYarn?.name ?? (seedExampleYarn ? 'Malabrigo Rios' : '');
    _brandController.text =
        catalogYarn?.brandName ?? (seedExampleYarn ? 'Malabrigo Yarn' : '');
    _weightController.text =
        catalogYarn?.weightName ?? (seedExampleYarn ? 'Worsted' : '');
    _wpiController.text = seedExampleYarn ? '9' : '';
    _lengthController.text = _catalogOptionalIntInputText(
      catalogYarn?.yardage,
      'm',
      fallback: seedExampleYarn ? '210 yd' : '',
    );
    _unitWeightController.text = _catalogOptionalIntInputText(
      catalogYarn?.unitWeightGrams,
      'g',
      fallback: seedExampleYarn ? '100 g' : '',
    );
    _needleController.text =
        catalogYarn?.needleSize ?? (seedExampleYarn ? 'US 6-8' : '');
    _gaugeController.text =
        catalogYarn?.gauge ?? (seedExampleYarn ? '18-22 sts' : '');
    _colorwayController.text = seedExampleYarn ? 'Aguas' : '';
    _dyeLotController.text = seedExampleYarn ? 'A27' : '';
    _ballsController.text = seedExampleYarn ? '4' : '';
    _priceController.text = seedExampleYarn ? r'$14.50' : '';
    _notesController.text = catalogYarn != null
        ? 'Imported from the Ravelry yarn catalog.'
        : seedCatalogYarn
        ? 'Reserved for the Weekender sweater.'
        : '';
    _replaceFiberRows(_catalogFiberRows(catalogYarn, seedCatalogYarn));
  }

  List<_FiberContentInput> _fiberRowsForYarn(Yarn yarn) {
    if (yarn.fiberContents.isNotEmpty) {
      return [
        for (final fiberContent in yarn.fiberContents)
          _FiberContentInput(
            fiber: fiberContent.fiber,
            percentage: fiberContent.percentage.toString(),
          ),
      ];
    }

    final legacyFiberContent = yarn.fiberContent?.trim();
    if (legacyFiberContent == null || legacyFiberContent.isEmpty) {
      return [_FiberContentInput()];
    }

    final rows = <_FiberContentInput>[];
    for (final part in legacyFiberContent.split(',')) {
      final match = RegExp(r'^\s*(\d+)\s*%\s*(.+?)\s*$').firstMatch(part);
      if (match == null) continue;
      rows.add(
        _FiberContentInput(fiber: match.group(2)!, percentage: match.group(1)!),
      );
    }

    return rows.isEmpty ? [_FiberContentInput()] : rows;
  }

  void _populateFormFromYarn(Yarn yarn) {
    if (_populatedYarnId == yarn.id) return;

    _editingYarn = yarn;
    _populatedYarnId = yarn.id;
    _selectedImageUrls
      ..clear()
      ..addAll(
        yarn.imageUrls
            .map((url) => url.trim())
            .where((url) => url.isNotEmpty)
            .take(_maxYarnImageCount),
      );
    _imageUrlController.clear();
    _colorFamily = _cleanText(yarn.colorFamily);
    _folder = _cleanText(yarn.folderName) ?? 'No folder';
    _selectedFolderId = yarn.folderIds.isEmpty ? null : yarn.folderIds.first;
    _yarnNameController.text = yarn.name;
    _brandController.text = yarn.brandName;
    _weightController.text = yarn.weightCategory ?? '';
    _wpiController.text = yarn.wpi?.toString() ?? '';
    _lengthController.text = _optionalIntInputText(yarn.yardage, 'yd');
    _unitWeightController.text = _optionalIntInputText(
      yarn.unitWeightGrams,
      'g',
    );
    _needleController.text = yarn.needleSize ?? '';
    _gaugeController.text = yarn.gauge ?? '';
    _colorwayController.text = yarn.colorway ?? '';
    _dyeLotController.text = yarn.dyeLot ?? '';
    _ballsController.text = yarn.skeinCount.toString();
    _priceController.text = _priceInputText(yarn.priceCents);
    _notesController.text = yarn.notes ?? '';
    _replaceFiberRows(_fiberRowsForYarn(yarn));
  }

  void _addFiberRow() {
    setState(() => _fiberRows.add(_FiberContentInput()));
  }

  void _removeFiberRow(int index) {
    final removed = _fiberRows[index];
    setState(() => _fiberRows.removeAt(index));
    removed.dispose();
  }

  List<YarnFiberContent>? _validatedFiberContents() {
    final fiberContents = <YarnFiberContent>[];

    for (final row in _fiberRows) {
      final rawFiber = row.fiberController.text.trim();
      final fiber = _normalizeFiberName(rawFiber);
      final percentageText = row.percentageController.text.trim();

      if ((fiber == null || fiber.isEmpty) && percentageText.isEmpty) continue;

      final percentage = _parseFirstInt(percentageText);
      if (fiber == null || fiber.isEmpty || percentage == null || percentage <= 0) {
        setState(() {
          _errorMessage =
              'Each fiber needs a name and a percentage from 1 to 100.';
        });
        return null;
      }
      if (percentage > 100) {
        setState(() {
          _errorMessage = 'Fiber percentages must be between 1 and 100.';
        });
        return null;
      }

      fiberContents.add(YarnFiberContent(fiber: fiber, percentage: percentage));
    }

    if (fiberContents.isEmpty) {
      setState(() {
        _errorMessage = 'Add at least one fiber and percentage.';
      });
      return null;
    }

    final totalPercentage = fiberContents.fold<int>(
      0,
      (total, fiberContent) => total + fiberContent.percentage,
    );
    if (totalPercentage != 100) {
      setState(() {
        _errorMessage = 'Fiber percentages must add up to 100%.';
      });
      return null;
    }

    return fiberContents;
  }

  Future<void> _moveEditingYarnToUsedUp(List<StashFolder> folders) async {
    if (_isSaving) return;

    final editingYarn = _editingYarn;
    if (editingYarn == null) {
      setState(() {
        _errorMessage = 'Unable to load yarn details. Try again.';
      });
      return;
    }

    final usedUpFolder = _usedUpFolder(folders);
    if (usedUpFolder == null) {
      setState(() {
        _errorMessage = 'Unable to find the Used Up folder.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final nextFolderIds = [usedUpFolder.id];

    try {
      await _yarnRepository.updateYarn(
        Yarn(
          id: editingYarn.id,
          ownerUid: editingYarn.ownerUid,
          collectionId: editingYarn.collectionId,
          brandName: editingYarn.brandName,
          name: editingYarn.name,
          colorway: editingYarn.colorway,
          colorFamily: editingYarn.colorFamily,
          dyeLot: editingYarn.dyeLot,
          weightCategory: editingYarn.weightCategory,
          wpi: editingYarn.wpi,
          fiberContent: editingYarn.fiberContent,
          fiberContents: editingYarn.fiberContents,
          yardage: editingYarn.yardage,
          unitWeightGrams: editingYarn.unitWeightGrams,
          needleSize: editingYarn.needleSize,
          gauge: editingYarn.gauge,
          skeinCount: editingYarn.skeinCount,
          priceCents: editingYarn.priceCents,
          status: YarnStatus.usedUp,
          imageUrls: editingYarn.imageUrls,
          folderName: usedUpFolder.name,
          folderIds: nextFolderIds,
          notes: editingYarn.notes,
          createdAt: editingYarn.createdAt,
          updatedAt: DateTime.now(),
        ),
      );

      await _folderRepository.syncYarnMembership(
        uid: editingYarn.ownerUid,
        collectionId: editingYarn.collectionId,
        yarnId: editingYarn.id,
        previousFolderIds: editingYarn.folderIds,
        nextFolderIds: nextFolderIds,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Yarn moved to Used Up.')),
      );

      widget.onPrimary();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Unable to move yarn to Used Up. Try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _moveEditingYarnIntoStash() async {
    if (_isSaving) return;

    final editingYarn = _editingYarn;
    if (editingYarn == null) {
      setState(() {
        _errorMessage = 'Unable to load yarn details. Try again.';
      });
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await _yarnRepository.updateYarn(
        Yarn(
          id: editingYarn.id,
          ownerUid: editingYarn.ownerUid,
          collectionId: editingYarn.collectionId,
          brandName: editingYarn.brandName,
          name: editingYarn.name,
          colorway: editingYarn.colorway,
          colorFamily: editingYarn.colorFamily,
          dyeLot: editingYarn.dyeLot,
          weightCategory: editingYarn.weightCategory,
          wpi: editingYarn.wpi,
          fiberContent: editingYarn.fiberContent,
          fiberContents: editingYarn.fiberContents,
          yardage: editingYarn.yardage,
          unitWeightGrams: editingYarn.unitWeightGrams,
          needleSize: editingYarn.needleSize,
          gauge: editingYarn.gauge,
          skeinCount: editingYarn.skeinCount,
          priceCents: editingYarn.priceCents,
          status: YarnStatus.inStash,
          imageUrls: _imageUrlsForSave().isEmpty
              ? editingYarn.imageUrls
              : _imageUrlsForSave(),
          folderName: null,
          folderIds: const [],
          notes: editingYarn.notes,
          createdAt: editingYarn.createdAt,
          updatedAt: DateTime.now(),
        ),
      );

      await _folderRepository.syncYarnMembership(
        uid: editingYarn.ownerUid,
        collectionId: editingYarn.collectionId,
        yarnId: editingYarn.id,
        previousFolderIds: editingYarn.folderIds,
        nextFolderIds: const [],
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Yarn moved back into your stash.')),
      );

      widget.onPrimary();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Unable to move yarn into stash. Try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _deleteEditingYarn() async {
    if (_isSaving) return;

    final editingYarn = _editingYarn;
    if (editingYarn == null) {
      setState(() {
        _errorMessage = 'Unable to load yarn details. Try again.';
      });
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: AppColors.ink.withValues(alpha: 0.35),
      builder: (context) => const DeleteYarnConfirmDialog(),
    );

    if (confirmed != true) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      await _folderRepository.syncYarnMembership(
        uid: editingYarn.ownerUid,
        collectionId: editingYarn.collectionId,
        yarnId: editingYarn.id,
        previousFolderIds: editingYarn.folderIds,
        nextFolderIds: const [],
      );

      for (final imageUrl in editingYarn.imageUrls) {
        await _deleteStorageImageIfPossible(imageUrl);
      }

      await _yarnRepository.deleteYarn(
        uid: editingYarn.ownerUid,
        collectionId: editingYarn.collectionId,
        yarnId: editingYarn.id,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Yarn deleted.')),
      );

      (widget.onDelete ?? widget.onPrimary)();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Unable to delete yarn. Try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  List<String> _mergeUploadedImageUrl(String uploadedUrl, List<String> existingUrls) {
    return [
      uploadedUrl,
      ...existingUrls.where((url) => url != uploadedUrl),
    ].take(_maxYarnImageCount).toList(growable: false);
  }

  Future<void> _saveYarn(List<StashFolder> folders) async {
    if (_isSaving) return;
    FocusScope.of(context).unfocus();

    final yarnName = _yarnNameController.text.trim();
    final brand = _brandController.text.trim();

    if (yarnName.isEmpty || brand.isEmpty) {
      setState(() {
        _errorMessage = 'Yarn name and brand are required.';
      });
      return;
    }

    final fiberContents = _validatedFiberContents();
    if (fiberContents == null) return;

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    final now = DateTime.now();
    final selectedFolder = _selectedFolder(folders);
    final selectedFolderId = selectedFolder?.id ?? _selectedFolderId;
    final hasFolder = _folder != 'No folder' && selectedFolderId != null;
    final folderName = hasFolder ? selectedFolder?.name ?? _folder : null;
    final folderIds = hasFolder ? [selectedFolderId] : const <String>[];
    final fiberContent = yarnFiberContentSummary(fiberContents);

    final isUsedUpFolder = _selectedFolderIsUsedUp(folders);
    final skeinCount = _parseFirstInt(_ballsController.text) ?? 1;

    try {
      if (widget.isEditing) {
        final editingYarn = _editingYarn;
        if (editingYarn == null) {
          setState(() {
            _errorMessage = 'Unable to load yarn details. Try again.';
            _isSaving = false;
          });
          return;
        }

        var imageUrlsToSave = _imageUrlsForSave();

        for (final imageFile in _selectedImageFiles) {
          final uploadedImageUrl = await _imageStorage.uploadYarnImage(
            uid: widget.userId,
            yarnId: editingYarn.id,
            imageFile: imageFile,
          );

          imageUrlsToSave = _mergeUploadedImageUrl(
            uploadedImageUrl,
            imageUrlsToSave,
          );
        }

        await _yarnRepository.updateYarn(
          Yarn(
            id: editingYarn.id,
            ownerUid: editingYarn.ownerUid,
            collectionId: editingYarn.collectionId,
            brandName: brand,
            name: yarnName,
            colorway: _trimmedOrNull(_colorwayController.text),
            colorFamily: _colorFamily,
            dyeLot: _trimmedOrNull(_dyeLotController.text),
            weightCategory: _normalizeWeightName(_weightController.text),
            wpi: _parseFirstInt(_wpiController.text),
            fiberContent: fiberContent,
            fiberContents: fiberContents,
            yardage: _parseFirstInt(_lengthController.text),
            unitWeightGrams: _parseFirstInt(_unitWeightController.text),
            needleSize: _trimmedOrNull(_needleController.text),
            gauge: _trimmedOrNull(_gaugeController.text),
            skeinCount: skeinCount,
            priceCents: _parsePriceCents(_priceController.text),
            status: isUsedUpFolder
                ? YarnStatus.usedUp
                : editingYarn.status == YarnStatus.usedUp
                ? YarnStatus.inStash
                : editingYarn.status,
            imageUrls: imageUrlsToSave,
            folderName: folderName,
            folderIds: folderIds,
            notes: _trimmedOrNull(_notesController.text),
            createdAt: editingYarn.createdAt,
            updatedAt: now,
          ),
        );

        for (final oldImageUrl in editingYarn.imageUrls) {
          if (!imageUrlsToSave.contains(oldImageUrl)) {
            await _deleteStorageImageIfPossible(oldImageUrl);
          }
        }

        await _folderRepository.syncYarnMembership(
          uid: editingYarn.ownerUid,
          collectionId: editingYarn.collectionId,
          yarnId: editingYarn.id,
          previousFolderIds: editingYarn.folderIds,
          nextFolderIds: folderIds,
        );
      } else {
        final initialImageUrls = _imageUrlsForSave();

        final createdYarn = await _yarnRepository.createYarn(
          uid: widget.userId,
          yarn: Yarn(
            id: '',
            ownerUid: widget.userId,
            collectionId: '',
            brandName: brand,
            name: yarnName,
            colorway: _trimmedOrNull(_colorwayController.text),
            colorFamily: _colorFamily,
            dyeLot: _trimmedOrNull(_dyeLotController.text),
            weightCategory: _normalizeWeightName(_weightController.text),
            wpi: _parseFirstInt(_wpiController.text),
            fiberContent: fiberContent,
            fiberContents: fiberContents,
            yardage: _parseFirstInt(_lengthController.text),
            unitWeightGrams: _parseFirstInt(_unitWeightController.text),
            needleSize: _trimmedOrNull(_needleController.text),
            gauge: _trimmedOrNull(_gaugeController.text),
            skeinCount: skeinCount,
            priceCents: _parsePriceCents(_priceController.text),
            status: isUsedUpFolder ? YarnStatus.usedUp : YarnStatus.inStash,
            imageUrls: initialImageUrls,
            folderName: folderName,
            folderIds: folderIds,
            notes: _trimmedOrNull(_notesController.text),
            createdAt: now,
            updatedAt: now,
          ),
        );

        var updatedImageUrls = initialImageUrls;

        for (final imageFile in _selectedImageFiles) {
          final uploadedImageUrl = await _imageStorage.uploadYarnImage(
            uid: widget.userId,
            yarnId: createdYarn.id,
            imageFile: imageFile,
          );

          updatedImageUrls = _mergeUploadedImageUrl(
            uploadedImageUrl,
            updatedImageUrls,
          );
        }

        if (_selectedImageFiles.isNotEmpty) {
          await _yarnRepository.updateYarn(
            Yarn(
              id: createdYarn.id,
              ownerUid: createdYarn.ownerUid,
              collectionId: createdYarn.collectionId,
              brandName: createdYarn.brandName,
              name: createdYarn.name,
              colorway: createdYarn.colorway,
              colorFamily: createdYarn.colorFamily,
              dyeLot: createdYarn.dyeLot,
              weightCategory: createdYarn.weightCategory,
              wpi: createdYarn.wpi,
              fiberContent: createdYarn.fiberContent,
              fiberContents: createdYarn.fiberContents,
              yardage: createdYarn.yardage,
              unitWeightGrams: createdYarn.unitWeightGrams,
              needleSize: createdYarn.needleSize,
              gauge: createdYarn.gauge,
              skeinCount: createdYarn.skeinCount,
              priceCents: createdYarn.priceCents,
              status: createdYarn.status,
              imageUrls: updatedImageUrls,
              folderName: createdYarn.folderName,
              folderIds: createdYarn.folderIds,
              notes: createdYarn.notes,
              createdAt: createdYarn.createdAt,
              updatedAt: DateTime.now(),
            ),
          );
        }

        await _folderRepository.syncYarnMembership(
          uid: createdYarn.ownerUid,
          collectionId: createdYarn.collectionId,
          yarnId: createdYarn.id,
          previousFolderIds: const [],
          nextFolderIds: folderIds,
        );
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.isEditing
                ? 'Yarn changes saved.'
                : 'Yarn added to your stash.',
          ),
        ),
      );
      widget.onPrimary();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = widget.isEditing
            ? 'Unable to save changes. Try again.'
            : 'Unable to save yarn. Try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Widget _editLoadState({required Widget child}) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 28),
      children: [
        NavRow(
          leading: CircleIconButton(
            icon: FontAwesomeIcons.xmark,
            onTap: widget.onBack,
          ),
        ),
        const SizedBox(height: 96),
        child,
      ],
    );
  }

  Widget _editMessageState({required String title, required String message}) {
    return _editLoadState(
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              letterSpacing: tightLetterSpacing,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: tightLetterSpacing,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEditForm() {
    final collectionId = widget.collectionId;
    final yarnId = widget.yarnId;
    if (collectionId == null || yarnId == null) {
      return _editMessageState(
        title: 'No yarn selected',
        message: 'Choose a yarn from your stash before editing it.',
      );
    }

    return StreamBuilder<Yarn?>(
      stream: _yarnRepository.watchYarn(
        uid: widget.userId,
        collectionId: collectionId,
        yarnId: yarnId,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _editMessageState(
            title: 'Unable to load yarn',
            message: 'Try returning to your stash and opening it again.',
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return _editLoadState(
            child: const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            ),
          );
        }

        final yarn = snapshot.data;
        if (yarn == null) {
          return _editMessageState(
            title: 'Yarn not found',
            message: 'This yarn may have been removed from your stash.',
          );
        }

        _populateFormFromYarn(yarn);
        return _buildFolderAwareForm();
      },
    );
  }

  Widget _buildFolderAwareForm() {
    final collectionId =
        widget.collectionId ?? FirestoreDocumentIds.defaultStashCollection;

    return StreamBuilder<List<StashFolder>>(
      stream: _folderRepository.watchFolders(
        uid: widget.userId,
        collectionId: collectionId,
      ),
      builder: (context, snapshot) {
        final folders = snapshot.data ?? const <StashFolder>[];
        return _buildForm(folders: folders);
      },
    );
  }

  Widget _buildForm({required List<StashFolder> folders}) {
    _syncSelectedFolderName(folders);

    return ListView(
      padding: const EdgeInsets.only(bottom: 28),
      children: [
        NavRow(
          leading: CircleIconButton(
            icon: widget.isEditing
                ? FontAwesomeIcons.xmark
                : FontAwesomeIcons.chevronLeft,
            onTap: _isSaving ? null : widget.onBack,
          ),
        ),
        const SizedBox(height: 16),
        NavTitle(widget.isEditing ? 'Edit stash item' : 'Add yarn'),
        const SizedBox(height: 20),
        CardSurface(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              YarnPhoto(
                url: _coverImageUrl,
                width: widget.isEditing ? 80 : 96,
                height: widget.isEditing ? 80 : 96,
                radius: widget.isEditing ? 22 : 24,
                fallbackColor: widget.startBlank
                    ? AppColors.cream
                    : const Color(0xFFB8D6E8),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const FieldLabel('Yarn name'),
                    InlineTextField(controller: _yarnNameController),
                    const SizedBox(height: 10),
                    const FieldLabel('Brand'),
                    InlineTextField(controller: _brandController, muted: true),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const SectionTitle('Yarn details'),
        const SizedBox(height: 12),
        _fiberContentField(),
        const SizedBox(height: 12),
        _editableAutofillGrid(),
        const SizedBox(height: 24),
        const SectionTitle('Your stash info'),
        const SizedBox(height: 12),
        InfoField(
          label: 'Colorway',
          child: InlineTextField(controller: _colorwayController, muted: true),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: InfoField(
                label: 'Color family',
                child: SelectField(
                  value: _colorFamily,
                  hintText: '',
                  items: _colorFamilyItems,
                  onChanged: (value) => setState(() => _colorFamily = value),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InfoField(
                label: 'Dye lot',
                child: InlineTextField(
                  controller: _dyeLotController,
                  muted: true,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: InfoField(
                label: 'Skeins',
                child: InlineTextField(
                  controller: _ballsController,
                  keyboardType: TextInputType.number,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: InfoField(
                label: 'Price',
                child: InlineTextField(
                  controller: _priceController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  muted: true,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        InfoField(
          label: 'Folder',
          child: SelectField(
            value: _folder,
            items: _folderOptions(folders),
            onChanged: (value) => _selectFolder(value, folders),
          ),
        ),
        const SizedBox(height: 12),
        InfoField(
          label: 'Notes',
          minHeight: 92,
          child: InlineTextField(
            controller: _notesController,
            keyboardType: TextInputType.multiline,
            maxLines: 3,
            muted: true,
          ),
        ),
        const SizedBox(height: 12),
        InfoField(
          label: 'Images',
          minHeight: 120,
          child: _imagePickerField(),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 12),
          _AuthMessage(message: _errorMessage!, isError: true),
        ],
        const SizedBox(height: 20),
        PrimaryButton(
          label: _isSaving
              ? 'Saving...'
              : widget.isEditing
              ? 'Save changes'
              : 'Add to collection',
          icon: widget.isEditing
              ? FontAwesomeIcons.check
              : FontAwesomeIcons.plus,
          onTap: _isSaving ? null : () => _saveYarn(folders),
        ),
        if (widget.isEditing) ...[
          const SizedBox(height: 12),
          SecondaryButton(
            label: _editingYarn?.status == YarnStatus.usedUp
                ? 'Move into stash'
                : 'Move to used up',
            icon: _editingYarn?.status == YarnStatus.usedUp
                ? FontAwesomeIcons.basketShopping
                : FontAwesomeIcons.boxArchive,
            onTap: _isSaving
                ? null
                : _editingYarn?.status == YarnStatus.usedUp
                ? _moveEditingYarnIntoStash
                : () => _moveEditingYarnToUsedUp(folders),
          ),
          const SizedBox(height: 12),
          SecondaryButton(
            label: 'Remove from stash',
            icon: FontAwesomeIcons.trashCan,
            foregroundColor: AppColors.danger,
            onTap: _isSaving ? null : _deleteEditingYarn,
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isEditing) return _buildEditForm();

    return _buildFolderAwareForm();
  }

  @override
  void dispose() {
    _yarnNameController.dispose();
    _brandController.dispose();
    _weightController.dispose();
    _wpiController.dispose();
    _lengthController.dispose();
    _unitWeightController.dispose();
    _needleController.dispose();
    _gaugeController.dispose();
    _colorwayController.dispose();
    _dyeLotController.dispose();
    _ballsController.dispose();
    _priceController.dispose();
    _notesController.dispose();
    _imageUrlController.dispose();
    for (final fiberRow in _fiberRows) {
      fiberRow.dispose();
    }
    super.dispose();
  }

  Widget _editableAutofillGrid() {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      mainAxisExtent: 76,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        InfoField(
          label: 'Weight',
          child: InlineTextField(controller: _weightController),
        ),
        InfoField(
          label: 'WPI',
          child: InlineTextField(
            controller: _wpiController,
            keyboardType: TextInputType.number,
          ),
        ),
        InfoField(
          label: 'Yardage',
          child: InlineTextField(controller: _lengthController),
        ),
        InfoField(
          label: 'Grams',
          child: InlineTextField(controller: _unitWeightController),
        ),
        InfoField(
          label: 'Needle Size',
          child: InlineTextField(controller: _needleController),
        ),
        InfoField(
          label: 'Gauge(sts)',
          child: InlineTextField(controller: _gaugeController),
        ),
      ],
    );
  }

  Widget _fiberContentField() {
    return InfoField(
      label: 'Fiber content',
      minHeight: 112,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Expanded(child: FieldLabel('Fiber')),
              SizedBox(width: 12),
              SizedBox(width: 92, child: FieldLabel('%')),
              SizedBox(width: 38),
            ],
          ),
          const SizedBox(height: 6),
          for (var index = 0; index < _fiberRows.length; index++) ...[
            _FiberContentRow(
              fiberController: _fiberRows[index].fiberController,
              percentageController: _fiberRows[index].percentageController,
              onRemove: _fiberRows.length > 1
                  ? () => _removeFiberRow(index)
                  : null,
            ),
            if (index != _fiberRows.length - 1) const SizedBox(height: 10),
          ],
          const SizedBox(height: 10),
          TextButton.icon(
            onPressed: _addFiberRow,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.accentDark,
              minimumSize: const Size(0, 32),
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: const FaIcon(FontAwesomeIcons.plus, size: 12),
            label: const Text(
              'Add fiber',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedImagePreview extends StatelessWidget {
  const _SelectedImagePreview({
    required this.imageUrl,
    required this.fallbackColor,
    required this.onRemove,
  });

  final String imageUrl;
  final Color fallbackColor;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        YarnPhoto(
          url: imageUrl,
          width: 72,
          height: 72,
          radius: 18,
          fallbackColor: fallbackColor,
        ),
        Positioned(
          top: -7,
          right: -7,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: AppColors.ink,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.card, width: 2),
              ),
              child: const Center(
                child: FaIcon(
                  FontAwesomeIcons.xmark,
                  color: Colors.white,
                  size: 11,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SelectedLocalImagePreview extends StatelessWidget {
  const _SelectedLocalImagePreview({
    required this.imageFile,
    required this.onRemove,
  });

  final File imageFile;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: Image.file(
            imageFile,
            width: 72,
            height: 72,
            fit: BoxFit.cover,
          ),
        ),
        Positioned(
          top: -7,
          right: -7,
          child: GestureDetector(
            onTap: onRemove,
            child: Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: AppColors.ink,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.card, width: 2),
              ),
              child: const Center(
                child: FaIcon(
                  FontAwesomeIcons.xmark,
                  color: Colors.white,
                  size: 11,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _FiberContentInput {
  _FiberContentInput({String fiber = '', String percentage = ''})
    : fiberController = TextEditingController(text: fiber),
      percentageController = TextEditingController(text: percentage);

  final TextEditingController fiberController;
  final TextEditingController percentageController;

  void dispose() {
    fiberController.dispose();
    percentageController.dispose();
  }
}

class _FiberContentRow extends StatelessWidget {
  const _FiberContentRow({
    required this.fiberController,
    required this.percentageController,
    this.onRemove,
  });

  final TextEditingController fiberController;
  final TextEditingController percentageController;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _FiberInputBox(
            child: InlineTextField(
              controller: fiberController,
              hintText: 'Merino',
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 92,
          child: _FiberInputBox(
            child: Row(
              children: [
                Expanded(
                  child: InlineTextField(
                    controller: percentageController,
                    keyboardType: TextInputType.number,
                    hintText: '100',
                  ),
                ),
                const SizedBox(width: 4),
                const Text(
                  '%',
                  style: TextStyle(
                    color: AppColors.accentDark,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    letterSpacing: tightLetterSpacing,
                  ),
                ),
              ],
            ),
          ),
        ),
        SizedBox(
          width: 38,
          height: 44,
          child: onRemove == null
              ? const SizedBox.shrink()
              : IconButton(
                  tooltip: 'Remove fiber',
                  onPressed: onRemove,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints.tightFor(
                    width: 36,
                    height: 44,
                  ),
                  icon: const FaIcon(
                    FontAwesomeIcons.xmark,
                    size: 14,
                    color: AppColors.muted,
                  ),
                ),
        ),
      ],
    );
  }
}

class _FiberInputBox extends StatelessWidget {
  const _FiberInputBox({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.accent.withValues(alpha: 0.35),
          width: 1.3,
        ),
      ),
      child: child,
    );
  }
}

class FoldersScreen extends StatelessWidget {
  const FoldersScreen({
    super.key,
    required this.userId,
    required this.collectionId,
    required this.onFolderTap,
    this.folderRepository,
    this.yarnRepository,
  });

  final String userId;
  final String collectionId;
  final ValueChanged<StashFolder> onFolderTap;
  final StashFolderRepository? folderRepository;
  final YarnRepository? yarnRepository;

  Future<void> _openCreateFolder(BuildContext context) async {
    final result = await showDialog<_FolderEditResult>(
      context: context,
      barrierColor: AppColors.ink.withValues(alpha: 0.35),
      builder: (context) => const FolderEditDialog(
        initialName: '',
        title: 'Create folder',
        showDelete: false,
      ),
    );
    if (result == null || result.name.isEmpty) return;

    final repository = folderRepository ?? StashFolderRepository();
    try {
      await repository.createFolder(
        uid: userId,
        collectionId: collectionId,
        name: result.name,
        iconKey: result.iconKey,
        colorValue: result.colorValue,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Folder created.')));
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to create folder. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final foldersRepository = folderRepository ?? StashFolderRepository();
    final yarnsRepository = yarnRepository ?? YarnRepository();

    return ListView(
      padding: const EdgeInsets.only(bottom: 18),
      children: [
        NavRow(
          title: 'Folders',
          trailing: CircleIconButton(
            icon: FontAwesomeIcons.plus,
            label: 'Create folder',
            onTap: () => _openCreateFolder(context),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Group yarn by project, fiber, season, or storage bin.',
          style: TextStyle(
            color: AppColors.muted,
            fontSize: 15,
            height: 1.35,
            fontWeight: FontWeight.w700,
            letterSpacing: tightLetterSpacing,
          ),
        ),
        const SizedBox(height: 20),
        StreamBuilder<List<StashFolder>>(
          stream: foldersRepository.watchFolders(
            uid: userId,
            collectionId: collectionId,
          ),
          builder: (context, folderSnapshot) {
            if (folderSnapshot.hasError) {
              return const _FolderLoadState(
                title: 'Unable to load folders',
                message: 'Try again in a moment.',
              );
            }

            if (folderSnapshot.connectionState == ConnectionState.waiting &&
                !folderSnapshot.hasData) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 42),
                  child: CircularProgressIndicator(color: AppColors.accent),
                ),
              );
            }

            final folders = folderSnapshot.data ?? const <StashFolder>[];
            if (folders.isEmpty) {
              return const _FolderLoadState(
                title: 'No folders yet',
                message: 'Create a folder to organize your stash.',
              );
            }

            return StreamBuilder<List<Yarn>>(
              stream: yarnsRepository.watchYarns(
                uid: userId,
                collectionId: collectionId,
              ),
              builder: (context, yarnSnapshot) {
                final yarns = yarnSnapshot.data ?? const <Yarn>[];

                return GridView.count(
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  mainAxisExtent: 156,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    for (final folder in folders)
                      _FolderCard(
                        title: folder.name,
                        subtitle: _folderSubtitle(
                          folder,
                          _yarnsForFolder(folder, yarns),
                        ),
                        icon: _folderIconForKey(folder.iconKey),
                        background: _folderBackgroundColor(folder),
                        foreground: _folderForegroundColor(
                          _folderBackgroundColor(folder),
                        ),
                        onTap: () => onFolderTap(folder),
                      ),
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class FolderDetailScreen extends StatelessWidget {
  const FolderDetailScreen({
    super.key,
    required this.userId,
    required this.collectionId,
    required this.folderId,
    required this.onBack,
    required this.onYarnTap,
    this.folderRepository,
    this.yarnRepository,
  });

  final String userId;
  final String collectionId;
  final String? folderId;
  final VoidCallback onBack;
  final ValueChanged<Yarn> onYarnTap;
  final StashFolderRepository? folderRepository;
  final YarnRepository? yarnRepository;

  Future<void> _openFolderEditor(
    BuildContext context,
    StashFolder folder,
  ) async {
    final repository = folderRepository ?? StashFolderRepository();
    final result = await showDialog<_FolderEditResult>(
      context: context,
      barrierColor: AppColors.ink.withValues(alpha: 0.35),
      builder: (context) => FolderEditDialog(
        initialName: folder.name,
        initialIconKey: folder.iconKey,
        initialColorValue: folder.colorValue,
        showDelete: !folder.isSystem,
      ),
    );
    if (result == null) return;

    try {
      switch (result.action) {
        case _FolderEditAction.save:
          if (result.name.isNotEmpty) {
            await repository.updateFolder(
              folder.copyWith(
                name: result.name,
                iconKey: result.iconKey,
                colorValue: result.colorValue,
              ),
            );
          }
        case _FolderEditAction.delete:
          await repository.deleteFolder(
            uid: userId,
            collectionId: collectionId,
            folderId: folder.id,
          );
          if (context.mounted) onBack();
      }
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to update folder. Try again.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedFolderId = folderId;
    if (selectedFolderId == null) {
      return _FolderDetailMessageState(
        onBack: onBack,
        title: 'No folder selected',
        message: 'Choose a folder to view its yarns.',
      );
    }

    final foldersRepository = folderRepository ?? StashFolderRepository();
    final yarnsRepository = yarnRepository ?? YarnRepository();

    return StreamBuilder<StashFolder?>(
      stream: foldersRepository.watchFolder(
        uid: userId,
        collectionId: collectionId,
        folderId: selectedFolderId,
      ),
      builder: (context, folderSnapshot) {
        if (folderSnapshot.hasError) {
          return _FolderDetailMessageState(
            onBack: onBack,
            title: 'Unable to load folder',
            message: 'Try returning to your folders and opening it again.',
          );
        }

        if (folderSnapshot.connectionState == ConnectionState.waiting &&
            !folderSnapshot.hasData) {
          return _FolderDetailLoadingState(onBack: onBack);
        }

        final folder = folderSnapshot.data;
        if (folder == null) {
          return _FolderDetailMessageState(
            onBack: onBack,
            title: 'Folder not found',
            message: 'This folder may have been deleted.',
          );
        }

        return StreamBuilder<List<Yarn>>(
          stream: yarnsRepository.watchYarns(
            uid: userId,
            collectionId: collectionId,
          ),
          builder: (context, yarnSnapshot) {
            final yarns = _yarnsForFolder(
              folder,
              yarnSnapshot.data ?? const <Yarn>[],
            );

            return _FolderDetailContent(
              folder: folder,
              yarns: yarns,
              onBack: onBack,
              onEdit: () => _openFolderEditor(context, folder),
              onYarnTap: onYarnTap,
            );
          },
        );
      },
    );
  }
}

class _FolderLoadState extends StatelessWidget {
  const _FolderLoadState({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 46),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: tightLetterSpacing,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: tightLetterSpacing,
            ),
          ),
        ],
      ),
    );
  }
}

class _FolderDetailLoadingState extends StatelessWidget {
  const _FolderDetailLoadingState({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 28),
      children: [
        NavRow(
          leading: CircleIconButton(
            icon: FontAwesomeIcons.chevronLeft,
            onTap: onBack,
          ),
        ),
        const SizedBox(height: 96),
        const Center(child: CircularProgressIndicator(color: AppColors.accent)),
      ],
    );
  }
}

class _FolderDetailMessageState extends StatelessWidget {
  const _FolderDetailMessageState({
    required this.onBack,
    required this.title,
    required this.message,
  });

  final VoidCallback onBack;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 28),
      children: [
        NavRow(
          leading: CircleIconButton(
            icon: FontAwesomeIcons.chevronLeft,
            onTap: onBack,
          ),
        ),
        const SizedBox(height: 96),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            letterSpacing: tightLetterSpacing,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            letterSpacing: tightLetterSpacing,
          ),
        ),
      ],
    );
  }
}

class _FolderDetailContent extends StatefulWidget {
  const _FolderDetailContent({
    required this.folder,
    required this.yarns,
    required this.onBack,
    required this.onEdit,
    required this.onYarnTap,
  });

  final StashFolder folder;
  final List<Yarn> yarns;
  final VoidCallback onBack;
  final VoidCallback onEdit;
  final ValueChanged<Yarn> onYarnTap;

  @override
  State<_FolderDetailContent> createState() => _FolderDetailContentState();
}

class _FolderDetailContentState extends State<_FolderDetailContent> {
  late final TextEditingController _searchController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesSearch(Yarn yarn) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return true;

    final searchableText = [
      _yarnTitle(yarn),
      _yarnSubtitle(yarn),
      yarn.name,
      yarn.brandName,
      yarn.colorway,
      yarn.colorFamily,
      yarn.weightCategory,
      yarn.dyeLot,
      yarn.notes,
      yarn.fiberContent,
      ...yarn.fiberContents.map((fiber) => fiber.fiber),
    ].whereType<String>().join(' ').toLowerCase();

    return searchableText.contains(query);
  }

  @override
  Widget build(BuildContext context) {
    final folder = widget.folder;
    final filteredYarns = widget.yarns
        .where(_matchesSearch)
        .toList(growable: false);
    final background = _folderBackgroundColor(folder);
    return ListView(
      padding: const EdgeInsets.only(bottom: 28),
      children: [
        NavRow(
          leading: CircleIconButton(
            icon: FontAwesomeIcons.chevronLeft,
            onTap: widget.onBack,
          ),
          trailing: CircleIconButton(
            icon: FontAwesomeIcons.pen,
            label: 'Edit folder',
            onTap: widget.onEdit,
          ),
        ),
        const SizedBox(height: 20),
        CardSurface(
          radius: 28,
          padding: const EdgeInsets.all(18),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.card, Color(0xFFFFF8F0)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              IconBadge(
                icon: _folderIconForKey(folder.iconKey),
                background: background,
                foreground: _folderForegroundColor(background),
                size: 56,
                iconSize: 20,
              ),
              const SizedBox(height: 18),
              NavTitle(folder.name),
              const SizedBox(height: 8),
              Text(
                _folderSubtitle(folder, widget.yarns),
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: tightLetterSpacing,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SearchBox(
          text: 'Search in ${folder.name}',
          controller: _searchController,
          onChanged: (value) {
            setState(() {
              _searchQuery = value;
            });
          },
        ),
        const SizedBox(height: 16),
        if (widget.yarns.isEmpty)
          const _FolderLoadState(
            title: 'No yarns here yet',
            message:
            'Assign yarn to this folder from the add or edit yarn page.',
          )
        else if (filteredYarns.isEmpty)
          const _FolderLoadState(
            title: 'No yarn matches your search',
            message: 'Try searching by name, brand, colorway, weight, or fiber.',
          )
        else
          for (var index = 0; index < filteredYarns.length; index++) ...[
            _YarnListCard(
              imageUrl: filteredYarns[index].imageUrls.isEmpty
                  ? ''
                  : filteredYarns[index].imageUrls.first,
              title: _yarnTitle(filteredYarns[index]),
              subtitle: _folderYarnSubtitle(filteredYarns[index]),
              detail: _folderYarnDetail(filteredYarns[index]),
              showChevron: true,
              fallbackColor: _fallbackColorForYarn(filteredYarns[index]),
              onTap: () => widget.onYarnTap(filteredYarns[index]),
            ),
            if (index != filteredYarns.length - 1) const SizedBox(height: 12),
          ],
      ],
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.userId,
    required this.collectionId,
    required this.displayName,
    required this.onSettings,
    this.yarnRepository,
    this.folderRepository,
    this.userRepository,
  });

  final String userId;
  final String collectionId;
  final String displayName;
  final VoidCallback onSettings;
  final YarnRepository? yarnRepository;
  final StashFolderRepository? folderRepository;
  final UserRepository? userRepository;

  @override
  Widget build(BuildContext context) {
    final yarnsRepository = yarnRepository ?? YarnRepository();
    final foldersRepository = folderRepository ?? StashFolderRepository();
    final usersRepository = userRepository ?? UserRepository();

    return StreamBuilder<AppUser?>(
      stream: usersRepository.watchUser(userId),
      builder: (context, userSnapshot) {
        final profileName = _profileDisplayName(userSnapshot.data, displayName);

        return ListView(
          padding: const EdgeInsets.only(bottom: 18),
          children: [
            NavRow(
              title: 'Profile',
              trailing: CircleIconButton(
                icon: FontAwesomeIcons.gear,
                onTap: onSettings,
              ),
            ),
            const SizedBox(height: 16),
            CardSurface(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      color: AppColors.cream,
                      borderRadius: BorderRadius.all(Radius.circular(24)),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(4),
                      child: IconBadge(
                        icon: FontAwesomeIcons.basketShopping,
                        background: AppColors.rose,
                        foreground: AppColors.accentDark,
                        size: 56,
                        iconSize: 23,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      profileName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: tightLetterSpacing,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            StreamBuilder<List<Yarn>>(
              stream: yarnsRepository.watchYarns(
                uid: userId,
                collectionId: collectionId,
              ),
              builder: (context, yarnSnapshot) {
                if (yarnSnapshot.hasError) {
                  return const _ProfileLoadState(
                    title: 'Unable to load stash data',
                    message: 'Try opening your profile again in a moment.',
                  );
                }

                if (yarnSnapshot.connectionState == ConnectionState.waiting &&
                    !yarnSnapshot.hasData) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 42),
                      child: CircularProgressIndicator(color: AppColors.accent),
                    ),
                  );
                }

                return StreamBuilder<List<StashFolder>>(
                  stream: foldersRepository.watchFolders(
                    uid: userId,
                    collectionId: collectionId,
                  ),
                  builder: (context, folderSnapshot) {
                    final stats = _ProfileStats.fromStash(
                      yarnSnapshot.data ?? const <Yarn>[],
                      folderSnapshot.data ?? const <StashFolder>[],
                    );
                    return _ProfileStatsContent(stats: stats);
                  },
                );
              },
            ),
          ],
        );
      },
    );
  }
}

class _ProfileStats {
  const _ProfileStats({
    required this.yarnCount,
    required this.skeinCount,
    required this.totalGrams,
    required this.totalYardage,
    required this.folderCount,
    required this.usedUpCount,
    required this.fiberRows,
    required this.weightRows,
    required this.statusRows,
  });

  final int yarnCount;
  final int skeinCount;
  final int totalGrams;
  final int totalYardage;
  final int folderCount;
  final int usedUpCount;
  final List<ProgressRow> fiberRows;
  final List<ProgressRow> weightRows;
  final List<ProgressRow> statusRows;

  bool get hasYarn => yarnCount > 0;

  factory _ProfileStats.fromStash(List<Yarn> yarns, List<StashFolder> folders) {
    final activeYarns = yarns
        .where((yarn) => yarn.status != YarnStatus.usedUp)
        .toList(growable: false);

    final totalSkeins = activeYarns.fold<int>(
      0,
          (total, yarn) => total + yarn.skeinCount,
    );

    final totalGrams = activeYarns.fold<int>(0, (total, yarn) {
      final grams = yarn.unitWeightGrams;
      return total + (grams == null ? 0 : grams * yarn.skeinCount);
    });

    final totalYardage = _totalYardageForYarns(activeYarns);

    return _ProfileStats(
      yarnCount: activeYarns.length,
      skeinCount: totalSkeins,
      totalGrams: totalGrams,
      totalYardage: totalYardage,
      folderCount: folders.length,
      usedUpCount: yarns
          .where((yarn) => yarn.status == YarnStatus.usedUp)
          .length,
      fiberRows: _topProgressRows(_fiberBreakdown(activeYarns), maxRows: 4),
      weightRows: _topProgressRows(_weightBreakdown(activeYarns), maxRows: 4),
      statusRows: _topProgressRows(_statusBreakdown(activeYarns), maxRows: 4),
    );
  }
}

String _compactNumber(int value) {
  if (value < 1000) return value.toString();

  final compact = value / 1000;
  if (compact >= 10 || compact == compact.roundToDouble()) {
    return '${compact.round()}k';
  }

  return '${compact.toStringAsFixed(1)}k';
}

Map<String, double> _fiberBreakdown(List<Yarn> yarns) {
  final breakdown = <String, double>{};

  for (final yarn in yarns) {
    final multiplier = yarn.skeinCount <= 0 ? 1 : yarn.skeinCount;
    if (yarn.fiberContents.isNotEmpty) {
      for (final fiberContent in yarn.fiberContents) {
        final label = _normalizeFiberName(fiberContent.fiber) ?? ' ';
        breakdown[label] =
            (breakdown[label] ?? 0) + fiberContent.percentage * multiplier;
      }
      continue;
    }

    final legacy = _cleanText(yarn.fiberContent);
    if (legacy == null) {
      breakdown[' '] = (breakdown[' '] ?? 0) + 100 * multiplier;
      continue;
    }

    var parsedAny = false;
    for (final part in legacy.split(',')) {
      final match = RegExp(r'^\s*(\d+)\s*%\s*(.+?)\s*$').firstMatch(part);
      if (match == null) continue;

      parsedAny = true;
      final label = _normalizeFiberName(match.group(2)) ?? ' ';
      final percent = int.tryParse(match.group(1)!) ?? 0;
      breakdown[label] = (breakdown[label] ?? 0) + percent * multiplier;
    }

    if (!parsedAny) {
      final label = _normalizeFiberName(legacy) ?? legacy;
      breakdown[label] = (breakdown[label] ?? 0) + 100 * multiplier;
    }
  }

  return breakdown;
}

Map<String, double> _weightBreakdown(List<Yarn> yarns) {
  final breakdown = <String, double>{};

  for (final yarn in yarns) {
    final label = _normalizeWeightName(yarn.weightCategory) ?? ' ';
    final amount = yarn.skeinCount <= 0 ? 1 : yarn.skeinCount;
    breakdown[label] = (breakdown[label] ?? 0) + amount;
  }

  return breakdown;
}

Map<String, double> _statusBreakdown(List<Yarn> yarns) {
  final breakdown = <String, double>{};

  for (final yarn in yarns) {
    final label = _statusLabel(yarn.status);
    breakdown[label] = (breakdown[label] ?? 0) + 1;
  }

  return breakdown;
}

List<ProgressRow> _topProgressRows(
  Map<String, double> values, {
  required int maxRows,
}) {
  if (values.isEmpty) {
    return const [ProgressRow(label: ' ', percent: 100)];
  }

  final entries = values.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final total = entries.fold<double>(0, (sum, entry) => sum + entry.value);
  if (total <= 0) {
    return const [ProgressRow(label: ' ', percent: 100)];
  }

  final visible = entries.take(maxRows).toList();
  final hidden = entries
      .skip(maxRows)
      .fold<double>(0, (sum, entry) => sum + entry.value);
  if (hidden > 0) {
    visible.add(MapEntry('Other', hidden));
  }

  return [
    for (final entry in visible)
      ProgressRow(
        label: entry.key,
        percent: ((entry.value / total) * 100).round().clamp(1, 100),
      ),
  ];
}

class _ProfileStatsContent extends StatelessWidget {
  const _ProfileStatsContent({required this.stats});

  final _ProfileStats stats;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle('Stash statistics'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: StatCard(
                value: stats.skeinCount.toString(),
                label: 'Skeins',
                centered: true,
                valueSize: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                value: _compactNumber(stats.totalGrams),
                label: 'Grams',
                centered: true,
                valueSize: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                value: _compactNumber(stats.totalYardage),
                label: 'Yards',
                centered: true,
                valueSize: 24,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        if (!stats.hasYarn)
          const _ProfileLoadState(
            title: 'No stash data yet',
            message: 'Add yarn to see your profile statistics.',
          )
        else ...[
          _ProgressCard(title: 'Fiber content', rows: stats.fiberRows),
          const SizedBox(height: 16),
          _ProgressCard(title: 'Weight', rows: stats.weightRows),
        ],
      ],
    );
  }
}

class _ProfileLoadState extends StatelessWidget {
  const _ProfileLoadState({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 34),
      child: Column(
        children: [
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: tightLetterSpacing,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 15,
              fontWeight: FontWeight.w700,
              letterSpacing: tightLetterSpacing,
            ),
          ),
        ],
      ),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.userId,
    required this.authService,
    required this.currentDisplayName,
    required this.currentEmail,
    required this.onBack,
    required this.onSignOut,
    required this.onProfileChanged,
    this.userRepository,
  });

  final String userId;
  final AuthService authService;
  final String? currentDisplayName;
  final String? currentEmail;
  final VoidCallback onBack;
  final VoidCallback onSignOut;
  final VoidCallback onProfileChanged;
  final UserRepository? userRepository;

  Future<void> _openAccountSettings(
    BuildContext context,
    _SettingsProfile profile,
  ) async {
    final emailVerificationSent = await showDialog<bool>(
      context: context,
      barrierColor: AppColors.ink.withValues(alpha: 0.35),
      builder: (context) => AccountSettingsDialog(
        authService: authService,
        initialDisplayName: profile.displayName,
        initialEmail: profile.email,
      ),
    );

    if (emailVerificationSent == null) return;

    onProfileChanged();
    if (!context.mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          emailVerificationSent
              ? 'Profile saved. Check your email to confirm the new address.'
              : 'Profile saved.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final usersRepository = userRepository ?? UserRepository();

    return StreamBuilder<AppUser?>(
      stream: usersRepository.watchUser(userId),
      builder: (context, snapshot) {
        final profile = _settingsProfile(
          appUser: snapshot.data,
          authDisplayName: currentDisplayName,
          authEmail: currentEmail,
        );

        return ListView(
          padding: const EdgeInsets.only(bottom: 28),
          children: [
            NavRow(
              leading: CircleIconButton(
                icon: FontAwesomeIcons.chevronLeft,
                onTap: onBack,
              ),
            ),
            const SizedBox(height: 16),
            const NavTitle('Settings'),
            const SizedBox(height: 20),
            CardSurface(
              padding: const EdgeInsets.all(8),
              child: _SettingsRow(
                title: 'Account',
                subtitle: profile.accountSummary,
                icon: FontAwesomeIcons.user,
                background: AppColors.rose,
                foreground: AppColors.accentDark,
                onTap: () => _openAccountSettings(context, profile),
              ),
            ),
            const SizedBox(height: 24),
            SecondaryButton(
              label: 'Sign out',
              foregroundColor: AppColors.danger,
              onTap: onSignOut,
            ),
          ],
        );
      },
    );
  }
}

class FolderEditDialog extends StatefulWidget {
  const FolderEditDialog({
    super.key,
    required this.initialName,
    this.initialIconKey = 'folder',
    this.initialColorValue = 0xFFF6D9CD,
    this.title = 'Edit folder',
    this.showDelete = true,
  });

  final String initialName;
  final String initialIconKey;
  final int initialColorValue;
  final String title;
  final bool showDelete;

  @override
  State<FolderEditDialog> createState() => _FolderEditDialogState();
}

enum _FolderEditAction { save, delete }

class _FolderEditResult {
  const _FolderEditResult.save(
    this.name, {
    required this.iconKey,
    required this.colorValue,
  }) : action = _FolderEditAction.save;

  const _FolderEditResult.delete()
    : action = _FolderEditAction.delete,
      name = '',
      iconKey = 'folder',
      colorValue = 0xFFF6D9CD;

  final _FolderEditAction action;
  final String name;
  final String iconKey;
  final int colorValue;
}

class _FolderEditDialogState extends State<FolderEditDialog> {
  late final TextEditingController _controller;
  int _selectedIcon = 0;
  int _selectedColor = 0;
  Color? _customColor;

  final _iconKeys = const [
    'folder',
    'shirt',
    'socks',
    'sun',
    'boxArchive',
    'circleCheck',
  ];

  static const _customColorIndex = 4;

  final _presetColorValues = const [
    0xFFF6D9CD,
    0xFFDCE7D7,
    0xFFF7E7C6,
    0xFFE7DDF6,
  ];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
    final iconIndex = _iconKeys.indexOf(widget.initialIconKey);
    _selectedIcon = iconIndex < 0 ? 0 : iconIndex;

    final colorIndex = _presetColorValues.indexOf(widget.initialColorValue);
    if (colorIndex < 0) {
      _customColor = Color(widget.initialColorValue);
      _selectedColor = _customColorIndex;
    } else {
      _selectedColor = colorIndex;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _openCustomColorPicker() async {
    final color = await showDialog<Color>(
      context: context,
      barrierColor: AppColors.ink.withValues(alpha: 0.35),
      builder: (context) =>
          CustomColorDialog(initialColor: _customColor ?? AppColors.accent),
    );

    if (color != null) {
      setState(() {
        _customColor = color;
        _selectedColor = _customColorIndex;
      });
    }
  }

  void _saveFolder() {
    Navigator.pop(
      context,
      _FolderEditResult.save(
        _controller.text.trim(),
        iconKey: _iconKeys[_selectedIcon],
        colorValue: _selectedColor == _customColorIndex
            ? (_customColor ?? AppColors.accent).toARGB32()
            : _presetColorValues[_selectedColor],
      ),
    );
  }

  Future<void> _deleteFolder() async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierColor: AppColors.ink.withValues(alpha: 0.35),
      builder: (context) => const DeleteFolderConfirmDialog(),
    );

    if (confirmed == true && mounted) {
      Navigator.pop(context, const _FolderEditResult.delete());
    }
  }

  @override
  Widget build(BuildContext context) {
    return ModalCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: tightLetterSpacing,
                  ),
                ),
              ),
              CircleIconButton(
                icon: FontAwesomeIcons.xmark,
                size: 36,
                iconSize: 15,
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AuthField(label: 'Name', controller: _controller),
          const SizedBox(height: 16),
          const Align(
            alignment: Alignment.centerLeft,
            child: FieldLabel('Icon'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i < _iconKeys.length; i++) ...[
                Expanded(
                  child: ChoiceButton(
                    label: '',
                    icon: _folderIconForKey(_iconKeys[i]),
                    selected: _selectedIcon == i,
                    onTap: () => setState(() => _selectedIcon = i),
                  ),
                ),
                if (i < _iconKeys.length - 1) const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: 16),
          const Align(
            alignment: Alignment.centerLeft,
            child: FieldLabel('Icon color'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              for (var i = 0; i < _presetColorValues.length; i++) ...[
                Expanded(
                  child: SwatchButton(
                    color: Color(_presetColorValues[i]),
                    selected: _selectedColor == i,
                    onTap: () => setState(() => _selectedColor = i),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: SwatchButton(
                  color: _customColor ?? const Color(0xFFE1DEDA),
                  selected: _selectedColor == _customColorIndex,
                  icon: FontAwesomeIcons.plus,
                  iconColor: _selectedColor == _customColorIndex
                      ? _folderForegroundColor(_customColor ?? AppColors.accent)
                      : AppColors.muted,
                  onTap: _openCustomColorPicker,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              if (widget.showDelete) ...[
                Expanded(
                  child: SecondaryButton(
                    label: 'Delete',
                    foregroundColor: AppColors.danger,
                    onTap: _deleteFolder,
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: SecondaryButton(
                  label: 'Cancel',
                  onTap: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: PrimaryButton(
                  label: 'Save',
                  height: 48,
                  onTap: _saveFolder,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class DeleteYarnConfirmDialog extends StatelessWidget {
  const DeleteYarnConfirmDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return ModalCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Delete yarn?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: tightLetterSpacing,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Are you sure you want to delete this yarn?',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 15,
              height: 1.35,
              fontWeight: FontWeight.w700,
              letterSpacing: tightLetterSpacing,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  label: 'No',
                  height: 48,
                  onTap: () => Navigator.pop(context, false),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SecondaryButton(
                  label: 'Yes',
                  foregroundColor: AppColors.danger,
                  onTap: () => Navigator.pop(context, true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class DeleteFolderConfirmDialog extends StatelessWidget {
  const DeleteFolderConfirmDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return ModalCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Delete folder?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: tightLetterSpacing,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Are you sure you want to delete this folder?',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 15,
              height: 1.35,
              fontWeight: FontWeight.w700,
              letterSpacing: tightLetterSpacing,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: PrimaryButton(
                  label: 'No',
                  height: 48,
                  onTap: () => Navigator.pop(context, false),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SecondaryButton(
                  label: 'Yes',
                  foregroundColor: AppColors.danger,
                  onTap: () => Navigator.pop(context, true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class CustomColorDialog extends StatefulWidget {
  const CustomColorDialog({super.key, required this.initialColor});

  final Color initialColor;

  @override
  State<CustomColorDialog> createState() => _CustomColorDialogState();
}

class _CustomColorDialogState extends State<CustomColorDialog> {
  late HSVColor _color;

  @override
  void initState() {
    super.initState();
    _color = HSVColor.fromColor(widget.initialColor);
  }

  @override
  Widget build(BuildContext context) {
    final selectedColor = _color.toColor();
    return ModalCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Custom color',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: tightLetterSpacing,
                  ),
                ),
              ),
              CircleIconButton(
                icon: FontAwesomeIcons.xmark,
                size: 36,
                iconSize: 15,
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Center(
            child: SizedBox(
              width: 220,
              height: 220,
              child: _ColorWheelPicker(
                color: _color,
                onChanged: (color) => setState(() => _color = color),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: selectedColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.line),
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  label: 'Cancel',
                  onTap: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: PrimaryButton(
                  label: 'Apply',
                  height: 48,
                  onTap: () => Navigator.pop(context, selectedColor),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ColorWheelPicker extends StatelessWidget {
  const _ColorWheelPicker({required this.color, required this.onChanged});

  final HSVColor color;
  final ValueChanged<HSVColor> onChanged;

  void _updateColor(Offset position, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final delta = position - center;
    final radius = math.min(size.width, size.height) / 2;
    final distance = math.min(delta.distance, radius);
    final radians = math.atan2(delta.dy, delta.dx);
    final hue = (radians * 180 / math.pi + 360) % 360;
    final saturation = (distance / radius).clamp(0.0, 1.0);
    onChanged(HSVColor.fromAHSV(1, hue, saturation, 0.95));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        return GestureDetector(
          onPanDown: (details) => _updateColor(details.localPosition, size),
          onPanUpdate: (details) => _updateColor(details.localPosition, size),
          child: CustomPaint(painter: _ColorWheelPainter(color)),
        );
      },
    );
  }
}

class _ColorWheelPainter extends CustomPainter {
  const _ColorWheelPainter(this.color);

  final HSVColor color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = const SweepGradient(
          colors: [
            Color(0xFFFF3B30),
            Color(0xFFFFCC00),
            Color(0xFF34C759),
            Color(0xFF00C7BE),
            Color(0xFF007AFF),
            Color(0xFFAF52DE),
            Color(0xFFFF3B30),
          ],
        ).createShader(rect),
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [Colors.white, Colors.white.withValues(alpha: 0)],
        ).createShader(rect),
    );

    final angle = color.hue * math.pi / 180;
    final selectorRadius = color.saturation * radius;
    final selectorCenter = Offset(
      center.dx + math.cos(angle) * selectorRadius,
      center.dy + math.sin(angle) * selectorRadius,
    );

    canvas.drawCircle(
      selectorCenter,
      8,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill,
    );
    canvas.drawCircle(
      selectorCenter,
      8,
      Paint()
        ..color = AppColors.ink
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _ColorWheelPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class AccountSettingsDialog extends StatefulWidget {
  const AccountSettingsDialog({
    super.key,
    required this.authService,
    required this.initialDisplayName,
    required this.initialEmail,
  });

  final AuthService authService;
  final String initialDisplayName;
  final String initialEmail;

  @override
  State<AccountSettingsDialog> createState() => _AccountSettingsDialogState();
}

class _AccountSettingsDialogState extends State<AccountSettingsDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _usernameController;
  late final TextEditingController _emailController;
  bool _isSaving = false;
  bool _isSendingReset = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(
      text: widget.initialDisplayName,
    );
    _emailController = TextEditingController(text: widget.initialEmail);
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving || _isSendingReset) return;
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() {
      _isSaving = true;
      _errorMessage = null;
    });

    try {
      final result = await widget.authService.updateSignedInUserProfile(
        displayName: _usernameController.text,
        email: _emailController.text,
      );
      if (!mounted) return;
      Navigator.pop(context, result.emailVerificationSent);
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = _authErrorMessage(error));
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Unable to save profile. Try again.');
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _sendPasswordReset() async {
    if (_isSaving || _isSendingReset) return;
    FocusScope.of(context).unfocus();

    final emailError = _emailValidator(_emailController.text);
    if (emailError != null) {
      setState(() => _errorMessage = emailError);
      return;
    }

    setState(() {
      _isSendingReset = true;
      _errorMessage = null;
    });

    try {
      await widget.authService.sendPasswordResetEmail(_emailController.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password reset email sent.')),
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = _authErrorMessage(error));
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = 'Unable to send reset email. Try again.');
    } finally {
      if (mounted) {
        setState(() => _isSendingReset = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ModalCard(
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Account',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: tightLetterSpacing,
                    ),
                  ),
                ),
                CircleIconButton(
                  icon: FontAwesomeIcons.xmark,
                  size: 36,
                  iconSize: 15,
                  onTap: _isSaving || _isSendingReset
                      ? null
                      : () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),
            AuthField(
              label: 'Username',
              controller: _usernameController,
              textInputAction: TextInputAction.next,
              validator: (value) => _requiredAuthValue(value, 'Username'),
              enabled: !_isSaving && !_isSendingReset,
            ),
            const SizedBox(height: 12),
            AuthField(
              label: 'Email',
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _save(),
              validator: _emailValidator,
              enabled: !_isSaving && !_isSendingReset,
            ),
            const SizedBox(height: 12),
            SecondaryButton(
              label: _isSendingReset ? 'Sending...' : 'Reset password',
              icon: FontAwesomeIcons.key,
              onTap: _isSaving || _isSendingReset ? null : _sendPasswordReset,
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              _AuthMessage(message: _errorMessage!, isError: true),
            ],
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: SecondaryButton(
                    label: 'Cancel',
                    onTap: _isSaving || _isSendingReset
                        ? null
                        : () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: PrimaryButton(
                    label: _isSaving ? 'Saving...' : 'Save',
                    height: 48,
                    onTap: _isSaving || _isSendingReset ? null : _save,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthBrand extends StatelessWidget {
  const _AuthBrand({
    required this.title,
    this.icon = FontAwesomeIcons.layerGroup,
  });

  final String title;
  final FaIconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(18),
            boxShadow: accentShadow,
          ),
          child: Center(child: FaIcon(icon, color: Colors.white, size: 20)),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Yarn Stash',
                style: TextStyle(
                  color: AppColors.muted,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  letterSpacing: tightLetterSpacing,
                ),
              ),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 30,
                  height: 1.05,
                  fontWeight: FontWeight.w900,
                  letterSpacing: tightLetterSpacing,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AuthDivider extends StatelessWidget {
  const _AuthDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: AppColors.line)),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'OR',
            style: TextStyle(
              color: AppColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Expanded(child: Container(height: 1, color: AppColors.line)),
      ],
    );
  }
}

class _AuthSwitchLine extends StatelessWidget {
  const _AuthSwitchLine({
    required this.prefix,
    required this.action,
    required this.onTap,
  });

  final String prefix;
  final String action;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 4,
      children: [
        Text(
          prefix,
          style: const TextStyle(
            color: AppColors.muted,
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: tightLetterSpacing,
          ),
        ),
        LinkText(text: action, onTap: onTap),
      ],
    );
  }
}

class _YarnGridCard extends StatelessWidget {
  const _YarnGridCard({
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    required this.fallbackColor,
    this.onTap,
  });

  final String imageUrl;
  final String title;
  final String subtitle;
  final Color fallbackColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return CardSurface(
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          YarnPhoto(
            url: imageUrl,
            width: double.infinity,
            height: 118,
            radius: 22,
            fallbackColor: fallbackColor,
          ),
          const SizedBox(height: 12),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              height: 1.05,
              fontWeight: FontWeight.w900,
              letterSpacing: tightLetterSpacing,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: tightLetterSpacing,
            ),
          ),
        ],
      ),
    );
  }
}

class _YarnListCard extends StatelessWidget {
  const _YarnListCard({
    required this.imageUrl,
    required this.title,
    required this.subtitle,
    required this.fallbackColor,
    this.chips = const [],
    this.detail,
    this.onAction,
    this.onTap,
    this.showChevron = false,
  });

  final String imageUrl;
  final String title;
  final String subtitle;
  final Color fallbackColor;
  final List<String> chips;
  final String? detail;
  final VoidCallback? onAction;
  final VoidCallback? onTap;
  final bool showChevron;

  @override
  Widget build(BuildContext context) {
    return CardSurface(
      radius: 24,
      padding: const EdgeInsets.all(12),
      onTap: onTap,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          YarnPhoto(
            url: imageUrl,
            width: 84,
            height: 84,
            radius: 20,
            fallbackColor: fallbackColor,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    letterSpacing: tightLetterSpacing,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: tightLetterSpacing,
                  ),
                ),
                if (chips.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      for (final chip in chips)
                        StashChip(label: chip, small: true),
                    ],
                  ),
                ],
                if (detail != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    detail!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      letterSpacing: tightLetterSpacing,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onAction != null) ...[
            const SizedBox(width: 10),
            Padding(
              padding: const EdgeInsets.only(top: 22),
              child: CircleIconButton(
                icon: FontAwesomeIcons.plus,
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                borderColor: AppColors.accent,
                onTap: onAction,
              ),
            ),
          ],
          if (showChevron) ...[
            const SizedBox(width: 8),
            const Padding(
              padding: EdgeInsets.only(top: 34),
              child: FaIcon(
                FontAwesomeIcons.chevronRight,
                color: AppColors.muted,
                size: 14,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoGrid extends StatelessWidget {
  const _InfoGrid({required this.items});

  final List<InfoItem> items;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: items.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent: 76,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return InfoField(label: item.label, value: item.value);
      },
    );
  }
}

class _FolderCard extends StatelessWidget {
  const _FolderCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.background,
    required this.foreground,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final FaIconData icon;
  final Color background;
  final Color foreground;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return CardSurface(
      radius: 28,
      padding: const EdgeInsets.all(18),
      onTap: onTap,
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [AppColors.card, Color(0xFFFFF8F0)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(icon: icon, background: background, foreground: foreground),
          const Spacer(),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: tightLetterSpacing,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: tightLetterSpacing,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({required this.title, required this.rows});

  final String title;
  final List<ProgressRow> rows;

  @override
  Widget build(BuildContext context) {
    return CardSurface(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle(title),
          const SizedBox(height: 16),
          for (var i = 0; i < rows.length; i++) ...[
            rows[i],
            if (i < rows.length - 1) const SizedBox(height: 16),
          ],
        ],
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({
    required this.title,
    required this.subtitle,
    this.icon,
    this.background,
    this.foreground,
    this.onTap,
  });

  final String title;
  final String subtitle;
  final FaIconData? icon;
  final Color? background;
  final Color? foreground;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              if (icon != null) ...[
                IconBadge(
                  icon: icon!,
                  background: background ?? AppColors.rose,
                  foreground: foreground ?? AppColors.accentDark,
                  size: 40,
                  iconSize: 16,
                ),
                const SizedBox(width: 16),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        letterSpacing: tightLetterSpacing,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.muted,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        letterSpacing: tightLetterSpacing,
                      ),
                    ),
                  ],
                ),
              ),
              const FaIcon(
                FontAwesomeIcons.chevronRight,
                color: AppColors.muted,
                size: 14,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
