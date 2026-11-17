import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../services/queries.dart';
import '../../services/graphql_service.dart';
import '../home/home_screen.dart'; // We'll create this next
import '../main_layout.dart';
import '../auth/register_driver_screen.dart'; // And this
import '../auth/sign_up_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _storage = const FlutterSecureStorage();
  bool _rememberMe = false;
  bool _obscureText = true;


  @override
  void initState() {
    super.initState();
    _loadCredentials();
  }

  Future<void> _loadCredentials() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _rememberMe = prefs.getBool('remember_me') ?? false;
    });

    if (_rememberMe) {
      final email = await _storage.read(key: 'email');
      final password = await _storage.read(key: 'password');

      if (email != null && password != null) {
        setState(() {
          _emailController.text = email;
          _passwordController.text = password;
        });
      }
    }
  }


  Future<void> _onLoginSuccess(Map<String, dynamic> data, BuildContext context) async {
    final token = data['login']['token'];
    final user = data['login']['user'];

    // Save Token
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
    await prefs.setBool('remember_me', _rememberMe);

    if (_rememberMe) {
      await _storage.write(key: 'email', value: _emailController.text.trim());
      await _storage.write(key: 'password', value: _passwordController.text.trim());
    } else {
      await _storage.delete(key: 'email');
      await _storage.delete(key: 'password');
    }

    if (!mounted) return;

    // Reset GraphQL Client to ensure new token is used immediately
    GraphQLService.resetClient();

    // Navigate based on User Type
    if (user['userType'] == 'DRIVER') {
       Navigator.pushReplacement(
        context, 
        MaterialPageRoute(builder: (_) => MainLayout())
      );
    } else {
      // If not a driver, prompt to register as driver
      Navigator.pushReplacement(
        context, 
        MaterialPageRoute(builder: (_) => const RegisterDriverScreen())
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Driver", style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        elevation: 0,
        centerTitle: true,
      ),

      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Mutation(
              options: MutationOptions(
                document: gql(Queries.login),
                onCompleted: (data) {
                  print('Login Mutation Completed: \$data');
                  if (data != null) {
                    _onLoginSuccess(data, context);
                  }
                },
                onError: (error) {
                  print('Login Mutation Error: \$error');
                  
                  String message = "Login Failed";
                  if (error != null) {
                     if (error.graphqlErrors.isNotEmpty) {
                        message = error.graphqlErrors.first.message;
                     } else if (error.linkException != null) {
                        message = "Network Error: \${error.linkException.toString()}";
                     }
                  }
    
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(message))
                  );
                }
              ),
              builder: (RunMutation runMutation, QueryResult? result) {
                return Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                       // LOGO
                       Padding(
                         padding: const EdgeInsets.only(bottom: 30),
                         child: Image.asset('assets/images/logo.png', height: 120),
                       ),
    
                       // EMAIL
                      TextFormField(
                        controller: _emailController,
                        decoration: InputDecoration(
                          labelText: "Email",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          prefixIcon: const Icon(Icons.email, color: Color(0xFFFF6600)),
                          focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFFF6600), width: 2.0))
                        ),
                        validator: (v) => v!.isEmpty ? "Required" : null,
                      ),
                      const SizedBox(height: 15),
    
                      // PASSWORD
                      TextFormField(
                        controller: _passwordController,
                        decoration: InputDecoration(
                          labelText: "Password",
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          prefixIcon: const Icon(Icons.lock, color: Color(0xFFFF6600)),
                          focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: Color(0xFFFF6600), width: 2.0)),
                          suffixIcon: IconButton(
                            icon: Icon(_obscureText ? Icons.visibility : Icons.visibility_off, color: Colors.grey),
                            onPressed: () => setState(() => _obscureText = !_obscureText),
                          )
                        ),
                        obscureText: _obscureText,
                        validator: (v) => v!.isEmpty ? "Required" : null,
                      ),
                      
                      // CHECKBOX
                      CheckboxListTile(
                        title: const Text("Recordar credenciales"),
                        activeColor: const Color(0xFFFF6600),
                        value: _rememberMe, 
                        onChanged: (v) => setState(() => _rememberMe = v ?? false),
                        controlAffinity: ListTileControlAffinity.leading,
                        contentPadding: EdgeInsets.zero,
                      ),
                      const SizedBox(height: 20),
                      if (result?.isLoading ?? false)
                        const CircularProgressIndicator()
                      else
                        ElevatedButton(
                          onPressed: () {
                            if (_formKey.currentState!.validate()) {
                              print('Attempting login with: \${_emailController.text}');
                              runMutation({
                                'email': _emailController.text.trim(),
                                'password': _passwordController.text.trim(),
                              });
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: const Color(0xFFFF6600),
                            padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                            textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                          ),
                          child: const Text("INICIAR SESIÓN"),
                        ),
                        const SizedBox(height: 20),
                        TextButton(
                          onPressed: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const SignUpScreen()));
                          }, 
                          style: TextButton.styleFrom(foregroundColor: Colors.black54),
                          child: const Text("¿No tienes cuenta? Regístrate aquí")
                        )
                    ],
                  ),
                );
            },
          ),
        ),
      ),
      ),
  );
}

}
