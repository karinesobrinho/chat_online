import 'dart:io';
import 'package:chat/text_composer.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'ChatMessage.dart';

class ChatScreen extends StatefulWidget {
  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final GoogleSignIn googleSignIn = GoogleSignIn();

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  FirebaseUser _currentUser;

  @override
  void initState() {
    super.initState();

    FirebaseAuth.instance.onAuthStateChanged.listen((user) {
      _currentUser = user;
    });
  }

  Future<FirebaseUser> _getUser() async {
    if (_currentUser != null) return _currentUser;

    try {
      final GoogleSignInAccount googleSignInAccount =
          await googleSignIn.signIn();

      final GoogleSignInAuthentication googleSignInAuthentication =
          await googleSignInAccount.authentication;

      final AuthCredential credential = GoogleAuthProvider.getCredential(
        idToken: googleSignInAuthentication.idToken, //ou fb, ou linkedin, etc
        accessToken: googleSignInAuthentication.accessToken,
      );

      final AuthResult authResult =
          await FirebaseAuth.instance.signInWithCredential(credential);

      final FirebaseUser user = authResult.user;

      return user;
    } catch (error) {
      return null;
    }
  }

  void sendMessage({String text, File img}) async {
    final FirebaseUser user = await _getUser();

    if (user == null) {
      _scaffoldKey.currentState.showSnackBar(SnackBar(
        content: Text('Não foi possível fazer login, tente novamente'),
        backgroundColor: Colors.red,
      ));
    }

    Map<String, dynamic> data = {
      'uid': user.uid,
      'senderName': user.displayName,
      'senderPhotourl': user.photoUrl,
    };

    if (img != null) {
      StorageUploadTask task = FirebaseStorage.instance
          .ref()
          .child(DateTime.now().millisecondsSinceEpoch.toString())
          .putFile(img);

      StorageTaskSnapshot taskSnapshot = await task.onComplete;
      String url = await taskSnapshot.ref.getDownloadURL();
      print(url);
    }

    Firestore.instance.collection('message').add({'text': text});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        key: _scaffoldKey,
        appBar: AppBar(
          title: Text('Olá'),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.blueAccent,
        ),
        body: Column(
          children: <Widget>[
            Expanded(
                child: StreamBuilder<QuerySnapshot>(
                    stream:
                        Firestore.instance.collection('messages').snapshots(),
                    builder: (context, snapshot) {
                      switch (snapshot.connectionState) {
                        case ConnectionState.none:
                        case ConnectionState.waiting:
                          return Center(
                            child: CircularProgressIndicator(),
                          );
                        default:
                          List<DocumentSnapshot> documents =
                              snapshot.data.documents.reversed.toList();

                          return ListView.builder(
                            itemCount: documents.length,
                            reverse: true,
                            itemBuilder: (context, index){
                              return ChatMessage(documents[index].data, true);
                            },
                          );
                      }
                    })),
            TextComposer(sendMessage),
          ],
        ));
  }
}
