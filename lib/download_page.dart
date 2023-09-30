import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:ui';

import 'package:background_downloader/background_downloader.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class DownloadPage extends StatefulWidget {
  const DownloadPage({super.key});

  @override
  State<DownloadPage> createState() => _DownloadPageState();
}

class _DownloadPageState extends State<DownloadPage> {
  StreamController<TaskUpdate> streamController =
      StreamController<TaskUpdate>();
  late Stream<TaskUpdate> stream;
  late StreamSink<TaskUpdate> sink;
  final ReceivePort _port = ReceivePort();
  String id = '';
  List<Map<String, dynamic>> tasks = [];
  int taskId = 0;

  @override
  void initState() {
    stream = streamController.stream;
    sink = streamController.sink;

    FileDownloader().registerCallbacks(
      taskProgressCallback: (update) {
        debugPrint('Progress: ${update.progress * 100}%');
      },
      taskNotificationTapCallback: (task, notificationType) {
        debugPrint('notification tapped');
      },
      taskStatusCallback: (update) {
        debugPrint(update.status.name);
      },
    );
    permissionStatus();
    // FileDownloader().configureNotificationForGroup(
    //   FileDownloader.defaultGroup,
    //   progressBar: true,
    //   running: TaskNotification('Downloading',
    //       'file: ${tasks.last['path'].toString().split('/').join()}'),
    //   error: TaskNotification(
    //       'Error', 'file: ${tasks.last['path'].toString().split('/').join()}'),
    //   paused: TaskNotification(
    //       'Paused', 'file: ${tasks.last['path'].toString().split('/').join()}'),
    //   complete: TaskNotification('Downloading finished',
    //       'file: ${tasks.last['path'].toString().split('/').join()}'),
    // );
    // .configureNotification(
    //   progressBar: true,
    //   running: TaskNotification('Downloading',
    //       'file: ${tasks.last['path'].toString().split('/').join()}'),
    //   complete: TaskNotification('Downloading finished',
    //       'file: ${tasks.last['path'].toString().split('/').join()}'),
    // );
    FileDownloader().updates.listen((update) async {
      final s = await stream.last;
      switch (update) {
        case TaskStatusUpdate _:
          // process the TaskStatusUpdate, e.g.
          switch (update.status) {
            case TaskStatus.complete:
              print('Task ${update.task.taskId} success!');

            case TaskStatus.canceled:
              print('Download was canceled');

            case TaskStatus.paused:
              print('Download was paused');

            default:
              print('Download not successful');
          }

        case TaskProgressUpdate _:

          // process the TaskProgressUpdate, e.g.
          sink.add(update); // pass on to widget for indicator
      }
    });

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FloatingActionButton(
            onPressed: () async {
              final file = File(tasks.last['path']);
              final doesExist = await file.exists();
              debugPrint('exists:' + doesExist.toString());
              await file.delete();
            },
            child: Icon(
              CupertinoIcons.delete,
              color: Colors.red,
            ),
          ),
          FloatingActionButton(
            onPressed: () {
              download('https://speed.hetzner.de/100MB.bin');
            },
            child: Icon(Icons.download),
          ),
          FloatingActionButton(
            onPressed: () async {
              await FileDownloader().resume(tasks.last['task']);
            },
            child: Icon(Icons.play_arrow),
          ),
          FloatingActionButton(
              onPressed: () async {
                await FileDownloader().pause(tasks.last['task']);
              },
              child: Icon(Icons.pause)),
        ],
      ),
      body: Center(child: DownloadProgressIndicator(stream)),
    );
  }

  Future download(String url) async {
    final dir = await getDirectory();
    final fileName = url.split('/').last;
    final saveDir = '${dir?.path}/$fileName';
    debugPrint(dir!.path.toString());
    taskId = tasks.length;

    final task = DownloadTask(
      url: url,
      taskId: taskId.toString(),
      baseDirectory: BaseDirectory.temporary,
      allowPause: true,
      filename: fileName,
      updates: Updates.statusAndProgress,
      retries: 2,
    );
    tasks.add({'path': saveDir, 'task': task});
    final result = await FileDownloader().enqueue(task);
    // await FileDownloader().pause(task);
    // await Future.delayed(Duration(milliseconds: 400));
    await FileDownloader().resume(task);

    FileDownloader().configureNotificationForTask(
      task,
      progressBar: true,
      paused: TaskNotification('Sugu', 'GUGU'),
      error: TaskNotification('Mugu', 'Gugu'),
      tapOpensFile: true,
      running: TaskNotification('Downloading',
          'file: ${tasks.last['path'].toString().split('/').join()}'),
      complete: TaskNotification('Downloading finished',
          'file: ${tasks.last['path'].toString().split('/').join()}'),
    );
    switch (result) {
      case true:
        debugPrint('enqueued');

        break;
      case false:
        debugPrint('failed');
        break;
      default:
        debugPrint('something happened');
        break;
    }
  }

  permissionStatus() async {
    final deviceInfo = await DeviceInfoPlugin().androidInfo;
    final isGranted = await Permission.notification.isGranted;
    if (deviceInfo.version.sdkInt > 32) {
      if (!isGranted) {
        await Permission.notification.request();
      }
    }
  }

  Future<Directory?> getDirectory() async {
    Directory? directory;

    if (Platform.isAndroid) {
      directory = await getTemporaryDirectory();
    } else if (Platform.isIOS) {
      directory = await getDownloadsDirectory();
    }
    if (directory == null) {
      throw Exception('Could not access local storage for '
          'download. Please try again.');
    }
    return directory;
  }
}
