import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'app_style.dart';
import 'components.dart';

const _imgBlueYarn = 'https://source.unsplash.com/500x500/?blue,yarn';
const _imgPinkYarn = 'https://source.unsplash.com/501x501/?pink,yarn';
const _imgGreenYarn = 'https://source.unsplash.com/502x502/?green,wool,yarn';
const _imgCreamYarn = 'https://source.unsplash.com/503x503/?cream,yarn';
const _imgMerino = 'https://source.unsplash.com/420x420/?merino,yarn,skein';
const _imgWool = 'https://source.unsplash.com/410x410/?wool,skein';
const _imgHandDyed = 'https://source.unsplash.com/411x411/?handdyed,yarn';
const _imgDyed = 'https://source.unsplash.com/412x412/?dyed,yarn';
const _imgDetail = 'https://source.unsplash.com/900x700/?blue,yarn,skein';
const _imgEdit = 'https://source.unsplash.com/430x430/?blue,wool,yarn';
const _imgFolderGreen = 'https://source.unsplash.com/440x440/?green,yarn,skein';
const _imgFolderBrown = 'https://source.unsplash.com/441x441/?brown,yarn';
const _imgFolderCream = 'https://source.unsplash.com/442x442/?cream,wool';

const _detailFields = <InfoItem>[
  InfoItem('Weight', 'Worsted'),
  InfoItem('WPI', '9'),
  InfoItem('Length', '210 yd'),
  InfoItem('Unit weight', '100 g'),
  InfoItem('Needle', 'US 6-8'),
  InfoItem('Gauge', '18-22 sts'),
  InfoItem('Fiber', '100% Merino'),
  InfoItem('Color family', 'Blue'),
  InfoItem('Colorway', 'Aguas'),
  InfoItem('Dye lot', 'A27'),
  InfoItem('Balls', '4'),
  InfoItem('Price', r'$14.50'),
];

class InfoItem {
  const InfoItem(this.label, this.value);

  final String label;
  final String value;
}

class LoginScreen extends StatelessWidget {
  const LoginScreen({
    super.key,
    required this.onLogin,
    required this.onSignUp,
    required this.onForgotPassword,
  });

  final VoidCallback onLogin;
  final VoidCallback onSignUp;
  final VoidCallback onForgotPassword;

  @override
  Widget build(BuildContext context) {
    return ListView(
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
        const AuthField(
          label: 'Email',
          initialValue: 'sarah@example.com',
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 12),
        const AuthField(
          label: 'Password',
          initialValue: 'weekender',
          obscureText: true,
          suffixIcon: Padding(
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
            LinkText(text: 'Forgot?', onTap: onForgotPassword),
          ],
        ),
        const SizedBox(height: 24),
        PrimaryButton(
          label: 'Log in',
          icon: FontAwesomeIcons.arrowRightToBracket,
          onTap: onLogin,
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
          onTap: onSignUp,
        ),
      ],
    );
  }
}

class SignUpScreen extends StatelessWidget {
  const SignUpScreen({
    super.key,
    required this.onBack,
    required this.onCreateAccount,
    required this.onLogin,
  });

  final VoidCallback onBack;
  final VoidCallback onCreateAccount;
  final VoidCallback onLogin;

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
        const SizedBox(height: 14),
        const _AuthBrand(title: 'Create account'),
        const SizedBox(height: 18),
        const AuthField(label: 'Username', initialValue: 'Sarah Liu'),
        const SizedBox(height: 12),
        const AuthField(
          label: 'Email',
          hintText: 'you@example.com',
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 12),
        const AuthField(
          label: 'Password',
          hintText: 'Create a password',
          obscureText: true,
          suffixIcon: Padding(
            padding: EdgeInsets.only(right: 2),
            child: FaIcon(
              FontAwesomeIcons.eye,
              size: 14,
              color: AppColors.muted,
            ),
          ),
        ),
        const SizedBox(height: 20),
        PrimaryButton(
          label: 'Create account',
          icon: FontAwesomeIcons.userPlus,
          onTap: onCreateAccount,
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
          onTap: onLogin,
        ),
      ],
    );
  }
}

class ForgotPasswordScreen extends StatelessWidget {
  const ForgotPasswordScreen({
    super.key,
    required this.onBack,
    required this.onSend,
  });

  final VoidCallback onBack;
  final VoidCallback onSend;

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
        const SizedBox(height: 32),
        const IconBadge(
          icon: FontAwesomeIcons.lockOpen,
          background: AppColors.rose,
          foreground: AppColors.accentDark,
          size: 80,
          iconSize: 30,
        ),
        const SizedBox(height: 24),
        const NavTitle('Reset password'),
        const SizedBox(height: 12),
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
        const AuthField(
          label: 'Email',
          initialValue: 'sarah@example.com',
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 20),
        PrimaryButton(
          label: 'Send reset link',
          icon: FontAwesomeIcons.paperPlane,
          onTap: onSend,
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
          onTap: onBack,
        ),
      ],
    );
  }
}

class CollectionScreen extends StatelessWidget {
  const CollectionScreen({super.key, required this.onYarnTap});

  final VoidCallback onYarnTap;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.only(bottom: 18),
      children: [
        const NavRow(
          title: 'Stash',
          trailing: CircleIconButton(icon: FontAwesomeIcons.sliders),
        ),
        const SizedBox(height: 16),
        const SearchBox(text: 'Search your collection'),
        const SizedBox(height: 16),
        const _ChipStrip(
          labels: ['All', 'Worsted', 'Merino', 'Sock', 'Unused'],
        ),
        const SizedBox(height: 20),
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          mainAxisExtent: 218,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _YarnGridCard(
              imageUrl: _imgBlueYarn,
              title: 'Malabrigo Rios',
              subtitle: 'Aguas - 4 balls',
              fallbackColor: const Color(0xFFB8D6E8),
              onTap: onYarnTap,
            ),
            _YarnGridCard(
              imageUrl: _imgPinkYarn,
              title: 'Tosh Merino Light',
              subtitle: 'Antler - 2 skeins',
              fallbackColor: AppColors.rose,
              onTap: onYarnTap,
            ),
            _YarnGridCard(
              imageUrl: _imgGreenYarn,
              title: 'Cascade 220',
              subtitle: 'Sage - 7 balls',
              fallbackColor: AppColors.sageSoft,
              onTap: onYarnTap,
            ),
            _YarnGridCard(
              imageUrl: _imgCreamYarn,
              title: 'Cotton Pure',
              subtitle: 'Heirloom - 6 balls',
              fallbackColor: AppColors.cream,
              onTap: onYarnTap,
            ),
          ],
        ),
      ],
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
        const SizedBox(height: 8),
        const Text(
          'Search by name or brand and autofill trusted yarn attributes.',
          style: TextStyle(
            color: AppColors.muted,
            fontSize: 15,
            height: 1.35,
            fontWeight: FontWeight.w700,
            letterSpacing: tightLetterSpacing,
          ),
        ),
        const SizedBox(height: 20),
        const SearchBox(
          text: 'Malabrigo Rios',
          highlighted: true,
          trailingIcon: FontAwesomeIcons.xmark,
        ),
        const SizedBox(height: 16),
        const _ChipStrip(labels: ['Catalog', 'Brand', 'Weight', 'Fiber']),
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
    required this.onBack,
    required this.onEdit,
  });

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
        const YarnPhoto(
          url: _imgDetail,
          width: double.infinity,
          height: 256,
          radius: 34,
          fallbackColor: Color(0xFFB8D6E8),
        ),
        const SizedBox(height: 20),
        const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Malabrigo Rios',
                    style: TextStyle(
                      fontSize: 30,
                      height: 1.08,
                      fontWeight: FontWeight.w900,
                      letterSpacing: tightLetterSpacing,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Aguas - Malabrigo Yarn',
                    style: TextStyle(
                      color: AppColors.muted,
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: tightLetterSpacing,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 12),
            StashChip(label: 'In stash', active: true),
          ],
        ),
        const SizedBox(height: 20),
        const Row(
          children: [
            Expanded(
              child: StatCard(value: '4', label: 'Balls'),
            ),
            SizedBox(width: 12),
            Expanded(
              child: StatCard(value: '840', label: 'Yards'),
            ),
            SizedBox(width: 12),
            Expanded(
              child: StatCard(value: '400g', label: 'Total'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const SectionTitle('Details'),
        const SizedBox(height: 12),
        const _InfoGrid(items: _detailFields),
        const SizedBox(height: 16),
        const CardSurface(
          padding: EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FieldLabel('Notes'),
              SizedBox(height: 8),
              Text(
                'Soft, saturated color. Keep together for cardigan yardage.',
                style: TextStyle(
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

class YarnFormScreen extends StatefulWidget {
  const YarnFormScreen({
    super.key,
    required this.isEditing,
    required this.onBack,
    required this.onPrimary,
    this.startBlank = false,
  });

  final bool isEditing;
  final VoidCallback onBack;
  final VoidCallback onPrimary;
  final bool startBlank;

  @override
  State<YarnFormScreen> createState() => _YarnFormScreenState();
}

class _YarnFormScreenState extends State<YarnFormScreen> {
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

  String? _colorFamily;
  late String _folder;

  @override
  void initState() {
    super.initState();
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
            onTap: widget.onBack,
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
        const SectionTitle('Autofilled details'),
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
                  items: const [
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
                  ],
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
        const SizedBox(height: 20),
        PrimaryButton(
          label: widget.isEditing ? 'Save changes' : 'Add to collection',
          icon: widget.isEditing
              ? FontAwesomeIcons.check
              : FontAwesomeIcons.plus,
          onTap: widget.onPrimary,
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

class FoldersScreen extends StatelessWidget {
  const FoldersScreen({super.key, required this.onFolderTap});

  final VoidCallback onFolderTap;

  Future<void> _openCreateFolder(BuildContext context) async {
    await showDialog<String>(
      context: context,
      barrierColor: AppColors.ink.withValues(alpha: 0.35),
      builder: (context) =>
          const FolderEditDialog(initialName: '', title: 'Create folder'),
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
    final updated = await showDialog<String>(
      context: context,
      barrierColor: AppColors.ink.withValues(alpha: 0.35),
      builder: (context) => FolderEditDialog(initialName: folderName),
    );
    if (updated != null && updated.trim().isNotEmpty) {
      onFolderNameChanged(updated.trim());
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
  const ProfileScreen({super.key, required this.onSettings});

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
        const CardSurface(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              DecoratedBox(
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
              SizedBox(width: 12),
              Text(
                'Sarah Liu',
                style: TextStyle(
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
  });

  final String initialName;
  final String title;

  @override
  State<FolderEditDialog> createState() => _FolderEditDialogState();
}

class _FolderEditDialogState extends State<FolderEditDialog> {
  late final TextEditingController _controller;
  int _selectedIcon = 0;
  int _selectedColor = 0;

  final _icons = const [
    FontAwesomeIcons.shirt,
    FontAwesomeIcons.socks,
    FontAwesomeIcons.sun,
    FontAwesomeIcons.boxArchive,
  ];

  final _colors = const [
    AppColors.rose,
    AppColors.sageSoft,
    AppColors.goldSoft,
    AppColors.lavenderSoft,
    AppColors.taupeSoft,
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
              for (var i = 0; i < _colors.length; i++) ...[
                Expanded(
                  child: SwatchButton(
                    color: _colors[i],
                    selected: _selectedColor == i,
                    onTap: () => setState(() => _selectedColor = i),
                  ),
                ),
                if (i < _colors.length - 1) const SizedBox(width: 8),
              ],
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
                  onTap: () => Navigator.pop(context, _controller.text.trim()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
  const _AuthBrand({required this.title});

  final String title;

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
          child: const Center(
            child: FaIcon(
              FontAwesomeIcons.layerGroup,
              color: Colors.white,
              size: 20,
            ),
          ),
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
  final VoidCallback onTap;

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

class _ChipStrip extends StatelessWidget {
  const _ChipStrip({required this.labels});

  final List<String> labels;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++) ...[
            StashChip(label: labels[i], active: i == 0),
            if (i < labels.length - 1) const SizedBox(width: 8),
          ],
        ],
      ),
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
