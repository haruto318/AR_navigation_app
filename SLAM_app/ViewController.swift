//
//  ViewController.swift
//  SLAM_app
//
//  Created by Haruto Hamano on 2024/06/17.
//

import UIKit
import SceneKit
import ARKit
import CoreLocation
import MapKit
import Vision

class ViewController: UIViewController, UIScrollViewDelegate, UIPickerViewDelegate, UIPickerViewDataSource {

    var mapView: MapView!
    var scrollView: UIScrollView!
    var mapImageView: UIImageView!
    var mapImage: UIImage = UIImage(named: "map")! // Specify the map image here
    var pickerTitleLabel: UILabel!
    let PickerView = UIPickerView()
    let kakuninButton = UIButton()
    var roomArray: [(id: String, index: Character)] = []
    var start: Character = "H"
    var goal: Character = "H"

    private let configuration = ARWorldTrackingConfiguration()
    var locationService: LocationService = LocationService()
    private var sceneView: ARSCNView!
    
    private var startBtn: UIButton!
    
    private var sphereNodes: [SCNNode] = []
    var startLocation = simd_float4x4()
    
    
    ///Text Detection
    private var textDetectionRequest: VNRecognizeTextRequest?
    private var lastProcessingTime = Date()
    private var processInterval: TimeInterval = 5 // 1秒ごとに処理
    private var visited_room:[String] = []
    private var locationManager = CLLocationManager()
    private var currentLocation: CLLocation?
    var detectedText: (id: String, index: Character) = (id: "", index: "H") //Characterの初期値わからん
    private var isTextRecognitionRunning: Bool = true
    
    
    var locations: [CLLocation] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        roomArray = [
            (id: "H705", index: "H"),
            (id: "H706", index: "I"),
            (id: "H707", index: "J"),
            (id: "H708", index: "M"),
            (id: "H709", index: "N"),
            (id: "H723", index: "G"),
            (id: "H724", index: "F"),
            (id: "H725", index: "E"),
            (id: "H726", index: "D"),
            (id: "H727", index: "C"),
            (id: "H728", index: "B"),
            (id: "H729", index: "A")]
        
        setupSceneView()
        setupScene()
        
        setupLocationService()
        setupScrollView()
        setupPickerView()
        setupConfirmationButton()
        
        setupTextDetection()
        
        // Add annotation
        addAnnotation(at: CGPoint(x: 131, y: 846), title: "location")
        
        // Detect device orientation change
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(ViewController.orientationChanged),
            name: UIDevice.orientationDidChangeNotification,
            object: nil)
    }
    
    // Called when device orientation changes
    @objc func orientationChanged() {
        let isPortrait = UIDevice.current.orientation.isPortrait
        if isPortrait {
            sceneView.frame = CGRect(x: 0, y: 0, width: view.frame.width, height: view.frame.height / 2)
            scrollView.frame = CGRect(x: 0, y: view.frame.height / 2, width: view.frame.width, height: view.frame.height / 2)
        } else {
            sceneView.frame = .zero
            scrollView.frame = CGRect(x: 0, y: 0, width: view.frame.width, height: view.frame.height)
        }
        scrollView.contentSize = mapImageView.bounds.size
    }

    func setupScrollView() {
        scrollView = UIScrollView()
        scrollView.delegate = self
        view.addSubview(scrollView)
        
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: sceneView.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        let aspectRatio = mapImage.size.height / mapImage.size.width
        mapImageView = UIImageView(image: mapImage)
        mapImageView.contentMode = .scaleAspectFit
        scrollView.addSubview(mapImageView)
        
        mapImageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            mapImageView.topAnchor.constraint(equalTo: scrollView.topAnchor),
            mapImageView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
            mapImageView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
            mapImageView.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            mapImageView.heightAnchor.constraint(equalTo: mapImageView.widthAnchor, multiplier: aspectRatio)
        ])
        
        mapView = MapView(frame: mapImageView.bounds)
        mapView.backgroundColor = .clear
        mapImageView.addSubview(mapView)
    }
    
    func setupPickerView() {
        PickerView.delegate = self
        PickerView.dataSource = self
        view.addSubview(PickerView)
        
        PickerView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            PickerView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            PickerView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            PickerView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            PickerView.heightAnchor.constraint(equalToConstant: 150)
        ])
        
        PickerView.layer.borderWidth = 1.0
        PickerView.layer.borderColor = UIColor(red: 0.86, green: 0.86, blue: 0.86, alpha: 1.0).cgColor
    }

    func setupConfirmationButton() {
        kakuninButton.setTitle("Confirmed Start and Goal", for: .normal)
        kakuninButton.titleLabel?.font = UIFont(name: "HiraKakuProN-W6", size: 14)
        kakuninButton.setTitleColor(.white, for: .normal)
        kakuninButton.backgroundColor = UIColor(red: 0.13, green: 0.61, blue: 0.93, alpha: 1.0)
        kakuninButton.addTarget(self, action: #selector(tapKakuninButton(_:)), for: .touchUpInside)
        view.addSubview(kakuninButton)
        
        kakuninButton.translatesAutoresizingMaskIntoConstraints = false
        kakuninButton.isHidden = true /// ボタン非表示
        NSLayoutConstraint.activate([
            kakuninButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 10),
            kakuninButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -10),
            kakuninButton.topAnchor.constraint(equalTo: PickerView.bottomAnchor, constant: 20),
            kakuninButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    func addAnnotation(at point: CGPoint, title: String) {
        let annotationView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 10))
        annotationView.backgroundColor = .red
        annotationView.center = point
        mapView.addSubview(annotationView)
        
        let label = UILabel()
        label.text = title
        label.textAlignment = .center
        label.backgroundColor = .white
        mapView.addSubview(label)
        
        label.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: annotationView.centerXAnchor),
            label.topAnchor.constraint(equalTo: annotationView.bottomAnchor, constant: 5)
        ])
    }
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return roomArray.count
    }

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return roomArray[row].id
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        switch component {
        case 0:
            print(roomArray[row].id)
            goal = roomArray[row].index
        default:
            break
        }
    }

    @objc func tapKakuninButton(_ sender: UIButton) {
        print(PickerView.selectedRow(inComponent: 0))
        
        PickerView.removeFromSuperview()
        kakuninButton.removeFromSuperview()
        
        self.kakuninButton.isHidden = false /// ボタン非表示
        
        let nodes = createNodes()
        if let startNode = nodes[start], let goalNode = nodes[goal] {
            let path = aStar(startNode: startNode, goalNode: goalNode)
            ///2D Map
            mapView.path = path
       
            /// AR Map
            for node in self.mapView.path{
                print(node.ARPoint)
                addBlueSphere(at: startLocation, point: node.ARPoint)
            }
        }
    }
    
    func createNodes() -> [Character: Node] {
        let map = [
            "#####",
            "#GsH#",
            "##r##",
            "##q##",
            "#FpI#",
            "##o##",
            "##n##",
            "#EmJ#",
            "##l##",
            "##k##",
            "#Dj##",
            "##i##",
            "##h##",
            "#Cg##",
            "##f##",
            "##e##",
            "#BdM#",
            "##c##",
            "##b##",
            "#AaN#",
            "#####"
        ]

        var nodes: [Character: Node] = [:]
        let directions = [(-1, 0), (1, 0), (0, -1), (0, 1)]

        for (i, row) in map.enumerated() {
            for (j, char) in row.enumerated() {
                if char != "#" {
                    nodes[char] = Node(id: char, x: i, y: j)
                }
            }
        }

        for node in nodes.values {
            for direction in directions {
                let nx = node.x + direction.0
                let ny = node.y + direction.1
                if nx >= 0 && ny >= 0 && nx < map.count && ny < map[nx].count {
                    let neighborChar = Array(map[nx])[ny]
                    if neighborChar != "#", let neighbor = nodes[neighborChar] {
                        node.neighbors.append(neighbor)
                    }
                }
            }
        }
        
        return nodes
    }
}


////
///Set Up AR diplay and diplay route on AR
extension ViewController {
    private func setupSceneView() {
        sceneView = ARSCNView(frame: CGRect(x: 0, y: 0, width: view.frame.width, height: view.frame.height / 2))
        sceneView.delegate = self
        view.addSubview(sceneView)
        
        sceneView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            sceneView.topAnchor.constraint(equalTo: view.topAnchor),
            sceneView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            sceneView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            sceneView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.5)
        ])
    }

    private func setupScene() {
        sceneView.delegate = self
        sceneView.showsStatistics = true
        let scene = SCNScene()
        sceneView.scene = scene
        navigationController?.setNavigationBarHidden(true, animated: false)
        
        if CLLocationManager.locationServicesEnabled() {
            switch CLLocationManager.authorizationStatus() {
            case .notDetermined:
                locationService.locationManager?.requestWhenInUseAuthorization()
            case .restricted, .denied:
                presentMessage(title: "Error", message: "Location services are not enabled or permission is denied.")
            case .authorizedWhenInUse, .authorizedAlways:
                runSession()
            @unknown default:
                fatalError("Unknown authorization status")
            }
        } else {
            presentMessage(title: "Error", message: "Location services are not enabled.")
        }
    }
}

extension ViewController: MessagePresenting {
    func runSession() {
        configuration.worldAlignment = .gravityAndHeading
        configuration.planeDetection = [.horizontal, .vertical]
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
}

///AR Display
extension ViewController: ARSCNViewDelegate {
//    func session(_ session: ARSession, didFailWithError error: Error) {
//        presentMessage(title: "Error", message: error.localizedDescription)
//    }
    
    func sessionWasInterrupted(_ session: ARSession) {
        presentMessage(title: "Error", message: "Session Interruption")
    }
    
    func restartSessionWithoutDelete() {
        sceneView.session.pause()
        print("--------------------------------------")
        print("reset")
//        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        if let arError = error as? ARError {
            switch arError.errorCode {
            case 102:
                configuration.worldAlignment = .gravity
                restartSessionWithoutDelete()
            default:
                restartSessionWithoutDelete()
            }
        }
    }
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        switch camera.trackingState {
        case .normal:
            print("ready")
        case .notAvailable:
            print("wait")
        case .limited(let reason):
            print("limited tracking state: \(reason)")
        }
    }
}

extension ViewController: LocationServiceDelegate {
    func trackingLocation(for currentLocation: CLLocation) {

    }
    
    func modifyLocationCoordinates(location: CLLocation, newLatitude: CLLocationDegrees, newLongitude: CLLocationDegrees) -> CLLocation {
            return CLLocation(
                coordinate: CLLocationCoordinate2D(latitude: newLatitude, longitude: newLongitude),
                altitude: location.altitude,
                horizontalAccuracy: location.horizontalAccuracy,
                verticalAccuracy: location.verticalAccuracy,
                course: location.course,
                speed: location.speed,
                timestamp: location.timestamp
            )
        }
    
    func trackingLocationDidFail(with error: Error) {
        print("error")
    }
}


extension ViewController {
    private func setupLocationService() {
        locationService = LocationService()
        locationService.delegate = self
    }
}

///2D Map
extension ViewController: MKMapViewDelegate {
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
        let annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: "annotationView") ?? MKAnnotationView()
        annotationView.rightCalloutAccessoryView = UIButton(type: .detailDisclosure)
        annotationView.canShowCallout = true
        return annotationView
    }
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
        if overlay is MKCircle {
            let renderer = MKCircleRenderer(overlay: overlay)
            renderer.fillColor = UIColor.black.withAlphaComponent(0.1)
            renderer.strokeColor = .red
            renderer.lineWidth = 2
            return renderer
        }
        return MKOverlayRenderer()
    }
    
    func mapView(_ mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        let alertController = UIAlertController(title: "Welcome to \(String(describing: title))", message: "You've selected \(String(describing: title))", preferredStyle: .alert)
        let cancelAction = UIAlertAction(title: "OK", style: .cancel, handler: nil)
        alertController.addAction(cancelAction)
        present(alertController, animated: true, completion: nil)
    }
}

///Text Detection
extension ViewController {
    private func setupTextDetection() {
        textDetectionRequest = VNRecognizeTextRequest { [weak self] request, error in
            if let observations = request.results as? [VNRecognizedTextObservation] {
                guard self!.isTextRecognitionRunning else {
                    print("Text recognition is already running.")
                    return
                }
                self?.processObservations(observations)
            }
        }
        textDetectionRequest?.recognitionLevel = .accurate
    }
    
    private func processObservations(_ observations: [VNRecognizedTextObservation]) {
        guard let _ = sceneView else { return }
        
//        isTextRecognitionRunning = true
        guard isTextRecognitionRunning else {
            print("Text recognition is already running.")
            return
        }
            
        for observation in observations {
            let topCandidates = observation.topCandidates(1)
            if let candidate = topCandidates.first {
                let text = candidate.string
                print(text)
                if roomArray.contains(where: { $0.id == text }){
                    stopTextRecognition()
                    detectedText = roomArray.first(where: { $0.id == text })!
                    DispatchQueue.main.sync {
                        showAlert(text: detectedText)
                        
                        if let currentFrame = sceneView.session.currentFrame {
                            let transform = currentFrame.camera.transform
                            
                            startLocation = transform
                            print("start location: \(transform)")
                        }
                    }
                }
            }
        }
    }
    
    func stopTextRecognition() {
        guard isTextRecognitionRunning else {
            print("Text recognition is not running.")
            return
        }

        // Cancel the text detection request
        textDetectionRequest?.cancel()
        
        // Reset the flag and any necessary variables
        isTextRecognitionRunning = false
        detectedText = (id: "", index: "H")
    }
    
    func restartTextRecognition() {
        guard !isTextRecognitionRunning else {
            print("Text recognition is already running.")
            return
        }
        
        // Restart the text recognition process
        setupTextDetection()
    }
}

extension ViewController {
    func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
        let currentTime = Date()
        guard currentTime.timeIntervalSince(lastProcessingTime) >= processInterval else { return }
        lastProcessingTime = currentTime
        
        guard let frame = sceneView.session.currentFrame else { return }
        let pixelBuffer = frame.capturedImage
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        do {
            try imageRequestHandler.perform([self.textDetectionRequest!])
        } catch {
            print("Failed to perform text-detection request: \(error)")
        }
        
        getDistancesToSpheres()
    }
}


///Confirm Alert
extension ViewController {
    func showAlert(text: (id: String, index: Character)){
        //UIAlertControllerを用意する
        let actionAlert = UIAlertController(title: text.id, message: "Is this the starting point?", preferredStyle: UIAlertController.Style.alert)
        //UIAlertControllerにOKのアクションを追加する
        let comfirmAction = UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: {
            (action: UIAlertAction!) in
            self.start = text.index
            self.kakuninButton.isHidden = false /// ボタン表示
            print("Okのシートが選択されました。")
        })
        actionAlert.addAction(comfirmAction)
        
        //UIAlertControllerにキャンセルのアクションを追加する
        let cancelAction = UIAlertAction(title: "cancel", style: UIAlertAction.Style.cancel, handler: {
            (action: UIAlertAction!) in
            self.restartTextRecognition()
            print("キャンセルのシートが押されました。")
        })
        actionAlert.addAction(cancelAction)
        
        //アクションを表示する
        self.present(actionAlert, animated: true, completion: nil)
    }
}

///AR
extension ViewController {
    // 青い球体を追加する関数
    func addBlueSphere(at referencePoint: simd_float4x4, point: (z: Float, y: Float)) {
        // 球体のノードを作成
        let sphere = SCNSphere(radius: 0.1)
        let material = SCNMaterial()
        material.diffuse.contents = UIColor.blue
        sphere.materials = [material]
        let sphereNode = SCNNode(geometry: sphere)
        
        // 基準点からのオフセットを計算
        var translation = matrix_identity_float4x4
        translation.columns.3.z = point.z // 後ろに2.2m
        translation.columns.3.y = point.y // 右に9.1m
        
        
        let finalTransform = simd_mul(referencePoint, translation)
        print(finalTransform)
        
        sphereNode.simdTransform = finalTransform
        sceneView.scene.rootNode.addChildNode(sphereNode)
        
        // Add the sphere node to the list
        sphereNodes.append(sphereNode)
    }
    
    
    // Function to calculate distance between two SCNVector3 points
    func distanceBetweenPoints(_ pointA: SCNVector3, _ pointB: SCNVector3) -> Float {
        let dx = pointB.x - pointA.x
        let dy = pointB.y - pointA.y
        let dz = pointB.z - pointA.z
        return sqrt(dx*dx + dy*dy + dz*dz)
    }
    
    // Function to get distances from the camera to all sphere nodes
    func getDistancesToSpheres() {
        guard let cameraNode = sceneView.pointOfView else { return }
        let cameraPosition = cameraNode.position
        
//        for sphereNode in sphereNodes {
//            let spherePosition = sphereNode.position
//            let distance = distanceBetweenPoints(cameraPosition, spherePosition)
//            print("Distance to sphere at \(spherePosition): \(distance) meters")
//        }
        guard sphereNodes.count > 0 else {
            print("0 node")
            return
        }
        let spherePosition = sphereNodes.first!.position
        let distance = distanceBetweenPoints(cameraPosition, spherePosition)
        if distance <= 1 {
            removeSphere()
        }
        print("--------------------------------------------")
        print("Distance to sphere at \(spherePosition): \(distance) meters")
    }
    
    func removeSphere() {
        let sphereNode = sphereNodes.first!
        sphereNode.removeFromParentNode()
        sphereNodes.removeFirst()
    }
}
