import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:firebase_core/firebase_core.dart';

import 'app_style.dart';
import 'data/models/ravelry_yarn.dart';
import 'data/models/yarn.dart';
import 'data/models/stash_folder.dart';
import 'data/services/auth_service.dart';
import 'firebase_options.dart';
import 'screens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: AppColors.bg,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: AppColors.bg,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const YarnStashApp());
}

class YarnStashApp extends StatelessWidget {
  const YarnStashApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Yarn Stash',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: const YarnStashRoot(),
    );
  }
}

enum AppScreen {
  login,
  signUp,
  forgotPassword,
  collection,
  search,
  addYarn,
  yarnDetail,
  editYarn,
  folders,
  folderDetail,
  profile,
  settings,
}

class YarnStashRoot extends StatefulWidget {
  const YarnStashRoot({super.key, this.authService});

  final AuthService? authService;

  @override
  State<YarnStashRoot> createState() => _YarnStashRootState();
}

class _YarnStashRootState extends State<YarnStashRoot> {
  late final AuthService _authService;
  AppScreen _screen = AppScreen.login;
  int _currentTab = 0;
  AppScreen _yarnDetailBackScreen = AppScreen.collection;
  bool _addYarnStartsBlank = false;
  RavelryYarnCatalogItem? _selectedCatalogYarn;
  String? _profileBootstrapUid;
  String? _selectedYarnId;
  String? _selectedYarnCollectionId;
  String? _selectedFolderId;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? AuthService();
  }

  void _go(AppScreen screen) {
    setState(() {
      _screen = screen;
      _currentTab = switch (screen) {
        AppScreen.collection => 0,
        AppScreen.yarnDetail || AppScreen.editYarn =>
          _yarnDetailBackScreen == AppScreen.folderDetail ? 2 : 0,
        AppScreen.search || AppScreen.addYarn => 1,
        AppScreen.folders || AppScreen.folderDetail => 2,
        AppScreen.profile || AppScreen.settings => 3,
        _ => _currentTab,
      };
    });
  }

  void _openYarnDetail(AppScreen backScreen, Yarn yarn) {
    setState(() {
      _yarnDetailBackScreen = backScreen;
      _selectedYarnId = yarn.id;
      _selectedYarnCollectionId = yarn.collectionId.isEmpty
          ? _authService.defaultStashCollectionId
          : yarn.collectionId;
      _screen = AppScreen.yarnDetail;
      _currentTab = backScreen == AppScreen.folderDetail ? 2 : 0;
    });
  }

  void _openFolderDetail(StashFolder folder) {
    setState(() {
      _selectedFolderId = folder.id;
      _screen = AppScreen.folderDetail;
      _currentTab = 2;
    });
  }

  void _openAddYarn({
    required bool startBlank,
    RavelryYarnCatalogItem? catalogYarn,
  }) {
    setState(() {
      _addYarnStartsBlank = startBlank;
      _selectedCatalogYarn = catalogYarn;
      _screen = AppScreen.addYarn;
      _currentTab = 1;
    });
  }

  void _selectTab(int index) {
    setState(() {
      _currentTab = index;
      _screen = switch (index) {
        0 => AppScreen.collection,
        1 => AppScreen.search,
        2 => AppScreen.folders,
        _ => AppScreen.profile,
      };
    });
  }

  Future<void> _signOut() async {
    await _authService.signOut();
    if (!mounted) return;
    setState(() {
      _screen = AppScreen.login;
      _currentTab = 0;
      _selectedYarnId = null;
      _selectedYarnCollectionId = null;
      _selectedFolderId = null;
      _selectedCatalogYarn = null;
    });
  }

  bool _isAuthScreen(AppScreen screen) {
    return switch (screen) {
      AppScreen.login || AppScreen.signUp || AppScreen.forgotPassword => true,
      _ => false,
    };
  }

  AppScreen _effectiveScreen({required bool isSignedIn}) {
    if (isSignedIn) {
      return _isAuthScreen(_screen) ? AppScreen.collection : _screen;
    }

    return _isAuthScreen(_screen) ? _screen : AppScreen.login;
  }

  bool _showsTabsFor(AppScreen screen) {
    return switch (screen) {
      AppScreen.collection ||
      AppScreen.search ||
      AppScreen.folders ||
      AppScreen.profile => true,
      _ => false,
    };
  }

  int _tabForScreen(AppScreen screen) {
    return switch (screen) {
      AppScreen.collection => 0,
      AppScreen.yarnDetail || AppScreen.editYarn =>
        _yarnDetailBackScreen == AppScreen.folderDetail ? 2 : 0,
      AppScreen.search || AppScreen.addYarn => 1,
      AppScreen.folders || AppScreen.folderDetail => 2,
      AppScreen.profile || AppScreen.settings => 3,
      _ => _currentTab,
    };
  }

  String _profileName(User? user) {
    final displayName = user?.displayName?.trim();
    if (displayName != null && displayName.isNotEmpty) {
      return displayName;
    }

    final email = user?.email?.trim();
    if (email != null && email.isNotEmpty) {
      return email.split('@').first;
    }

    return 'Your stash';
  }

  void _ensureProfileFor(User? user) {
    if (user == null || _profileBootstrapUid == user.uid) {
      return;
    }

    _profileBootstrapUid = user.uid;
    unawaited(
      _authService.ensureSignedInUserProfile().catchError((_) {
        if (mounted && _profileBootstrapUid == user.uid) {
          setState(() => _profileBootstrapUid = null);
        }
      }),
    );
  }

  Widget _buildScreen(AppScreen screen, User? user) {
    return switch (screen) {
      AppScreen.login => LoginScreen(
        authService: _authService,
        onLogin: () => _go(AppScreen.collection),
        onSignUp: () => _go(AppScreen.signUp),
        onForgotPassword: () => _go(AppScreen.forgotPassword),
      ),
      AppScreen.signUp => SignUpScreen(
        authService: _authService,
        onBack: () => _go(AppScreen.login),
        onCreateAccount: () => _go(AppScreen.collection),
        onLogin: () => _go(AppScreen.login),
      ),
      AppScreen.forgotPassword => ForgotPasswordScreen(
        authService: _authService,
        onBack: () => _go(AppScreen.login),
        onSend: () => _go(AppScreen.login),
      ),
      AppScreen.collection => CollectionScreen(
        userId: user!.uid,
        onYarnTap: (yarn) => _openYarnDetail(AppScreen.collection, yarn),
        onAddYarn: () => _go(AppScreen.search),
      ),
      AppScreen.search => SearchCatalogScreen(
        onAddYarn: (catalogYarn) =>
            _openAddYarn(startBlank: false, catalogYarn: catalogYarn),
        onAddCustomYarn: () => _openAddYarn(startBlank: true),
      ),
      AppScreen.addYarn => YarnFormScreen(
        isEditing: false,
        userId: user!.uid,
        startBlank: _addYarnStartsBlank,
        catalogYarn: _selectedCatalogYarn,
        onBack: () => _go(AppScreen.search),
        onPrimary: () => _go(AppScreen.collection),
      ),
      AppScreen.yarnDetail => YarnDetailScreen(
        userId: user!.uid,
        collectionId:
            _selectedYarnCollectionId ?? _authService.defaultStashCollectionId,
        yarnId: _selectedYarnId,
        onBack: () => _go(_yarnDetailBackScreen),
        onEdit: () => _go(AppScreen.editYarn),
      ),
      AppScreen.editYarn => YarnFormScreen(
        isEditing: true,
        userId: user!.uid,
        collectionId:
            _selectedYarnCollectionId ?? _authService.defaultStashCollectionId,
        yarnId: _selectedYarnId,
        onBack: () => _go(AppScreen.yarnDetail),
        onPrimary: () => _go(AppScreen.yarnDetail),
      ),
      AppScreen.folders => FoldersScreen(
        userId: user!.uid,
        collectionId: _authService.defaultStashCollectionId,
        onFolderTap: _openFolderDetail,
      ),
      AppScreen.folderDetail => FolderDetailScreen(
        userId: user!.uid,
        collectionId: _authService.defaultStashCollectionId,
        folderId: _selectedFolderId,
        onBack: () => _go(AppScreen.folders),
        onYarnTap: (yarn) => _openYarnDetail(AppScreen.folderDetail, yarn),
      ),
      AppScreen.profile => ProfileScreen(
        userId: user!.uid,
        collectionId: _authService.defaultStashCollectionId,
        displayName: _profileName(user),
        onSettings: () => _go(AppScreen.settings),
      ),
      AppScreen.settings => SettingsScreen(
        userId: user!.uid,
        authService: _authService,
        currentDisplayName: user.displayName,
        currentEmail: user.email,
        onBack: () => _go(AppScreen.profile),
        onSignOut: _signOut,
        onProfileChanged: () => setState(() {}),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authService.authStateChanges,
      initialData: _authService.currentUser,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting &&
            snapshot.data == null) {
          return PhoneScaffold(
            showTabs: false,
            currentTab: 0,
            onTabSelected: _selectTab,
            child: const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            ),
          );
        }

        final user = snapshot.data;
        _ensureProfileFor(user);
        final screen = _effectiveScreen(isSignedIn: user != null);

        return PhoneScaffold(
          showTabs: _showsTabsFor(screen),
          currentTab: _tabForScreen(screen),
          onTabSelected: _selectTab,
          child: _buildScreen(screen, user),
        );
      },
    );
  }
}

class PhoneScaffold extends StatelessWidget {
  const PhoneScaffold({
    super.key,
    required this.child,
    required this.showTabs,
    required this.currentTab,
    required this.onTabSelected,
  });

  final Widget child;
  final bool showTabs;
  final int currentTab;
  final ValueChanged<int> onTabSelected;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 0, 20, showTabs ? 0 : 18),
                child: child,
              ),
            ),
            if (showTabs)
              YarnBottomTabs(
                currentIndex: currentTab,
                onTabSelected: onTabSelected,
              ),
          ],
        ),
      ),
    );
  }
}

class YarnBottomTabs extends StatelessWidget {
  const YarnBottomTabs({
    super.key,
    required this.currentIndex,
    required this.onTabSelected,
  });

  final int currentIndex;
  final ValueChanged<int> onTabSelected;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return Container(
      height: 84 + bottomInset,
      padding: EdgeInsets.fromLTRB(14, 10, 14, 21 + bottomInset),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.92),
        border: Border(
          top: BorderSide(color: AppColors.line.withValues(alpha: 0.82)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _TabItem(
            index: 0,
            currentIndex: currentIndex,
            icon: FontAwesomeIcons.layerGroup,
            label: 'Stash',
            onTap: onTabSelected,
          ),
          _TabItem(
            index: 1,
            currentIndex: currentIndex,
            icon: FontAwesomeIcons.plus,
            label: 'Add Yarn',
            onTap: onTabSelected,
          ),
          _TabItem(
            index: 2,
            currentIndex: currentIndex,
            icon: FontAwesomeIcons.folder,
            label: 'Folders',
            onTap: onTabSelected,
          ),
          _TabItem(
            index: 3,
            currentIndex: currentIndex,
            icon: FontAwesomeIcons.user,
            label: 'Profile',
            onTap: onTabSelected,
          ),
        ],
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({
    required this.index,
    required this.currentIndex,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final int index;
  final int currentIndex;
  final FaIconData icon;
  final String label;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final active = index == currentIndex;
    final color = active ? AppColors.accentDark : AppColors.muted;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => onTap(index),
      child: SizedBox(
        width: 72,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FaIcon(icon, size: 19, color: color),
            const SizedBox(height: 5),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: tightLetterSpacing,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
