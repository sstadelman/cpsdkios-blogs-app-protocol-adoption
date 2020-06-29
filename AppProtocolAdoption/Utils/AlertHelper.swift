//
// AppProtocolAdoption
//
// Created by SAP Cloud Platform SDK for iOS Assistant application on 27/06/20
//

import Foundation
import UIKit

class AlertHelper {
    static let okTitle = NSLocalizedString("keyOkButtonTitle",
                                           value: "OK",
                                           comment: "XBUT: Title of OK button.")

    static func displayAlert(with title: String, error: Error?, buttonTitle: String = AlertHelper.okTitle, viewController: UIViewController) {
        let alertController = UIAlertController(title: title, message: error?.localizedDescription, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: buttonTitle, style: .default))
        DispatchQueue.main.async {
            // Present the alertController
            viewController.present(alertController, animated: true)
        }
    }
}
