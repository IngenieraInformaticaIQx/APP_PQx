import Flutter
import UIKit
import WebKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let channel = FlutterMethodChannel(
      name: "visor/webview_config",
      binaryMessenger: engineBridge.pluginRegistry.registrar(forPlugin: "WebviewConfig")!.messenger()
    )
    channel.setMethodCallHandler { [weak self] call, result in
      if call.method == "disableTextInteraction" {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
          self?.disableTextInteractionInAllWKWebViews()
        }
        result(nil)
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func disableTextInteractionInAllWKWebViews() {
    for scene in UIApplication.shared.connectedScenes {
      guard let windowScene = scene as? UIWindowScene else { continue }
      for window in windowScene.windows {
        findAndConfigureWKWebViews(in: window)
      }
    }
  }

  private func findAndConfigureWKWebViews(in view: UIView) {
    if let wkWebView = view as? WKWebView {
      let views: [UIView] = [wkWebView, wkWebView.scrollView]

      for v in views {
        for gr in v.gestureRecognizers ?? [] {
          let recognizerType = String(describing: type(of: gr))
          if recognizerType.contains("Text") ||
              recognizerType.contains("Selection") ||
              recognizerType.contains("Loupe") ||
              recognizerType.contains("EditMenu") {
            gr.isEnabled = false
          }
        }
      }

      wkWebView.isUserInteractionEnabled = true
      wkWebView.scrollView.delaysContentTouches = false
      wkWebView.scrollView.canCancelContentTouches = false
    }

    for subview in view.subviews {
      findAndConfigureWKWebViews(in: subview)
    }
  }
}
