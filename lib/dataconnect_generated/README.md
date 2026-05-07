# dataconnect_generated SDK

## Installation
```sh
flutter pub get firebase_data_connect
flutterfire configure
```
For more information, see [Flutter for Firebase installation documentation](https://firebase.google.com/docs/data-connect/flutter-sdk#use-core).

## Data Connect instance
Each connector creates a static class, with an instance of the `DataConnect` class that can be used to connect to your Data Connect backend and call operations.

### Connecting to the emulator

```dart
String host = 'localhost'; // or your host name
int port = 9399; // or your port number
ExampleConnector.instance.dataConnect.useDataConnectEmulator(host, port);
```

You can also call queries and mutations by using the connector class.
## Queries

### ListPosts
#### Required Arguments
```dart
// No required arguments
ExampleConnector.instance.listPosts().execute();
```



#### Return Type
`execute()` returns a `QueryResult<ListPostsData, void>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

/// Result of a query request. Created to hold extra variables in the future.
class QueryResult<Data, Variables> extends OperationResult<Data, Variables> {
  QueryResult(super.dataConnect, super.data, super.ref);
}

final result = await ExampleConnector.instance.listPosts();
ListPostsData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
final ref = ExampleConnector.instance.listPosts().ref();
ref.execute();

ref.subscribe(...);
```


### GetMyProfile
#### Required Arguments
```dart
// No required arguments
ExampleConnector.instance.getMyProfile().execute();
```



#### Return Type
`execute()` returns a `QueryResult<GetMyProfileData, void>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

/// Result of a query request. Created to hold extra variables in the future.
class QueryResult<Data, Variables> extends OperationResult<Data, Variables> {
  QueryResult(super.dataConnect, super.data, super.ref);
}

final result = await ExampleConnector.instance.getMyProfile();
GetMyProfileData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
final ref = ExampleConnector.instance.getMyProfile().ref();
ref.execute();

ref.subscribe(...);
```

## Mutations

### AddWaterTracking
#### Required Arguments
```dart
DateTime date = ...;
int amountMl = ...;
ExampleConnector.instance.addWaterTracking(
  date: date,
  amountMl: amountMl,
).execute();
```



#### Return Type
`execute()` returns a `OperationResult<AddWaterTrackingData, AddWaterTrackingVariables>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

final result = await ExampleConnector.instance.addWaterTracking(
  date: date,
  amountMl: amountMl,
);
AddWaterTrackingData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
DateTime date = ...;
int amountMl = ...;

final ref = ExampleConnector.instance.addWaterTracking(
  date: date,
  amountMl: amountMl,
).ref();
ref.execute();
```


### CreateComment
#### Required Arguments
```dart
String postId = ...;
String content = ...;
ExampleConnector.instance.createComment(
  postId: postId,
  content: content,
).execute();
```



#### Return Type
`execute()` returns a `OperationResult<CreateCommentData, CreateCommentVariables>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

final result = await ExampleConnector.instance.createComment(
  postId: postId,
  content: content,
);
CreateCommentData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
String postId = ...;
String content = ...;

final ref = ExampleConnector.instance.createComment(
  postId: postId,
  content: content,
).ref();
ref.execute();
```


### CreateLike
#### Required Arguments
```dart
String postId = ...;
ExampleConnector.instance.createLike(
  postId: postId,
).execute();
```



#### Return Type
`execute()` returns a `OperationResult<CreateLikeData, CreateLikeVariables>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

final result = await ExampleConnector.instance.createLike(
  postId: postId,
);
CreateLikeData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
String postId = ...;

final ref = ExampleConnector.instance.createLike(
  postId: postId,
).ref();
ref.execute();
```


### CreatePost
#### Required Arguments
```dart
String mediaUrl = ...;
MediaType mediaType = ...;
String description = ...;
ExampleConnector.instance.createPost(
  mediaUrl: mediaUrl,
  mediaType: mediaType,
  description: description,
).execute();
```



#### Return Type
`execute()` returns a `OperationResult<CreatePostData, CreatePostVariables>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

final result = await ExampleConnector.instance.createPost(
  mediaUrl: mediaUrl,
  mediaType: mediaType,
  description: description,
);
CreatePostData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
String mediaUrl = ...;
MediaType mediaType = ...;
String description = ...;

final ref = ExampleConnector.instance.createPost(
  mediaUrl: mediaUrl,
  mediaType: mediaType,
  description: description,
).ref();
ref.execute();
```


### CreateProfile
#### Required Arguments
```dart
String displayName = ...;
int age = ...;
Gender gender = ...;
double weight = ...;
double height = ...;
double targetWeight = ...;
FitnessGoal fitnessGoal = ...;
TrainingLocation trainingLocation = ...;
String timeAvailability = ...;
ExampleConnector.instance.createProfile(
  displayName: displayName,
  age: age,
  gender: gender,
  weight: weight,
  height: height,
  targetWeight: targetWeight,
  fitnessGoal: fitnessGoal,
  trainingLocation: trainingLocation,
  timeAvailability: timeAvailability,
).execute();
```



#### Return Type
`execute()` returns a `OperationResult<CreateProfileData, CreateProfileVariables>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

final result = await ExampleConnector.instance.createProfile(
  displayName: displayName,
  age: age,
  gender: gender,
  weight: weight,
  height: height,
  targetWeight: targetWeight,
  fitnessGoal: fitnessGoal,
  trainingLocation: trainingLocation,
  timeAvailability: timeAvailability,
);
CreateProfileData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
String displayName = ...;
int age = ...;
Gender gender = ...;
double weight = ...;
double height = ...;
double targetWeight = ...;
FitnessGoal fitnessGoal = ...;
TrainingLocation trainingLocation = ...;
String timeAvailability = ...;

final ref = ExampleConnector.instance.createProfile(
  displayName: displayName,
  age: age,
  gender: gender,
  weight: weight,
  height: height,
  targetWeight: targetWeight,
  fitnessGoal: fitnessGoal,
  trainingLocation: trainingLocation,
  timeAvailability: timeAvailability,
).ref();
ref.execute();
```


### CreateUser
#### Required Arguments
```dart
String username = ...;
String email = ...;
ExampleConnector.instance.createUser(
  username: username,
  email: email,
).execute();
```



#### Return Type
`execute()` returns a `OperationResult<CreateUserData, CreateUserVariables>`
```dart
/// Result of an Operation Request (query/mutation).
class OperationResult<Data, Variables> {
  OperationResult(this.dataConnect, this.data, this.ref);
  Data data;
  OperationRef<Data, Variables> ref;
  FirebaseDataConnect dataConnect;
}

final result = await ExampleConnector.instance.createUser(
  username: username,
  email: email,
);
CreateUserData data = result.data;
final ref = result.ref;
```

#### Getting the Ref
Each builder returns an `execute` function, which is a helper function that creates a `Ref` object, and executes the underlying operation.
An example of how to use the `Ref` object is shown below:
```dart
String username = ...;
String email = ...;

final ref = ExampleConnector.instance.createUser(
  username: username,
  email: email,
).ref();
ref.execute();
```

