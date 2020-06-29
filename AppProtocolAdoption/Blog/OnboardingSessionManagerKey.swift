//
//  OnboardingSessionManagerKey.swift
//  AppProtocolAdoption
//
//  Created by Stadelman, Stan on 6/27/20.
//  Copyright © 2020 SAP. All rights reserved.
//

import Foundation
import SwiftUI
import SAPFioriFlows

struct OnboardingSessionManagerKey: EnvironmentKey {
    
    static let defaultValue: OnboardingSessionManager<OnboardingSession> = OnboardingSessionManager(presentationDelegate: ReferenceApplicationUIManager.shared, flowProvider: OnboardingFlowProvider())

}

extension EnvironmentValues {
    var onboardingSessionManager: OnboardingSessionManager<OnboardingSession> {
        get {
            return self[OnboardingSessionManagerKey.self]
        }
        set {
            self[OnboardingSessionManagerKey.self] = newValue
        }
    }
}
