// import 'package:datalocal_for_firestore/datalocal_for_firestore.dart';
// import 'package:datalocal_for_firestore/datalocal_for_firestore_extension.dart';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:datalocal_for_firestore/datalocal_for_firestore.dart';
import 'package:datalocal_for_firestore/datalocal_for_firestore_extension.dart';
// import 'package:datalocal_for_firestore/datalocal_for_firestore_extension.dart';
// import 'package:example/dl.dart';
// import 'package:datalocal/datalocal.dart';
import 'package:example/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  await initializeDateFormatting();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late DataLocalForFirestore notesDataLocal;
  List<DataItem> notes = [];
  bool isLoading = false;

  DataItem? selectedData;

  TextEditingController titleController = TextEditingController();
  TextEditingController contentController = TextEditingController();

  openForm(DataItem value) {
    selectedData = value;
    // titleController.text = value.get(DataKey('title'));
    // contentController.text = value.get(DataKey("content"));
    setState(() {});
  }

  closeForm() {
    selectedData = null;
    titleController.text = "";
    contentController.text = "";
    setState(() {});
  }

  save() async {
    if (selectedData != null) {
      edit();
    } else {
      await notesDataLocal.insertOne({
        "title": titleController.text,
        "content": contentController.text,
        "createdAt": DateTime.now(),
        "updatedAt": null,
      });
      titleController.clear();
      contentController.clear();
      setState(() {});
    }
  }

  edit() async {
    await notesDataLocal.updateSyncOne(selectedData!.id, value: {
      "title": titleController.text,
      "content": contentController.text,
      "updatedAt": DateTime.now(),
    });
    setState(() {});
  }

  delete() async {
    bool rmv = (await showDialog<bool?>(
          context: context,
          builder: (_) {
            return AlertDialog(
              title: const Text('Delete this note'),
              content: const Text(
                'This action cannot be undone',
              ),
              actions: <Widget>[
                TextButton(
                  style: TextButton.styleFrom(
                    textStyle: Theme.of(context).textTheme.labelLarge,
                  ),
                  child: const Text('Delete'),
                  onPressed: () {
                    Navigator.of(context).pop(true);
                  },
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    textStyle: Theme.of(context).textTheme.labelLarge,
                  ),
                  child: const Text('Cancel'),
                  onPressed: () {
                    Navigator.of(context).pop(false);
                  },
                ),
              ],
            );
          },
        )) ??
        false;
    if (rmv) {
      await notesDataLocal.deleteOne(selectedData!.id);
      selectedData = null;
      titleController.clear();
      contentController.clear();
      setState(() {});
    }
  }

  Future<void> initialize() async {
    isLoading = true;
    setState(() {});
    notesDataLocal = await DataLocalForFirestore.stream(
      "notes",
      collectionPath: "notes",
      onRefresh: () {
        setState(() {});
      },
      debugMode: true,
      sorts: [
        DataSort(key: DataKey("updatedAt")),
      ],
    );
    notesDataLocal.onRefresh = () async {
      notes = await notesDataLocal.find(
        sorts: [
          DataSort(key: DataKey("updatedAt", onKeyCatch: "createdAt")),
        ],
      );
      // for (DataItem note in notes) {
      //   print("========================${note.updatedAt}-${note.get("title")}");
      // }
      setState(() {});
    };
    notesDataLocal.refresh();
    isLoading = false;
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    initialize();
  }

  @override
  Widget build(BuildContext context) {
    double width = MediaQuery.of(context).size.width;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text("Datalocal for Firestore Demo"),
      ),
      body: SizedBox(
        width: width,
        height: MediaQuery.of(context).size.height,
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream:
                      FirebaseFirestore.instance.collection("locs").snapshots(),
                  builder: (_, snapshot) {
                    if (!snapshot.hasData) {
                      return const Text("Loading");
                    }
                    return SingleChildScrollView(
                      child: Column(
                        children:
                            List.generate(snapshot.data!.docs.length, (index) {
                          DocumentSnapshot<Map<String, dynamic>> e =
                              snapshot.data!.docs[index];

                          DataItem d = DataItem().setFromDoc(e);
                          return Column(
                            children: [
                              Text(e.id),
                              Text(e.data()!['geo'].toString()),
                              Text(d.id),
                              Text(DataItem.fromMap(jsonDecode(d.toJson()))
                                  .get(DataKey("geo.latitude"))
                                  .toString()),
                            ],
                          );
                        }),
                      ),
                    );
                  }),
            ),
            // StreamBuilder(
            //   stream:
            //       FirebaseFirestore.instance.collection("notes").snapshots(),
            //   builder: (_, snapshot) {
            //     if (!snapshot.hasData) {
            //       return const SizedBox(
            //         child: Text("Loading"),
            //       );
            //     } else {
            //       return Text("${snapshot.data!.docs.length}");
            //     }
            //   },
            // ),
            // Text(notesDataLocal.data.length.toString()),
            // Expanded(
            //   flex: 5,
            //   child: Builder(
            //     builder: (_) {
            //       if (isLoading) {
            //         return const Center(
            //           child: CircularProgressIndicator(),
            //         );
            //       }
            //       return Column(
            //         children: [
            //           Text(notesDataLocal.count.toString()),
            //           Expanded(
            //             child: ListView.builder(
            //               padding: const EdgeInsets.symmetric(
            //                 horizontal: 16,
            //                 vertical: 8,
            //               ),
            //               itemCount: notesDataLocal.count,
            //               itemBuilder: (_, index) {
            //                 DataItem data = notes[index];
            //                 return Padding(
            //                   padding: const EdgeInsets.symmetric(
            //                     vertical: 4,
            //                   ),
            //                   child: InkWell(
            //                     onTap: () => openForm(data),
            //                     child: Container(
            //                       width: width,
            //                       padding: const EdgeInsets.symmetric(
            //                         horizontal: 16,
            //                         vertical: 16,
            //                       ),
            //                       decoration: BoxDecoration(
            //                         color: Colors.white,
            //                         borderRadius: BorderRadius.circular(10),
            //                       ),
            //                       child: Column(
            //                         crossAxisAlignment:
            //                             CrossAxisAlignment.start,
            //                         children: [
            //                           SizedBox(
            //                             width: width,
            //                             child: Text(
            //                               data.get(DataKey("title")),
            //                               style: const TextStyle(
            //                                 fontSize: 16,
            //                                 fontWeight: FontWeight.w600,
            //                               ),
            //                             ),
            //                           ),
            //                           Text(
            //                             data.get(DataKey("content")),
            //                             maxLines: 3,
            //                             overflow: TextOverflow.ellipsis,
            //                           ),
            //                           Text(
            //                               "${data.get(DataKey("updatedAt", onKeyCatch: "createdAt")) ?? "-"}")
            //                           // Text(
            //                           //   DateTimeUtils.dateFormat(
            //                           //           data.get("createdAt")) ??
            //                           //       "",
            //                           //   overflow: TextOverflow.ellipsis,
            //                           //   style: const TextStyle(
            //                           //     fontSize: 12,
            //                           //   ),
            //                           // ),
            //                         ],
            //                       ),
            //                     ),
            //                   ),
            //                 );
            //               },
            //             ),
            //           ),
            //         ],
            //       );
            //     },
            //   ),
            // ),
            // Expanded(
            //   flex: 5,
            //   child: Container(
            //     decoration: const BoxDecoration(
            //       color: Colors.white,
            //       border: Border(
            //         top: BorderSide(),
            //       ),
            //     ),
            //     child: Column(
            //       children: [
            //         Expanded(
            //           child: SingleChildScrollView(
            //             padding: const EdgeInsets.symmetric(
            //               horizontal: 16,
            //               vertical: 16,
            //             ),
            //             child: Column(
            //               children: [
            //                 Container(
            //                   width: width,
            //                   padding: const EdgeInsets.symmetric(
            //                     vertical: 16,
            //                   ),
            //                   child: const Text(
            //                     "Title",
            //                     style: TextStyle(
            //                       fontSize: 18,
            //                     ),
            //                   ),
            //                 ),
            //                 TextField(
            //                   controller: titleController,
            //                   decoration: const InputDecoration(
            //                     border: OutlineInputBorder(),
            //                   ),
            //                 ),
            //                 Container(
            //                   width: width,
            //                   padding: const EdgeInsets.symmetric(
            //                     vertical: 16,
            //                   ),
            //                   child: const Text(
            //                     "Content",
            //                     style: TextStyle(
            //                       fontSize: 18,
            //                     ),
            //                   ),
            //                 ),
            //                 TextField(
            //                   controller: contentController,
            //                   minLines: 4,
            //                   maxLines: 100,
            //                   decoration: const InputDecoration(
            //                     border: OutlineInputBorder(),
            //                   ),
            //                 ),
            //               ],
            //             ),
            //           ),
            //         ),
            //         Container(
            //           height: 60,
            //           width: width,
            //           color: Colors.grey[50],
            //           padding: const EdgeInsets.symmetric(
            //             horizontal: 16,
            //           ),
            //           child: Row(
            //             crossAxisAlignment: CrossAxisAlignment.center,
            //             mainAxisAlignment: MainAxisAlignment.end,
            //             children: [
            //               if (selectedData != null)
            //                 InkWell(
            //                   onTap: () => delete(),
            //                   child: Container(
            //                     padding: const EdgeInsets.symmetric(
            //                       horizontal: 16,
            //                       vertical: 8,
            //                     ),
            //                     decoration: BoxDecoration(
            //                       color: Colors.grey[200],
            //                       borderRadius: BorderRadius.circular(4),
            //                     ),
            //                     child: const Text(
            //                       "Delete",
            //                       style: TextStyle(
            //                           // color: Colors.white,
            //                           ),
            //                     ),
            //                   ),
            //                 ),
            //               const Expanded(child: SizedBox()),
            //               if (selectedData != null)
            //                 InkWell(
            //                   onTap: () => closeForm(),
            //                   child: Container(
            //                     padding: const EdgeInsets.symmetric(
            //                       horizontal: 16,
            //                       vertical: 8,
            //                     ),
            //                     decoration: BoxDecoration(
            //                       color: Colors.grey[200],
            //                       borderRadius: BorderRadius.circular(4),
            //                     ),
            //                     child: const Text(
            //                       "Cancel",
            //                       style: TextStyle(
            //                           // color: Colors.white,
            //                           ),
            //                     ),
            //                   ),
            //                 ),
            //               const SizedBox(
            //                 width: 16,
            //               ),
            //               InkWell(
            //                 onTap: () => save(),
            //                 child: Container(
            //                   padding: const EdgeInsets.symmetric(
            //                     horizontal: 16,
            //                     vertical: 8,
            //                   ),
            //                   decoration: BoxDecoration(
            //                     color: Colors.deepPurple,
            //                     borderRadius: BorderRadius.circular(4),
            //                   ),
            //                   child: const Text(
            //                     "Save",
            //                     style: TextStyle(
            //                       color: Colors.white,
            //                     ),
            //                   ),
            //                 ),
            //               ),
            //             ],
            //           ),
            //         ),
            //       ],
            //     ),
            //   ),
            // ),
          ],
        ),
      ),
    );
  }
}
