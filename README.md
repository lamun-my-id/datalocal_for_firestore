# DataLocal for Firestore

Plugin package to store data locally with storage techniques using the "shared preferences" plugin, this plugin already supports Android, iOS, Web, Windows, MacOS, and Linux. Data storage and data retrieval use isolates, so it can maximize the performance of flutter.

In addition, storing data in a structured manner, so it can be used to replace a local database. and there are various ways to call data, change data and delete data.

You can try it on
[datalocal.web.app](https://datalocal.web.app).

## Getting Started

The plugin itself is quite easy to use. Just call the DataLocal().create() method with the arguments. Don't forget to name the data state for example "notes". After that, you can do whatever you need such as inserting data, updating data, deleting data.
The state data will be reloaded when the app is restarted, but the data will remain there, until the app is removed or uninstalled.

#### Initialize example
```dart
state = await DataLocalForFirestore.stream("notes", collectionPath: "userNotes", onRefresh: () => setState(() {}));
```
change the name "note" with the name of the appropriate collection.

onRefresh can be filled in for what will be done when there is a data change (create, update, delete).

### Usage

for data usage and retrieval. Can be done using find(), this can also be done by sorting and filtering data easily. The result of data retrieval is a DataQuery containing data, the amount of data and the amount of data searched.

DataItem is the data that is stored, you can retrieve data directly in the form of Map<String, dynamic> or you can retrieve data according to the desired field using data.get(Datakey("field name")).
```dart
child: FutureBuilder<DataQuery>(
future: state.find(sorts:[DataSort(DataKey("#createdAt"))]),
builder: (_, snapshot){
    if(!snapshot.hasData) return CircularProgressIndicator();
    DataQuery query = snapshot.data;
    List<DataItem> datas = query.data;
    return Column(
    children: List.generate(datas.length, (index){
        DataItem data = datas[index];
        return Text(data.get(DataKey("title")));
    },
    );
    )
},
),
```
## Contribution 
You can request new features, file issues for missing features relevant to this plugin. You can also help by pointing out any bugs. Feedback is also welcome.

## Status 
DataLocal will continue to be active in helping especially ourselves in project development.

## Support the package (optional) 
If you find this package useful, you can support it by giving it a star.

## Credits 
This package is developed by void
