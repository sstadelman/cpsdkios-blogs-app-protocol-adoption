//
// AppProtocolAdoption
//
// Created by SAP Cloud Platform SDK for iOS Assistant application on 27/06/20
//

import Foundation

enum Comsapedmsampleservicev2CollectionType: String {
    case salesOrderHeaders = "SalesOrderHeaders"
    case customers = "Customers"
    case productTexts = "ProductTexts"
    case purchaseOrderHeaders = "PurchaseOrderHeaders"
    case salesOrderItems = "SalesOrderItems"
    case purchaseOrderItems = "PurchaseOrderItems"
    case stock = "Stock"
    case suppliers = "Suppliers"
    case products = "Products"
    case productCategories = "ProductCategories"
    case none = ""
    static let all = [salesOrderHeaders, customers, productTexts, purchaseOrderHeaders, salesOrderItems, purchaseOrderItems, stock, suppliers, products, productCategories]
}
