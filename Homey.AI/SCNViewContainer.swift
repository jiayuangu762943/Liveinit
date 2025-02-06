import SwiftUI
import SceneKit

struct SCNViewContainer: UIViewRepresentable {
//    @Binding var clickCnt: Int  // Use Binding to manage state from parent view
    var onSceneReady: (SCNView) -> Void  // Use a closure to pass the SCNView back
    let room3D: String? = "Home.scn"
    
    
    func makeUIView(context: Context) -> SCNView {
        let sceneView = SCNView()

        // Load the scene from the specified SceneKit file
        if let scene = SCNScene(named: room3D!) {
            sceneView.scene = scene
            sceneView.allowsCameraControl = true
            sceneView.autoenablesDefaultLighting = true
            sceneView.backgroundColor = UIColor.black
            // Adjust positions of all walls and room parts
            centerRoomModel(scene: scene)
            self.onSceneReady(sceneView)
        }
        
        if let objects = sceneView.scene?.rootNode.childNode(withName: "Object_grp", recursively: true) {
            objects.removeFromParentNode()
        }
        
            self.onSceneReady(sceneView)  // Call the closure to handle the scene view setup
        return sceneView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        // Update the view if needed
    }
    
    func centerRoomModel(scene: SCNScene) {
        let roomWidth: Float = 7.75  // Scene width
        let roomDepth: Float = 7.61  // Scene depth
        let roomHeight: Float = 2.45 // Scene height (optional)
        print("Width \(roomWidth) + Depth \(roomDepth) + roomHeight \(roomHeight) before eulerAngle = \(scene.rootNode.eulerAngles.y)")
        scene.rootNode.position.x -= 2 // Move rootnode (entire view) to the left

        // Iterate over all nodes in the scene
        scene.rootNode.enumerateChildNodes { (node, _) in if ((node.name?.contains("grp")) == false && (node.name?.contains("Floor")) == false) {
            print("Home Adjusting position for \(node.name ?? "Unnamed"), position: \(node.position),rotation: \(node.rotation)")
            let pivotPoint = SCNVector3(0, 0, 0) // Replace with the pivot position
            let angleVector = convertRotationToDegrees(rotation:SCNVector4(x: 0.0, y: 1.1, z: 0.0, w: 0.45199576))
            rotateNodeAroundPivot(node: node, pivot: pivotPoint, angle: angleVector, axis: SCNVector3(0, 1, 0)) // rotation around Y-axis
            print("Home Adjusting (After) position for \(node.name ?? "Unnamed"), position: \(node.position),rotation: \(node.rotation)")
        }
        }
    }
    
    func convertRotationToDegrees(rotation: SCNVector4) -> SCNVector4 {
        let degrees = rotation.w * (180.0 / .pi)  // Convert radians to degrees
        return SCNVector4(rotation.x, rotation.y, rotation.z, degrees)
    }

    func rotateNodeAroundPivot(node: SCNNode, pivot: SCNVector3, angle: SCNVector4, axis: SCNVector3) {
        let translationToPivot = SCNMatrix4MakeTranslation(-pivot.x, -pivot.y, -pivot.z)
        let rotationMatrix = SCNMatrix4MakeRotation(angle.y, axis.x, axis.y, axis.z)
        let translationBack = SCNMatrix4MakeTranslation(pivot.x, pivot.y, pivot.z)
        // Apply transformations
        let shiftDepth = SCNMatrix4MakeTranslation(0, 0, -0.25) // Shift 0.25 along depth (Z) axis
        let finalTransform = SCNMatrix4Mult(SCNMatrix4Mult(SCNMatrix4Mult(translationToPivot, rotationMatrix), shiftDepth), translationBack)
        node.transform = SCNMatrix4Mult(finalTransform, node.transform)
    }

    
}
