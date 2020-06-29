//
//  ReferenceAppDelegate.swift
//  AppProtocolAdoption
//
//  Created by Stadelman, Stan on 6/27/20.
//  Copyright © 2020 SAP. All rights reserved.
//

import Foundation
import SwiftUI
import SAPFoundation
import SAPCommon
import SAPFioriFlows

class ReferenceAppDelegate: NSObject, UIApplicationDelegate {
    
    @Environment(\.onboardingSessionManager) var onboardingSessionManager
    let logger = Logger.shared(named: "ReferenceAppDelegate")
    
    func application(_: UIApplication, didFinishLaunchingWithOptions _: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        do {
            try SAPcpmsLogUploader.attachToRootLogger()
            try UsageBroker.shared.start()
        } catch {
            print(error)
        }
        
        Logger.root.logLevel = .warn
        
        onboardingSessionManager.open { [self] error in
            // setup notifications
            initializeRemoteNotification()
            ConnectivityReceiver.registerObserver(self)
        }
        
        return true
    }
    
    func applicationDidEnterBackground(_: UIApplication) {
        onboardingSessionManager.lock { error in
            print("error: \(error)")
        }
    }

    func applicationWillEnterForeground(_: UIApplication) {
        // Triggers to show the passcode screen
        onboardingSessionManager.unlock { error in
            print("error: \(error)")
        }
    }

    func application(_: UIApplication, supportedInterfaceOrientationsFor _: UIWindow?) -> UIInterfaceOrientationMask {
        // Onboarding is only supported in portrait orientation
        switch OnboardingFlowController.presentationState {
        case .onboarding, .restoring:
            return .portrait
        default:
            return .allButUpsideDown
        }
    }
}

// MARK: - Notification Registration

extension ReferenceAppDelegate: UNUserNotificationCenterDelegate {
    
    func initializeRemoteNotification() {
        // Registering for remote notifications
        UIApplication.shared.registerForRemoteNotifications()
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in
            // Enable or disable features based on authorization.
        }
        center.delegate = self
    }
    
    func uploadDeviceTokenForRemoteNotification(_ deviceToken: Data) {
        
        guard let onboardingSession = onboardingSessionManager.onboardingSession else { return }
        
        let parameters = SAPcpmsRemoteNotificationParameters(deviceType: "iOS")
        
        onboardingSession.registerDeviceToken(deviceToken: deviceToken, withParameters: parameters) { [self] error in
            if let error = error {
                logger.error("Register DeviceToken failed", error: error)
            } else {
                logger.info("Register DeviceToken succeeded")
            }
        }
    }
    
    // MARK: AppDelegate method implementations for remote notification handling

    func application(_: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        self.uploadDeviceTokenForRemoteNotification(deviceToken)
    }

    func application(_: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        self.logger.error("Failed to register for Remote Notification", error: error)
    }

    // Called to let your app know which action was selected by the user for a given notification.
    func userNotificationCenter(_: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        self.logger.info("App opened via user selecting notification: \(response.notification.request.content.body)")
        // Here is where you want to take action to handle the notification, maybe navigate the user to a given screen.
        completionHandler()
    }

    // Called when a notification is delivered to a foreground app.
    func userNotificationCenter(_: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        self.logger.info("Remote Notification arrived while app was in foreground: \(notification.request.content.body)")
        // Currently we are presenting the notification alert as the application were in the background.
        // If you have handled the notification and do not want to display an alert, call the completionHandler with empty options: completionHandler([])
        completionHandler([.banner, .sound])
    }
}

// MARK: - ConnectivityObserver implementation

extension ReferenceAppDelegate: ConnectivityObserver {
    func connectionEstablished() {
        // connection established
        self.logger.info("Connection established.")
    }

    func connectionChanged(_ previousReachabilityType: ReachabilityType, reachabilityType _: ReachabilityType) {
        // connection changed
        self.logger.info("Connection changed.")
        if case previousReachabilityType = ReachabilityType.offline {
            // connection established
            onboardingSessionManager.open { error in
                if let error = error {
                    self.logger.error("Error in opeing session", error: error)
                }
            }
        }
    }

    func connectionLost() {
        // connection lost
        self.logger.info("Connection lost.")
    }
}
