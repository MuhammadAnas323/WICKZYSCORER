import 'package:flutter/material.dart';
import 'package:sportyapp/theme/app_colors.dart';
import 'package:sportyapp/theme/app_text_styles.dart';

class CommonSignupForm extends StatefulWidget {
  final bool isScorer;
  const CommonSignupForm({super.key, this.isScorer = false});

  @override
  State<CommonSignupForm> createState() => CommonSignupFormState();
}

class CommonSignupFormState extends State<CommonSignupForm> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  
  final nameController = TextEditingController();
  final emailController = TextEditingController();
  final phoneController = TextEditingController();
  final addressController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final orgController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirm = true;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  @override
  void initState() {
    super.initState();
    _shakeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _shakeAnimation = Tween<double>(begin: 0, end: 10).animate(CurvedAnimation(
      parent: _shakeController,
      curve: Curves.elasticIn,
    ));
  }

  @override
  void dispose() {
    nameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    addressController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    orgController.dispose();
    _shakeController.dispose();
    super.dispose();
  }

  bool validate() {
    if (_formKey.currentState?.validate() ?? false) {
      return true;
    }
    _shakeController.forward(from: 0);
    return false;
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    bool? obscureText,
    VoidCallback? onToggleObscure,
    String? Function(String?)? validator,
  }) {
    return AnimatedBuilder(
      animation: _shakeAnimation,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(
            (controller.text.isEmpty && _shakeController.isAnimating) ? _shakeAnimation.value : 0,
            0,
          ),
          child: child,
        );
      },
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16.0),
        child: TextFormField(
          controller: controller,
          obscureText: obscureText ?? false,
          style: AppTextStyles.bodyMedium(Colors.white),
          decoration: InputDecoration(
            labelText: label,
            labelStyle: AppTextStyles.bodyMedium(AppColors.charcoal200),
            prefixIcon: Icon(icon, color: AppColors.charcoal200),
            suffixIcon: isPassword
                ? IconButton(
                    icon: Icon(
                      obscureText == true ? Icons.visibility_off : Icons.visibility,
                      color: AppColors.charcoal200,
                    ),
                    onPressed: onToggleObscure,
                  )
                : null,
            filled: true,
            fillColor: AppColors.darkSurfaceVariant,
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.charcoal600),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: widget.isScorer ? AppColors.floodlightGold : AppColors.pitchGreen),
            ),
            errorBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.error),
            ),
          ),
          validator: validator,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          _buildField(
            controller: nameController,
            label: 'Full Name',
            icon: Icons.person_outline,
            validator: (val) => val == null || val.isEmpty ? 'Required' : null,
          ),
          _buildField(
            controller: emailController,
            label: 'Email',
            icon: Icons.email_outlined,
            validator: (val) => val == null || val.isEmpty ? 'Required' : null,
          ),
          _buildField(
            controller: phoneController,
            label: 'Phone',
            icon: Icons.phone_outlined,
            validator: (val) => val == null || val.isEmpty ? 'Required' : null,
          ),
          _buildField(
            controller: addressController,
            label: 'Address',
            icon: Icons.location_on_outlined,
            validator: (val) => val == null || val.isEmpty ? 'Required' : null,
          ),
          if (widget.isScorer)
            _buildField(
              controller: orgController,
              label: 'Organization / Club (Optional)',
              icon: Icons.business_outlined,
            ),
          _buildField(
            controller: passwordController,
            label: 'Password',
            icon: Icons.lock_outline,
            isPassword: true,
            obscureText: _obscurePassword,
            onToggleObscure: () => setState(() => _obscurePassword = !_obscurePassword),
            validator: (val) => val == null || val.isEmpty ? 'Required' : null,
          ),
          _buildField(
            controller: confirmPasswordController,
            label: 'Confirm Password',
            icon: Icons.lock_outline,
            isPassword: true,
            obscureText: _obscureConfirm,
            onToggleObscure: () => setState(() => _obscureConfirm = !_obscureConfirm),
            validator: (val) {
              if (val == null || val.isEmpty) return 'Required';
              if (val != passwordController.text) return 'Passwords do not match';
              return null;
            },
          ),
        ],
      ),
    );
  }
}
