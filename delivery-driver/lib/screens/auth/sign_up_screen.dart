import 'package:flutter/material.dart';
import 'package:graphql_flutter/graphql_flutter.dart';
import '../../services/queries.dart';
import 'login_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Controllers
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _plateController = TextEditingController();
  final _licenseController = TextEditingController();
  
  String _vehicleType = "motorcycle";

  void _onSignUpSuccess(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text("Registration Successful"),
        content: const Text(
          "We have sent a verification email to your address.\n\n"
          "Please check your inbox (and spam folder) and click the link to activate your account.\n\n"
          "Once verified, you can log in."
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pushReplacement(
                context, 
                MaterialPageRoute(builder: (_) => const LoginScreen())
              );
            }, 
            child: const Text("Go to Login")
          )
        ],
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Driver Registration")),
      body: Mutation(
        options: MutationOptions(
          document: gql(Queries.registerDriverAuth),
          onCompleted: (data) {
             if (data != null) {
               _onSignUpSuccess(context);
             }
          },
          onError: (error) {
            String message = "Registration Failed";
             if (error != null) {
                 if (error.graphqlErrors.isNotEmpty) {
                    message = error.graphqlErrors.first.message;
                 } else if (error.linkException != null) {
                    message = "Network Error: ${error.linkException.toString()}";
                 }
              }
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(message), backgroundColor: Colors.red)
            );
          }
        ),
        builder: (runMutation, result) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                   const Text(
                     "Create your account", 
                     style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                     textAlign: TextAlign.center,
                   ),
                   const SizedBox(height: 20),
                   
                   // Name
                   Row(
                     children: [
                       Expanded(child: TextFormField(
                         controller: _firstNameController,
                         decoration: const InputDecoration(labelText: "First Name", border: OutlineInputBorder()),
                         validator: (v) => v!.isEmpty ? "Required" : null,
                       )),
                       const SizedBox(width: 10),
                       Expanded(child: TextFormField(
                         controller: _lastNameController,
                         decoration: const InputDecoration(labelText: "Last Name", border: OutlineInputBorder()),
                         validator: (v) => v!.isEmpty ? "Required" : null,
                       )),
                     ],
                   ),
                   const SizedBox(height: 15),

                   // Contact
                   TextFormField(
                     controller: _emailController,
                     decoration: const InputDecoration(labelText: "Email", border: OutlineInputBorder()),
                     validator: (v) => v!.contains("@") ? null : "Invalid Email",
                     keyboardType: TextInputType.emailAddress,
                   ),
                   const SizedBox(height: 15),
                   TextFormField(
                     controller: _phoneController,
                     decoration: const InputDecoration(labelText: "Phone Number", border: OutlineInputBorder()),
                     keyboardType: TextInputType.phone,
                   ),
                   const SizedBox(height: 15),

                   // Password
                   TextFormField(
                     controller: _passwordController,
                     decoration: const InputDecoration(labelText: "Password", border: OutlineInputBorder()),
                     obscureText: true,
                     validator: (v) => v!.length < 6 ? "Min 6 chars" : null,
                   ),
                   const SizedBox(height: 15),
                    TextFormField(
                     controller: _confirmPasswordController,
                     decoration: const InputDecoration(labelText: "Confirm Password", border: OutlineInputBorder()),
                     obscureText: true,
                     validator: (v) => v != _passwordController.text ? "Passwords do not match" : null,
                   ),
                   const SizedBox(height: 25),
                   
                   const Text("Vehicle Information", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                   const Divider(),
                   
                   DropdownButtonFormField<String>(
                     value: _vehicleType,
                     decoration: const InputDecoration(labelText: "Vehicle Type", border: OutlineInputBorder()),
                     items: const [
                       DropdownMenuItem(value: "motorcycle", child: Text("Motorcycle")),
                       DropdownMenuItem(value: "bicycle", child: Text("Bicycle")),
                       DropdownMenuItem(value: "car", child: Text("Car")),
                     ],
                     onChanged: (v) => setState(() => _vehicleType = v!),
                   ),
                   const SizedBox(height: 15),
                    TextFormField(
                     controller: _plateController,
                     decoration: const InputDecoration(labelText: "Plate Number", border: OutlineInputBorder()),
                     validator: (v) => v!.isEmpty ? "Required" : null,
                   ),
                   const SizedBox(height: 15),
                    TextFormField(
                     controller: _licenseController,
                     decoration: const InputDecoration(labelText: "Driver License Number", border: OutlineInputBorder()),
                     validator: (v) => v!.isEmpty ? "Required" : null,
                   ),
                   const SizedBox(height: 30),

                   if (result?.isLoading ?? false)
                      const Center(child: CircularProgressIndicator())
                   else
                      ElevatedButton(
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            runMutation({
                              'firstName': _firstNameController.text.trim(),
                              'lastName': _lastNameController.text.trim(),
                              'email': _emailController.text.trim(),
                              'phoneNr': _phoneController.text.trim(),
                              'password': _passwordController.text,
                              'vehicleType': _vehicleType,
                              'plateNumber': _plateController.text.trim(),
                              'licenseNumber': _licenseController.text.trim()
                            });
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          textStyle: const TextStyle(fontSize: 18)
                        ),
                        child: const Text("Register"),
                      ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
