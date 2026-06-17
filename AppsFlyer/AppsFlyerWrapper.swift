import UIKit
import SwiftUI
import AppsFlyerLib
import AppTrackingTransparency

extension AppDelegate: AppsFlyerLibDelegate {
    
    public static let appsFlyerDevKey = "BYbL7iQyGkW9x2ZSzbyhh7"
    public static let appleAppID = "6781236201"
    public static var fcmToken = ""

    static var subParams : String {
        get {
            return UserDefaults.standard.string(forKey: "subParams") ?? ""
        } set {
            UserDefaults.standard.set(newValue, forKey: "subParams")
        }
    }
    
    static var afid : String {
        get {
            return UserDefaults.standard.string(forKey: "afid") ?? ""
        } set {
            UserDefaults.standard.set(newValue, forKey: "afid")
        }
    }
    
    func onConversionDataSuccess(_ conversionInfo: [AnyHashable : Any]) {
        print("AF ConversionData: \(conversionInfo)")
        if let campaign = conversionInfo["campaign"] as? String {
            print("AF Campaign: \(campaign)")
            let strings = campaign.split(separator: "_")
            
            if strings.count > 1 {
                var result = ""
                
                for i in 0..<strings.count {
                    let str = "sub\(i + 1)=\(strings[i])&"
                    result += str
                }
                
                result = String(result.dropLast())
                AppDelegate.subParams = result
                print("afid: \(AppDelegate.afid)")
            }
        }
        
        DispatchQueue.main.async {
            self.resolveAFContinuation()
        }
    }
    
    func onConversionDataFail(_ error: any Error) {
        print(error)
    }

    func initAppsFlyer() {
        AppsFlyerLib.shared().appsFlyerDevKey = AppDelegate.appsFlyerDevKey
        AppsFlyerLib.shared().appleAppID = AppDelegate.appleAppID
        AppsFlyerLib.shared().delegate = self
        AppsFlyerLib.shared().isDebug = true
        AppsFlyerLib.shared().start(completionHandler: { (dictionary, error) in
            if (error != nil){
                print("AF error: \(error)")
            } else {
                print("AF inited: \(String(describing: dictionary))")
            }
        })
        
        AppDelegate.afid = AppsFlyerLib.shared().getAppsFlyerUID()
    }
}
