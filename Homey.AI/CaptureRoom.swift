//
//  CaptureRoom.swift
//  Homey.AI
//
//  Created by 顾嘉元 on 2024/4/30.
//

import SwiftUI
import SceneKit
import UIKit
import FirebaseStorage

// MARK: - Data Models for the Provided JSON Structure
struct OpenAIChatResponse: Decodable {
    let id: String
    let object: String
    let created: Int
    let choices: [Choice]
}

struct Choice: Decodable {
    let index: Int
    let message: Message
    let finish_reason: String?
}

struct Message: Decodable {
    let role: String
    let content: String
}

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

struct BulkResponse: Codable {
    struct ProductTransform: Codable {
        let id: Int
        let position: Position
        let orientation: Orientation
    }
    struct Position: Codable { let x: Float; let y: Float; let z: Float }
    struct Orientation: Codable { let rotationX: Float; let rotationY: Float; let rotationZ: Float }

    let products: [ProductTransform]
}

// MARK: - Global Function to Extract Number

func extractFirstNumber(from input: String) -> String? {
    // Split the string by "/"
    let components = input.split(separator: "/")
    
    for component in components {
        if component.hasPrefix("product_id") || component.hasPrefix("image") {
            // Extract digits from the component
            let number = component.filter { "0123456789".contains($0) }
            if !number.isEmpty {
                return String(number)
            }
        }
    }
    
    return nil
}

// MARK: - SwiftUI View

struct CaptureRoomView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var scnView: SCNView?
    @State var selectedImage: UIImage
    @Binding var searchResponse: [ProductGroupedResult]
    @State private var isBottomSheetPresented = false
    
    // Mapping from product.id to extractedNumber
    @State private var idToNumberMap: [Int: String] = [:]
    // Maximum number of iterations
    let maxIterations = 5
    
    var body: some View {
        NavigationView {
            VStack {
                ZStack {
                    SCNViewContainer { view in
                        scnView = view
//                        clearScene()
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
                // On appear, start the iterative placement process if there are grouped results
                print("onAppear: searchResponse")
                if !searchResponse.isEmpty {
                    startIterativePlacement()
                }
            }
            .sheet(isPresented: $isBottomSheetPresented) {
                if !searchResponse.isEmpty {
                    // Flatten all ProductResult items from the grouped results
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
    
    // Clear the scene
    func clearScene() {
        if let scnView = self.scnView {
            if scnView.scene == nil {
                scnView.scene = SCNScene()
            }
            if let objects = scnView.scene?.rootNode.childNode(withName: "Object_grp", recursively: true) {
                objects.removeFromParentNode()
            }
        }
    }
    
    // MARK: - Iterative Placement Process
    func startIterativePlacement() {
        performIteration(currentIteration: 1)
    }
    
    func performIteration(currentIteration: Int) {
        guard currentIteration <= maxIterations else {
            print("Reached maximum number of iterations.")
            return
        }
        
        print("Starting iteration \(currentIteration)")
        
        // Load models into the scene based on current transforms
        loadModelsIntoScene(iteration: currentIteration) { success in
            if success {
                // Take snapshot of the current scene
                if let snapshot = self.takeSnapshot() {
                    // Send snapshot to LLM to get updated transforms
                    self.sendSnapshotToLLM(snapshot: snapshot) { newTransforms in
                        if let newTransforms = newTransforms, !newTransforms.isEmpty {
                            // Update the transforms
                            self.updateTransforms(with: newTransforms)
                            
                            // Proceed to next iteration
                            self.performIteration(currentIteration: currentIteration + 1)
                        } else {
                            print("No updates from LLM. Terminating iterations.")
                        }
                    }
                } else {
                    print("Failed to take snapshot.")
                }
            } else {
                print("Failed to load models into scene.")
            }
        }
    }
    
    // MARK: - Load Models into Scene (Skip Re-Download, Skip Re-Add if Already Added)
    func loadModelsIntoScene(iteration: Int, completion: @escaping (Bool) -> Void) {
        guard let scnView = self.scnView else {
            completion(false)
            return
        }
        
        print("loadModelsIntoScene: \(searchResponse.count)")
        
        // Gather product entries
        let productEntries = searchResponse.enumerated().compactMap {
            (index, groupedResult) -> (Int, ProductResult, BoundingPoly, String)? in
            guard let topProduct = groupedResult.results.first else { return nil }
            guard let extractedNumber = extractFirstNumber(from: topProduct.image) else { return nil }
            return (index, topProduct, groupedResult.boundingPoly, extractedNumber)
        }
        print("productEntries: \(productEntries)")
        
        // We want to (1) download them only if needed, (2) then add them if they're not already in the scene
        let downloadGroup = DispatchGroup()
        
        for (index, product, _, number) in productEntries {
            downloadGroup.enter()
            downloadModel(index: index, product: product, extractedNumber: number) {
                // Store the index->number mapping
                idToNumberMap[index] = number
                downloadGroup.leave()
            }
        }
        
        downloadGroup.notify(queue: .main) {
            print("All models downloaded (or already existed). Now place them if not placed yet.")
            
            // Add node if not already present (with a default or identity transform).
            for (index, _, _, _) in productEntries {
                let nodeName = "model_\(index)"
                if scnView.scene?.rootNode.childNode(withName: nodeName, recursively: true) == nil {
                    // Node does not exist yet, so add it at default transform.
                    if let number = self.idToNumberMap[index] {
                        let localURL = self.localURLForNumber(number)
                        self.addModelIfNeeded(from: localURL, index: index)
                    }
                } else {
                    // Already in the scene from a previous iteration
                    // (We do nothing here; will just transform it in updateTransforms.)
                }
            }
            
            // Return success
            completion(true)
        }
    }
    
    /// Checks if local file already exists. If not, downloads from Firebase.
    func downloadModel(index: Int, product: ProductResult, extractedNumber: String, completion: @escaping () -> Void) {
        let modelFileName = "\(extractedNumber).usdz"
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let localURL = documentsDirectory.appendingPathComponent(modelFileName)
        
        // If already exists, skip downloading
        if FileManager.default.fileExists(atPath: localURL.path) {
            print("Model file already exists locally: \(localURL.path). Skipping download.")
            completion()
            return
        }
        
        // Otherwise, download from Firebase
        let storageRef = Storage.storage(url: "gs://temporal-ground-437002-b8.firebasestorage.app").reference()
        let modelRef = storageRef.child("onehundred").child(modelFileName)
        
        modelRef.write(toFile: localURL) { url, error in
            if let error = error {
                print("Error downloading file: \(error.localizedDescription)")
            } else {
                print("Downloaded model to: \(localURL)")
            }
            completion()
        }
    }
    
    /// Add the model node to the scene only if not already present
    private func addModelIfNeeded(from localURL: URL, index: Int) {
        guard let scnView = self.scnView else { return }
        
        if FileManager.default.fileExists(atPath: localURL.path) {
            do {
                let modelScene = try SCNScene(url: localURL, options: nil)
                let modelNode = SCNNode()
                modelScene.rootNode.childNodes.forEach { modelNode.addChildNode($0) }
                
                // Give it a default transform. For instance:
                // - Identity position
                // - A small pitch so that it's “standing” (depending on your models)
                var transform = SCNMatrix4Identity
//                transform = SCNMatrix4Rotate(transform, -90 * .pi / 180, 1, 0, 0)
                modelNode.transform = transform
                modelNode.position.x = -1 * modelNode.position.x

                // Scale down if needed
                modelNode.scale = SCNVector3(0.3048, 0.3048, 0.3048)
                
                // Name the node
                modelNode.name = "model_\(index)"
                
                scnView.scene?.rootNode.addChildNode(modelNode)
                print("Successfully added model \(index) to scene (with default transform).")
            } catch {
                print("Error loading model: \(error.localizedDescription)")
            }
        } else {
            print("Model file does not exist at: \(localURL.path)")
        }
    }
    
    
    
    // MARK: - Local URL for Number
    func localURLForNumber(_ number: String) -> URL {
        let modelFileName = "\(number).usdz"
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDirectory.appendingPathComponent(modelFileName)
    }
    
    // MARK: - JSON String Conversion
    func jsonString(from object: Any) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: []),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }
    

    // MARK: - Get OpenAI API Key
    func getOpenAIAPIKey() -> String? {
        return Constants.OPENAI_API_KEY
    }
    
    // MARK: - Take Snapshot
    func takeSnapshot() -> UIImage? {
        guard let scnView = self.scnView else { return nil }
        let snapshot = scnView.snapshot()
        return snapshot
    }
    
    // MARK: - Send Snapshot to LLM (One Call Per Iteration)
    func sendSnapshotToLLM(snapshot: UIImage, completion: @escaping ([Int: SCNMatrix4]?) -> Void) {
        guard let apiKey = getOpenAIAPIKey() else {
            completion(nil)
            return
        }
        
        guard let imageData = snapshot.pngData() else {
            print("Failed to convert snapshot to PNG data.")
            completion(nil)
            return
        }
        
        let base64Image = imageData.base64EncodedString()
        
        // Build a JSON chunk for the LLM. For now, you might just send a textual prompt,
        // or combine it with boundingPoly, etc., whichever makes sense.
        // For illustration, we’ll show the same prompt you had earlier:
        
        let productEntries = searchResponse.enumerated().compactMap {
            (index, groupedResult) -> (Int, ProductResult, BoundingPoly, String)? in
            guard let topProduct = groupedResult.results.first else { return nil }
            guard let extractedNumber = extractFirstNumber(from: topProduct.image) else { return nil }
            return (index, topProduct, groupedResult.boundingPoly, extractedNumber)
        }
        let productsData: [[String: Any]] = productEntries.map { (index, product, poly, number) in
            let vertices = poly.normalizedVertices.map {
                ["x": $0.x ?? 0, "y": $0.y ?? 0]
            }
            return [
                "id": index,
                "name": product.product.displayName ?? "furniture",
                "boundingPoly": vertices,
                "number": number
            ]
        }
        
        let prompt = """
        You are a professional interior designer. I have several products with bounding polygons in a room scene. \
        For each product, provide the 3D position and orientation (in degrees). \
        Scale the x and z coordinates to the range from 0 to 3.48 which is the room's dimension. \ 
        Spread furnitures out as much as possible by having a high variance of x and z coordinates. \
        The furnitures' are all 0.5 by 0.5. Place furniture so that they are upright and they don't collide into each other! \
        

        Input (JSON):
        \(jsonString(from: productsData))

        For each product in the "products" array, return a JSON with the same structure:
        {
          "products": [
            {
              "id": 0,
              "position": { "x":1.0, "y":0.0, "z":2.0 },
              "orientation": { "rotationX":0, "rotationY":90, "rotationZ":0 }
            },
            ...
          ]
        }

        IMPORTANT: Return only a valid JSON object without any code fences, formatting, or additional text. Use two decimal places.
        """
        
        let imageDataURL = "data:image/jpeg;base64,\(base64Image)"
        
        guard let requestURL = URL(string: "https://api.openai.com/v1/chat/completions") else {
            print("Invalid OpenAI API URL.")
            completion(nil)
            return
        }
        
        var request = URLRequest(url: requestURL)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "model": "gpt-4o",  // or your own model name
            "messages": [
                [
                    "role": "system",
                    "content": "You are a professional interior designer. Return only valid JSON (no code fences and no ` charater)."
                ],
                [
                    "role": "user",
                    "content": [
                        ["type": "text", "text": prompt],
                        ["type": "image_url", "image_url": ["url": imageDataURL]]
                    ]
                ]
            ],
            "max_tokens": 1500,
            "temperature": 0.7
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error sending snapshot to LLM: \(error)")
                completion(nil)
                return
            }
            guard let data = data else {
                print("No data received from LLM.")
                completion(nil)
                return
            }
            
            if let responseString = String(data: data, encoding: .utf8) {
                print("LLM Response: \(responseString)")
            }
            
            // Attempt to parse the "content" as BulkResponse
            do {
                let jsonResponse = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
                if let content = jsonResponse.choices.first?.message.content {
                    let decoder = JSONDecoder()
                    let updatedBulkResponse = try decoder.decode(BulkResponse.self,
                                                                from: content.data(using: .utf8)!)
                    // Convert BulkResponse → [Int : SCNMatrix4]
                    var transformDict: [Int: SCNMatrix4] = [:]
                    for product in updatedBulkResponse.products {
                        var transform = SCNMatrix4Identity
                        // Position
                        transform = SCNMatrix4Translate(transform,
                                                        -1 * product.position.x,
                                                        product.position.y,
                                                        product.position.z)
                        // Rotation
                        transform = SCNMatrix4Rotate(transform,
                                                     product.orientation.rotationX * .pi / 180,
                                                     1, 0, 0)
                        transform = SCNMatrix4Rotate(transform,
                                                     product.orientation.rotationY * .pi / 180,
                                                     0, 1, 0)
                        transform = SCNMatrix4Rotate(transform,
                                                     product.orientation.rotationZ * .pi / 180,
                                                     0, 0, 1)
                        // Pitch up furniture
                        transform = SCNMatrix4Rotate(transform, -90 * .pi / 180, 1, 0, 0)
                        
                        transformDict[product.id] = transform
                    }
                    completion(transformDict)
                } else {
                    print("No content in LLM response.")
                    completion(nil)
                }
            } catch {
                print("Error parsing LLM response: \(error)")
                completion(nil)
            }
        }
        task.resume()
    }
    
    // MARK: - Update Trafnsforms
    func updateTransforms(with newTransforms: [Int: SCNMatrix4]) {
        DispatchQueue.main.async {
            guard let scnView = self.scnView else { return }
            
            for (id, transform) in newTransforms {
                let nodeName = "model_\(id)"
                if let modelNode = scnView.scene?.rootNode.childNode(withName: nodeName, recursively: true) {
                    
                    modelNode.transform = transform
                    modelNode.scale = SCNVector3(0.75, 0.75, 0.75)

                    print("Updated transform for model \(id)")
                } else {
                    print("Model node with id \(id) not found in scene.")
                }
            }
        }
    }
}

// MARK: - ProductSheetView

struct ProductSheetView: View {
    let searchResults: [ProductResult]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(Array(searchResults.enumerated()), id: \.offset) { index, result in
                    ProductCardView(product: result, index: index)
                        .onTapGesture {
                            
                            // Handle product selection if needed
                        }
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
            // Extract number from product.image and construct "35.png"
            if let imageNumber = extractFirstNumber(from: product.image) {
                RemoteImage(name: "\(imageNumber).png")
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 100, height: 100)
                    .cornerRadius(10)
            } else {
                // Placeholder image if extraction fails
                Rectangle()
                    .foregroundColor(Color(UIColor.systemGray5))
                    .frame(width: 100, height: 100)
                    .cornerRadius(10)
                    .overlay(
                        Text("No Image")
                            .foregroundColor(.white)
                    )
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
