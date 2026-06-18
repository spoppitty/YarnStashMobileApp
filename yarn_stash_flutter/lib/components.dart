import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

import 'app_style.dart';

class NavTitle extends StatelessWidget {
  const NavTitle(this.text, {super.key, this.size = 32});

  final String text;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: size,
        height: 1.05,
        fontWeight: FontWeight.w900,
        letterSpacing: tightLetterSpacing,
      ),
    );
  }
}

class NavRow extends StatelessWidget {
  const NavRow({
    super.key,
    this.title,
    this.leading,
    this.trailing,
    this.marginTop = 8,
  });

  final String? title;
  final Widget? leading;
  final Widget? trailing;
  final double marginTop;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(top: marginTop),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 42),
        child: Row(
          children: [
            ?leading,
            if (title != null)
              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: NavTitle(title!),
                ),
              )
            else
              const Spacer(),
            ?trailing,
          ],
        ),
      ),
    );
  }
}

class CircleIconButton extends StatelessWidget {
  const CircleIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.backgroundColor = AppColors.card,
    this.foregroundColor = AppColors.ink,
    this.borderColor = AppColors.line,
    this.size = 42,
    this.iconSize = 17,
    this.label,
  });

  final FaIconData icon;
  final VoidCallback? onTap;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color borderColor;
  final double size;
  final double iconSize;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: backgroundColor,
      shape: CircleBorder(side: BorderSide(color: borderColor)),
      elevation: 0,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: size,
          height: size,
          child: Center(
            child: FaIcon(icon, size: iconSize, color: foregroundColor),
          ),
        ),
      ),
    );

    return DecoratedBox(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: appShadow,
      ),
      child: label == null
          ? button
          : Semantics(label: label, button: true, child: button),
    );
  }
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.height = 54,
    this.fullWidth = true,
  });

  final String label;
  final FaIconData? icon;
  final VoidCallback? onTap;
  final double height;
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    return _ActionButton(
      label: label,
      icon: icon,
      onTap: onTap,
      height: height,
      fullWidth: fullWidth,
      backgroundColor: AppColors.accent,
      foregroundColor: Colors.white,
      borderColor: AppColors.accent,
      borderRadius: 20,
      shadows: accentShadow,
    );
  }
}

class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.height = 48,
    this.fullWidth = true,
    this.foregroundColor = AppColors.ink,
  });

  final String label;
  final FaIconData? icon;
  final VoidCallback? onTap;
  final double height;
  final bool fullWidth;
  final Color foregroundColor;

  @override
  Widget build(BuildContext context) {
    return _ActionButton(
      label: label,
      icon: icon,
      onTap: onTap,
      height: height,
      fullWidth: fullWidth,
      backgroundColor: AppColors.card,
      foregroundColor: foregroundColor,
      borderColor: AppColors.line,
      borderRadius: 18,
      shadows: const [],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.borderColor,
    required this.borderRadius,
    required this.shadows,
    this.icon,
    this.onTap,
    this.height = 54,
    this.fullWidth = true,
  });

  final String label;
  final FaIconData? icon;
  final VoidCallback? onTap;
  final double height;
  final bool fullWidth;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color borderColor;
  final double borderRadius;
  final List<BoxShadow> shadows;

  @override
  Widget build(BuildContext context) {
    final child = Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(borderRadius),
      child: InkWell(
        borderRadius: BorderRadius.circular(borderRadius),
        onTap: onTap,
        child: SizedBox(
          height: height,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    FaIcon(icon, color: foregroundColor, size: 16),
                    const SizedBox(width: 10),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: foregroundColor,
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        letterSpacing: tightLetterSpacing,
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

    return Container(
      width: fullWidth ? double.infinity : null,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(color: borderColor),
        boxShadow: shadows,
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }
}

class SearchBox extends StatefulWidget {
  const SearchBox({
    super.key,
    required this.text,
    this.highlighted = false,
    this.trailingIcon,
    this.onTap,
  });

  final String text;
  final bool highlighted;
  final FaIconData? trailingIcon;
  final VoidCallback? onTap;

  @override
  State<SearchBox> createState() => _SearchBoxState();
}

class _SearchBoxState extends State<SearchBox> {
  late final TextEditingController _controller;
  bool _hasText = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController()..addListener(_handleTextChanged);
  }

  @override
  void didUpdateWidget(SearchBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      setState(() {});
    }
  }

  void _handleTextChanged() {
    final hasText = _controller.text.isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  void _clearText() {
    _controller.clear();
  }

  @override
  void dispose() {
    _controller.removeListener(_handleTextChanged);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final iconColor = widget.highlighted ? AppColors.accent : AppColors.muted;
    return Material(
      color: AppColors.card,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        height: 50,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: widget.highlighted ? AppColors.accent : AppColors.line,
          ),
          boxShadow: appShadow,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          children: [
            FaIcon(
              FontAwesomeIcons.magnifyingGlass,
              size: 15,
              color: iconColor,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _controller,
                onTap: widget.onTap,
                cursorColor: AppColors.accent,
                maxLines: 1,
                textInputAction: TextInputAction.search,
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 15,
                  fontWeight: widget.highlighted
                      ? FontWeight.w900
                      : FontWeight.w700,
                  letterSpacing: tightLetterSpacing,
                ),
                decoration: InputDecoration(
                  hintText: widget.text.isEmpty ? null : widget.text,
                  hintStyle: TextStyle(
                    color: AppColors.muted,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: tightLetterSpacing,
                  ),
                ),
              ),
            ),
            if (_hasText) ...[
              const SizedBox(width: 10),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _clearText,
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: FaIcon(
                    FontAwesomeIcons.xmark,
                    size: 16,
                    color: AppColors.muted,
                  ),
                ),
              ),
            ] else if (widget.trailingIcon != null) ...[
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.all(4),
                child: FaIcon(
                  widget.trailingIcon,
                  size: 16,
                  color: AppColors.muted,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class StashChip extends StatelessWidget {
  const StashChip({
    super.key,
    required this.label,
    this.active = false,
    this.small = false,
    this.icon,
    this.trailingIcon,
  });

  final String label;
  final bool active;
  final bool small;
  final FaIconData? icon;
  final FaIconData? trailingIcon;

  @override
  Widget build(BuildContext context) {
    final height = small ? 28.0 : 34.0;
    return Container(
      height: height,
      padding: EdgeInsets.symmetric(horizontal: small ? 9 : 12),
      decoration: BoxDecoration(
        color: active ? AppColors.ink : AppColors.card,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: active ? AppColors.ink : AppColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            FaIcon(
              icon,
              size: small ? 10 : 12,
              color: active ? Colors.white : AppColors.muted,
            ),
            SizedBox(width: small ? 5 : 7),
          ],
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: active ? Colors.white : AppColors.muted,
              fontSize: small ? 11 : 13,
              fontWeight: FontWeight.w800,
              letterSpacing: tightLetterSpacing,
            ),
          ),
          if (trailingIcon != null) ...[
            SizedBox(width: small ? 5 : 7),
            FaIcon(
              trailingIcon,
              size: small ? 10 : 12,
              color: active ? Colors.white : AppColors.muted,
            ),
          ],
        ],
      ),
    );
  }
}

class CardSurface extends StatelessWidget {
  const CardSurface({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.radius = 24,
    this.gradient,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Gradient? gradient;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(radius);
    return Container(
      decoration: BoxDecoration(
        color: gradient == null ? AppColors.card : null,
        gradient: gradient,
        borderRadius: borderRadius,
        border: Border.all(color: AppColors.line),
        boxShadow: appShadow,
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: borderRadius,
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.value,
    required this.label,
    this.centered = false,
    this.valueSize = 21,
  });

  final String value;
  final String label;
  final bool centered;
  final double valueSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.card, Color(0xFFFFF5ED)],
        ),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: centered
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: centered ? TextAlign.center : TextAlign.left,
            style: TextStyle(
              fontSize: valueSize,
              fontWeight: FontWeight.w900,
              height: 1.05,
              letterSpacing: tightLetterSpacing,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: centered ? TextAlign.center : TextAlign.left,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: tightLetterSpacing,
            ),
          ),
        ],
      ),
    );
  }
}

class InfoField extends StatelessWidget {
  const InfoField({
    super.key,
    required this.label,
    this.value,
    this.child,
    this.mutedValue = false,
    this.minHeight,
  }) : assert(value != null || child != null);

  final String label;
  final String? value;
  final Widget? child;
  final bool mutedValue;
  final double? minHeight;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(minHeight: minHeight ?? 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FieldLabel(label),
          const SizedBox(height: 4),
          child ??
              Text(
                value!,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: mutedValue ? AppColors.muted : AppColors.ink,
                  fontSize: 16,
                  fontWeight: mutedValue ? FontWeight.w700 : FontWeight.w800,
                  letterSpacing: tightLetterSpacing,
                ),
              ),
        ],
      ),
    );
  }
}

class FieldLabel extends StatelessWidget {
  const FieldLabel(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: const TextStyle(
        color: AppColors.muted,
        fontSize: 12,
        fontWeight: FontWeight.w900,
        letterSpacing: 0.5,
      ),
    );
  }
}

class AuthField extends StatelessWidget {
  const AuthField({
    super.key,
    required this.label,
    this.initialValue,
    this.hintText,
    this.obscureText = false,
    this.controller,
    this.keyboardType,
    this.suffixIcon,
  });

  final String label;
  final String? initialValue;
  final String? hintText;
  final bool obscureText;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final Widget? suffixIcon;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 58),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
        boxShadow: appShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          FieldLabel(label),
          const SizedBox(height: 4),
          TextFormField(
            controller: controller,
            initialValue: controller == null ? initialValue : null,
            obscureText: obscureText,
            keyboardType: keyboardType,
            cursorColor: AppColors.accent,
            style: const TextStyle(
              color: AppColors.ink,
              fontSize: 16,
              fontWeight: FontWeight.w800,
              letterSpacing: tightLetterSpacing,
            ),
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: const TextStyle(
                color: AppColors.muted,
                fontWeight: FontWeight.w800,
                letterSpacing: tightLetterSpacing,
              ),
              suffixIcon: suffixIcon,
              suffixIconConstraints: const BoxConstraints(
                minWidth: 24,
                minHeight: 24,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SelectField extends StatelessWidget {
  const SelectField({
    super.key,
    required this.value,
    required this.items,
    this.hintText,
    this.onChanged,
  });

  final String? value;
  final List<String> items;
  final String? hintText;
  final ValueChanged<String?>? onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonHideUnderline(
      child: SizedBox(
        height: 22,
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          isDense: true,
          hint: Text(hintText ?? ''),
          itemHeight: kMinInteractiveDimension,
          borderRadius: BorderRadius.circular(18),
          iconEnabledColor: AppColors.muted,
          iconSize: 18,
          style: const TextStyle(
            color: AppColors.ink,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: tightLetterSpacing,
          ),
          items: [
            for (final item in items)
              DropdownMenuItem(value: item, child: Text(item)),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class InlineTextField extends StatelessWidget {
  const InlineTextField({
    super.key,
    required this.controller,
    this.keyboardType,
    this.maxLines = 1,
    this.muted = false,
  });

  final TextEditingController controller;
  final TextInputType? keyboardType;
  final int maxLines;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      minLines: maxLines > 1 ? maxLines : null,
      cursorColor: AppColors.accent,
      style: TextStyle(
        color: muted ? AppColors.muted : AppColors.ink,
        fontSize: 16,
        height: 1.25,
        fontWeight: muted ? FontWeight.w700 : FontWeight.w800,
        letterSpacing: tightLetterSpacing,
      ),
      decoration: const InputDecoration(
        border: InputBorder.none,
        enabledBorder: InputBorder.none,
        focusedBorder: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.zero,
      ),
    );
  }
}

class YarnPhoto extends StatelessWidget {
  const YarnPhoto({
    super.key,
    required this.url,
    required this.width,
    required this.height,
    this.radius = 20,
    this.fallbackColor = AppColors.rose,
  });

  final String url;
  final double width;
  final double height;
  final double radius;
  final Color fallbackColor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: width,
        height: height,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, progress) {
            if (progress == null) return child;
            return _YarnPhotoFallback(color: fallbackColor);
          },
          errorBuilder: (context, error, stackTrace) {
            return _YarnPhotoFallback(color: fallbackColor);
          },
        ),
      ),
    );
  }
}

class _YarnPhotoFallback extends StatelessWidget {
  const _YarnPhotoFallback({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color, AppColors.cream],
        ),
      ),
      child: Center(
        child: FaIcon(
          FontAwesomeIcons.basketShopping,
          size: 28,
          color: AppColors.accentDark.withValues(alpha: 0.75),
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w900,
        letterSpacing: tightLetterSpacing,
      ),
    );
  }
}

class UploadBox extends StatelessWidget {
  const UploadBox({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DashedRRectPainter(color: AppColors.line, radius: 20),
      child: Container(
        height: 96,
        width: double.infinity,
        decoration: BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FaIcon(FontAwesomeIcons.camera, color: AppColors.accent, size: 24),
            SizedBox(height: 8),
            Text(
              'Add images (optional)',
              style: TextStyle(
                color: AppColors.accent,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                letterSpacing: tightLetterSpacing,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  const _DashedRRectPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)),
      );
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        final next = math.min(distance + 8, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance += 14;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.radius != radius;
  }
}

class ProgressRow extends StatelessWidget {
  const ProgressRow({super.key, required this.label, required this.percent});

  final String label;
  final int percent;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: tightLetterSpacing,
              ),
            ),
            Text(
              '$percent%',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                letterSpacing: tightLetterSpacing,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: SizedBox(
            height: 10,
            child: Stack(
              children: [
                Positioned.fill(child: Container(color: AppColors.taupeSoft)),
                FractionallySizedBox(
                  widthFactor: percent / 100,
                  child: Container(color: AppColors.accent),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class IconBadge extends StatelessWidget {
  const IconBadge({
    super.key,
    required this.icon,
    required this.background,
    required this.foreground,
    this.size = 48,
    this.iconSize = 18,
  });

  final FaIconData icon;
  final Color background;
  final Color foreground;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(size >= 54 ? 20 : 16),
      ),
      child: Center(
        child: FaIcon(icon, color: foreground, size: iconSize),
      ),
    );
  }
}

class LinkText extends StatelessWidget {
  const LinkText({super.key, required this.text, this.onTap, this.size = 14});

  final String text;
  final VoidCallback? onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Text(
        text,
        style: TextStyle(
          color: AppColors.accentDark,
          fontSize: size,
          fontWeight: FontWeight.w900,
          letterSpacing: tightLetterSpacing,
        ),
      ),
    );
  }
}

class ChoiceButton extends StatelessWidget {
  const ChoiceButton({
    super.key,
    required this.label,
    required this.selected,
    this.icon,
    this.onTap,
    this.height = 48,
  });

  final String label;
  final bool selected;
  final FaIconData? icon;
  final VoidCallback? onTap;
  final double height;

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
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? AppColors.accentDark : AppColors.line,
              width: selected ? 2 : 1,
            ),
          ),
          child: Center(
            child: icon == null
                ? Text(
                    label,
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w900,
                      letterSpacing: tightLetterSpacing,
                    ),
                  )
                : FaIcon(icon, color: color, size: 17),
          ),
        ),
      ),
    );
  }
}

class SwatchButton extends StatelessWidget {
  const SwatchButton({
    super.key,
    required this.color,
    required this.selected,
    this.icon,
    this.iconColor = AppColors.muted,
    this.onTap,
  });

  final Color color;
  final bool selected;
  final FaIconData? icon;
  final Color iconColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.accentDark : AppColors.line,
              width: selected ? 2 : 1,
            ),
          ),
          child: icon == null
              ? null
              : Center(child: FaIcon(icon, color: iconColor, size: 15)),
        ),
      ),
    );
  }
}

class ModalCard extends StatelessWidget {
  const ModalCard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: CardSurface(
        radius: 24,
        padding: const EdgeInsets.all(16),
        child: child,
      ),
    );
  }
}
