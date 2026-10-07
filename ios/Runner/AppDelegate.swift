import Flutter
import UIKit

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  private var pendingVideoURL: URL?
  private var videoEventSink: FlutterEventSink?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let url = launchOptions?[.url] as? URL, url.isFileURL {
      pendingVideoURL = url
    }
    GeneratedPluginRegistrant.register(with: self)
    let launched = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    if let controller = window?.rootViewController as? FlutterViewController {
      let messenger = controller.binaryMessenger
      FlutterMethodChannel(
        name: "kostori/external_intent",
        binaryMessenger: messenger
      ).setMethodCallHandler { [weak self] call, result in
        guard call.method == "getInitialVideo" else {
          result(FlutterMethodNotImplemented)
          return
        }
        self?.consumePendingVideo(result: result)
      }
      FlutterEventChannel(
        name: "kostori/external_intent/events",
        binaryMessenger: messenger
      ).setStreamHandler(self)
    }
    return launched
  }

  override func application(
    _ application: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    let handled = super.application(application, open: url, options: options)
    guard url.isFileURL else { return handled }
    receiveVideoURL(url)
    return true
  }

  func onListen(
    withArguments arguments: Any?,
    eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    videoEventSink = events
    if let url = pendingVideoURL {
      pendingVideoURL = nil
      copyVideoToCache(url) { [weak self] path in
        guard self?.videoEventSink != nil else { return }
        events(path)
      }
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    videoEventSink = nil
    return nil
  }

  private func receiveVideoURL(_ url: URL) {
    guard let sink = videoEventSink else {
      pendingVideoURL = url
      return
    }
    copyVideoToCache(url) { [weak self] path in
      guard self?.videoEventSink != nil else { return }
      sink(path)
    }
  }

  private func consumePendingVideo(result: @escaping FlutterResult) {
    guard let url = pendingVideoURL else {
      result(nil)
      return
    }
    pendingVideoURL = nil
    copyVideoToCache(url, completion: result)
  }

  private func copyVideoToCache(_ url: URL, completion: @escaping (String?) -> Void) {
    DispatchQueue.global(qos: .userInitiated).async {
      let didAccess = url.startAccessingSecurityScopedResource()
      defer {
        if didAccess { url.stopAccessingSecurityScopedResource() }
      }
      let fileManager = FileManager.default
      let directory = fileManager.temporaryDirectory.appendingPathComponent(
        "external_videos",
        isDirectory: true
      )
      var path: String?
      do {
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let name = "video_\(UUID().uuidString).\(url.pathExtension.isEmpty ? "video" : url.pathExtension)"
        let target = directory.appendingPathComponent(name)
        try fileManager.copyItem(at: url, to: target)
        path = target.path
      } catch {
        NSLog("Kostori: failed to import video: %@", error.localizedDescription)
      }
      DispatchQueue.main.async { completion(path) }
    }
  }
}

extension AppDelegate: FlutterStreamHandler {}
