import 'dart:math' as math;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'app_style.dart';
import 'components.dart';
import 'data/models/yarn.dart';
import 'data/repositories/yarn_repository.dart';
import 'data/services/auth_service.dart';

const _imgMerino = 'https://source.unsplash.com/420x420/?merino,yarn,skein';
const _imgWool = 'https://source.unsplash.com/410x410/?wool,skein';
const _imgHandDyed = 'https://source.unsplash.com/411x411/?handdyed,yarn';
const _imgDyed = 'https://source.unsplash.com/412x412/?dyed,yarn';
const _imgEdit = 'https://source.unsplash.com/430x430/?blue,wool,yarn';
const _imgFolderGreen = 'https://source.unsplash.com/440x440/?green,yarn,skein';
const _imgFolderBrown = 'https://source.unsplash.com/441x441/?brown,yarn';
const _imgFolderCream = 'https://source.unsplash.com/442x442/?cream,wool';

const _allStashFilter = 'All';
const _stashWeightFilters = ['Worsted', 'Sock'];
const _stashFiberFilters = ['Merino', 'Wool', 'Cotton'];
const _stashStatusFilters = ['In stash', 'Used up'];
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
const _stashFilterOrder = [
  ..._stashWeightFilters,
  ..._stashFiberFilters,
  ..._colorFamilyOptions,
  ..._stashStatusFilters,
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

_StashYarnItem _stashItemFromYarn(Yarn yarn) {
  final colorway = yarn.colorway?.trim();
  final balls = yarn.skeinCount == 1 ? '1 ball' : '${yarn.skeinCount} balls';
  final fiberFilters = {
    for (final fiberContent in yarn.fiberContents)
      if (fiberContent.fiber.trim().isNotEmpty) fiberContent.fiber.trim(),
  };
  final subtitleParts = [
    if (colorway != null && colorway.isNotEmpty) colorway,
    balls,
  ];
  final filters = <String>{
    if (yarn.weightCategory != null && yarn.weightCategory!.trim().isNotEmpty)
      yarn.weightCategory!.trim(),
    ...fiberFilters,
    if (fiberFilters.isEmpty &&
        yarn.fiberContent != null &&
        yarn.fiberContent!.trim().isNotEmpty)
      yarn.fiberContent!.trim(),
    if (yarn.colorFamily != null && yarn.colorFamily!.trim().isNotEmpty)
      yarn.colorFamily!.trim(),
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
            obscureText: true,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
            validator: _passwordValidator,
            enabled: !_isSubmitting,
            suffixIcon: const Padding(
              padding: EdgeInsets.only(right: 2),
              child: FaIcon(
                FontAwesomeIcons.eye,
                size: 14,
                color: AppColors.muted,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const _RememberCheck(),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Remember me',
                  style: TextStyle(
                    color: Color(0xFF5F5148),
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: tightLetterSpacing,
                  ),
                ),
              ),
              LinkText(
                text: 'Forgot?',
                onTap: _isSubmitting ? null : widget.onForgotPassword,
              ),
            ],
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 16),
            _AuthMessage(message: _errorMessage!, isError: true),
          ],
          const SizedBox(height: 24),
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
            obscureText: true,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
            validator: _passwordValidator,
            enabled: !_isSubmitting,
            suffixIcon: const Padding(
              padding: EdgeInsets.only(right: 2),
              child: FaIcon(
                FontAwesomeIcons.eye,
                size: 14,
                color: AppColors.muted,
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
  Set<String> _activeFilters = const {_allStashFilter};
  _StashSort _activeSort = _StashSort.recentlyAdded;
  _StashSortDirection _sortDirection = _StashSortDirection.descending;

  @override
  void initState() {
    super.initState();
    _yarnRepository = widget.yarnRepository ?? YarnRepository();
  }

  bool get _hasActiveFilters => !_activeFilters.contains(_allStashFilter);

  List<String> get _filterChips {
    if (!_hasActiveFilters) {
      return const [];
    }
    return _stashFilterOrder
        .where((filter) => _activeFilters.contains(filter))
        .toList(growable: false);
  }

  List<_StashYarnItem> _filteredItems(List<Yarn> yarns) {
    final stashItems = yarns.map(_stashItemFromYarn).toList(growable: false);
    final items = _hasActiveFilters
        ? stashItems.where(_matchesActiveFilters).toList(growable: false)
        : List<_StashYarnItem>.of(stashItems);
    return _sortItems(items);
  }

  bool _matchesActiveFilters(_StashYarnItem item) {
    return _matchesFilterGroup(item, _stashWeightFilters) &&
        _matchesFilterGroup(item, _stashFiberFilters) &&
        _matchesFilterGroup(item, _colorFamilyOptions) &&
        _matchesFilterGroup(item, _stashStatusFilters);
  }

  bool _matchesFilterGroup(_StashYarnItem item, List<String> filters) {
    final selectedFilters = filters.where(
      (filter) => _activeFilters.contains(filter),
    );
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

  Future<void> _openFilters() async {
    final updatedFilters = await showDialog<Set<String>>(
      context: context,
      barrierColor: AppColors.ink.withValues(alpha: 0.35),
      builder: (context) =>
          _StashFilterDialog(initialFilters: Set<String>.of(_activeFilters)),
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
    return ListView(
      padding: const EdgeInsets.only(bottom: 18),
      children: [
        NavRow(
          title: 'Stash',
          trailing: CircleIconButton(
            icon: FontAwesomeIcons.sliders,
            label: 'Filter stash',
            backgroundColor: _hasActiveFilters
                ? AppColors.accent
                : AppColors.card,
            foregroundColor: _hasActiveFilters ? Colors.white : AppColors.ink,
            borderColor: _hasActiveFilters ? AppColors.accent : AppColors.line,
            onTap: _openFilters,
          ),
        ),
        const SizedBox(height: 16),
        const SearchBox(text: 'Search your collection'),
        const SizedBox(height: 12),
        _StashControlStrip(
          activeSort: _activeSort,
          activeDirection: _sortDirection,
          allSelected: !_hasActiveFilters,
          filterLabels: _filterChips,
          onSortSelected: (sort, direction) => setState(() {
            _activeSort = sort;
            _sortDirection = direction;
          }),
          onClearFilters: _resetFilters,
        ),
        const SizedBox(height: 20),
        StreamBuilder<List<Yarn>>(
          stream: _yarnRepository.watchYarns(uid: widget.userId),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const _StashLoadErrorState();
            }

            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 42),
                  child: CircularProgressIndicator(color: AppColors.accent),
                ),
              );
            }

            final yarns = snapshot.data ?? const <Yarn>[];
            if (yarns.isEmpty) {
              return _EmptyStashState(onAddYarn: widget.onAddYarn);
            }

            final filteredItems = _filteredItems(yarns);
            if (filteredItems.isEmpty) {
              return _EmptyFilterState(onReset: _resetFilters);
            }

            return GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              mainAxisExtent: 218,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (final item in filteredItems)
                  _YarnGridCard(
                    imageUrl: item.imageUrl,
                    title: item.title,
                    subtitle: item.subtitle,
                    fallbackColor: item.fallbackColor,
                    onTap: () => widget.onYarnTap(item.yarn),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _StashFilterDialog extends StatefulWidget {
  const _StashFilterDialog({required this.initialFilters});

  final Set<String> initialFilters;

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
                options: _stashWeightFilters,
                selectedFilters: _filters,
                onSelected: _toggleFilter,
              ),
              const SizedBox(height: 16),
              _FilterSection(
                label: 'Fiber',
                options: _stashFiberFilters,
                selectedFilters: _filters,
                onSelected: _toggleFilter,
              ),
              const SizedBox(height: 16),
              _FilterSection(
                label: 'Color family',
                options: _colorFamilyOptions,
                selectedFilters: _filters,
                onSelected: _toggleFilter,
              ),
              const SizedBox(height: 16),
              _FilterSection(
                label: 'Status',
                options: _stashStatusFilters,
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

class SearchCatalogScreen extends StatelessWidget {
  const SearchCatalogScreen({
    super.key,
    required this.onAddYarn,
    required this.onAddCustomYarn,
  });

  final VoidCallback onAddYarn;
  final VoidCallback onAddCustomYarn;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 18),
      children: [
        const NavRow(title: 'Find yarn'),
        const SizedBox(height: 16),
        const SearchBox(text: 'Search by name or brand'),
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
        _YarnListCard(
          imageUrl: _imgWool,
          title: 'Malabrigo Rios',
          subtitle: 'Malabrigo Yarn',
          chips: const ['Worsted', '100% Merino'],
          onAction: onAddYarn,
          fallbackColor: AppColors.rose,
        ),
        const SizedBox(height: 12),
        _YarnListCard(
          imageUrl: _imgHandDyed,
          title: 'Rios Solis',
          subtitle: 'Malabrigo Yarn',
          chips: const ['Worsted', 'Superwash Merino'],
          onAction: onAddYarn,
          fallbackColor: AppColors.goldSoft,
        ),
        const SizedBox(height: 12),
        _YarnListCard(
          imageUrl: _imgDyed,
          title: 'Rios Tweed',
          subtitle: 'Malabrigo Yarn',
          chips: const ['Aran', 'Wool'],
          onAction: onAddYarn,
          fallbackColor: AppColors.sageSoft,
        ),
        const SizedBox(height: 20),
        SecondaryButton(
          label: "Can't find your yarn? Add your own",
          onTap: onAddCustomYarn,
        ),
      ],
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
    final imageUrl = yarn.imageUrls.isEmpty ? '' : yarn.imageUrls.first;

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
        YarnPhoto(
          url: imageUrl,
          width: double.infinity,
          height: 256,
          radius: 34,
          fallbackColor: _fallbackColorForYarn(yarn),
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
              child: StatCard(value: _totalYardageStat(yarn), label: 'Yards'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(value: _totalWeightStat(yarn), label: 'Weight'),
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
                  : 'Not set',
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
    InfoItem('Brand', _valueOrFallback(yarn.brandName)),
    InfoItem('Weight', _valueOrFallback(yarn.weightCategory)),
    InfoItem('WPI', yarn.wpi?.toString() ?? 'Not set'),
    InfoItem('Yardage', _yardageText(yarn.yardage)),
    InfoItem('Unit weight', _unitWeightText(yarn.unitWeightGrams)),
    InfoItem('Needle', _valueOrFallback(yarn.needleSize)),
    InfoItem('Gauge', _valueOrFallback(yarn.gauge)),
    InfoItem('Color family', _valueOrFallback(yarn.colorFamily)),
    InfoItem('Colorway', _valueOrFallback(yarn.colorway)),
    InfoItem('Dye lot', _valueOrFallback(yarn.dyeLot)),
    InfoItem('Skeins', yarn.skeinCount.toString()),
    InfoItem('Price', _priceText(yarn.priceCents)),
    InfoItem(
      'Folder',
      _valueOrFallback(yarn.folderName, fallback: 'No folder'),
    ),
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
  return '${grams * yarn.skeinCount}g';
}

String _yardageText(int? yardage) {
  return yardage == null ? 'Not set' : '$yardage yd';
}

String _unitWeightText(int? grams) {
  return grams == null ? 'Not set' : '$grams g';
}

String _priceText(int? priceCents) {
  if (priceCents == null) return 'Not set';
  return '\$${(priceCents / 100).toStringAsFixed(2)}';
}

String _valueOrFallback(String? value, {String fallback = 'Not set'}) {
  return _cleanText(value) ?? fallback;
}

String? _cleanText(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  return trimmed;
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
    this.startBlank = false,
    this.yarnRepository,
  });

  final bool isEditing;
  final String userId;
  final VoidCallback onBack;
  final VoidCallback onPrimary;
  final bool startBlank;
  final YarnRepository? yarnRepository;

  @override
  State<YarnFormScreen> createState() => _YarnFormScreenState();
}

class _YarnFormScreenState extends State<YarnFormScreen> {
  late final YarnRepository _yarnRepository;
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
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _yarnRepository = widget.yarnRepository ?? YarnRepository();
    _colorFamily = widget.startBlank ? null : 'White';
    _folder = widget.isEditing ? 'Sweaters' : 'No folder';
    _yarnNameController = TextEditingController(
      text: widget.startBlank ? '' : 'Malabrigo Rios',
    );
    _brandController = TextEditingController(
      text: widget.startBlank ? '' : 'Malabrigo Yarn',
    );
    _weightController = TextEditingController(
      text: widget.startBlank ? '' : 'Worsted',
    );
    _wpiController = TextEditingController(text: widget.startBlank ? '' : '9');
    _lengthController = TextEditingController(
      text: widget.startBlank ? '' : '210 yd',
    );
    _unitWeightController = TextEditingController(
      text: widget.startBlank ? '' : '100 g',
    );
    _needleController = TextEditingController(
      text: widget.startBlank ? '' : 'US 6-8',
    );
    _gaugeController = TextEditingController(
      text: widget.startBlank ? '' : '18-22 sts',
    );
    _colorwayController = TextEditingController(
      text: widget.startBlank ? '' : 'Aguas',
    );
    _dyeLotController = TextEditingController(
      text: widget.startBlank ? '' : 'A27',
    );
    _ballsController = TextEditingController(
      text: widget.startBlank ? '' : '4',
    );
    _priceController = TextEditingController(
      text: widget.startBlank ? '' : r'$14.50',
    );
    _notesController = TextEditingController(
      text: widget.startBlank ? '' : 'Reserved for the Weekender sweater.',
    );
    _fiberRows.add(
      _FiberContentInput(
        fiber: widget.startBlank ? '' : 'Merino',
        percentage: widget.startBlank ? '' : '100',
      ),
    );
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
      final fiber = row.fiberController.text.trim();
      final percentageText = row.percentageController.text.trim();
      if (fiber.isEmpty && percentageText.isEmpty) continue;

      final percentage = _parseFirstInt(percentageText);
      if (fiber.isEmpty || percentage == null || percentage <= 0) {
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

  Future<void> _saveYarn() async {
    if (widget.isEditing) {
      widget.onPrimary();
      return;
    }

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
    final folderName = _folder == 'No folder' ? null : _folder;
    final fiberContent = yarnFiberContentSummary(fiberContents);

    try {
      await _yarnRepository.createYarn(
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
          weightCategory: _trimmedOrNull(_weightController.text),
          wpi: _parseFirstInt(_wpiController.text),
          fiberContent: fiberContent,
          fiberContents: fiberContents,
          yardage: _parseFirstInt(_lengthController.text),
          unitWeightGrams: _parseFirstInt(_unitWeightController.text),
          needleSize: _trimmedOrNull(_needleController.text),
          gauge: _trimmedOrNull(_gaugeController.text),
          skeinCount: _parseFirstInt(_ballsController.text) ?? 1,
          priceCents: _parsePriceCents(_priceController.text),
          folderName: folderName,
          notes: _trimmedOrNull(_notesController.text),
          createdAt: now,
          updatedAt: now,
        ),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Yarn added to your stash.')),
      );
      widget.onPrimary();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Unable to save yarn. Try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
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
          label: 'Length',
          child: InlineTextField(controller: _lengthController),
        ),
        InfoField(
          label: 'Unit weight',
          child: InlineTextField(controller: _unitWeightController),
        ),
        InfoField(
          label: 'Needle',
          child: InlineTextField(controller: _needleController),
        ),
        InfoField(
          label: 'Gauge',
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

  @override
  Widget build(BuildContext context) {
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
                url: widget.startBlank
                    ? ''
                    : widget.isEditing
                    ? _imgEdit
                    : _imgMerino,
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
                  items: _colorFamilyOptions,
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
                label: 'Balls',
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
            items: const [
              'Sweaters',
              'Socks',
              'Summer tops',
              'Bin 2',
              'No folder',
            ],
            onChanged: (value) => setState(() => _folder = value ?? _folder),
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
        const InfoField(
          label: 'Images',
          child: Column(children: [SizedBox(height: 8), UploadBox()]),
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
          onTap: _isSaving ? null : _saveYarn,
        ),
        if (widget.isEditing) ...[
          const SizedBox(height: 12),
          const SecondaryButton(
            label: 'Move to used up',
            icon: FontAwesomeIcons.boxArchive,
          ),
          const SizedBox(height: 12),
          const SecondaryButton(
            label: 'Remove from stash',
            icon: FontAwesomeIcons.trashCan,
            foregroundColor: AppColors.danger,
          ),
        ],
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
  const FoldersScreen({super.key, required this.onFolderTap});

  final VoidCallback onFolderTap;

  Future<void> _openCreateFolder(BuildContext context) async {
    await showDialog<_FolderEditResult>(
      context: context,
      barrierColor: AppColors.ink.withValues(alpha: 0.35),
      builder: (context) => const FolderEditDialog(
        initialName: '',
        title: 'Create folder',
        showDelete: false,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          mainAxisExtent: 156,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _FolderCard(
              title: 'Sweaters',
              subtitle: '24 yarns - 9.2k yd',
              icon: FontAwesomeIcons.shirt,
              background: AppColors.rose,
              foreground: AppColors.accentDark,
              onTap: onFolderTap,
            ),
            _FolderCard(
              title: 'Socks',
              subtitle: '18 yarns - 7.6k yd',
              icon: FontAwesomeIcons.socks,
              background: AppColors.sageSoft,
              foreground: const Color(0xFF587456),
              onTap: onFolderTap,
            ),
            _FolderCard(
              title: 'Summer tops',
              subtitle: '12 yarns - 4.1k yd',
              icon: FontAwesomeIcons.sun,
              background: AppColors.goldSoft,
              foreground: const Color(0xFFA87523),
              onTap: onFolderTap,
            ),
            _FolderCard(
              title: 'Bin 2',
              subtitle: '31 yarns - storage',
              icon: FontAwesomeIcons.boxArchive,
              background: AppColors.lavenderSoft,
              foreground: const Color(0xFF6D579A),
              onTap: onFolderTap,
            ),
            _FolderCard(
              title: 'Used up',
              subtitle: '7 yarns - finished',
              icon: FontAwesomeIcons.circleCheck,
              background: AppColors.taupeSoft,
              foreground: const Color(0xFF7A5F4E),
              onTap: onFolderTap,
            ),
          ],
        ),
      ],
    );
  }
}

class FolderDetailScreen extends StatelessWidget {
  const FolderDetailScreen({
    super.key,
    required this.folderName,
    required this.onBack,
    required this.onFolderNameChanged,
    required this.onYarnTap,
  });

  final String folderName;
  final VoidCallback onBack;
  final ValueChanged<String> onFolderNameChanged;
  final VoidCallback onYarnTap;

  Future<void> _openFolderEditor(BuildContext context) async {
    final result = await showDialog<_FolderEditResult>(
      context: context,
      barrierColor: AppColors.ink.withValues(alpha: 0.35),
      builder: (context) => FolderEditDialog(initialName: folderName),
    );
    if (result == null) return;

    switch (result.action) {
      case _FolderEditAction.save:
        if (result.name.isNotEmpty) {
          onFolderNameChanged(result.name);
        }
      case _FolderEditAction.delete:
        onBack();
    }
  }

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
            icon: FontAwesomeIcons.pen,
            label: 'Edit folder',
            onTap: () => _openFolderEditor(context),
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
              const IconBadge(
                icon: FontAwesomeIcons.shirt,
                background: AppColors.rose,
                foreground: AppColors.accentDark,
                size: 56,
                iconSize: 20,
              ),
              const SizedBox(height: 18),
              NavTitle(folderName),
              const SizedBox(height: 8),
              const Text(
                '24 yarns - 9,240 yards available',
                style: TextStyle(
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
        SearchBox(text: 'Search in $folderName'),
        const SizedBox(height: 16),
        _YarnListCard(
          imageUrl: _imgFolderGreen,
          title: 'Cascade 220',
          subtitle: 'Sage - 7 balls',
          detail: '1,540 yd total',
          showChevron: true,
          fallbackColor: AppColors.sageSoft,
          onTap: onYarnTap,
        ),
        const SizedBox(height: 12),
        _YarnListCard(
          imageUrl: _imgFolderBrown,
          title: 'Brooklyn Tweed Shelter',
          subtitle: 'Truffle - 5 skeins',
          detail: '700 yd total',
          showChevron: true,
          fallbackColor: AppColors.taupeSoft,
          onTap: onYarnTap,
        ),
        const SizedBox(height: 12),
        _YarnListCard(
          imageUrl: _imgFolderCream,
          title: 'Woolfolk Far',
          subtitle: 'Oat - 8 balls',
          detail: '1,136 yd total',
          showChevron: true,
          fallbackColor: AppColors.cream,
          onTap: onYarnTap,
        ),
      ],
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({
    super.key,
    required this.displayName,
    required this.onSettings,
  });

  final String displayName;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
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
              Text(
                displayName,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: tightLetterSpacing,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const SectionTitle('Stash statistics'),
        const SizedBox(height: 12),
        const Row(
          children: [
            Expanded(
              child: StatCard(
                value: '128',
                label: 'Skeins',
                centered: true,
                valueSize: 24,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: StatCard(
                value: '14.8k',
                label: 'Grams',
                centered: true,
                valueSize: 24,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: StatCard(
                value: '38.2k',
                label: 'Yardage',
                centered: true,
                valueSize: 24,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        const _ProgressCard(
          title: 'Fiber content',
          rows: [
            ProgressRow(label: 'Wool', percent: 52),
            ProgressRow(label: 'Cotton', percent: 24),
            ProgressRow(label: 'Acrylic', percent: 18),
          ],
        ),
        const SizedBox(height: 16),
        const _ProgressCard(
          title: 'Weight',
          rows: [
            ProgressRow(label: 'Lace', percent: 9),
            ProgressRow(label: 'Fingering', percent: 31),
            ProgressRow(label: 'DK', percent: 28),
            ProgressRow(label: 'Chunky', percent: 16),
          ],
        ),
      ],
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.accountSummary,
    required this.unitSummary,
    required this.onBack,
    required this.onSignOut,
    required this.onAccountChanged,
    required this.onUnitsChanged,
  });

  final String accountSummary;
  final String unitSummary;
  final VoidCallback onBack;
  final VoidCallback onSignOut;
  final ValueChanged<String> onAccountChanged;
  final ValueChanged<String> onUnitsChanged;

  Future<void> _openAccountSettings(BuildContext context) async {
    final updated = await showDialog<String>(
      context: context,
      barrierColor: AppColors.ink.withValues(alpha: 0.35),
      builder: (context) => const AccountSettingsDialog(),
    );
    if (updated != null) onAccountChanged(updated);
  }

  Future<void> _openUnitSettings(BuildContext context) async {
    final updated = await showDialog<String>(
      context: context,
      barrierColor: AppColors.ink.withValues(alpha: 0.35),
      builder: (context) => const UnitSettingsDialog(),
    );
    if (updated != null) onUnitsChanged(updated);
  }

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
        const SizedBox(height: 16),
        const NavTitle('Settings'),
        const SizedBox(height: 20),
        CardSurface(
          padding: const EdgeInsets.all(8),
          child: _SettingsRow(
            title: 'Account',
            subtitle: accountSummary,
            icon: FontAwesomeIcons.user,
            background: AppColors.rose,
            foreground: AppColors.accentDark,
            onTap: () => _openAccountSettings(context),
          ),
        ),
        const SizedBox(height: 24),
        const SectionTitle('Stash preferences'),
        const SizedBox(height: 12),
        CardSurface(
          padding: const EdgeInsets.all(8),
          child: _SettingsRow(
            title: 'Default units',
            subtitle: unitSummary,
            onTap: () => _openUnitSettings(context),
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
  }
}

class FolderEditDialog extends StatefulWidget {
  const FolderEditDialog({
    super.key,
    required this.initialName,
    this.title = 'Edit folder',
    this.showDelete = true,
  });

  final String initialName;
  final String title;
  final bool showDelete;

  @override
  State<FolderEditDialog> createState() => _FolderEditDialogState();
}

enum _FolderEditAction { save, delete }

class _FolderEditResult {
  const _FolderEditResult.save(this.name) : action = _FolderEditAction.save;

  const _FolderEditResult.delete()
    : action = _FolderEditAction.delete,
      name = '';

  final _FolderEditAction action;
  final String name;
}

class _FolderEditDialogState extends State<FolderEditDialog> {
  late final TextEditingController _controller;
  int _selectedIcon = 0;
  int _selectedColor = 0;
  Color? _customColor;

  final _icons = const [
    FontAwesomeIcons.shirt,
    FontAwesomeIcons.socks,
    FontAwesomeIcons.sun,
    FontAwesomeIcons.boxArchive,
  ];

  static const _customColorIndex = 4;

  final _presetColors = const [
    AppColors.rose,
    AppColors.sageSoft,
    AppColors.goldSoft,
    AppColors.lavenderSoft,
  ];

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
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
    Navigator.pop(context, _FolderEditResult.save(_controller.text.trim()));
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
              for (var i = 0; i < _icons.length; i++) ...[
                Expanded(
                  child: ChoiceButton(
                    label: '',
                    icon: _icons[i],
                    selected: _selectedIcon == i,
                    onTap: () => setState(() => _selectedIcon = i),
                  ),
                ),
                if (i < _icons.length - 1) const SizedBox(width: 8),
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
              for (var i = 0; i < _presetColors.length; i++) ...[
                Expanded(
                  child: SwatchButton(
                    color: _presetColors[i],
                    selected: _selectedColor == i,
                    onTap: () => setState(() => _selectedColor = i),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: SwatchButton(
                  color: const Color(0xFFE1DEDA),
                  selected: _selectedColor == _customColorIndex,
                  icon: FontAwesomeIcons.plus,
                  iconColor: AppColors.muted,
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
  const AccountSettingsDialog({super.key});

  @override
  State<AccountSettingsDialog> createState() => _AccountSettingsDialogState();
}

class _AccountSettingsDialogState extends State<AccountSettingsDialog> {
  late final TextEditingController _usernameController;
  late final TextEditingController _emailController;

  @override
  void initState() {
    super.initState();
    _usernameController = TextEditingController(text: 'Sarah Liu');
    _emailController = TextEditingController(text: 'sarah@example.com');
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ModalCard(
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
                onTap: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          AuthField(label: 'Username', controller: _usernameController),
          const SizedBox(height: 12),
          AuthField(
            label: 'Email',
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
          ),
          const SizedBox(height: 12),
          const SecondaryButton(
            label: 'Reset password',
            icon: FontAwesomeIcons.key,
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: SecondaryButton(
                  label: 'Cancel',
                  onTap: () => Navigator.pop(context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: PrimaryButton(
                  label: 'Save',
                  height: 48,
                  onTap: () {
                    final username = _usernameController.text.trim().isEmpty
                        ? 'Sarah Liu'
                        : _usernameController.text.trim();
                    final email = _emailController.text.trim().isEmpty
                        ? 'sarah@example.com'
                        : _emailController.text.trim();
                    Navigator.pop(context, '$username / $email');
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class UnitSettingsDialog extends StatefulWidget {
  const UnitSettingsDialog({super.key});

  @override
  State<UnitSettingsDialog> createState() => _UnitSettingsDialogState();
}

class _UnitSettingsDialogState extends State<UnitSettingsDialog> {
  String _length = 'Yards';
  String _weight = 'Grams';

  @override
  Widget build(BuildContext context) {
    return ModalCard(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Default units',
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
          const Align(
            alignment: Alignment.centerLeft,
            child: FieldLabel('Length'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ChoiceButton(
                  label: 'Yards',
                  selected: _length == 'Yards',
                  onTap: () => setState(() => _length = 'Yards'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceButton(
                  label: 'Meters',
                  selected: _length == 'Meters',
                  onTap: () => setState(() => _length = 'Meters'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Align(
            alignment: Alignment.centerLeft,
            child: FieldLabel('Weight'),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ChoiceButton(
                  label: 'Grams',
                  selected: _weight == 'Grams',
                  onTap: () => setState(() => _weight = 'Grams'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ChoiceButton(
                  label: 'Ounces',
                  selected: _weight == 'Ounces',
                  onTap: () => setState(() => _weight = 'Ounces'),
                ),
              ),
            ],
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
              const SizedBox(width: 12),
              Expanded(
                child: PrimaryButton(
                  label: 'Save',
                  height: 48,
                  onTap: () => Navigator.pop(context, '$_length / $_weight'),
                ),
              ),
            ],
          ),
        ],
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

class _RememberCheck extends StatelessWidget {
  const _RememberCheck();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 21,
      height: 21,
      decoration: BoxDecoration(
        color: AppColors.accent,
        borderRadius: BorderRadius.circular(7),
      ),
      child: const Center(
        child: FaIcon(FontAwesomeIcons.check, color: Colors.white, size: 11),
      ),
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
            height: 132,
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
