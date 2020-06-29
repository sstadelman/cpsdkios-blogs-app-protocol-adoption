//
//  ReferenceUILifecycleManager.swift
//  AppProtocolAdoption
//
//  Created by Stadelman, Stan on 6/27/20.
//  Copyright © 2020 SAP. All rights reserved.
//

import Foundation
import SwiftUI
import SAPFioriFlows
import SAPFiori
import Combine

final class ReferenceApplicationUIManager: ObservableObject, ApplicationUIManaging {
    
    static let shared = ReferenceApplicationUIManager()
    private init() {}
    @Published var screen: Screen = .onboarding
    
    enum Screen: String {
        case app, onboarding, screenshot
    }
    
    func hideApplicationScreen(completionHandler: @escaping (Error?) -> Void) {
        DispatchQueue.main.async {
            self.screen = .screenshot
            completionHandler(nil)
        }
    }
    
    func showSplashScreenForOnboarding(completionHandler: @escaping (Error?) -> Void) {
        DispatchQueue.main.async {
            self.screen = .onboarding
            completionHandler(nil)
        }
    }
    
    func showApplicationScreen(completionHandler: @escaping (Error?) -> Void) {
        DispatchQueue.main.async {
            self.screen = .app
            completionHandler(nil)
        }
    }
}
