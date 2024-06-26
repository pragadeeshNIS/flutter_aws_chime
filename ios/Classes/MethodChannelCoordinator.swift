//
//  MethodChannelCoordinator.swift
//  flutter_aws_chime
//
//  Created by Conan on 2023/9/9.
//

import AmazonChimeSDK
import AmazonChimeSDKMedia
import AVFoundation
import Flutter
import Foundation
import UIKit
import MediaPlayer

class MethodChannelCoordinator {
    let methodChannel: FlutterMethodChannel
    
    var realtimeObserver: RealtimeObserver?
    
    var audioVideoObserver: AudioVideoObserver?
    
    var videoTileObserver: VideoTileObserver?
    
    var dataMessageObserver: DataMessageObserver?
    
    var currentVolumeValue = AVAudioSession.sharedInstance().outputVolume
    
    
    init(binaryMessenger: FlutterBinaryMessenger) {
        self.methodChannel = FlutterMethodChannel(name: "com.oneplusdream.aws.chime.methodChannel", binaryMessenger: binaryMessenger)
    }
    
    //
    // ————————————————————————————————— Method Call Setup —————————————————————————————————
    //
    
    func setUpMethodCallHandler() {
        self.methodChannel.setMethodCallHandler { [unowned self]
            (call: FlutterMethodCall, result: @escaping FlutterResult) in
            let callMethod = MethodCall(rawValue: call.method)
            var response: MethodChannelResponse = .init(result: false, arguments: nil)
            switch callMethod {
            case .manageAllPermissions:
                response = self.manageAllPermissions()
            case .manageAudioPermissions:
                response = self.manageAudioPermissions()
            case .manageVideoPermissions:
                response = self.manageVideoPermissions()
            case .join:
                response = self.join(call: call)
            case .stop:
                response = self.stop()
            case .mute:
                response = self.mute()
            case .unmute:
                response = self.unmute()
            case .toggleSound:
                response = self.toggleVolume(off: call.arguments as? Bool ?? false)
            case .startLocalVideo:
                response = self.startLocalVideo()
            case .stopLocalVideo:
                response = self.stopLocalVideo()
            case .initialAudioSelection:
                response = self.initialAudioSelection()
            case .listAudioDevices:
                response = self.listAudioDevices()
            case .updateAudioDevice:
                response = self.updateAudioDevice(call: call)
            case .sendMessage:
                response = self.sendMessage(call: call)
                case .toggleCameraSwitch:
                response = self.switchCamera()
            default:
                response = MethodChannelResponse(result: false, arguments: Response.method_not_implemented)
            }
            result(response.toFlutterCompatibleType())
        }
    }
    
    func callFlutterMethod(method: MethodCall, args: Any?) {
        self.methodChannel.invokeMethod(method.rawValue, arguments: args)
    }
    
    //
    // ————————————————————————————————— Method Call Options —————————————————————————————————
    //

    func manageAllPermissions() -> MethodChannelResponse {
            let audioPermission = AVAudioSession.sharedInstance().recordPermission
            let videoPermission: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
            var audioPermissionGranted = false
            var videoPermissionGranted = false
            switch audioPermission {
            case .undetermined:
                if self.requestAudioPermission() {
                    audioPermissionGranted = true
                }
                audioPermissionGranted = false
            case .granted:
                audioPermissionGranted = true
            case .denied:
                audioPermissionGranted = false
            @unknown default:
                audioPermissionGranted = false
            }

            switch videoPermission {
                    case .notDetermined:
                        if self.requestVideoPermission() {
                            videoPermissionGranted = true
                        }
                        videoPermissionGranted = false
                    case .authorized:
                        videoPermissionGranted = true
                    case .denied:
                        videoPermissionGranted = false
                    case .restricted:
                        videoPermissionGranted = false
                    @unknown default:
                        videoPermissionGranted = false
                    }

                    if(videoPermissionGranted && audioPermissionGranted) {
                        return MethodChannelResponse(result: true, arguments: Response.all_authorized.rawValue)
                    } else {
                    return MethodChannelResponse(result: true, arguments: Response.all_auth_not_granted.rawValue)
                    }
        }
    
    func manageAudioPermissions() -> MethodChannelResponse {
        let audioPermission = AVAudioSession.sharedInstance().recordPermission
        switch audioPermission {
        case .undetermined:
            if self.requestAudioPermission() {
                return MethodChannelResponse(result: true, arguments: Response.audio_authorized.rawValue)
            }
            return MethodChannelResponse(result: false, arguments: Response.audio_auth_not_granted.rawValue)
        case .granted:
            return MethodChannelResponse(result: true, arguments: Response.audio_authorized.rawValue)
        case .denied:
            return MethodChannelResponse(result: false, arguments: Response.audio_auth_not_granted.rawValue)
        @unknown default:
            return MethodChannelResponse(result: false, arguments: Response.unknown_audio_authorization_status.rawValue)
        }
    }
    
    func manageVideoPermissions() -> MethodChannelResponse {
        let videoPermission: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        switch videoPermission {
        case .notDetermined:
            if self.requestVideoPermission() {
                return MethodChannelResponse(result: true, arguments: Response.video_authorized.rawValue)
            }
            return MethodChannelResponse(result: false, arguments: Response.video_auth_not_granted.rawValue)
        case .authorized:
            return MethodChannelResponse(result: true, arguments: Response.video_authorized.rawValue)
        case .denied:
            return MethodChannelResponse(result: false, arguments: Response.video_auth_not_granted.rawValue)
        case .restricted:
            return MethodChannelResponse(result: false, arguments: Response.video_restricted.rawValue)
        @unknown default:
            return MethodChannelResponse(result: false, arguments: Response.unknown_video_authorization_status.rawValue)
        }
    }
    
    func join(call: FlutterMethodCall) -> MethodChannelResponse {
        guard let json = call.arguments as? [String: String] else {
            return MethodChannelResponse(result: false, arguments: Response.create_meeting_failed)
        }
        
        // TODO: zmauricv: add a Json Decoder
        guard let meetingId = json["MeetingId"], let externalMeetingId = json["ExternalMeetingId"], let mediaRegion = json["MediaRegion"], let audioHostUrl = json["AudioHostUrl"], let audioFallbackUrl = json["AudioFallbackUrl"], let signalingUrl = json["SignalingUrl"], let turnControlUrl = json["TurnControlUrl"], let externalUserId = json["ExternalUserId"], let attendeeId = json["AttendeeId"], let joinToken = json["JoinToken"]
        else {
            return MethodChannelResponse(result: false, arguments: Response.incorrect_join_response_params.rawValue)
        }
        
        let meetingResponse = CreateMeetingResponse(meeting: Meeting(externalMeetingId: externalMeetingId, mediaPlacement: MediaPlacement(audioFallbackUrl: audioFallbackUrl, audioHostUrl: audioHostUrl, signalingUrl: signalingUrl, turnControlUrl: turnControlUrl), mediaRegion: mediaRegion, meetingId: meetingId))
        
        let attendeeResponse = CreateAttendeeResponse(attendee: Attendee(attendeeId: attendeeId, externalUserId: externalUserId, joinToken: joinToken))
        
        let meetingSessionConfiguration = MeetingSessionConfiguration(createMeetingResponse: meetingResponse, createAttendeeResponse: attendeeResponse)
        
        let logger = ConsoleLogger(name: "MeetingSession Logger", level: LogLevel.DEBUG)
        
        let meetingSession = DefaultMeetingSession(configuration: meetingSessionConfiguration, logger: logger)
        
        self.configureAudioSession()
        
        // Update Singleton Class
        MeetingSession.shared.meetingSession = meetingSession
        
        self.setupAudioVideoFacadeObservers()
        let meetingStartResponse = MeetingSession.shared.startMeetingAudio()
        return meetingStartResponse
    }
    
    func stop() -> MethodChannelResponse {
        MeetingSession.shared.meetingSession?.audioVideo.stop()
        MeetingSession.shared.meetingSession = nil
        return MethodChannelResponse(result: true, arguments: Response.meeting_stopped_successfully.rawValue)
    }
    
    func toggleVolume(off:Bool) -> MethodChannelResponse {
        var slider = (MPVolumeView().subviews.filter{ NSStringFromClass($0.classForCoder) == "MPVolumeSlider" }.first as? UISlider);
        if(off){
            currentVolumeValue = AVAudioSession.sharedInstance().outputVolume;
            slider?.setValue(0, animated: false)
        }else {
            slider?.setValue(currentVolumeValue, animated: false)
        }
        return MethodChannelResponse(result: true, arguments:"success")
    }
    
    func mute() -> MethodChannelResponse {
        let muted = MeetingSession.shared.meetingSession?.audioVideo.realtimeLocalMute() ?? false
        if muted {
            return MethodChannelResponse(result: true, arguments: Response.mute_successful.rawValue)
        } else {
            return MethodChannelResponse(result: false, arguments: Response.mute_failed.rawValue)
        }
    }
    
    func unmute() -> MethodChannelResponse {
        let unmuted = MeetingSession.shared.meetingSession?.audioVideo.realtimeLocalUnmute() ?? false
        
        if unmuted {
            return MethodChannelResponse(result: true, arguments: Response.unmute_successful.rawValue)
        } else {
            return MethodChannelResponse(result: false, arguments: Response.unmute_successful.rawValue)
        }
    }

    func switchCamera() -> MethodChannelResponse {
            MeetingSession.shared.meetingSession?.audioVideo.switchCamera()
            return MethodChannelResponse(result: true, arguments: Response.local_video_camera_success.rawValue)

        }

    
    func startLocalVideo() -> MethodChannelResponse {
        do {
            try MeetingSession.shared.meetingSession?.audioVideo.startLocalVideo()
            return MethodChannelResponse(result: true, arguments: Response.local_video_on_success.rawValue)
        } catch {
            MeetingSession.shared.meetingSession?.logger.error(msg: "Error configuring AVAudioSession: \(error.localizedDescription)")
            return MethodChannelResponse(result: false, arguments: Response.local_video_on_failed.rawValue)
        }
    }
    
    func stopLocalVideo() -> MethodChannelResponse {
        MeetingSession.shared.meetingSession?.audioVideo.stopLocalVideo()
        return MethodChannelResponse(result: true, arguments: Response.local_video_off_success.rawValue)
    }
    
    func initialAudioSelection() -> MethodChannelResponse {
        if let initialAudioDevice = MeetingSession.shared.meetingSession?.audioVideo.getActiveAudioDevice() {
            return MethodChannelResponse(result: true, arguments: initialAudioDevice.label)
        }
        return MethodChannelResponse(result: false, arguments: Response.failed_to_get_initial_audio_device.rawValue)
    }
    
    func listAudioDevices() -> MethodChannelResponse {
        guard let audioDevices = MeetingSession.shared.meetingSession?.audioVideo.listAudioDevices() else {
            return MethodChannelResponse(result: false, arguments: Response.failed_to_list_audio_devices.rawValue)
        }
        
        return MethodChannelResponse(result: true, arguments: audioDevices.map { $0.label })
    }
    
    func updateAudioDevice(call: FlutterMethodCall) -> MethodChannelResponse {
        guard let device = call.arguments as? String else {
            return MethodChannelResponse(result: false, arguments: Response.audio_device_update_failed.rawValue)
        }
        
        guard let audioDevices = MeetingSession.shared.meetingSession?.audioVideo.listAudioDevices() else {
            MeetingSession.shared.meetingSession?.logger.error(msg: Response.failed_to_list_audio_devices.rawValue)
            return MethodChannelResponse(result: false, arguments: Response.failed_to_list_audio_devices.rawValue)
        }
        
        for dev in audioDevices {
            if device == dev.label {
                MeetingSession.shared.meetingSession?.audioVideo.chooseAudioDevice(mediaDevice: dev)
                return MethodChannelResponse(result: true, arguments: Response.audio_device_updated.rawValue)
            }
        }
        
        return MethodChannelResponse(result: false, arguments: Response.audio_device_update_failed.rawValue)
    }
    
    func sendMessage(call: FlutterMethodCall) -> MethodChannelResponse {
        do {
            guard let json = call.arguments as? [String: Any],
                  let topic = json["topic"] as? String,
                  let message = json["message"] as? String else {
                return MethodChannelResponse(result: false, arguments: Response.message_payload_error.rawValue)
            }
            try MeetingSession.shared.meetingSession?.audioVideo.realtimeSendDataMessage(topic: topic, data: message.data(using: .utf8), lifetimeMs: json["lifetimeMs"] as? Int32 ?? 300_000)
        }catch {
            return MethodChannelResponse(result: false, arguments: "\(Response.message_sent_failed.rawValue) \(error.localizedDescription)")
        }
       
        
        return MethodChannelResponse(result: true, arguments: Response.message_sent_successful.rawValue)
    }
    
    //
    // ————————————————————————————————— Helper Functions —————————————————————————————————
    //
    
    private func requestAudioPermission() -> Bool {
        var result = false
        
        let group = DispatchGroup()
        group.enter()
        DispatchQueue.global(qos: .default).async {
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                result = granted
                group.leave()
            }
        }
        group.wait()
        return result
    }
    
    private func requestVideoPermission() -> Bool {
        var result = false
        
        let group = DispatchGroup()
        group.enter()
        DispatchQueue.global(qos: .default).async {
            AVCaptureDevice.requestAccess(for: .video) { granted in
                result = granted
                group.leave()
            }
        }
        group.wait()
        return result
    }
    
    private func setupAudioVideoFacadeObservers() {
        self.realtimeObserver = MyRealtimeObserver(withMethodChannel: self)
        if self.realtimeObserver != nil {
            MeetingSession.shared.meetingSession?.audioVideo.addRealtimeObserver(observer: self.realtimeObserver!)
            MeetingSession.shared.meetingSession?.logger.info(msg: "realtimeObserver set up...")
        }
        
        self.audioVideoObserver = MyAudioVideoObserver(withMethodChannel: self)
        if self.audioVideoObserver != nil {
            MeetingSession.shared.meetingSession?.audioVideo.addAudioVideoObserver(observer: self.audioVideoObserver!)
            MeetingSession.shared.meetingSession?.logger.info(msg: "audioVideoObserver set up...")
        }
        
        self.videoTileObserver = MyVideoTileObserver(withMethodChannel: self)
        if self.videoTileObserver != nil {
            MeetingSession.shared.meetingSession?.audioVideo.addVideoTileObserver(observer: self.videoTileObserver!)
            MeetingSession.shared.meetingSession?.logger.info(msg: "VideoTileObserver set up...")
        }
        
        self.dataMessageObserver = MyDataMessageObserver(withMethodChannel: self)
        if self.dataMessageObserver != nil {
            MeetingSession.shared.meetingSession?.audioVideo.addRealtimeDataMessageObserver(topic: "chat", observer: self.dataMessageObserver!)
            MeetingSession.shared.meetingSession?.logger.info(msg: "DataMessageObserver set up...")
        }
    }
    
    func stopAudioVideoFacadeObservers() {
        if let rtObserver = self.realtimeObserver {
            MeetingSession.shared.meetingSession?.audioVideo.removeRealtimeObserver(observer: rtObserver)
        }
        
        if let avObserver = self.audioVideoObserver {
            MeetingSession.shared.meetingSession?.audioVideo.removeAudioVideoObserver(observer: avObserver)
        }
        
        if let vtObserver = self.videoTileObserver {
            MeetingSession.shared.meetingSession?.audioVideo.removeVideoTileObserver(observer: vtObserver)
        }
        
        MeetingSession.shared.meetingSession?.audioVideo.removeRealtimeDataMessageObserverFromTopic(topic: "chat")
    }
    
    private func configureAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            if audioSession.category != .playAndRecord {
                try audioSession.setCategory(AVAudioSession.Category.playAndRecord,
                                             options: AVAudioSession.CategoryOptions.allowBluetooth)
                try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            }
            if audioSession.mode != .voiceChat {
                try audioSession.setMode(.voiceChat)
            }
        } catch {
            MeetingSession.shared.meetingSession?.logger.error(msg: "Error configuring AVAudioSession: \(error.localizedDescription)")
        }
    }
}

