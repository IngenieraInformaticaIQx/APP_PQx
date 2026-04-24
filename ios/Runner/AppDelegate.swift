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
      if #available(iOS 16.0, *) {
        wkWebView.textInteractionEnabled = false
      } else {
        // Pre-iOS 16: deshabilitar UILongPressGestureRecognizer en el WKWebView y su scrollView
        let views: [UIView] = [wkWebView, wkWebView.scrollView]
        for v in views {
          for gr in v.gestureRecognizers ?? [] {
            if gr is UILongPressGestureRecognizer {
              gr.isEnabled = false
            }
          }
        }
      }
    }
    for subview in view.subviews {
      findAndConfigureWKWebViews(in: subview)
    }
  }
}