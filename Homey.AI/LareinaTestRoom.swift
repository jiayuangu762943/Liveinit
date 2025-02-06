
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
            .sheet(isPresented: $isBottomSheetPresented) {
                Text("Product List Coming Soon!")  // Placeholder content for the sheet
            }
        }
    }
}

#Preview {
    LareinaTestRoom()
}
