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
    
    private var resetButton: UIButton!

    private let configuration = ARWorldTrackingConfiguration()
    var locationService: LocationService = LocationService()
    private var sceneView: ARSCNView!
    
    private var startBtn: UIButton!
    
    private var arrowNodes: [SCNNode] = []
    var startLocation = simd_float4x4()
    
    
    ///Text Detection
    private var textDetectionRequest: VNRecognizeTextRequest?
    private var lastProcessingTime = Date()
    private var processInterval: TimeInterval = 5 // 1秒ごとに処理
    private var visited_room:[String] = []
    private var locationManager = CLLocationManager()
    private var currentLocation: CLLocation?
    var detectedText: (id: String, index: Character) = (id: "", index: "H") //Characterの初期値わからん
    private var isTextRecognitionRunning: Bool = false
    
    var position: SCNVector3 = SCNVector3()
    var normal: SCNVector3 = SCNVector3()
    var right: SCNVector3 = SCNVector3()
    var lastSpherePosition: SCNVector3 = SCNVector3()
    
    var isInitialDisplay: Bool = true
    
    
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
        
        setupResetButton()
        
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
    
    private func setupResetButton() {
        resetButton = UIButton(type: .system)
        resetButton.setTitle("Reset", for: .normal)
        resetButton.setTitleColor(.white, for: .normal)
        resetButton.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        resetButton.layer.cornerRadius = 10
        resetButton.addTarget(self, action: #selector(resetButtonTapped), for: .touchUpInside)
        
        self.view.addSubview(resetButton)
        
        resetButton.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            resetButton.widthAnchor.constraint(equalToConstant: 80),
            resetButton.heightAnchor.constraint(equalToConstant: 40),
            resetButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            resetButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }
        
    @objc private func resetButtonTapped() {
        arrowNodes.removeAll()
        mapView.path.removeAll()
        restartSession()
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
            
            for node in self.mapView.path{
                addSpheres(at: position, normal: normal, right: right, node: node)
            }
            
            DispatchQueue.main.async {
                // ローディングビューを表示
                self.showLoadingView()
                                
                // 10秒後にローディングビューを非表示にする
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                    self.hideLoadingView()
                                    
//                    // 30秒後にrestartTextRecognition()を呼び出す
//                    DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
//                        self.restartTextRecognition()
//                    }
                }
            }
       
            /// AR Map
//            for node in self.mapView.path{
//                print(node.ARPoint)
//                addBlueSphere(at: startLocation, point: node.ARPoint)
//            }
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
        
        let lightNode = SCNNode()
        let light = SCNLight()
        lightNode.light = light
        scene.rootNode.addChildNode(lightNode)
        
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
        
        guard let nameplateImage = UIImage(named: "nameplate"),
              let cgImage = nameplateImage.cgImage else {
            fatalError("Failed to load nameplate image")
        }
        let referenceImage = ARReferenceImage(cgImage, orientation: .up, physicalWidth: 0.2) // 実際の表札サイズに合わせて調整してください
        referenceImage.name = "nameplate"
        configuration.detectionImages = [referenceImage]
        
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }
    
    func restartSession() {
        // 現在のセッションを停止
        sceneView.session.pause()
        
        // 既存のアンカーを削除
        sceneView.scene.rootNode.enumerateChildNodes { (node, _) in
            node.removeFromParentNode()
        }
        
        // 新しいセッションを開始
        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravityAndHeading
        configuration.planeDetection = [.horizontal, .vertical]
        
        if let nameplateImage = UIImage(named: "nameplate"),
           let cgImage = nameplateImage.cgImage {
            let referenceImage = ARReferenceImage(cgImage, orientation: .up, physicalWidth: 0.2)
            referenceImage.name = "nameplate"
            configuration.detectionImages = [referenceImage]
        }
        
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
//        textDetectionRequest?.cancel()
        
        // Reset the flag and any necessary variables
        isTextRecognitionRunning = false
        detectedText = (id: "", index: "H")
    }
    
    func restartTextRecognition() {
        isTextRecognitionRunning = true
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
        
//        getDistancesToSpheres()
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        guard let imageAnchor = anchor as? ARImageAnchor,
              imageAnchor.name == "nameplate" else { return }
        
        position = SCNVector3(imageAnchor.transform.columns.3.x,
                                  imageAnchor.transform.columns.3.y,
                                  imageAnchor.transform.columns.3.z)
        
        // 法線ベクトルを取得（画像の前向きベクトル）
        normal = SCNVector3(imageAnchor.transform.columns.1.x,
                                imageAnchor.transform.columns.1.y,
                                imageAnchor.transform.columns.1.z)
        
        // 表札の右方向ベクトルを取得
        right = SCNVector3(imageAnchor.transform.columns.0.x,
                               imageAnchor.transform.columns.0.y,
                               imageAnchor.transform.columns.0.z)
        
        restartTextRecognition()

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
            print("Start: \(self.start)")
            
            if self.isInitialDisplay {
                self.kakuninButton.isHidden = false /// ボタン表示
                self.isInitialDisplay = false
            } else {
//                self.sphereNodes.removeAll()
//                self.mapView.path.removeAll()
//                self.restartSession()
                
                // ローディングビューを表示
                self.showLoadingView()
                DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
                    let nodes = self.createNodes()
                    if let startNode = nodes[self.start], let goalNode = nodes[self.goal] {
                        let path = aStar(startNode: startNode, goalNode: goalNode)
                        ///2D Map
                        self.mapView.path = path
                        
                        for node in self.mapView.path{
                            self.addSpheres(at: self.position, normal: self.normal, right: self.right, node: node)
                        }
                        
//                        DispatchQueue.main.async {
//                            // ローディングビューを表示
//                            self.showLoadingView()
                            
                            // 10秒後にローディングビューを非表示にする
                            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                                self.hideLoadingView()
                                
//                                // 30秒後にrestartTextRecognition()を呼び出す
//                                DispatchQueue.main.asyncAfter(deadline: .now() + 10.0) {
//                                    self.restartTextRecognition()
//                                }
                            }
//                        }
                    }
                }
            }
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
//    func addSpheres(at position: SCNVector3, normal: SCNVector3, right: SCNVector3, node: Node) {
//        
////        print("node type: \(node.pointType)")
//        
//        if sphereNodes.count == 0 {
//            // 緑の球体を法線方向に2メートル離れた位置に配置
//            let sphereNode = createSphere(color: .green, radius: 0.05)
//            let distance: Float = 0.0
//            let spherePosition = SCNVector3(
//                position.x + normal.x * distance,
//                position.y + normal.y * distance, ///上
//                position.z + normal.z * distance  /// 縦
//            )
//            sphereNode.position = spherePosition
//            lastSpherePosition = spherePosition
//            sceneView.scene.rootNode.addChildNode(sphereNode)
//            sphereNodes.append(sphereNode)
//            lastSpherePosition = spherePosition
//        } else {
//            let sphereNode = createSphere(color: .blue, radius: 0.05)
//            switch node.pointType {
//            case 1:
//                let distance: Float = 2.2
//                let spherePosition = SCNVector3(
//                    position.x + normal.x * distance,
//                    position.y + normal.y * distance, ///上
//                    position.z + normal.z * distance  /// 縦
//                )
//                sphereNode.position = spherePosition
//                lastSpherePosition = spherePosition
//                sceneView.scene.rootNode.addChildNode(sphereNode)
//                sphereNodes.append(sphereNode)
//                lastSpherePosition = spherePosition
//                break
//            case 2:
//                let distance: Float = 9.1/3
//                let spherePosition = SCNVector3(
//                    lastSpherePosition.x + right.x * distance,
//                    lastSpherePosition.y + right.y * distance, ///上
//                    lastSpherePosition.z + right.z * distance  /// 縦
//                )
//                sphereNode.position = spherePosition
//                lastSpherePosition = spherePosition
//                sceneView.scene.rootNode.addChildNode(sphereNode)
//                sphereNodes.append(sphereNode)
//                lastSpherePosition = spherePosition
//                break
//            case 3:
//                let distance: Float = -9.1/3
//                let spherePosition = SCNVector3(
//                    lastSpherePosition.x + right.x * distance,
//                    lastSpherePosition.y + right.y * distance, ///上
//                    lastSpherePosition.z + right.z * distance  /// 縦
//                )
//                sphereNode.position = spherePosition
//                lastSpherePosition = spherePosition
//                sceneView.scene.rootNode.addChildNode(sphereNode)
//                sphereNodes.append(sphereNode)
//                lastSpherePosition = spherePosition
//                break
//            case 4:
//                let distance: Float = 2.2
//                let spherePosition = SCNVector3(
//                    lastSpherePosition.x + normal.x * distance,
//                    lastSpherePosition.y + normal.y * distance, ///上
//                    lastSpherePosition.z + normal.z * distance  /// 縦
//                )
//                sphereNode.position = spherePosition
//                lastSpherePosition = spherePosition
//                sceneView.scene.rootNode.addChildNode(sphereNode)
//                sphereNodes.append(sphereNode)
//                lastSpherePosition = spherePosition
//                break
//            case 5:
//                let distance: Float = -2.2
//                let spherePosition = SCNVector3(
//                    lastSpherePosition.x + normal.x * distance,
//                    lastSpherePosition.y + normal.y * distance, ///上
//                    lastSpherePosition.z + normal.z * distance  /// 縦
//                )
//                sphereNode.position = spherePosition
//                lastSpherePosition = spherePosition
//                sceneView.scene.rootNode.addChildNode(sphereNode)
//                sphereNodes.append(sphereNode)
//                lastSpherePosition = spherePosition
//                break
//            default:
//                return
//            }
//        }
//    }
//    
//    func createSphere(color: UIColor, radius: CGFloat) -> SCNNode {
//        let sphere = SCNSphere(radius: radius)
//        let material = SCNMaterial()
//        material.diffuse.contents = color
//        sphere.materials = [material]
//        return SCNNode(geometry: sphere)
//    }
    
    
    
    
    func addSpheres(at position: SCNVector3, normal: SCNVector3, right: SCNVector3, node: Node) {
        
        var arrowNode = SCNNode()
        let coneNode: SCNNode
        var cubeNode = SCNNode()
        
        if arrowNodes.isEmpty {
            // 緑の球体を法線方向に配置
            coneNode = createCone(color: .green.withAlphaComponent(0.9), radius: 0.15)
            let conePosition = SCNVector3(
                position.x + normal.x * 0.0,
                position.y + normal.y * 0.0,
                position.z + normal.z * 0.0
            )
            coneNode.position = conePosition
            
            cubeNode = createCube(color: .red.withAlphaComponent(0.9), size: 0.15)
            arrowNode.addChildNode(coneNode)
            arrowNode.addChildNode(cubeNode)
            
            cubeNode.position = SCNVector3(conePosition.x, conePosition.y-0.2, conePosition.z)
            
            lastSpherePosition = conePosition
        } else {
            coneNode = createCone(color: .blue.withAlphaComponent(0.9), radius: 0.15)
            
            let distance: Float
            var spherePosition: SCNVector3
            
            switch node.pointType {
            case 1:
                distance = 2.2
                spherePosition = SCNVector3(
                    position.x + normal.x * distance,
                    position.y + normal.y * distance,
                    position.z + normal.z * distance
                )
            case 2:
                distance = 9.1 / 3
                spherePosition = SCNVector3(
                    lastSpherePosition.x + right.x * distance,
                    lastSpherePosition.y + right.y * distance,
                    lastSpherePosition.z + right.z * distance
                )
            case 3:
                distance = -9.1 / 3
                spherePosition = SCNVector3(
                    lastSpherePosition.x + right.x * distance,
                    lastSpherePosition.y + right.y * distance,
                    lastSpherePosition.z + right.z * distance
                )
            case 4:
                distance = 2.2
                spherePosition = SCNVector3(
                    lastSpherePosition.x + normal.x * distance,
                    lastSpherePosition.y + normal.y * distance,
                    lastSpherePosition.z + normal.z * distance
                )
            case 5:
                distance = -2.2
                spherePosition = SCNVector3(
                    lastSpherePosition.x + normal.x * distance,
                    lastSpherePosition.y + normal.y * distance,
                    lastSpherePosition.z + normal.z * distance
                )
            default:
                return
            }
            
            
            arrowNode = SCNNode()
            //arrowNode.position = spherePosition
            
            coneNode.position = spherePosition
            
            cubeNode = createCube(color: .red.withAlphaComponent(0.9), size: 0.15)
            arrowNode.addChildNode(coneNode)
            arrowNode.addChildNode(cubeNode)
            
            cubeNode.position = SCNVector3(spherePosition.x, spherePosition.y-0.2, spherePosition.z)
            
            lastSpherePosition = spherePosition
        }
        
        sceneView.scene.rootNode.addChildNode(coneNode)
        if arrowNodes.count > 0 {
            // 次のノードがある方向にConeの先端を向ける
            rotateNode(arrowNodes.last!, to: coneNode.position)
        }
        arrowNodes.append(coneNode)
        lastSpherePosition = coneNode.position
        
//        // 次のノードがある方向にConeの先端を向ける
//        rotateNode(sphereNode, to: lastSpherePosition)
    }

    func createCone(color: UIColor, radius: CGFloat) -> SCNNode {
        let cone = SCNCone(topRadius: 0, bottomRadius: radius, height: 0.3)
        let material = SCNMaterial()
        material.diffuse.contents = color
        cone.materials = [material]
        return SCNNode(geometry: cone)
    }
    
    func createCube(color: UIColor, size: CGFloat) -> SCNNode {
        let cube = SCNBox(width: size, height: size, length: size, chamferRadius: 0.003)
        let material = SCNMaterial()
        material.diffuse.contents = color
        cube.materials = [material]
        return SCNNode(geometry: cube)
    }

    func rotateNode(_ node: SCNNode, to direction: SCNVector3) {
        let directionVector = SCNVector3ToGLKVector3(direction)
        let nodeDirection = SCNVector3(0, 1, 0) // ノードの初期方向
        let nodeDirectionGLK = SCNVector3ToGLKVector3(nodeDirection)
        
        let crossProduct = GLKVector3CrossProduct(nodeDirectionGLK, directionVector)
        let dotProduct = GLKVector3DotProduct(GLKVector3Normalize(nodeDirectionGLK), GLKVector3Normalize(directionVector))
        let angle = acos(dotProduct)
        
        print("-------------")
        print(crossProduct.x)
        print(crossProduct.y)
        print(crossProduct.z)
        
        node.rotation = SCNVector4(crossProduct.x, crossProduct.y, crossProduct.z, angle)
    }

    func SCNVector3ToGLKVector3(_ vector: SCNVector3) -> GLKVector3 {
        return GLKVector3Make(vector.x, vector.y, vector.z)
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
        guard arrowNodes.count > 0 else {
            print("0 node")
            return
        }
        let spherePosition = arrowNodes.first!.position
        let distance = distanceBetweenPoints(cameraPosition, spherePosition)
        if distance <= 1 {
            removeSphere()
        }
        print("--------------------------------------------")
        print("Distance to sphere at \(spherePosition): \(distance) meters")
    }
    
    func removeSphere() {
        let sphereNode = arrowNodes.first!
        sphereNode.removeFromParentNode()
        arrowNodes.removeFirst()
    }
}

extension ViewController {
    func showLoadingView() {
        let loadingView = UIView(frame: sceneView.bounds)
        loadingView.backgroundColor = UIColor(white: 0, alpha: 0.7)
        loadingView.tag = 1001  // Tag to identify the loading view

        let activityIndicator = UIActivityIndicatorView(style: .large)
        activityIndicator.color = .white
        activityIndicator.center = loadingView.center
        activityIndicator.startAnimating()

        let label = UILabel()
        label.text = "Do not move your device"
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false

        loadingView.addSubview(activityIndicator)
        loadingView.addSubview(label)
        sceneView.addSubview(loadingView)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: loadingView.centerXAnchor),
            label.topAnchor.constraint(equalTo: activityIndicator.bottomAnchor, constant: 20)
        ])
    }

    func hideLoadingView() {
        if let loadingView = sceneView.viewWithTag(1001) {
            loadingView.removeFromSuperview()
        }
    }
}


extension SCNQuaternion {
    init(_ x: Float, _ y: Float, _ z: Float, _ w: Float) {
        self.init()
        self.x = x
        self.y = y
        self.z = z
        self.w = w
    }
}
