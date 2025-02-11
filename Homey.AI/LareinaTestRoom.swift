
//
//  LareinaTestRoom.swift
//  Homey.AI
//
//  Created by Lareina Yang on 2/4/25.
//

import SwiftUI
import SceneKit
import UIKit
import FirebaseStorage

// MARK: - SwiftUI View
struct LareinaTestRoom: View {
    @State private var scnView: SCNView?  // Declare scnView as a @State variable
    @Environment(\.presentationMode) var presentationMode
    @State private var isBottomSheetPresented = false  // Track sheet presentation state
    
    var body: some View {
        NavigationStack {
            VStack {
                ZStack {
                    SCNViewContainer { view in
                        scnView = view  // Assign the SCNView instance
                    }
                }
            }
            .navigationBarTitle("Lareina HardCode Room", displayMode: .inline)
            .navigationBarItems(
                leading: Button(action: {
                    presentationMode.wrappedValue.dismiss()  // Dismiss the current view
                }) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                },
                trailing: Button("Products") {
                    isBottomSheetPresented = true  // Show bottom sheet
                }
            )
            .onAppear {
                print("onAppear: searchResponse")
                loadRoomSize() // Loading Room Size
                            
            }
            .sheet(isPresented: $isBottomSheetPresented) {
                Text("Product List Coming Soon!")  // Placeholder content for the sheet
            }
        }
    }
}

// MARK: - SceneKit Helpers
extension LareinaTestRoom {
    func loadRoomSize(){
            guard let scnView = self.scnView else { return }
            guard scnView.scene != nil else {
                scnView.scene = SCNScene()
                return
            }
            if let scene = scnView.scene {
                var minBounds = SCNVector3(Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude)
                var maxBounds = SCNVector3(-Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude)
                for node in scene.rootNode.childNodes {
                    let position = node.worldPosition
                    print("Home Scene Origin Offset - X: \(position.x), Y: \(position.y), Z: \(position.z)")
                    let (nodeMin, nodeMax) = node.boundingBox
                    minBounds.x = min(minBounds.x, nodeMin.x)
                    minBounds.y = min(minBounds.y, nodeMin.y)
                    minBounds.z = min(minBounds.z, nodeMin.z)
                    maxBounds.x = max(maxBounds.x, nodeMax.x)
                    maxBounds.y = max(maxBounds.y, nodeMax.y)
                    maxBounds.z = max(maxBounds.z, nodeMax.z)
                }
                let width = maxBounds.x - minBounds.x
                let height = maxBounds.y - minBounds.y
                let depth = maxBounds.z - minBounds.z
                print("Home Scene Dimensions - Width: \(width), Height: \(height), Depth: \(depth)")
            } else {
                print("Scene not loaded.")
            }
            

        }
}

#Preview {
    LareinaTestRoom()
}
