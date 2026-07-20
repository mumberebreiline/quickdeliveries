import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/app_user_profile.dart';
import '../../providers/auth_provider.dart';
import '../../utils/validators.dart';
import '../../widgets/custom_button.dart';
import '../vendor/dashboard_screen.dart';

/// One login screen, one button, for both customers and the vendor.
/// Firebase Auth doesn't distinguish account "types" on its own — after
/// sign-in, this screen reads the account's role (see AuthProvider,
/// backed by a `users/{uid}` document in Firestore) and sends them to
/// whichever experience matches. There's no separate vendor login screen
/// and no "sign up as vendor" option — her one account is provisioned by
/// hand once, in Firebase Console, tagged role: vendor.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isRegistering = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();

    final success = _isRegistering
        ? await auth.registerAsCustomer(
            _emailController.text.trim(),
            _passwordController.text,
            name: _nameController.text.trim(),
            phone: _phoneController.text.trim(),
          )
        : await auth.signIn(
            _emailController.text.trim(),
            _passwordController.text,
          );

    if (!mounted) return;

    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(auth.errorMessage ?? 'Something went wrong')),
      );
      return;
    }

    // Same button, same call — this is the one place that decides which
    // experience to show, based purely on the account's role.
    if (auth.role == UserRole.vendor) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const VendorDashboardScreen()),
      );
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(title: Text(_isRegistering ? 'Create Account' : 'Log In')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              const Icon(Icons.person_outline, size: 56, color: Colors.grey),
              const SizedBox(height: 20),
              if (_isRegistering) ...[
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Your name'),
                  validator: (v) => Validators.notEmpty(v, fieldName: 'Name'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Phone number'),
                  validator: Validators.phone,
                ),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
                validator: Validators.email,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
                validator: Validators.password,
              ),
              const SizedBox(height: 20),
              CustomButton(
                label: _isRegistering ? 'Create Account' : 'Log In',
                fullWidth: true,
                isLoading: auth.isLoading,
                onPressed: _submit,
              ),
              const SizedBox(height: 12),
              if (!_isRegistering)
                TextButton(
                  onPressed: () => setState(() => _isRegistering = true),
                  child: const Text("Don't have an account? Sign up"),
                )
              else
                TextButton(
                  onPressed: () => setState(() => _isRegistering = false),
                  child: const Text('Already have an account? Log in'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
