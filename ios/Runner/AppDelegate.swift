import UIKit
import GoogleMaps
import Flutter

@UIApplicationMain
class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GMSServices.provideAPIKey("AIzaSyDJ53HjRqauguIbbfgRKtBq_yy1eX7Q4HI")
        GeneratedPluginRegistrant.register(with: self)
        return true
    }
}