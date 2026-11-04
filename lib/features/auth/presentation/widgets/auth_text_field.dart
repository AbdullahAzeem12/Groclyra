import 'package:flutter/material.dart';
import '../../../../core/constants/app_dimensions.dart';
import '../../../../core/theme/gradient_palette.dart';

class AuthTextField extends StatefulWidget {
  final String label;
  final String? hint;
  final TextEditingController controller;
  final bool obscureText;
  final TextInputType keyboardType;
  final TextInputAction textInputAction;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;
  final void Function(String)? onFieldSubmitted;
  final FocusNode? focusNode;
  final Iterable<String>? autofillHints;
  final AppThemePalette palette;
  final bool isDark;
  final bool enabled;
  final bool readOnly;
  final VoidCallback? onTap;

  const AuthTextField({
    super.key,
    required this.label,
    this.hint,
    required this.controller,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.textInputAction = TextInputAction.next,
    this.prefixIcon,
    this.suffixIcon,
    this.validator,
    this.onChanged,
    this.onFieldSubmitted,
    this.focusNode,
    this.autofillHints,
    required this.palette,
    required this.isDark,
    this.enabled = true,
    this.readOnly = false,
    this.onTap,
  });

  @override
  State<AuthTextField> createState() => _AuthTextFieldState();
}

class _AuthTextFieldState extends State<AuthTextField> {
  FocusNode? _internalFocusNode;
  FocusNode get _effectiveFocusNode => widget.focusNode ?? (_internalFocusNode ??= FocusNode());
  bool _isFocused = false;
  late bool _isObscured;

  @override
  void initState() {
    super.initState();
    _isObscured = widget.obscureText;
    _effectiveFocusNode.addListener(_handleFocusChange);
    _isFocused = _effectiveFocusNode.hasFocus;
  }

  @override
  void didUpdateWidget(AuthTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.focusNode != oldWidget.focusNode) {
      (oldWidget.focusNode ?? _internalFocusNode)?.removeListener(_handleFocusChange);
      _effectiveFocusNode.addListener(_handleFocusChange);
      _isFocused = _effectiveFocusNode.hasFocus;
    }
    if (widget.obscureText != oldWidget.obscureText) {
      _isObscured = widget.obscureText;
    }
  }

  void _handleFocusChange() {
    if (mounted) {
      setState(() {
        _isFocused = _effectiveFocusNode.hasFocus;
      });
    }
  }

  @override
  void dispose() {
    _effectiveFocusNode.removeListener(_handleFocusChange);
    _internalFocusNode?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final effectiveIsDark = Theme.of(context).brightness == Brightness.dark;

    final bgColor = effectiveIsDark
        ? const Color(0xFF1E293B)
        : Colors.white;

    final borderColor = _isFocused
        ? widget.palette.startColor
        : (effectiveIsDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Label
        Text(
          widget.label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _isFocused
                ? widget.palette.startColor
                : (effectiveIsDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569)),
          ),
        ),
        const SizedBox(height: AppDimensions.p8),

        // Field Container
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(AppDimensions.radiusMedium),
            border: Border.all(
              color: borderColor,
              width: _isFocused ? 1.8 : 1.0,
            ),
            boxShadow: _isFocused
                ? [
                    BoxShadow(
                      color: widget.palette.startColor
                          .withValues(alpha: effectiveIsDark ? 0.28 : 0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black
                          .withValues(alpha: effectiveIsDark ? 0.12 : 0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
          ),
          child: TextFormField(
            controller: widget.controller,
            focusNode: _effectiveFocusNode,
            obscureText: _isObscured,
            keyboardType: widget.keyboardType,
            textInputAction: widget.textInputAction,
            autofillHints: widget.autofillHints,
            enabled: widget.enabled,
            readOnly: widget.readOnly,
            onTap: widget.onTap,
            cursorColor: widget.palette.startColor,
            onChanged: widget.onChanged,
            onFieldSubmitted: widget.onFieldSubmitted,
            validator: widget.validator,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: effectiveIsDark ? Colors.white : const Color(0xFF0F172A),
            ),
            decoration: InputDecoration(
              isDense: true,
              filled: true,
              fillColor: Colors.transparent,
              hintText: widget.hint,
              hintStyle: TextStyle(
                fontSize: 14,
                color: effectiveIsDark
                    ? const Color(0xFF94A3B8)
                    : const Color(0xFF64748B),
              ),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.p16,
                vertical: AppDimensions.p16,
              ),
              prefixIcon: widget.prefixIcon != null
                  ? IconTheme(
                      data: IconThemeData(
                        size: 20,
                        color: _isFocused
                            ? widget.palette.startColor
                            : (effectiveIsDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B)),
                      ),
                      child: widget.prefixIcon!,
                    )
                  : null,
              suffixIcon: widget.obscureText
                  ? IconButton(
                      icon: Icon(
                        _isObscured
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 20,
                        color: _isFocused
                            ? widget.palette.startColor
                            : (effectiveIsDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B)),
                      ),
                      onPressed: () {
                        setState(() {
                          _isObscured = !_isObscured;
                        });
                      },
                    )
                  : widget.suffixIcon,
            ),
          ),
        ),
      ],
    );
  }
}
