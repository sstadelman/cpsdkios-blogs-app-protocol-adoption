# Adopting `App` with SAP Cloud Platform SDK for iOS

## The `App` protocol

One of the most exciting additions to the SwiftUI development experience in iOS 14 is the [ `App`](https://developer.apple.com/documentation/swiftui/app) protocol.  The `App` interface looks similar to that of the `View`, but instead of returning a `View` body, it returns a `Scene`.  Thus, the developer has a 1st-class SwiftUI declaration at the root of their application, having a role similar in practice to that played by Xcode-generated `AppDelegate` implementations, but now formalized in the framework.

```swift
@main
struct MyApp: App {
    var body: some Scene {
        WindowGroup {
            Text("Hello, world!")
        }
    }
}
```
The `AppDelegate` in the wild has always been plagued by mediocrity of convention.  Rather than implementations focusing purely on the lifecycle management it's designed for, `AppDelegate`s have tended to accumulate unrelated model properties... CoreData stubs contributed to this... which then have terrible consumption patterns throughout the app.  Quite a few code bases have lines like `(UIApplication.shared.delegate as? AppDelegate).managedObjectContext` or worse scattered throughout the `UIViewController` files.  But what were the alternatives?  Injection, which doesn't work well with Storyboards, non-type-safe  `prepareForSeque(:)` implementations everywhere, singletons...

With the new `App` interface, developers can implement the concrete `struct` root of their application, which has the same model functionality as any SwiftUI `View`.  Specifically, developers can use the `@Environment` as the storage for their model objects, and _bind_ to the model objects either in the `App`, or in any child `Scene`s or `View`s.  Through this binding, the `App.body` implementation can respond to Combine-based model changes in the same way as any `View`.  And, as a result of using the `@Environment` and/or `@Binding` property wrappers, developers should never need to pass a reference to the delegate itself.

```swift
@main
struct Mail: App {
    @StateObject private var model = MailModel()

    @SceneBuilder var body: some Scene {
        WindowGroup {
            MailViewer()
                .environmentObject(model) // Passed through the environment.
        }
        Settings {
            SettingsView(model: model) // Passed as an observed object.
        }
    }
}
```
## Adapting the Assistant-generated `AppDelegate`

This is all terrifically exciting, but can we use it with the SAP Cloud Platform SDK for iOS?  Yes, but we'll need to make some modifications to the Assistant-generated app template.  What I'll share today is an example of how to modify a generated app with Assistant version 5.1 to use the `App` protocol.  This is a moving target, but right now, it looks like the integration is full-featured.  There are definitely some changes/enhancements which need to be made to SAPFioriFlows to fully take advantage of this new pattern, and we'll be sharing more of these throughout the summer during development with the betas.

> The source for this application is hosted here: [https://github.com/sstadelman/cpsdkios-blogs-app-protocol-adoption](https://github.com/sstadelman/cpsdkios-blogs-app-protocol-adoption).  To replicate from scratch, generate a new Master-Detail application with SAP Cloud Platform SDK for iOS Assistant version 5.1. Delete the contents of the 'View Controllers' group, and remove AppDelegate.swift, OnboardingErrorHandler.swift, and ApplicationUIManager.swift from the app target.  

Let's start with our simple `App`.  The first thing you'll notice is that there's no delegate.  Quite a lot of the boilerplate generated by the Assistant template is related to handling the app going to-and-from the background, with respect to the offline store, passcode challenges, etc.  In an ideal world, we want to know how to plug-in our SAPFioriFlow `onboarding` and `restore` sequences.  But how?  

In addition to the `App` protocol, there is also a new `@UIApplicationDelegateAdaptor` property wrapper, which creates an instance of the provided delegate, manages its lifetime, and invokes it when appropriate.  We can add this to our `App` declaration.  But, the Assistant-generated `AppDelegate` crashes at runtime... too many modal presentations & trying to access the `window`, if I had to bet.  So, let's declare a new `ReferenceAppDelegate: AppDelegate`, and use that instead.

```swift
@main
struct ReferenceApp: App {
    @UIApplicationDelegateAdaptor(ReferenceAppDelegate.self) private var appDelegate
    
    var body: some Scene {
        WindowGroup {
            Text("Hello, world!")
        }
    }
}
```
The `ReferenceAppDelegate` should do the same thing as the generated `AppDelegate`, but we should minimize it as much as possible, especially reducing the references to the view hierarchy.  Also, we ought to try to move model state _out_ of the delegate, and into the environment.  Let's see what that looks like.  

Here's a simplified implementation of the `AppDelegate` (excluding the notification registration and connectivity handlers, which can be moved to extension files).

```swift
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
}
```
Note that the main model object which was stored on the `AppDelegate`:  `var sessionManager: OnboardingSessionManager<ApplicationOnboardingSession>` is now moved to the `@Environment`.  This is accomplished by adding an `EnvironmentKey`, and a `default` instance of the session manager.  This has the really interesting effect of making the session manager available _anywhere_ in the application.  Furthermore, as we refine this template, we can certainly make `OnboardingSessionManager` implement `ObservableObject`, and enable application components to subscribe to changes on the session.  

```swift
struct OnboardingSessionManagerKey: EnvironmentKey {
    
    static let defaultValue: OnboardingSessionManager<OnboardingSession> = 
    OnboardingSessionManager(presentationDelegate: ReferenceApplicationUIManager.shared, 
                                     flowProvider: OnboardingFlowProvider())
    
}

extension EnvironmentValues {
    var onboardingSessionManager: OnboardingSessionManager<OnboardingSession> {
        get { return self[OnboardingSessionManagerKey.self] }
        set { self[OnboardingSessionManagerKey.self] = newValue }
    }
}
```

## Managing the UI Lifecycle

So, now we have an `UIApplicationDelegate` implementation, and the session manager in the environment.  If we run in this state, the `application(_:didFinishLaunchingWithOptions:)` callback will be invoked, and the `onboardingSessionManager` will trigger the `onboarding` flow.  In fact, if we exit and re-enter the app after onboarding, we'll be challenged for our app passcode for the `restore` flow as well.  Great!

We're not done yet.  The `FlowStep` screens don't have a splash screen behind them, so you can see the `Text("Hello, world!")` in-between modals.  That's problematic for a few reasons, so let's see how this is handled in the Assistant-generated template:  The `ApplicationUIManager` is responsible for handling calls from the `OnboardingSessionManager`, and swapping appropriate `UIViewController`s in and out.  There are three flavors: 1) application screen should be showing, 2) splash screen should be showing, 3) a 'blur' screen should be shown, to prevent business data from being screen-captured by the iOS multi-tasker.  The `ApplicationUIManager` maintains references to the respective view hierarchies, and manually sets the correct hierarchy to the `window.rootViewController`.  But, now we're in SwiftUI, and we shouldn't be operating on the state of the view hierarchy ourselves.  We should be able to declare what _ought_ to be, and let the framework manage the views.

To do this, let's invent a `View` which will serve as the view hierarchy of sorts for the regular application: `ESPMViewer`.  It's not doing anything special until we bind our data, but let's substitute that in for the `Text` we're displaying now.  And, while we can't use the generated `ApplicationUIManager`, we _do_ want an implementation of `ApplicationUIManaging` that can be invoked by the session manager.  So, this is where SwiftUI and Combine come into play (**this is important**):  instead of touching the view hierarchy when the UI manager is invoked, let's create a `@Published` state property, which is updated on invocations instead. By making our `ApplicationUIManaging` implementation also implement `ObservableObject`, we can subscribe to changes on that state in our `App`, and dictate which `View` should be displayed in the `WindowGroup`.

```swift
@main
struct ReferenceApp: App {
    @UIApplicationDelegateAdaptor(ReferenceAppDelegate.self) private var appDelegate
    @ObservedObject private var uiLifecycleManager = AppUILifecycleManager.shared

    var body: some Scene {
        WindowGroup {
            switch uiLifecycleManager.screen {
                case .app:
                    ESPMViewer()
                case .onboarding:
                    SplashScreen()
                case .screenshot:
                    Text("Capture screenshot for background")
            }
        }
    }
}

final class AppUILifecycleManager: ObservableObject, ApplicationUIManaging {
    
    static let shared = AppUILifecycleManager()
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
```
I love this... it's incredibly powerful.  Because we're eliminating all the stateful access to the view hierarchy, we're eliminating all of those opportunities for introducing app logic bugs.  Instead, the role of the application logic (and the SAPFioriFlows logic) is to ensure that the `state` property value is correct; the view hierarchy will be recomputed accordingly, by the framework.  There's a lot less code, and it's a lot cleaner.  🔥🔥🔥.

## Incorporating `OfflineODataProvider` status

Lastly, we need to bring the OData model back in.  Specifically, we want to take advantage of the new `OfflineODataProviderDelegate` in SDK version 5.1, which gives us granular info on the status & progress of the offline odata layer.  Today we'll make some minor tweaks to the generated `<Destination>OfflineODataController` from the Assistant; in a follow-up post, we'll wrap/re-write some of the controller methods for Combine-style API's, which gives us a really responsive user and programming experience.

Make these changes to the head of `<Destination>OfflineODataController`: 
1. `import Combine`
2. Declare conformance to `ObservableObject`
3. Make the `init()` `private`
4. Declare `static let shared = <Destination>OfflineODataProvider()`
5. Add a `@Published` dictionary, which handles the progress event records from the delegate.  

```swift
import Combine

public class <Destination>OfflineODataController: ODataControlling, ObservableObject {
    /* ... */
    
    @Published var steps = [String: OfflineODataProviderProgressReporting]() {
        didSet {
            objectWillChange.send()
        }
    }
    
    static let shared = <Destination>OfflineODataController()
    private init() {}
```
You'll also need to update the delegate at the bottom of the file.  Delete the generated `<Destination>OfflineODataDelegateSample`, and replace it with this extension implementation.  The only difference between the two is that the new version updates the `@Published var steps` property on each invocation.

You should also pass `self` to the `delegate:` parameter in `OfflineODataProvider(serviceRoot:parameters:sapURLSession:delegate)` instead of the sample.

```swift
extension <Destination>OfflineODataController: OfflineODataProviderDelegate {
    public func offlineODataProvider(_ provider: OfflineODataProvider, didUpdateOpenProgress progress: OfflineODataProviderOperationProgress) {
        updateModel(for: progress)
    }
    
    public func offlineODataProvider(_ provider: OfflineODataProvider, didUpdateDownloadProgress progress: OfflineODataProviderDownloadProgress) {
        updateModel(for: progress)
    }
    
    public func offlineODataProvider(_ provider: OfflineODataProvider, didUpdateUploadProgress progress: OfflineODataProviderOperationProgress) {
        updateModel(for: progress)
    }
    
    public func offlineODataProvider(_ provider: OfflineODataProvider, requestDidFail request: OfflineODataFailedRequest) {
    logger.error("requestFailed: \(request.httpStatusCode)")
    }
    
    public func offlineODataProvider(_ provider: OfflineODataProvider, didUpdateSendStoreProgress progress: OfflineODataProviderOperationProgress) {
        updateModel(for: progress)
    }
    
    private func updateModel(for progress: OfflineODataProviderProgressReporting) {
        DispatchQueue.main.async {
            self.steps[progress.operationId] = progress
        }
    }
}
```
With this accomplished, we can now subscribe to changes on the `steps` dictionary in the `App`, and determine whether we should show a regular `SplashScreen`, or a custom `ODataProgressView` (or the new `ProgressView`).

```swift
@main
struct ReferenceApp: App {
    @UIApplicationDelegateAdaptor(ReferenceAppDelegate.self) private var appDelegate
    @ObservedObject private var uiLifecycleManager = AppUILifecycleManager.shared
    @ObservedObject private var odataController = <Destination>OfflineODataController.shared
    
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
```
There we have it.  Realistically, we have a lot of work to do to perfectly adapt the SAPFioriFlows to modern SwiftUI, but I hope this sample both shows that the integration can work, even in the current state, and that we have a clear path to evolving to deliver a really fantastic developer experience in this new `App` based pattern.

## Appendix

Links:

 - [https://developer.apple.com/documentation/swiftui/app-structure-and-behavior](https://developer.apple.com/documentation/swiftui/app-structure-and-behavior)
