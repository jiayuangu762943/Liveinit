import SwiftUI
import SceneKit
import UIKit
import FirebaseStorage

// MARK: - Data Models

struct ProductLabel: Decodable {
    let key: String
    let value: String
}

struct ProductInfo: Decodable {
    let name: String
    let displayName: String?
    let productCategory: String
    let productLabels: [ProductLabel]?
}

struct ProductResult: Decodable {
    let product: ProductInfo
    let score: Float
    let image: String
}

struct NormalizedVertex: Decodable {
    let x: Float?
    let y: Float?
}

struct BoundingPoly: Decodable {
    let normalizedVertices: [NormalizedVertex]
}

struct ProductGroupedResult: Decodable {
    let boundingPoly: BoundingPoly
    let results: [ProductResult]
}

struct ProductSearchResults: Decodable {
    let indexTime: String
    let results: [ProductResult]
    let productGroupedResults: [ProductGroupedResult]
}

struct ResponseItem: Decodable {
    let productSearchResults: ProductSearchResults
}

struct ProductSearchAPIResponse: Decodable {
    let responses: [ResponseItem]
}

// MARK: - Extractor for numeric ID from Firebase image path
func extractFirstNumber(from input: String) -> String? {
    let components = input.split(separator: "/")
    for component in components {
        if component.hasPrefix("product_id") || component.hasPrefix("image") {
            let number = component.filter { "0123456789".contains($0) }
            if !number.isEmpty {
                return String(number)
            }
        }
    }
    return nil
}

struct CaptureRoomView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var scnView: SCNView?
    @State var selectedImage: UIImage
    @Binding var searchResponse: [ProductGroupedResult]
    @State private var isBottomSheetPresented = false
    
    // A dictionary of hardcoded transforms for each product ID.
    // Adjust these values (positions/rotations) as you like.
    // productID -> (position + orientation)
    //dimension: z ~ 4.5
    let hardcodedTransforms: [Int: (x: Float, y: Float, z: Float,
                                    rotX: Float, rotY: Float, rotZ: Float)] = [
        0: (x: 3.8,  y: 0.0, z: 1.0, rotX: 0.0, rotY: 0.0, rotZ: 0.0),
        1: (x: 1.5,  y: 0.0, z: 3.5, rotX: 0.0, rotY: 90.0, rotZ: 0.0),
        2: (x: 2.5,  y: 0.0, z: 3.5, rotX: 0.0, rotY: 45.0, rotZ: 0.0),
        3: (x: 3.8,  y: 0.0, z: 3.5, rotX: 0.0, rotY: 0.0, rotZ: 0.0), //sofa c pattern
        4: (x: 8.9,  y: 0.0, z: 1, rotX: 0.0, rotY: 0.0, rotZ: 0.0), //low back white
        5: (x: 2.2,  y: 0.0, z: 2, rotX: 0.0, rotY: 0.0, rotZ: 0.0), //table
        // ...add more if you have more products
    ]

    var body: some View {
        NavigationView {
            VStack {
                ZStack {
                    SCNViewContainer { view in
                        scnView = view
                    }
                }
            }
            .navigationBarTitle("Capture Room", displayMode: .inline)
            .navigationBarItems(
                leading: Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    HStack {
                        Image(systemName: "chevron.left")
                        Text("Back")
                    }
                },
                trailing: Button("Products") {
                    isBottomSheetPresented = true
                }
            )
            .onAppear {
                print("onAppear: searchResponse")

                // 1) Make sure we have a scene
                guard let scnView = self.scnView else { return }
                if scnView.scene == nil {
                    scnView.scene = SCNScene()
                }
                setupCustomCamera(for: scnView)
                
                // 2) For each product, load its USDZ model and apply the hardcoded transform
                for i in 0..<searchResponse.count {
                    loadModelIfNeeded(productID: i) {
                        // After the model is loaded, apply the transform (if we have one for this ID).
                        if let transformData = hardcodedTransforms[i] {
                            applyHardcodedTransform(productID: i, transformData: transformData)
                        }
                    }
                }
            }
            .sheet(isPresented: $isBottomSheetPresented) {
                if !searchResponse.isEmpty {
                    let allResults = searchResponse.compactMap { $0.results.first }
                    ProductSheetView(searchResults: allResults)
                        .presentationDetents([.medium, .large])
                        .presentationDragIndicator(.visible)
                } else {
                    Text("No products yet.")
                        .presentationDetents([.medium, .large])
                        .presentationDragIndicator(.visible)
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
    }
}

// MARK: - SceneKit Helpers
extension CaptureRoomView {
    func setupCustomCamera(for scnView: SCNView) {
        guard let scene = scnView.scene else { return }

        // Remove existing cameras if needed
        for child in scene.rootNode.childNodes where child.camera != nil {
            child.removeFromParentNode()
        }

        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()
        cameraNode.position = SCNVector3(0, 5, 5)
        cameraNode.eulerAngles = SCNVector3(Float.pi / 4, 0, 0)
        scene.rootNode.addChildNode(cameraNode)
    }

    // Download model if not already downloaded. Then add node if missing
    func loadModelIfNeeded(productID: Int, completion: @escaping () -> Void) {
        guard productID < searchResponse.count, productID >= 0 else {
            completion()
            return
        }
        let groupedResult = searchResponse[productID]
        guard let topProduct = groupedResult.results.first else {
            completion()
            return
        }
        guard let extractedNumber = extractFirstNumber(from: topProduct.image) else {
            completion()
            return
        }

        let modelFileName = "\(extractedNumber).usdz"
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory,
                                                          in: .userDomainMask).first!
        let localURL = documentsDirectory.appendingPathComponent(modelFileName)

        // If it's already downloaded, just add node if needed
        if FileManager.default.fileExists(atPath: localURL.path) {
            addNodeIfNeeded(from: localURL, index: productID)
            completion()
        } else {
            // Otherwise, download from Firebase
            let storageRef = Storage.storage(url: "gs://temporal-ground-437002-b8.firebasestorage.app").reference()
            let modelRef = storageRef.child("onehundred").child(modelFileName)

            modelRef.write(toFile: localURL) { _, error in
                if let error = error {
                    print("Error downloading file: \(error.localizedDescription)")
                } else {
                    print("Downloaded model to: \(localURL)")
                }
                self.addNodeIfNeeded(from: localURL, index: productID)
                completion()
            }
        }
    }

    func addNodeIfNeeded(from localURL: URL, index: Int) {
        guard let scnView = self.scnView else { return }
        guard let scene = scnView.scene else {
            scnView.scene = SCNScene()
            return
        }

        let nodeName = "model_\(index)"
        if scene.rootNode.childNode(withName: nodeName, recursively: true) == nil {
            do {
                let modelScene = try SCNScene(url: localURL, options: nil)
                let containerNode = SCNNode()
                for child in modelScene.rootNode.childNodes {
                    containerNode.addChildNode(child)
                }
                containerNode.name = nodeName
                scene.rootNode.addChildNode(containerNode)
                print("Added node for product \(index)")
            } catch {
                print("Error loading scene from \(localURL): \(error)")
            }
        } else {
            print("Node for product \(index) already exists in scene.")
        }
    }

    // Hardcode transform application
    func applyHardcodedTransform(
        productID: Int,
        transformData: (x: Float, y: Float, z: Float,
                        rotX: Float, rotY: Float, rotZ: Float)
    ) {
        guard let scnView = self.scnView else { return }
        let nodeName = "model_\(productID)"

        // Build the SCNMatrix4 from the stored floats
        var transform = SCNMatrix4Identity

        // Position
        transform = SCNMatrix4Translate(transform,
                                        -transformData.x,
                                        transformData.y,
                                        transformData.z)

        // Rotations in degrees -> convert to radians
        transform = SCNMatrix4Rotate(transform,
                                     transformData.rotX * .pi / 180,
                                     1, 0, 0)
        transform = SCNMatrix4Rotate(transform,
                                     transformData.rotY * .pi / 180,
                                     0, 1, 0)
        transform = SCNMatrix4Rotate(transform,
                                     transformData.rotZ * .pi / 180,
                                     0, 0, 1)

        // Pitch furniture upright if needed (optional)
        transform = SCNMatrix4Rotate(transform, -90 * .pi/180, 1, 0, 0)

        // Apply to the node
        DispatchQueue.main.async {
            if let modelNode = scnView.scene?.rootNode.childNode(withName: nodeName, recursively: true) {
                modelNode.transform = transform
                modelNode.scale = SCNVector3(0.75, 0.75, 0.75)
                print("Applied hardcoded transform for product \(productID)")
            } else {
                print("Node not found for product \(productID)")
            }
        }
    }
}

// MARK: - Product Sheet

struct ProductSheetView: View {
    let searchResults: [ProductResult]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(Array(searchResults.enumerated()), id: \.offset) { index, result in
                    ProductCardView(product: result, index: index)
                }
            }
            .padding()
        }
    }
}

struct ProductCardView: View {
    var product: ProductResult
    var index: Int

    var body: some View {
        HStack {
            if let imageNumber = extractFirstNumber(from: product.image) {
                RemoteImage(name: "\(imageNumber).png")
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 100, height: 100)
                    .cornerRadius(10)
            } else {
                Rectangle()
                    .foregroundColor(Color(UIColor.systemGray5))
                    .frame(width: 100, height: 100)
                    .cornerRadius(10)
                    .overlay(Text("No Image").foregroundColor(.white))
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(product.product.displayName ?? "Unnamed Product")
                    .font(.headline)
                    .lineLimit(1)
                Text("Category: \(product.product.productCategory)")
                    .font(.subheadline)
                    .lineLimit(1)
                Text(String(format: "Score: %.2f", product.score))
                    .font(.subheadline)
            }
            Spacer()
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(10)
        .shadow(radius: 5)
    }
}


