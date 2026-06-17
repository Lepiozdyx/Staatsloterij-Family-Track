import Foundation
import UIKit
import AppTrackingTransparency

extension AppDelegate : UNUserNotificationCenterDelegate {
    
    func decide() async -> Bool {
        await WebManager.decide(finalUrl: formulateRequest(initialUrl: WebManager.initialURL))
        return WebManager.provenUrl != nil
    }
    
    func onPositivelyDecided() {
        let contentView = CustomHostingController(rootView: WebView(url: WebManager.provenUrl!))
        window = UIWindow(frame: UIScreen.main.bounds)
        window?.rootViewController = contentView
        OrientationHelper.orientaionMask = UIInterfaceOrientationMask.all
        OrientationHelper.isAutoRotationEnabled = true
        window?.makeKeyAndVisible()
    }
    
    func formulateRequest(initialUrl: String) async -> String {
        var result = initialUrl
        var afData = ""
        
        if !AppDelegate.subParams.isEmpty {
            afData += "?\(AppDelegate.subParams)"
        }
        
        if !AppDelegate.afid.isEmpty {
            afData += "\(afData.isEmpty ? "?" : "&")afid=\(AppDelegate.afid)"
        }
        
        if !afData.isEmpty {
            if result.contains("?") {
                result = "\(result)\(afData)"
            } else {
                result = "\(result)\(afData)"
            }
        }
        return result
    }
    
    func resolveAFContinuation() {
        guard let continuation = afContinuation else { return }
        afContinuation = nil
        continuation.resume()
    }

    func initApp() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            ATTrackingManager.requestTrackingAuthorization(completionHandler: { status in
                print("Tracking authorization status: \(status)")
                DispatchQueue.main.async {
                    Task { @MainActor in
                        await withCheckedContinuation { continuation in
                            self.afContinuation = continuation
                            self.initAppsFlyer()
                            Task { @MainActor in
                                try? await Task.sleep(for: .seconds(5))
                                self.resolveAFContinuation()
                            }
                        }
                        self.applyDecision()
                    }
                }
            })
        }
    }
    
    func applyDecision() {
        Task {
            if await !decide() {
                self.onGameStart()
            } else {
                self.onPositivelyDecided()
            }
        }
    }
    
    func showLoadingScreen() {
        DispatchQueue.main.async {
            if let storyboard = UIStoryboard(name: "LaunchScreen", bundle: nil) as? UIStoryboard {
                if let loadingVC = storyboard.instantiateInitialViewController() as? UIViewController {
                    self.window = UIWindow(frame: UIScreen.main.bounds)
                    self.window?.rootViewController = loadingVC
                    self.window?.makeKeyAndVisible()
                    
                    if let logo = loadingVC.view.viewWithTag(1) as? UIImageView {
                        let pulseAnimation = CABasicAnimation(keyPath: "transform.scale")
                        pulseAnimation.duration = 1
                        pulseAnimation.fromValue = 1
                        pulseAnimation.toValue = 0.7
                        pulseAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                        pulseAnimation.autoreverses = true
                        pulseAnimation.repeatCount = .infinity
                        logo.layer.add(pulseAnimation, forKey: "pulse")
                    }
                }
            } else {
                print("Error: LaunchScreen storyboard not found")
            }
        }
    }
}
