//
// AppProtocolAdoption
//
// Created by SAP Cloud Platform SDK for iOS Assistant application on 27/06/20
//

import Foundation
import SAPCommon
import SAPFiori
import SAPFioriFlows
import SAPFoundation
import SAPOData
import SAPOfflineOData

public class Comsapedmsampleservicev2OfflineODataController: ODataControlling, ObservableObject {
    enum OfflineODataControllerError: Error {
        case cannotCreateOfflinePath
        case storeClosed
    }

    private let logger = Logger.shared(named: "Comsapedmsampleservicev2OfflineODataController")
    var espmContainer: ESPMContainer<OfflineODataProvider>!
    private(set) var isOfflineStoreOpened = false

    @Published var steps = [String: OfflineODataProviderProgressReporting]() {
        didSet {
            objectWillChange.send()
        }
    }
    
    static let shared = Comsapedmsampleservicev2OfflineODataController()
    private init() {}

    // MARK: - Public methods

    public static func offlineStorePath(for onboardingID: UUID) throws -> URL {
        guard let documentsFolderURL = FileManager.default.urls(for: FileManager.SearchPathDirectory.documentDirectory, in: FileManager.SearchPathDomainMask.userDomainMask).first else {
            throw OfflineODataControllerError.cannotCreateOfflinePath
        }
        let offlineStoreURL = documentsFolderURL.appendingPathComponent(onboardingID.uuidString).appendingPathComponent("Comsapedmsampleservicev2")
        return offlineStoreURL
    }

    public static func removeStore(for onboardingID: UUID) throws {
        let offlinePath = try offlineStorePath(for: onboardingID)
        try OfflineODataProvider.clear(at: offlinePath, withName: nil)
    }

    // Read more about setting up an application with Offline Store: https://help.sap.com/viewer/fc1a59c210d848babfb3f758a6f55cb1/Latest/en-US/92f0a91d9d3148fd98b86082cf2cb1d5.html
    public func configureOData(sapURLSession: SAPURLSession, serviceRoot: URL, onboardingID: UUID) throws {
        let offlineParameters = OfflineODataParameters()
        offlineParameters.enableRepeatableRequests = true

        // Configure the path of the Offline Store
        let offlinePath = try Comsapedmsampleservicev2OfflineODataController.offlineStorePath(for: onboardingID)
        try FileManager.default.createDirectory(at: offlinePath, withIntermediateDirectories: true)
        offlineParameters.storePath = offlinePath

        // Setup an instance of delegate. See sample code below for definition of OfflineODataDelegateSample class.
        let offlineODataProvider = try! OfflineODataProvider(serviceRoot: serviceRoot, parameters: offlineParameters, sapURLSession: sapURLSession, delegate: self)
        try configureDefiningQueries(on: offlineODataProvider)
        self.espmContainer = ESPMContainer(provider: offlineODataProvider)
    }

    public func openOfflineStore(synchronize: Bool, completionHandler: @escaping (Error?) -> Void) {
        if !self.isOfflineStoreOpened {
            // The OfflineODataProvider needs to be opened before performing any operations.
            self.espmContainer.open { error in
                if let error = error {
                    self.logger.error("Could not open offline store.", error: error)
                    completionHandler(error)
                    return
                }
                self.isOfflineStoreOpened = true
                self.logger.info("Offline store opened.")
                if synchronize {
                    // You might want to consider doing the synchronization based on an explicit user interaction instead of automatically synchronizing during startup
                    self.synchronize(completionHandler: completionHandler)
                } else {
                    completionHandler(nil)
                }
            }
        } else if synchronize {
            // You might want to consider doing the synchronization based on an explicit user interaction instead of automatically synchronizing during startup
            self.synchronize(completionHandler: completionHandler)
        } else {
            completionHandler(nil)
        }
    }

    public func closeOfflineStore() {
        if self.isOfflineStoreOpened {
            do {
                // the Offline store should be closed when it is no longer used.
                try self.espmContainer.close()
                self.isOfflineStoreOpened = false
            } catch {
                self.logger.error("Offline Store closing failed.")
            }
        }
        self.logger.info("Offline Store closed.")
    }

    // You can read more about data synchnonization: https://help.sap.com/viewer/fc1a59c210d848babfb3f758a6f55cb1/Latest/en-US/59ae11dc4df345bc8073f9da45170706.html
    public func synchronize(completionHandler: @escaping (Error?) -> Void) {
        if !self.isOfflineStoreOpened {
            self.logger.error("Offline Store is still closed")
            completionHandler(OfflineODataControllerError.storeClosed)
            return
        }
        self.uploadOfflineStore { error in
            if let error = error {
                completionHandler(error)
                return
            }
            self.downloadOfflineStore { error in
                completionHandler(error)
            }
        }
    }

    // MARK: - Private methods

    // Read more about Defining Queries: https://help.sap.com/viewer/fc1a59c210d848babfb3f758a6f55cb1/Latest/en-US/2235da24931b4be69ad0ada82873044e.html
    private func configureDefiningQueries(on offlineODataProvider: OfflineODataProvider) throws {
        // Although it is not the best practice, we are defining this query limit as top=20.
        // If the service supports paging, then paging should be used instead of top!
        do {
            try offlineODataProvider.add(definingQuery: OfflineODataDefiningQuery(name: ESPMContainerMetadata.EntitySets.salesOrderHeaders.localName, query: DataQuery().from(ESPMContainerMetadata.EntitySets.salesOrderHeaders).selectAll().top(20), automaticallyRetrievesStreams: false))
            try offlineODataProvider.add(definingQuery: OfflineODataDefiningQuery(name: ESPMContainerMetadata.EntitySets.customers.localName, query: DataQuery().from(ESPMContainerMetadata.EntitySets.customers).selectAll().top(20), automaticallyRetrievesStreams: false))
            try offlineODataProvider.add(definingQuery: OfflineODataDefiningQuery(name: ESPMContainerMetadata.EntitySets.productTexts.localName, query: DataQuery().from(ESPMContainerMetadata.EntitySets.productTexts).selectAll().top(20), automaticallyRetrievesStreams: false))
            try offlineODataProvider.add(definingQuery: OfflineODataDefiningQuery(name: ESPMContainerMetadata.EntitySets.purchaseOrderHeaders.localName, query: DataQuery().from(ESPMContainerMetadata.EntitySets.purchaseOrderHeaders).selectAll().top(20), automaticallyRetrievesStreams: false))
            try offlineODataProvider.add(definingQuery: OfflineODataDefiningQuery(name: ESPMContainerMetadata.EntitySets.salesOrderItems.localName, query: DataQuery().from(ESPMContainerMetadata.EntitySets.salesOrderItems).selectAll().top(20), automaticallyRetrievesStreams: false))
            try offlineODataProvider.add(definingQuery: OfflineODataDefiningQuery(name: ESPMContainerMetadata.EntitySets.purchaseOrderItems.localName, query: DataQuery().from(ESPMContainerMetadata.EntitySets.purchaseOrderItems).selectAll().top(20), automaticallyRetrievesStreams: false))
            try offlineODataProvider.add(definingQuery: OfflineODataDefiningQuery(name: ESPMContainerMetadata.EntitySets.stock.localName, query: DataQuery().from(ESPMContainerMetadata.EntitySets.stock).selectAll().top(20), automaticallyRetrievesStreams: false))
            try offlineODataProvider.add(definingQuery: OfflineODataDefiningQuery(name: ESPMContainerMetadata.EntitySets.suppliers.localName, query: DataQuery().from(ESPMContainerMetadata.EntitySets.suppliers).selectAll().top(20), automaticallyRetrievesStreams: false))
            try offlineODataProvider.add(definingQuery: OfflineODataDefiningQuery(name: ESPMContainerMetadata.EntitySets.products.localName, query: DataQuery().from(ESPMContainerMetadata.EntitySets.products).selectAll().top(20), automaticallyRetrievesStreams: true))
            try offlineODataProvider.add(definingQuery: OfflineODataDefiningQuery(name: ESPMContainerMetadata.EntitySets.productCategories.localName, query: DataQuery().from(ESPMContainerMetadata.EntitySets.productCategories).selectAll().top(20), automaticallyRetrievesStreams: false))
        } catch {
            self.logger.error("Failed to add defining query for Offline Store initialization", error: error)
            throw error
        }
    }

    private func downloadOfflineStore(completionHandler: @escaping (Error?) -> Void) {
        // the download function updates the client’s offline store from the backend.
        self.espmContainer.download { error in
            if let error = error {
                self.logger.error("Offline Store download failed", error: error)
            } else {
                self.logger.info("Offline Store successfully downloaded")
            }
            completionHandler(error)
        }
    }

    private func uploadOfflineStore(completionHandler: @escaping (Error?) -> Void) {
        // the upload function updates the backend from the client’s offline store.
        self.espmContainer.upload { error in
            if let error = error {
                self.logger.error("Offline Store upload failed.", error: error)
                completionHandler(error)
                return
            }
            self.logger.info("Offline Store successfully uploaded.")
            completionHandler(nil)
        }
    }
}

extension Comsapedmsampleservicev2OfflineODataController: OfflineODataProviderDelegate {
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
