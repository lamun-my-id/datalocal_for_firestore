# datalocal_for_firestore
Flutter local data with integration with firestore saved with state

You can try it on
[datalocal.web.app](https://datalocal.web.app).

### Usage

```dart
import 'package:datalocal_for_firestore/datalocal_for_firestore.dart';

...
Future<void> initialize() async {
  state = await DataLocalForFirestore.create(
      "notes",
      onRefresh: () {
        setState(() {});
      },
    );
    state.onRefresh = () {
      data = state.data;
      setState(() {});
    };
    state.refresh();
  ...
...
```

### DataLocal

[DataLocalForFirestore] is a class to initialize and save any state of data 

For example:

```dart
...
  state = await DataLocalForFirestore.create(
      "notes",
      onRefresh: () {
        setState(() {});
      },
    );
    state.onRefresh = () {
      data = state.data;
      setState(() {});
    };
    state.refresh();
    loading = false;
    setState(() {});
...
```
