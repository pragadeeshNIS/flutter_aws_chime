import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_aws_chime/models/meeting.model.dart';
import 'package:flutter_aws_chime/models/meeting.theme.model.dart';
import 'package:flutter_aws_chime/models/message.model.dart';
import 'package:flutter_aws_chime/utils/snackbar.dart';

import 'icon.button.view.dart';

class ActionsView extends StatefulWidget {
  final void Function(bool didStop)? onLeave;

  ActionsView({super.key, this.onLeave});

  @override
  State<ActionsView> createState() => _ActionsViewState();
}

class _ActionsViewState extends State<ActionsView> {
  final messageTextController = TextEditingController();
  bool videoOn = false;

  @override
  void initState() {
    super.initState();
    init();
  }

  init() async{
    var res = await MeetingModel().toggleVideo();
    setState(() {
      videoOn = res;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 0,
      right: MediaQuery.of(context).orientation == Orientation.portrait
          ? 0
          : max(0, MediaQuery.of(context).size.width - 550),
      bottom: 0,
      child: Container(
        padding: EdgeInsets.only(
          left: MeetingTheme().baseUnit * 2,
          right: MeetingTheme().baseUnit * 2,
          top: MeetingTheme().baseUnit * 2,
        ),
        height: MeetingTheme().actionViewHeight,
        child: Row(
          children: [
            const Spacer(),
            IconButtonView(
              icon: MeetingModel().getMuteStatus() ? Icons.mic_off : Icons.mic,
              onTap: () async {
                var res = await MeetingModel().toggleMute();
                return res ? Icons.mic_off : Icons.mic;
              },
            ),
            IconButtonView(
                icon: MeetingModel().getVideoOn()
                    ? Icons.videocam
                    : Icons.videocam_off,
                onTap: () async {
                  var res = await MeetingModel().toggleVideo();
                  return res
                      ? Icons.videocam
                      : Icons.videocam_off;
                }),
            IconButtonView(
              icon: Icons.headphones,
              onTap: () => showAudioDeviceDialog(context),
            ),
            // IconButtonView(
            //   icon: Icons.crop_rotate,
            //   onTap: () async {
            //     MeetingModel().toggleCameraSwitch();
            //   },
            // ),
            IconButtonView(
              icon: Icons.stop,
              iconColor: Colors.red,
              onTap: () async {
                var res = await MeetingModel().stopMeeting();
                if (widget.onLeave != null) {
                  widget.onLeave!(res);
                }
              },
            ),
            const Spacer(),
          ],
        ),
      ),
    );
  }

  Future<void> showAudioDeviceDialog(BuildContext context) async {
    String? device = await showModalBottomSheet(
        context: context,
        builder: (context) {
          var selected = MeetingModel().selectedAudioDevice;
          var selectedIcon = Icon(
            Icons.check,
            color: MeetingTheme().audioActiveColor,
          );
          var items = MeetingModel()
              .deviceList
              .whereType<String>()
              .map((e) => ListTile(
                    leading: Icon(
                      e.toLowerCase().contains('speaker')
                          ? Icons.volume_up_outlined
                          : Icons.hearing_outlined,
                    ),
                    title: Text(e),
                    onTap: () {
                      Navigator.pop(context, e);
                    },
                    trailing: selected == e ? selectedIcon : null,
                  ))
              .toList();
          return SizedBox(
            height: 200,
            child: ListView(
              padding: const EdgeInsets.all(8),
              children: items,
            ),
          );
        });
    if (device == null) {
      return;
    }

    MeetingModel().updateCurrentDevice(device);
  }

  Future<void> sendMessage(BuildContext context) async {
    if (messageTextController.text.trim().isEmpty) {
      showSnackBar(context, message: "Cannot send empty comment");
      return;
    }
    try {
      var localAttendee = MeetingModel().getLocalAttendee();
      var message = messageTextController.text;
      var res = await MeetingModel().sendMessage(message);
      if (res) {
        MeetingModel().hideControlInSeconds();
        MeetingModel().receivedMessage.add(MessageModel(
            localAttendee.attendeeId,
            localAttendee.externalUserId,
            message,
            MeetingModel().topic,
            DateTime.now().millisecondsSinceEpoch));
        messageTextController.clear();
      } else {
        if (context.mounted) {
          showSnackBar(context, message: 'Send failed, please try again');
        }
        return;
      }
    } catch (e) {
      if (context.mounted) {
        showSnackBar(context, message: e.toString());
      }
    }
  }

  Widget messageFormContainer(BuildContext context) {
    return Flexible(
      flex: 1,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.3),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Row(
          children: [
            messageSendForm(context),
            IconButtonView(
              icon: Icons.send,
              showBackgroundColor: false,
              onTap: () => sendMessage(context),
            )
          ],
        ),
      ),
    );
  }

  Widget messageSendForm(BuildContext context) {
    return Flexible(
      flex: 1,
      child: Padding(
        padding: EdgeInsets.only(
          left: MeetingTheme().baseUnit * 2,
        ),
        child: TextField(
          controller: messageTextController,
          onTap: () {
            MeetingModel().controlHideDelay?.cancel();
            MeetingModel().controlHideDelay = null;
          },
          onTapOutside: (evt) {
            FocusManager.instance.primaryFocus?.unfocus();
            MeetingModel().hideControlInSeconds();
          },
          onSubmitted: (value) => sendMessage(context),
          style: MeetingTheme().chatMessageTextStyle,
          decoration: InputDecoration(
            isCollapsed: true,
            border: InputBorder.none,
            hintText: 'Type your comment',
            hintStyle: MeetingTheme().chatMessageTextStyle,
          ),
        ),
      ),
    );
  }
}
