//
//  ViewController.swift
//  Barebones
//
//  Created by smarteye on 2/19/19.
//  Copyright © 2019 smarteye. All rights reserved.
//

import ARKit
import SceneKit
import UIKit

class ViewController: UIViewController, ARSessionDelegate {
   
    @IBOutlet var sceneView: ARSCNView!
    @IBOutlet weak var btnTexture: UIButton!
    @IBOutlet weak var switchOverlay: UISwitch!
    
    // MARK: Properties
    var resource: UIImage?
    var bTexture: Bool = true;
    
    var contentNode: SCNNode?
    var currentFaceAnchor: ARFaceAnchor?
    
    // MARK: - View Controller Life Cycle
    override func viewDidLoad() {
        super.viewDidLoad()
        
        sceneView.delegate = self
        sceneView.session.delegate = self
        sceneView.automaticallyUpdatesLighting = true
        
        resource = #imageLiteral(resourceName: "face1")
        btnTexture.setBackgroundImage(UIImage(named: "face2.png"), for: .normal)
        
        switchOverlay.setOn(false, animated: false)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        let configuration = ARFaceTrackingConfiguration()
        sceneView.session.run(configuration)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // AR experiences typically involve moving the device without
        // touch input for some time, so prevent auto screen dimming.
        UIApplication.shared.isIdleTimerDisabled = true
        // "Reset" to run the AR session for the first time.
        resetTracking()
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        sceneView.session.pause()
    }
    
    func resetTracking() {
        guard ARFaceTrackingConfiguration.isSupported else { return }
        let configuration = ARFaceTrackingConfiguration()
        configuration.isLightEstimationEnabled = true
        sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
    }

    // MARK: - ARSessionDelegate
    func session(_ session: ARSession, didFailWithError error: Error) {
        guard error is ARError else { return }
        
        let errorWithInfo = error as NSError
        let messages = [
            errorWithInfo.localizedDescription,
            errorWithInfo.localizedFailureReason,
            errorWithInfo.localizedRecoverySuggestion
        ]
        let errorMessage = messages.compactMap({ $0 }).joined(separator: "\n")
        
        DispatchQueue.main.async {
            self.displayErrorMessage(title: "The AR session failed.", message: errorMessage)
        }
    }
    // MARK: - Error handling
    func displayErrorMessage(title: String, message: String) {
        // Present an alert informing about the error that has occurred.
        let alertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        let restartAction = UIAlertAction(title: "Restart Session", style: .default) { _ in
            alertController.dismiss(animated: true, completion: nil)
            self.resetTracking()
        }
        alertController.addAction(restartAction)
        present(alertController, animated: true, completion: nil)
    }
    
    
    @IBAction func clickBtnTexture(_ sender: Any) {
        contentNode?.removeFromParentNode()
        sceneView.session.pause();
        bTexture = !bTexture
        if bTexture {
            self.resource = #imageLiteral(resourceName: "face1")
            btnTexture.setBackgroundImage(UIImage(named: "face2.png"), for: .normal)
        }
        else{
            self.resource = #imageLiteral(resourceName: "face2")
            btnTexture.setBackgroundImage(UIImage(named: "face1.png"), for: .normal)            
        }
        self.resetTracking()
    }
    
    
    @IBAction func SwitchStateDidChange(_ sender: Any) {
        if (switchOverlay.isOn == true) {
            self.addBackground()
        }
        else
        {
            self.removeBackground()
        }
    }
    

    func addBackground() {
        let imageMaterial = SCNMaterial()
        imageMaterial.isDoubleSided = false
        imageMaterial.diffuse.contents = UIImage(named: "myImage.png")
        let box = SCNBox(width: 0.6, height: 0.8, length: 0.01, chamferRadius: 0)
        
        let boxNode = SCNNode(geometry: box)
        boxNode.geometry?.materials = [imageMaterial]
        boxNode.position = SCNVector3(0, 0, 0.5)
        
        let scene = SCNScene()
        scene.rootNode.addChildNode(boxNode)
        sceneView.scene = scene
    }
    
    func removeBackground(){
        
    }
}


extension ViewController: ARSCNViewDelegate {
    
    func renderer(_ renderer: SCNSceneRenderer, nodeFor anchor: ARAnchor) -> SCNNode? {
        guard let sceneView = renderer as? ARSCNView,
            let frame = sceneView.session.currentFrame,
            anchor is ARFaceAnchor
            else { return nil }
        
        #if targetEnvironment(simulator)
        #error("ARKit is not supported in iOS Simulator. Connect a physical iOS device and select it as your Xcode run destination, or select Generic iOS Device as a build-only destination.")
        #else
        
        // Show video texture as the diffuse material and disable lighting.
        let faceGeometry = ARSCNFaceGeometry(device: sceneView.device!, fillMesh: true)!
        let material = faceGeometry.firstMaterial!
        
        material.diffuse.contents = self.resource
//        material.diffuse.contents = #imageLiteral(resourceName: "wireframeTexture")
        material.lightingModel = .constant
        
        // Must be Modified
        guard let shaderURL = Bundle.main.url(forResource: "VideoTexturedFace", withExtension: "shader"),
            let modifier = try? String(contentsOf: shaderURL)
            else { fatalError("Can't load shader modifier from bundle.") }
        faceGeometry.shaderModifiers = [ .geometry: modifier]
        
        // Pass view-appropriate image transform to the shader modifier so
        // that the mapped video lines up correctly with the background video.
        let affineTransform = frame.displayTransform(for: .portrait, viewportSize: sceneView.bounds.size)
        let transform = SCNMatrix4(affineTransform)
        faceGeometry.setValue(SCNMatrix4Invert(transform), forKey: "displayTransform")
        
        contentNode = SCNNode(geometry: faceGeometry)
        #endif
        return contentNode
    }
    
    /// - Tag: ARFaceGeometryUpdate
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        guard let faceGeometry = node.geometry as? ARSCNFaceGeometry,
            let faceAnchor = anchor as? ARFaceAnchor
            else { return }
        
        faceGeometry.update(from: faceAnchor.geometry)
    }
}

