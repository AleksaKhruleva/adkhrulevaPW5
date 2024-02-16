//
//  CoffeeShopAnnotation.swift
//
import Foundation
import MapKit

class CoffeeShopAnnotation: NSObject, MKAnnotation
{
    var title: String?
    var coordinate: CLLocationCoordinate2D
    var info: String

    init(title: String, coordinate: CLLocationCoordinate2D, info: String) {
        self.title = title
        self.coordinate = coordinate
        self.info = info
    }
}
