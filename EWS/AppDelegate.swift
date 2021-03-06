//
//  AppDelegate.swift
//  EWS
//
//  Created by Alvin Ling on 4/8/19.
//  Copyright © 2019 iOSPlayground. All rights reserved.
//

import UIKit
import Firebase
import CoreLocation
import GoogleMaps
import GooglePlaces
import GoogleSignIn
import FBSDKCoreKit
import UserNotifications
import FirebaseMessaging

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?
    var clManager: CLLocationManager!
    var currentLocation: CLLocation?
    var locationName: String?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        setupCoreLocation()
        GMSServices.provideAPIKey(GoogleAPIKeys.maps)
        GMSPlacesClient.provideAPIKey(GoogleAPIKeys.places)
        GIDSignIn.sharedInstance().clientID = FirebaseApp.app()?.options.clientID
        FBSDKApplicationDelegate.sharedInstance()?.application(application, didFinishLaunchingWithOptions: launchOptions)
        setupNotifications()
        checkAlreadyLoggedIn()
        return true
    }
    
    
    func checkAlreadyLoggedIn() {
        if let _ = FirebaseManager.shared.currentUser {
            let initialView = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "Tabs")
            window?.rootViewController = initialView
        }
    }
    
    func application(_ application: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any])
        -> Bool {
            let sourceApp = options[UIApplication.OpenURLOptionsKey.sourceApplication] as? String
            let gidHandled = GIDSignIn.sharedInstance().handle(url, sourceApplication: sourceApp, annotation: [:])
            let fbHandled = FBSDKApplicationDelegate.sharedInstance()?.application(application, open: url, sourceApplication: sourceApp, annotation: options[UIApplication.OpenURLOptionsKey.annotation])
            
            return gidHandled || fbHandled!
    }
    
    // MARK: - Notifcations
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let varAvgvalue = String(format: "%@", deviceToken as CVarArg)
        
//        let  token = varAvgvalue.trimmingCharacters(in: CharacterSet(charactersIn: "<>")).replacingOccurrences(of: " ", with: "")
        Messaging.messaging().apnsToken = deviceToken
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print(error.localizedDescription)
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        
        
        guard let userInfo = userInfo as? [String : Any],
            let senderID = userInfo["gcm.notification.sender"] as? String,
            let aps = userInfo["aps"] as? [String : Any],
            let alert = aps["alert"] as? [String : Any],
            let message = alert["body"] as? String else { return }
        
        if let root = window?.rootViewController as? UITabBarController,
            root.selectedIndex == 2,
            let chatNav = root.viewControllers?[2] as? UINavigationController,
            let currentVC = chatNav.visibleViewController as? ChatVC,
            senderID == currentVC.friend?.uid {
            let uid = FirebaseManager.shared.currentUser?.uid
            let chatInfo = ChatInfo(msg: message, receiver: uid!)
            currentVC.addRow(chatInfo)
        }
    }
}

extension AppDelegate: MessagingDelegate {
    
    func messaging(_ messaging: Messaging, didReceive remoteMessage: MessagingRemoteMessage) {
    }
    
    // The callback to handle data message received via FCM for devices running iOS 10 or above.
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String) {
        print("Firebase registration token: \(fcmToken)")
        
        let dataDict:[String: String] = ["token": fcmToken]
        NotificationCenter.default.post(name: Notification.Name("FCMToken"), object: nil, userInfo: dataDict)
        // TODO: If necessary send token to application server.
        // Note: This callback is fired at each app startup and whenever a new token is generated.
    }
    func messaging(_ messaging: Messaging, didRefreshRegistrationToken fcmToken: String) {
        //Messaging.messaging().apnsToken = fcmToken
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    
    func setupNotifications() {
        let setting = UNUserNotificationCenter.current()
        setting.delegate = self
        setting.requestAuthorization(options: [.badge, .sound, .alert]) { (granted, error) in
            
            if granted{
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
            
            Messaging.messaging().delegate = self
            Messaging.messaging().isAutoInitEnabled = true
            Messaging.messaging().shouldEstablishDirectChannel = true
        }
    }
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        
        if let userInfo = response.notification.request.content.userInfo as? [String : Any] {
            navToChat(with: userInfo)
        }
        
        completionHandler()
    }
    
    func navToChat(with userInfo: [String: Any]) {
        let chatStoryboard = UIStoryboard(name: "Main", bundle: Bundle.main)
        if let senderId = userInfo["gcm.notification.sender"] as? String,
            let targetVC = chatStoryboard.instantiateViewController(withIdentifier: "ChatVC") as? ChatVC,
            let root = window?.rootViewController as? UITabBarController,
            let chatNav = root.viewControllers?[2] as? UINavigationController,
            let friendsVC = chatNav.viewControllers[0] as? FriendsVC,
            !(chatNav.visibleViewController is ChatVC) {
            
            var receiver: UserInfo!
            for friend in friendsVC.userList {
                if friend.uid == senderId {
                    receiver = friend
                }
            }
            
            if receiver == nil {
                receiver =  UserInfo(senderId)
            }
            
            targetVC.friend = receiver
            chatNav.present(targetVC, animated: true)
            root.selectedIndex = 2
        }
    }
}

extension AppDelegate: CLLocationManagerDelegate {
    
    var hasAllowedCoreLocation: Bool {
        return CLLocationManager.authorizationStatus() == .authorizedWhenInUse
    }
    
    func setupCoreLocation() {
        clManager = CLLocationManager()
        clManager.delegate = self
        clManager.desiredAccuracy = kCLLocationAccuracyBest
        requestLocation()
    }
    
    func requestLocation() {
        clManager.requestWhenInUseAuthorization()
        if hasAllowedCoreLocation {
            clManager.startUpdatingLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        if status == .authorizedWhenInUse {
            manager.startUpdatingLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = manager.location else { return }
        manager.stopUpdatingLocation()
        let gc = CLGeocoder()
        gc.reverseGeocodeLocation(loc) { (placemarks, error) in
            self.currentLocation = loc
            guard let place = placemarks?.last?.locality else { return }
            self.locationName = place
            
            print("\n--- Your Location: \(place) ---\n")
            let info: [String : Any] = [
                "latitude": loc.coordinate.latitude,
                "longitude": loc.coordinate.longitude,
                "location": place
            ]
            
            FirebaseManager.shared.updateCurrentUserInfo(info)
        }
        
    }
    
}

let app = UIApplication.shared.delegate as! AppDelegate
