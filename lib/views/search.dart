import 'dart:io';

import 'package:chat_app/helper/constants.dart';
import 'package:chat_app/helper/helperFunctions.dart';
import 'package:chat_app/services/database.dart';
import 'package:chat_app/views/conversation_screen.dart';
import 'package:chat_app/widgets/widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart'as Path;


class SearchScreen extends StatefulWidget {
  final String uid;
  final String tag;
  final File imgFile;
  SearchScreen(this.uid, this.tag, this.imgFile);
  @override
  _SearchScreenState createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {

  Stream groupChatsSnapshot;
  TextEditingController tagEditingController = new TextEditingController();

  getAllChats(){
    DatabaseMethods(uid: widget.uid).getAllGroupChats().then((val){
      setState(() {
        groupChatsSnapshot = val;
      });
    });
  }

  searchChats(String searchText){
    if(searchText.isNotEmpty){
      DatabaseMethods(uid: widget.uid).searchGroupChats(searchText.toUpperCase()).then((val){
        setState(() {
          groupChatsSnapshot = val;
        });
      });
    }else{
      DatabaseMethods(uid: widget.uid).getAllGroupChats().then((val){
        setState(() {
          groupChatsSnapshot = val;
        });
      });
    }

  }

  joinChat(String hashTag, String groupId, String username, String admin, int numOfMem, double groupCapacity, String groupState) async{
    if(numOfMem < groupCapacity){
      await DatabaseMethods(uid: widget.uid).toggleGroupMembership(groupId, username, hashTag, "JOIN_PUB_GROUP_CHAT");
      Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (context) => ConversationScreen(groupId, hashTag, admin, widget.uid, false)
      ));
    }else{
      showAlertDialog(groupState, groupId, hashTag, admin);
    }

  }

  requestJoin(String groupId, int numOfMem, double groupCapacity, String groupState, String hashTag, String admin){
    String search = tagEditingController.text;
    if(numOfMem < groupCapacity){
      DatabaseMethods(uid: widget.uid).requestJoinGroup(groupId, Constants.myName, Constants.myEmail, search.toUpperCase()).then((val) {
        setState(() {
          groupChatsSnapshot = val;
        });
      });
    }else{
      showAlertDialog(groupState, groupId, hashTag, admin);
    }

  }

  Future sendImgOrJoin(imgUrl, String hashTag, String groupId, String admin, bool myChat, int numOfMem, double groupCapacity, groupState) async{
    DateTime now = DateTime.now();
    String formattedDate = DateFormat('kk:mm:a').format(now);

    await DatabaseMethods(uid: widget.uid).addConversationMessages(groupId, '', Constants.myName, formattedDate, now.microsecondsSinceEpoch, imgUrl);
    if(!myChat){
      joinChat(hashTag, groupId, Constants.myName, admin, numOfMem, groupCapacity, groupState);
    }
    Navigator.of(context).pop();
    if(myChat){
      Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (context) => ConversationScreen(groupId, hashTag, admin, widget.uid, false)
      ));
    }

  }


  fileUpload(File imgFile, String hashTag, String groupId, String admin, bool myChat, int numOfMem, double groupCapacity, groupState){
    String fileName = Path.basename(imgFile.path);
    Reference ref = FirebaseStorage.instance
        .ref()
        .child('chats/${widget.uid}_${Constants.myName}/$fileName');

    ref.putFile(imgFile).then((value){
      value.ref.getDownloadURL().then((val){
        sendImgOrJoin(val, hashTag, groupId, admin, myChat, numOfMem, groupCapacity, groupState);
      });
    });
  }

  Widget searchTile(
      bool myChat,
      int numOfMem,
      double groupCapacity,
      bool waitListed,
      String hashTag,
      String groupId,
      String adminName,
      String admin,
      String chatRoomState,
      List joinRequests){

    bool requested = joinRequests.contains(widget.uid + '_' + Constants.myEmail + '_' + Constants.myName);

    return Container(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(hashTag, style: TextStyle(color: Colors.black,fontWeight: FontWeight.bold,),),
                Text("Admin: "+adminName, style: TextStyle(color: Colors.black,fontWeight: FontWeight.bold,),),
                Text(chatRoomState, style: TextStyle(
                  fontSize: 16,
                  color: chatRoomState == "public" ? Colors.green : Colors.red
                ),)
              ],
            ),
            Spacer(),
            GestureDetector(
              onTap: (){

                if(myChat){
                  fileUpload(widget.imgFile, hashTag, groupId, admin, myChat, numOfMem, groupCapacity, chatRoomState);
                }else{
                  if(chatRoomState == 'private'){
                    !waitListed ? !requested ? requestJoin(groupId, numOfMem, groupCapacity, chatRoomState, hashTag, admin) : null : null;
                  }else{
                    if(widget.imgFile == null){
                      joinChat(hashTag, groupId, Constants.myName, admin, numOfMem, groupCapacity, chatRoomState);
                    }else{
                      numOfMem < groupCapacity ?
                      !waitListed ? fileUpload(widget.imgFile, hashTag, groupId, admin, myChat, numOfMem, groupCapacity, chatRoomState) :
                      null : goOnWaitListAndOrSpectate(groupId, hashTag, admin, chatRoomState);
                    }
                  }
                }
              },
              child: Container(
                decoration: BoxDecoration(
                    border: waitListed ? Border.all(
                        color: Colors.redAccent,
                        width: 3.0
                    ) : null,
                    color: !myChat ? !waitListed ? !requested ? widget.imgFile != null && numOfMem == groupCapacity ? Colors.redAccent : Colors.blue : Colors.grey : null : Theme.of(context).primaryColor,
                    borderRadius: BorderRadius.circular(30)
                ),
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Text(!waitListed ? !myChat ? !requested ? widget.imgFile != null && numOfMem == groupCapacity ? chatRoomState == "private" ?
                "Full | Waitlist" : "Full | Spectate" :
                chatRoomState == "public" ? "Join" : "Request" : "Requested" : "Send" :
                chatRoomState == 'private' ? "Waitlisted" : "Spectating",
                  style: TextStyle(color: waitListed ? Colors.redAccent : Colors.white),),
              ),
            )
          ],
        )
    );
  }

  String _destructureName(String res) {
    return res.substring(res.indexOf('_') + 1);
  }

  Widget groupChatsList(){
    return StreamBuilder(
      stream:groupChatsSnapshot,
        builder: (context, snapshot){
        if(snapshot.hasData){
          if(snapshot.data.docs != null){
            return ListView.builder(
                itemCount: snapshot.data.docs.length,
                shrinkWrap: true,
                itemBuilder: (context, index){
                  return widget.imgFile == null ? !snapshot.data.docs[index].data()['members'].contains(widget.uid + '_' + Constants.myName) ?
                  searchTile(
                      false,
                      snapshot.data.docs[index].data()['members'].length,
                      snapshot.data.docs[index].data()['groupCapacity'],
                      snapshot.data.docs[index].data()['waitList'].contains(widget.uid + '_' + Constants.myName),
                      snapshot.data.docs[index].data()["hashTag"],
                      snapshot.data.docs[index].data()["groupId"],
                      _destructureName(snapshot.data.docs[index].data()["admin"]),
                      snapshot.data.docs[index].data()["admin"],
                      snapshot.data.docs[index].data()["chatRoomState"],
                      snapshot.data.docs[index].data()["joinRequests"]
                  ): Container() :
                  searchTile(
                      snapshot.data.docs[index].data()['members'].contains(widget.uid + '_' + Constants.myName),
                      snapshot.data.docs[index].data()['members'].length,
                      snapshot.data.docs[index].data()['groupCapacity'],
                      snapshot.data.docs[index].data()['waitList'].contains(widget.uid + '_' + Constants.myName),
                      snapshot.data.docs[index].data()["hashTag"],
                      snapshot.data.docs[index].data()["groupId"],
                      _destructureName(snapshot.data.docs[index].data()["admin"]),
                      snapshot.data.docs[index].data()["admin"],
                      snapshot.data.docs[index].data()["chatRoomState"],
                      snapshot.data.docs[index].data()["joinRequests"]
                  );
                });
          }else{
            return Center(
                child: CircularProgressIndicator(),
            );
          }
        }else{
          return Center(
          child: CircularProgressIndicator(),
          );
          }
      });
  }


  @override
  void initState() {
    // TODO: implement initState
    widget.tag.isEmpty ? getAllChats() : searchChats(widget.tag);
    if(widget.tag.isNotEmpty){
      tagEditingController.text = widget.tag;
    }
    super.initState();
  }

  goOnWaitListAndOrSpectate(String groupId, String hashTag, String admin, String groupState) async{
    String search = tagEditingController.text;
    await DatabaseMethods(uid: widget.uid).putOnWaitList(groupId, Constants.myName, search.toUpperCase()).then((value) {
      setState(() {
        groupChatsSnapshot = value;
      });
    });
    if(groupState == "public"){
      Navigator.of(context).pop();
      if(widget.imgFile != null){
        Navigator.of(context).pop();
      }
      Navigator.push(context, MaterialPageRoute(
          builder: (context) => ConversationScreen(groupId, hashTag, admin, widget.uid, true)
      ));
    }


  }

  showAlertDialog(String groupState, String groupId, String hashTag, String admin){
    showDialog(
        context: context,
        builder: (BuildContext context){
          return AlertDialog(
            title: Text("Sorry"),
            content: Text(groupState == 'public' ?
            "This group you are trying to join has reached its full capacity. Do you want to be on the waitlist and spectate?" :
            "This group you are requesting to join has reached its full capacity. Do you want to be on the waitlist?"),
            actions: [
              FlatButton(
                  onPressed:(){
                    Navigator.of(context).pop();
                    goOnWaitListAndOrSpectate(groupId, hashTag, admin, groupState);
                  },
                  child: Text("YES")
              ),
              FlatButton(
                  onPressed:(){
                    Navigator.of(context).pop();
                  },
                  child: Text("NO")
              )
            ],
          );
        }
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: appBarMain(context),
        body: Container(
          color: Colors.white,
          child: Column(
            children: [
              Container(
                color: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  children: [
                    Container(
                        height: 40,
                        width: 40,
                        decoration: BoxDecoration(
                            gradient: LinearGradient(
                                colors: [
                                  const Color(0xfffb934d),
                                  const Color(0xfffb934d)
                                ]
                            ),
                            borderRadius: BorderRadius.circular(40)
                        ),
                        padding: EdgeInsets.all(12),
                        child: Image.asset("assets/images/search.png")
                    ),
                    SizedBox(width: 15,),
                    Expanded(child: TextField(
                      controller: tagEditingController,
                      onChanged: (String val){
                        searchChats(val);
                      },
                      style: TextStyle(color: Colors.black),
                      decoration: InputDecoration(

                        hintText: "Search for group",
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.orange),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.orange),
                        ),
                        border: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.orange),
                        ),
                      ),
                    )),
                  ],
                ),
          ),
              Expanded(child: groupChatsList()),
            ],
          ),
        ),
      ),
    );
  }
}



