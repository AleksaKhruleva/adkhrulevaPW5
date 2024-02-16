//
//  CoffeeMapVC.swift
//
import UIKit
import MapKit
import CoreLocation

class CoffeeMapVC: UIViewController, CLLocationManagerDelegate, UITableViewDataSource, UITableViewDelegate, MKMapViewDelegate
{
    var mapView: MKMapView!
    var tableView: UITableView!
    let locationManager = CLLocationManager()
    var coffeeShops: [MKMapItem] = []
    var currentRouteOverlays: [MKOverlay] = []
    
    var timerRoute: Timer?
    var selectedCoffeeShop = MKMapItem()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupMap()
        setupTableView()
        requestLocationAuthorization()
    }
    
    // MARK: - Настройка карты
    private func setupMap() {
        mapView = MKMapView()
        mapView.delegate = self
        mapView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(mapView)
        mapView.pinTop(to: view)
        mapView.pinHorizontal(to: view)
        mapView.setHeight(UIScreen.main.bounds.height * 0.7)
        mapView.showsUserLocation = true
    }
    
    // MARK: - Настройка таблицы
    private func setupTableView() {
        tableView = UITableView()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.dataSource = self
        tableView.delegate = self
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)
        tableView.pinTop(to: mapView.bottomAnchor)
        tableView.pinHorizontal(to: view)
        tableView.pinBottom(to: view)
    }
    
    // MARK: - Запрос разрешения на использование геолокации
    private func requestLocationAuthorization() {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestAlwaysAuthorization()
        locationManager.startUpdatingLocation()
    }
    
    // MARK: - Поиск кофеен
    private func searchCoffeeShops(in region: MKCoordinateRegion) {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "coffee"
        request.region = region
        let search = MKLocalSearch(request: request)
        
        search.start { [weak self] (response, error) in
            guard let self = self, let response = response else {
                print("Error")
                return
            }
            self.coffeeShops = response.mapItems
            self.tableView.reloadData()
            
            mapView.removeAnnotations(mapView.annotations)
            
            for item in response.mapItems {
                let annotation = CoffeeShopAnnotation(title: item.name ?? "", coordinate: item.placemark.coordinate, info: "")
                self.mapView.addAnnotation(annotation)
            }
        }
    }
    
    // MARK: - Маршрут до выбранной кофейни
    private func routeToCoffeeShop(destination: MKMapItem) {
        mapView.removeOverlays(currentRouteOverlays)
        currentRouteOverlays.removeAll()

        guard let sourceCoordinate = locationManager.location?.coordinate else { return }

        let sourcePlacemark = MKPlacemark(coordinate: sourceCoordinate)
        let destinationPlacemark = MKPlacemark(coordinate: destination.placemark.coordinate)

        let directionRequest = MKDirections.Request()
        directionRequest.source = MKMapItem(placemark: sourcePlacemark)
        directionRequest.destination = MKMapItem(placemark: destinationPlacemark)
        directionRequest.transportType = .automobile
        
        let directions = MKDirections(request: directionRequest)
        directions.calculate { [weak self] (response, error) in
            guard let self = self, let response = response else {
                print("Error")
                return
            }

            let route = response.routes[0]
            self.mapView.addOverlay(route.polyline, level: .aboveRoads)
            self.currentRouteOverlays.append(route.polyline)
            
            let rect = route.polyline.boundingMapRect
            self.mapView.setVisibleMapRect(rect, edgePadding: UIEdgeInsets(top: 40, left: 40, bottom: 40, right: 40), animated: true)
        }
    }
    
    private func updateRoute(destination: MKMapItem) {
        guard let sourceCoordinate = locationManager.location?.coordinate else { return }

        let sourcePlacemark = MKPlacemark(coordinate: sourceCoordinate)
        let destinationPlacemark = MKPlacemark(coordinate: destination.placemark.coordinate)

        let directionRequest = MKDirections.Request()
        directionRequest.source = MKMapItem(placemark: sourcePlacemark)
        directionRequest.destination = MKMapItem(placemark: destinationPlacemark)
        directionRequest.transportType = .automobile
        
        let directions = MKDirections(request: directionRequest)
        directions.calculate { [weak self] (response, error) in
            guard let self = self, let response = response else {
                print("Error")
                return
            }
            
            mapView.removeOverlays(currentRouteOverlays)
            currentRouteOverlays.removeAll()
            
            let route = response.routes[0]
            self.mapView.addOverlay(route.polyline, level: .aboveRoads)
            self.currentRouteOverlays.append(route.polyline)
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first {
            let userLocation = location.coordinate
            let regionRadius: CLLocationDistance = 1000
            let region = MKCoordinateRegion(center: userLocation, latitudinalMeters: regionRadius, longitudinalMeters: regionRadius)
            mapView.setRegion(region, animated: true)
            searchCoffeeShops(in: region)
            timedRoute(in: region)
        }
    }
    
    private func timedRoute(in region: MKCoordinateRegion) {
        timerRoute?.invalidate()
        timerRoute = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: false) { [weak self] _ in
            self?.updateRoute(destination: self?.selectedCoffeeShop ?? MKMapItem())
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return coffeeShops.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let coffeeShop = coffeeShops[indexPath.row]
        cell.textLabel?.text = coffeeShop.name
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        selectedCoffeeShop = coffeeShops[indexPath.row]
        routeToCoffeeShop(destination: selectedCoffeeShop)
    }

    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if let polyline = overlay as? MKPolyline {
            let renderer = MKPolylineRenderer(polyline: polyline)
            renderer.strokeColor = UIColor.blue
            renderer.lineWidth = 4.0
            return renderer
        }
        return MKOverlayRenderer(overlay: overlay)
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        if annotation is MKUserLocation {
            return nil
        }
        
        if let cluster = annotation as? MKClusterAnnotation {
            let clusterView = MKAnnotationView(annotation: annotation, reuseIdentifier: "id")
            clusterView.annotation = cluster
            let label = UILabel()
            label.text = cluster.memberAnnotations.count < 50 ? "\(cluster.memberAnnotations.count)" : "50"
            label.textColor = .black
            clusterView.addSubview(label)
            
            if let customImage = UIImage(named: "cluster") {
                let backgroundColor = UIColor.white
                let resizedAndRoundedImage = resizeImage(image: customImage, targetSize: CGSize(width: 30, height: 30), backgroundColor: backgroundColor)
                clusterView.image = resizedAndRoundedImage
            }
            
            label.pinCenter(to: clusterView)
            return clusterView
        }
        
        let view = MKAnnotationView(annotation: annotation, reuseIdentifier: "CoffeeShopAnnotation")
        view.annotation = annotation
        if let customImage = UIImage(named: "test") {
            let backgroundColor = UIColor.white
            let resizedAndRoundedImage = resizeImage(image: customImage, targetSize: CGSize(width: 30, height: 30), backgroundColor: backgroundColor)
            view.image = resizedAndRoundedImage
        }
        view.clusteringIdentifier = "id"
        view.canShowCallout = true
        return view
    }
    
    func resizeImage(image: UIImage, targetSize: CGSize, backgroundColor: UIColor) -> UIImage {
        let size = image.size
        let widthRatio  = targetSize.width  / size.width
        let heightRatio = targetSize.height / size.height
        var newSize: CGSize
        if widthRatio > heightRatio {
            newSize = CGSize(width: size.width * heightRatio, height: size.height * heightRatio)
        } else {
            newSize = CGSize(width: size.width * widthRatio, height: size.height * widthRatio)
        }
        let rect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height)

        UIGraphicsBeginImageContextWithOptions(newSize, false, 0)
        let context = UIGraphicsGetCurrentContext()!
        context.addEllipse(in: rect)
        context.clip()
        
        context.setFillColor(backgroundColor.cgColor)
        context.fill(rect)
        image.draw(in: rect)

        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return newImage!
    }
}
