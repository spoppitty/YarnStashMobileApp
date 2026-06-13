import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'app_style.dart';
import 'screens.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
  const YarnStashRoot({super.key});

  @override
  State<YarnStashRoot> createState() => _YarnStashRootState();
}

class _YarnStashRootState extends State<YarnStashRoot> {
  AppScreen _screen = AppScreen.login;
  int _currentTab = 0;
  AppScreen _yarnDetailBackScreen = AppScreen.collection;
  bool _addYarnStartsBlank = false;
  String _folderName = 'Sweaters';
  String _accountSummary = 'Email, password, profile';
  String _unitSummary = 'Yards / Grams';

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

  void _openYarnDetail(AppScreen backScreen) {
    setState(() {
      _yarnDetailBackScreen = backScreen;
      _screen = AppScreen.yarnDetail;
      _currentTab = backScreen == AppScreen.folderDetail ? 2 : 0;
    });
  }

  void _openAddYarn({required bool startBlank}) {
    setState(() {
      _addYarnStartsBlank = startBlank;
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

  bool get _showsTabs {
    return switch (_screen) {
      AppScreen.collection ||
      AppScreen.search ||
      AppScreen.folders ||
      AppScreen.profile => true,
      _ => false,
    };
  }

  Widget _buildScreen() {
    return switch (_screen) {
      AppScreen.login => LoginScreen(
        onLogin: () => _go(AppScreen.collection),
        onSignUp: () => _go(AppScreen.signUp),
        onForgotPassword: () => _go(AppScreen.forgotPassword),
      ),
      AppScreen.signUp => SignUpScreen(
        onBack: () => _go(AppScreen.login),
        onCreateAccount: () => _go(AppScreen.collection),
        onLogin: () => _go(AppScreen.login),
      ),
      AppScreen.forgotPassword => ForgotPasswordScreen(
        onBack: () => _go(AppScreen.login),
        onSend: () => _go(AppScreen.login),
      ),
      AppScreen.collection => CollectionScreen(
        onYarnTap: () => _openYarnDetail(AppScreen.collection),
      ),
      AppScreen.search => SearchCatalogScreen(
        onAddYarn: () => _openAddYarn(startBlank: false),
        onAddCustomYarn: () => _openAddYarn(startBlank: true),
      ),
      AppScreen.addYarn => YarnFormScreen(
        isEditing: false,
        startBlank: _addYarnStartsBlank,
        onBack: () => _go(AppScreen.search),
        onPrimary: () => _go(AppScreen.collection),
      ),
      AppScreen.yarnDetail => YarnDetailScreen(
        onBack: () => _go(_yarnDetailBackScreen),
        onEdit: () => _go(AppScreen.editYarn),
      ),
      AppScreen.editYarn => YarnFormScreen(
        isEditing: true,
        onBack: () => _go(AppScreen.yarnDetail),
        onPrimary: () => _go(AppScreen.yarnDetail),
      ),
      AppScreen.folders => FoldersScreen(
        onFolderTap: () => _go(AppScreen.folderDetail),
      ),
      AppScreen.folderDetail => FolderDetailScreen(
        folderName: _folderName,
        onBack: () => _go(AppScreen.folders),
        onFolderNameChanged: (name) => setState(() => _folderName = name),
        onYarnTap: () => _openYarnDetail(AppScreen.folderDetail),
      ),
      AppScreen.profile => ProfileScreen(
        onSettings: () => _go(AppScreen.settings),
      ),
      AppScreen.settings => SettingsScreen(
        accountSummary: _accountSummary,
        unitSummary: _unitSummary,
        onBack: () => _go(AppScreen.profile),
        onSignOut: () => _go(AppScreen.login),
        onAccountChanged: (summary) =>
            setState(() => _accountSummary = summary),
        onUnitsChanged: (summary) => setState(() => _unitSummary = summary),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return PhoneScaffold(
      showTabs: _showsTabs,
      currentTab: _currentTab,
      onTabSelected: _selectTab,
      child: _buildScreen(),
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
