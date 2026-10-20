import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProfileScreen extends StatefulWidget {
  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final User? user = FirebaseAuth.instance.currentUser;
  bool isAutoReplyEnabled = false;
  String autoReplyMessage = "";
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  void _fetchUserData() async {
    if (user == null) return;
    DocumentSnapshot doc = await FirebaseFirestore.instance.collection('users').doc(user!.uid).get();
    if (doc.exists) {
      var data = doc.data() as Map<String, dynamic>;
      setState(() {
        isAutoReplyEnabled = data['autoReplyEnabled'] ?? false;
        autoReplyMessage = data['autoReplyMessage'] ?? "Hey! I'm currently busy. I'll reply soon.";
        isLoading = false;
      });
    }
  }

  void _updateAutoReply(bool value) async {
    setState(() => isAutoReplyEnabled = value);
    await FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
      'autoReplyEnabled': value,
      'autoReplyMessage': autoReplyMessage,
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(title: const Text("Profile"), backgroundColor: Colors.transparent, elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundImage: user?.photoURL != null ? NetworkImage(user!.photoURL!) : null,
              child: user?.photoURL == null ? const Icon(Icons.person, size: 50) : null,
            ),
            const SizedBox(height: 10),
            Text(user?.displayName ?? "User", style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            Text(user?.email ?? "", style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 30),
            
            // AUTO-REPLY SETTINGS CARD
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Auto-Reply (WhatsApp Style)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        Switch(
                          value: isAutoReplyEnabled,
                          activeColor: const Color(0xFF6B4EFF),
                          onChanged: _updateAutoReply,
                        ),
                      ],
                    ),
                    if (isAutoReplyEnabled) ...[
                      const SizedBox(height: 10),
                      TextFormField(
                        initialValue: autoReplyMessage,
                        maxLines: 2,
                        decoration: const InputDecoration(
                          labelText: "Auto-Reply Message",
                          border: OutlineInputBorder(),
                        ),
                        onChanged: (val) {
                          autoReplyMessage = val;
                          FirebaseFirestore.instance.collection('users').doc(user!.uid).update({
                            'autoReplyMessage': val,
                          });
                        },
                      ),
                    ]
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text("Log Out", style: TextStyle(color: Colors.red)),
              onTap: () async {
                await FirebaseAuth.instance.signOut();
                // Navigate to Login
              },
            )
          ],
        ),
      ),
    );
  }
}
