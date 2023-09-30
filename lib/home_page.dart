import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:ffmpeg_kit_flutter/ffmpeg_kit.dart';
import 'package:file_merger/player_page.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String get lineTerminator => '\n';
  double received = 0;
  double totalReceived = 0;
  double total = 0;
  int fileInt = 0;
  int mb = 1024 * 1024;
  List<String> savePaths = [];
  CancelToken cancelToken = CancelToken();
  DownloadStatus downloadStatus = DownloadStatus.nonDownloading;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FloatingActionButton(
            backgroundColor: downloadStatus == DownloadStatus.downloaded
                ? Colors.cyan
                : Colors.grey,
            onPressed: () {
              Navigator.push(context,
                  MaterialPageRoute(builder: (_) => PlayerPage(url: '')));
            },
            child: Icon(Icons.play_arrow_outlined),
          ),
          FloatingActionButton(onPressed: () async {
            final dir = await getDirectory();
            final file = File('${dir?.path}/big_buck_bunny_240p_10mb.txt');
            file.writeAsStringSync('ds$lineTerminator', mode: FileMode.append);
            // await file.writeAsString('ds', mode: FileMode.append, flush: true);
            final contents = await file.readAsString();

            debugPrint(contents.toString());
            // for (var element in savePaths) {
            //   debugPrint(element);
            //   final file = File(element);
            //   final length = await file.length();
            //   debugPrint(length.toString());
            // }
          }),
          FloatingActionButton(
            onPressed: () async {
              if (downloadStatus == DownloadStatus.downloading) {
                downloadStatus = DownloadStatus.paused;
                cancelToken.cancel();
                totalReceived += received;
                final file = File(savePaths.last);
                final f = File(savePaths.first);
  
                // final length = await file.length();
                // final flength = await f.length();
                // debugPrint(f.path);
                // debugPrint(flength.toString());

                // debugPrint(savePaths.last);
                // debugPrint(length.toString());
                received = 0;
                setState(() {});
              } else if (downloadStatus == DownloadStatus.paused ||
                  downloadStatus == DownloadStatus.nonDownloading) {
                debugPrint('download started');
                cancelToken = CancelToken();
                downloadStatus = DownloadStatus.downloading;

                await downloadFile(
                    'https://sample-videos.com/video123/mp4/240/big_buck_bunny_240p_10mb.mp4');
              } else if (downloadStatus == DownloadStatus.downloaded) {
                final file = File(savePaths.first);
                await file.delete();
                received = 0;
                totalReceived = 0;
                total = 0;
                downloadStatus = DownloadStatus.nonDownloading;
                setState(() {});
              }
            },
            child: downloadStatus == DownloadStatus.nonDownloading
                ? Icon(Icons.download)
                : downloadStatus == DownloadStatus.downloaded
                    ? const Icon(
                        CupertinoIcons.trash,
                        color: Colors.red,
                      )
                    : downloadStatus == DownloadStatus.downloading
                        ? Icon(Icons.pause)
                        : Icon(Icons.play_arrow),
          ),
        ],
      ),
      body: Center(
          child: Text(
              '${((totalReceived + received) / mb).toStringAsFixed(1)}mb/${(total / mb).toStringAsFixed(1)}mb')),
    );
  }

  Future downloadFile(String url) async {
    Directory? directory;
    directory = await getDirectory();
    String videoName = url.split('/').last;
    List<String> list = videoName.split('.');
    list.insert(1, '/$fileInt.');
    fileInt++;
    print('fileInt: $fileInt');
    videoName = list.join();
    savePaths.add('${directory?.path}/$videoName');
    downloadStatus = DownloadStatus.downloading;
    if (total == 0) {
      total = (await getFileSize(url)).toDouble();
    }
    try {
      await Dio().download(
        url,
        savePaths.last,
        deleteOnError: false,
        options: Options(
          headers: {'range': 'bytes=${(totalReceived.toInt())}-'},
        ),
        cancelToken: cancelToken,
        onReceiveProgress: (count, tot) {
          debugPrint('received:$count\ntotal:$tot');
          print('sometin workin');
          received = count.toDouble();

          setState(() {});
        },
      ).then((value) async {
        downloadStatus = DownloadStatus.downloaded;
        setState(() {});
        const url =
            'https://sample-videos.com/video123/mp4/240/big_buck_bunny_240p_10mb.mp4';
        String videoName = url.split('/').last;
        String txtfileName = '${url.split('/').last.split('.').first}.txt';
        final dir = await getDirectory();
        final combinedVideoPath = '${dir?.path}/$videoName';

        if (totalReceived + received == total && savePaths.length > 1) {
          downloadStatus = DownloadStatus.downloaded;
          final file = File(savePaths[0]);
          final videoFile = File('${dir?.path}/$txtfileName');
          for (var element in savePaths) {
            await videoFile.writeAsString('$element');
            final contents = await videoFile.readAsLines();
            debugPrint(contents.toString());
          }

          String command =
              'ffmpeg -f concat -i ${videoFile.path} -c copy $combinedVideoPath';
          await FFmpegKit.execute(command);

          final newfile = File(combinedVideoPath);
          final flength = await newfile.length();

          savePaths = [newfile.path];
          debugPrint("readyFile:${newfile.path}");
          debugPrint('fileSize: $flength');
        } else {
          File file = File(savePaths.first);
          file.rename(combinedVideoPath);
        }

        debugPrint('then ishlamayapti');
      });
    } on DioException catch (e) {
      debugPrint(e.message);
    }
  }

  Future<int> getFileSize(String fileUrl) async {
    try {
      final dio = Dio();

      final response = await dio.head(fileUrl);

      final contentLengthHeader = response.headers.value('content-length');
      if (contentLengthHeader != null) {
        return int.parse(contentLengthHeader);
      } else {
        throw Exception('Content-Length header not found in the response.');
      }
    } catch (e) {
      print('Error getting file size: $e');
      rethrow;
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

enum DownloadStatus { paused, downloading, nonDownloading, downloaded }
