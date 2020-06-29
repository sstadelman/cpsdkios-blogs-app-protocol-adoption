//
//  ReferenceApp.swift
//  AppProtocolAdoption
//
//  Created by Stadelman, Stan on 6/27/20.
//  Copyright © 2020 SAP. All rights reserved.
//

import Foundation
import SwiftUI
import SAPFiori
import SAPFioriFlows
import SAPOData
import SAPOfflineOData

// MARK: - Reference App implementation
@main
struct ReferenceApp: App {
    @UIApplicationDelegateAdaptor(ReferenceAppDelegate.self) private var appDelegate
    @ObservedObject private var uiLifecycleManager = ReferenceApplicationUIManager.shared
    @ObservedObject private var odataController = Comsapedmsampleservicev2OfflineODataController.shared
    
    @SceneBuilder
    var body: some Scene {
        
        WindowGroup {
            switch uiLifecycleManager.screen {
                case .app:
                    ESPMViewer()
                case .onboarding:
                    if odataController.steps.isEmpty {
                        SplashScreen()
                    } else {
                        ODataProgressViewContainer(steps: odataController.steps)
                    }
                case .screenshot:
                    Text("Capture screenshot for background")
            }
        }
    }
}

// MARK: - Utility Views
struct ESPMViewer: View {
    var body: some View {
        NavigationView {
            Text("ESPM Content")
        }
        .navigationTitle("ESPMViewer")
    }
}

struct SplashScreen: View {
    
    @State var message: String = ""
    
    var body: some View {
        Text("Splash Screen")
    }
}

struct ODataProgressViewContainer: View {
    var steps: [String: OfflineODataProviderProgressReporting]
    
    var body: some View {
        GeometryReader { proxy in
            
            VStack(alignment: .leading, spacing: 8) {
                Spacer()
                ForEach(self.steps.values.sorted(by: { $0.operationId < $1.operationId }), id: \.operationId) {
                    ODataProgressView(step: $0)
                        .frame(height: 68, alignment: .top)
                }
            }
            .frame(width: proxy.size.width, alignment: .leading)
        }
        .padding(16)
    }
}

struct ODataProgressView: View {
    let step: OfflineODataProviderProgressReporting

    var body: some View {
        GeometryReader { geometry in
            VStack(alignment: .center, spacing: 4) {
                ZStack(alignment: .leading) {
                    Rectangle().frame(width: geometry.size.width, height: 18)
                        .opacity(0.3)
                        .foregroundColor(Color(UIColor.systemTeal))
                    
                    Rectangle().frame(width: min(self.progress() * geometry.size.width, geometry.size.width), height: 18)
                        .foregroundColor(Color(UIColor.systemBlue))
                        .animation(.linear)
                }.cornerRadius(45.0)
                Text(self.step.defaultMessage)
                    .lineLimit(2)
            }
        }
    }

    private func progress() -> CGFloat {
        let val = CGFloat(step.currentStepNumber) / CGFloat(step.totalNumberOfSteps)
        return val
    }
}
