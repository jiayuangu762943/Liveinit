//
//  CapturedRoom.swift
//  Homey.AI
//
//  Created by 顾嘉元 on 2024/4/19.
//

import Foundation
import SwiftUI
import RealityKit
import ARKit
import RoomPlan

struct CaptureRoomView: View {
    @State private var clickCnt = 0
    @State private var scnView: SCNView?
    var roomName:String?
    var model: Model?
    var uuid: UUID?
    var selectedCards: Set<String>?
    var body: some View {
        HStack{
            NavigationLink(destination: ChatInterfaceView(roomId: self.uuid, selectedCards: selectedCards, model: self.model!)){
                Text("Fine Tune").padding(.leading, 20)
                Image(systemName: "chair.lounge.fill" )
            }
            Spacer()
            Button(action: {
                clear()
            }, label: {
                Text("CLEAR").padding(.trailing, 20)
            })
        }
        VStack {
            SCNViewContainer(clickCnt: $clickCnt){ view in
                scnView = view  // Setup the SCNView when ready
                print("\(scnView!.bounds.width), height = \(scnView!.bounds.height)")
            }
            Spacer()
            Button(action: {
                clickCnt += 1
                Task {
                    print("selectedCards: \(selectedCards)")
                    //LLM Chain-of-thought
                    
//                    let llm = await LLMManager().sendMessage(w: scnView!.bounds.width, h: scnView!.bounds.height, imageUrls: selectedCards)
                    let llm = await LLMManager().sendMessageFurnitureChoice(w: scnView!.bounds.width, h: scnView!.bounds.height, imageUrls: selectedCards)
                    let furnitureChoiceStr = (llm!.choices[0].message.content[0] as? TextContent)!.text
                    print("furniture choice: \(furnitureChoiceStr)")
                    let postureOutput = await LLMManager().sendMessageFurniturePosture(choiceStr: furnitureChoiceStr, w: 500, h: 300, imageUrls: selectedCards)
                    let furniturePostureJSONStr = (postureOutput!.choices[0].message.content[0] as? TextContent)!.text
                    print("furniture posture: \(furniturePostureJSONStr)")

                    style(llmOutput: furniturePostureJSONStr)
                }
            }, label: {
                Text("GO!!")
                Image(systemName: "house.fill")
            }).padding(10)
            
        }
    }
    func clear(){
        let rootNode = self.scnView!.scene?.rootNode
        let objGroupNode = rootNode?.childNode(withName: "Object_grp", recursively: true)
        objGroupNode?.removeFromParentNode()
    }
    func style(llmOutput: String) {
        let tmp = llmOutput.replacingOccurrences(of: "```", with: "")
        let processed = tmp.replacingOccurrences(of: "json", with: "")
        print("processed: \(processed)")
        let data = processed.data(using: .utf8)!
        
        if let jsonDictionary = try? JSONSerialization.jsonObject(with: data, options : .allowFragments) as? Dictionary<String,Any>
        {
            for furniture in jsonDictionary["area_objects_list"] as! [Dictionary<String,Any>] {
                
//                if let x = furniture["X"] as? Float, let z = furniture["Z"] as? Float {
                if let xNumber = furniture["X"] as? NSNumber,
                   let zNumber = furniture["Z"] as? NSNumber {
                    let x = xNumber.floatValue
                    let z = zNumber.floatValue
                    if let usdzURL = Bundle.main.url(forResource: furniture["object_name"] as? String, withExtension: "usdz") {
                        let usdzScene = try? SCNScene(url: usdzURL, options: nil)
                        print("added: \(furniture["object_name"])")
                        let tmpNode = SCNNode()
                        for child in usdzScene!.rootNode.childNodes {
                            tmpNode.addChildNode(child)
                        }
                        tmpNode.position = SCNVector3(x: -x/100, y: -1, z: z/100)
                        tmpNode.eulerAngles = SCNVector3(x: -.pi/2, y: 0, z: 0)
                        if let loc = self.scnView!.scene?.rootNode.childNode(withName: "Object_grp", recursively: true) {
                            loc.addChildNode(tmpNode)
                        }else{
                            if let loc = self.scnView!.scene?.rootNode.childNode(withName: "Parametric_grp", recursively: true) {
                                let newObjGrp = SCNNode()
                                newObjGrp.name =  "Object_grp"
                                loc.addChildNode(newObjGrp)
                                print("add in object group")
                                newObjGrp.addChildNode(tmpNode)
                            }
                        }
//                        scnView?.scene?.rootNode.addChildNode(tmpNode)
                    }
                }
            }
        }
        
    }
    
}

struct SCNViewContainer: UIViewRepresentable {
   
    @Binding var clickCnt: Int  // Use Binding to manage state from parent view
    var onSceneReady: (SCNView) -> Void  // Use a closure to pass the SCNView back
    var modelFilePath: String = "home.usdz"
    
    func makeUIView(context: Context) -> SCNView {
        let sceneView = SCNView()
                
                // Load the scene from the specified SceneKit file
        sceneView.scene = SCNScene(named: "Home.scn")
        
        func printChildNodes(node: SCNNode, indent: String = "") -> Void {
            print("\(indent)Node name: \(node.name ?? "Unnamed")")
            for childNode in node.childNodes {
                printChildNodes(node: childNode, indent: "\(indent)  ")
            }
        }
        if let pNode = sceneView.scene?.rootNode{
            printChildNodes(node: pNode)
        }
        
        sceneView.allowsCameraControl = true
        sceneView.autoenablesDefaultLighting = true
        sceneView.backgroundColor = UIColor.black
        DispatchQueue.main.async {
            self.onSceneReady(sceneView)  // Call the closure to handle the scene view setup
        }
        return sceneView
    }
    
    func updateUIView(_ uiView: SCNView, context: Context) {
        print("herer")
//        if context.coordinator.room != roomController.getCapturedRoom() {
////                    remove all anchors or nodes
//                    
//            }
    }
    
    
    func loadModel(named name: String) -> Entity {
        // Load a USDZ file into an Entity
        let filename = name + ".usdz"
        guard let modelEntity = try? Entity.loadModel(named: filename) else {
            fatalError("Failed to load \(filename)")
        }
        return modelEntity
    }
    
    
}



extension CapturedRoom: Equatable {
    public static func == (lhs: CapturedRoom, rhs: CapturedRoom) -> Bool {
        // Implement your comparison logic here
        // Example: Compare based on some identifiable properties
        return lhs.identifier == rhs.identifier
    }
}

#Preview {
    CaptureRoomView()
}
