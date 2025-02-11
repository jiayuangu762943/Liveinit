import SwiftUI
import SceneKit

struct SCNViewContainer: UIViewRepresentable {
//    @Binding var clickCnt: Int  // Use Binding to manage state from parent view
    var onSceneReady: (SCNView) -> Void  // Use a closure to pass the SCNView back
    let room3D: String? = "Home.scn"

    func makeUIView(context: Context) -> SCNView {
        let sceneView = SCNView()

        // Load the scene from the specified SceneKit file
        sceneView.scene = SCNScene(named: room3D!)

        sceneView.allowsCameraControl = true
        sceneView.autoenablesDefaultLighting = true
        sceneView.backgroundColor = UIColor.black
        
        if let objects = sceneView.scene?.rootNode.childNode(withName: "Object_grp", recursively: true) {
            objects.removeFromParentNode()
        }
        
//        DispatchQueue.main.async {
            self.onSceneReady(sceneView)  // Call the closure to handle the scene view setup
//        }
        return sceneView
    }

    func updateUIView(_ uiView: SCNView, context: Context) {
        // Update the view if needed
    }
    
}


#Preview {
    SCNViewContainer { sceneView in
        print("Scene is ready for preview!")
    }
    .frame(width: 300, height: 300)
}
