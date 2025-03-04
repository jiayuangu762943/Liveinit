//
//  CaptureRoom.swift
//  Homey.AI
//
//  Created by 顾嘉元 on 2024/4/30.
//

import SwiftUI
import SceneKit
import UIKit

// MARK: - Data Models for the Provided JSON Structure
struct OpenAIChatResponse: Decodable {
    let id: String?
    let object: String?
    let created: Int?
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
    @State private var lastPosOrienString = ""
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
        let modelIdentifiers = ["11", "6", "76", "22"]
//        let modelIdentifiers = ["1", "2", "3", "4"]
        loadModelsIntoScene(modelIdentifiers: modelIdentifiers) {success in if success {
            if let scnView = self.scnView {
                setupCustomCamera(for: scnView)
            }
            
//             request textual grid representation
            self.requestTextualInstructions(referenceImage: self.selectedImage, sceneSnapshot: self.selectedImage) {instructionText in
                guard let instructionText = instructionText else {
                    print("No grid from LLM. stopping")
                    return
                }
                print("LLM grid layout: \(instructionText)")
                
                // extract furniture centers
                let furnitureCenters = self.extractFurnitureCenters(from: instructionText)
                print("Extracted furniture centers: \(furnitureCenters)")
                
                // convert 2D grid positiosn into 3D screenkit positions
                var transformDict = [Int: SCNMatrix4]()
                
                for (char, centers) in furnitureCenters{
                    if let productID = Int(String(char)), let center = centers.first {
                        let (row, col) = center
                        var transform = SCNMatrix4Identity
                        let xPos = Float(col) // convert to meters
                        let zPos = Float(row)
                        
                        transform = SCNMatrix4Translate(transform, -xPos, 0.0, zPos)
                        
                        // ensure furniture is correctly oriented
                        let rotationAngle: Float = 0.0
                        let rotationMatrix = SCNMatrix4MakeRotation(rotationAngle, 0, 1, 0)
                        transform = SCNMatrix4Mult(transform, rotationMatrix)
                        
                        transformDict[productID] = transform
                    }
                }
                
//                 apply new transforms to scene
                self.updateTransforms(with: transformDict)
                
//                 proceed to next iteration
                self.performIteration(currentIteration: currentIteration + 1)
            }
        }
            else {print("Failed to load models into scene ")}}
    }
    
    // MARK: - Load Models into Scene (Skip Re-Download, Skip Re-Add if Already Added)
    func loadModelsIntoScene(modelIdentifiers: [String], completion: @escaping (Bool) -> Void) {
        guard let scnView = self.scnView else {
            completion(false)
            return
        }

        // Add node if not already present (with a default or identity transform).
        for (index, number) in modelIdentifiers.enumerated() {
            let nodeName = "model_\(index)"
            if scnView.scene?.rootNode.childNode(withName: nodeName, recursively: true) == nil {
                // Node does not exist yet, so add it at default transform.
                let localURL = self.localURLForNumber(number)
                self.addModelIfNeeded(from: localURL, index: index)
            }
        }

        // Return success
        completion(true)
    }
    
    /// Checks if local file already exists. If not, downloads from Firebase.
//    func downloadModel(index: Int, product: ProductResult, extractedNumber: String, completion: @escaping () -> Void) {
//        let modelFileName = "\(extractedNumber).usdz"
//        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
//        let localURL = documentsDirectory.appendingPathComponent(modelFileName)
//        
//        // If already exists, skip downloading
//        if FileManager.default.fileExists(atPath: localURL.path) {
//            print("Model file already exists locally: \(localURL.path). Skipping download.")
//            completion()
//            return
//        }
//        
//        // Otherwise, download from Firebase
//        let storageRef = Storage.storage(url: "gs://temporal-ground-437002-b8.firebasestorage.app").reference()
//        let modelRef = storageRef.child("onehundred").child(modelFileName)
//        
//        modelRef.write(toFile: localURL) { url, error in
//            if let error = error {
//                print("Error downloading file: \(error.localizedDescription)")
//            } else {
//                print("Downloaded model to: \(localURL)")
//            }
//            completion()
//        }
//    }
    
    /// Add the model node to the scene only if not already present
    private func addModelIfNeeded(from localURL: URL, index: Int) {
        guard let scnView = self.scnView else { return }

        if FileManager.default.fileExists(atPath: localURL.path) {
            do {
                let modelScene = try SCNScene(url: localURL, options: nil)
                let modelNode = SCNNode()
                modelScene.rootNode.childNodes.forEach { modelNode.addChildNode($0) }

                // Ensure model pivot is at its center
                let (min, max) = modelNode.boundingBox
                let center = SCNVector3((min.x + max.x) / 2, (min.y + max.y) / 2, (min.z + max.z) / 2)
                modelNode.pivot = SCNMatrix4MakeTranslation(-center.x, -center.y, -center.z)

                // Give it a default transform. For instance:
                // - Identity position
                // - A small pitch so that it's “standing” (depending on your models)
                modelNode.eulerAngles.x = 0
                var transform = SCNMatrix4Identity
                transform = SCNMatrix4Rotate(transform, -90 * .pi / 180, 1, 0, 0)
                transform = SCNMatrix4Rotate(transform, 0 * .pi / 180, 0, 1, 0)
                transform = SCNMatrix4Rotate(transform, 0 * .pi / 180, 0, 0, 1)
                modelNode.transform = transform
                modelNode.position.x = -1 * modelNode.position.x
                modelNode.scale = SCNVector3(0.75, 0.75, 0.75)

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
    
    func computeInverseRoomOffset() -> (position: SCNVector3, rotation: SCNVector4) {
            let positionOffset = SCNVector3(0, 0, 0)  // Inverted position
            let rotationOffset = SCNVector4(0.0, -1, 0.0, 1) // Inverted rotation (negate Y and W)

            return (positionOffset, rotationOffset)
        }
    
    // MARK: - Local URL for Number
    func localURLForNumber(_ number: String) -> URL {
        let modelFileName = "\(number).usdz"
        let modelsDirectory = URL(fileURLWithPath: "/Users/t-borabin/Desktop/college/10_S2025/TECH 5910/Liveinit/Homey.AI")
        return modelsDirectory.appendingPathComponent(modelFileName)
    }
//    func localURLForNumber(_ number: String) -> URL {
//        let modelFileName = "\(number).usdz"
//        let currentDirectory = Bundle.main.bundleURL
//           return currentDirectory.appendingPathComponent(modelFileName)
////        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
////        return documentsDirectory.appendingPathComponent(modelFileName)
////    }
    
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
    
    func setupCustomCamera(for scnView: SCNView) {
        guard let scene = scnView.scene else { return }
        
        // Remove any existing camera nodes if you only want one camera in the scene:
        // (Optional step, depends on whether you already have a camera node set up)
        for child in scene.rootNode.childNodes where child.camera != nil {
            child.removeFromParentNode()
        }
        
        // Create a new camera node
        let cameraNode = SCNNode()
        cameraNode.camera = SCNCamera()

        // Position the camera above the scene, looking downward
        // E.g., (x: 0, y: 5, z: 5) for a slanted top-down
        cameraNode.position = SCNVector3(0, 5, 5)

        // Rotate the camera to look down
        // The 'eulerAngles' are in radians, so
        // -45º is -π/4
        cameraNode.eulerAngles = SCNVector3(Float.pi / 4, 0, 0)

        // Optionally adjust camera properties, e.g. fieldOfView
        // cameraNode.camera?.fieldOfView = 60
        // cameraNode.camera?.orthographicScale = 2.0 // if using orthographic projection
        
        // Add the camera to the scene
        scene.rootNode.addChildNode(cameraNode)
    }
    
    // Add a method to get model identifiers from the scene
    func getModelIdentifiersFromScene() -> [String] {
        guard let scnView = self.scnView else { return [] }
        var modelIdentifiers: [String] = []

        for child in scnView.scene?.rootNode.childNodes ?? [] {
            if let name = child.name, name.hasPrefix("model_") {
                let identifier = name.replacingOccurrences(of: "model_", with: "")
                modelIdentifiers.append(identifier)
            }
        }

        return modelIdentifiers
    }

    // MARK: - Step 1: Request grid layout Instructions
    func requestTextualInstructions(
        referenceImage: UIImage,
        sceneSnapshot: UIImage,
        completion: @escaping (String?) -> Void
    ) {
        guard let apiKey = getOpenAIAPIKey() else {
            completion(nil)
            return
        }
        // Convert both images to Base64
//        guard let refData = referenceImage.pngData(),
//          guard    let snapData = sceneSnapshot.jpegData(compressionQuality: 0.3) else {
//            completion(nil)
//            return
//        }
//        let refBase64 = refData.base64EncodedString()
//        let snapBase64 = snapData.base64EncodedString()
//        let productEntries = searchResponse.enumerated().compactMap {
//            (index, groupedResult) -> (Int, ProductResult, BoundingPoly, String)? in
//            guard let topProduct = groupedResult.results.first else { return nil }
//            guard let extractedNumber = extractFirstNumber(from: topProduct.image) else { return nil }
//            return (index, topProduct, groupedResult.boundingPoly, extractedNumber)
//        }
        // update productsData to get the size of each object and dimensions
        let productsData: [[String: Any]] = getModelIdentifiersFromScene().enumerated().map { (index, identifier) in
                guard let modelNode = scnView?.scene?.rootNode.childNode(withName: "model_\(identifier)", recursively: true) else {
                    print("Model node for index \(index) not found in scene")
                    return [:]
                }
            // Calculate dimensions from the bounding polygon
            var min = SCNVector3Zero
            var max = SCNVector3Zero
            modelNode.__getBoundingBoxMin(&min, max: &max)
            
            let width = (max.x - min.x)
            let depth = (max.z - min.z)
            
//            let xCoordinates = poly.normalizedVertices.compactMap { $0.x }
//            let yCoordinates = poly.normalizedVertices.compactMap { $0.y }
//            
//            let width = (xCoordinates.max() ?? 0) - (xCoordinates.min() ?? 0)
//            let depth = (yCoordinates.max() ?? 0) - (yCoordinates.min() ?? 0)
            
            return [
                "id": index,
//                "name": product.product.displayName ?? "furniture",
//                "boundingPoly": vertices,
//                "number": number,
                "dimensions": [
                    "width": (width * 10).rounded() / 10,
                    "depth": (depth * 10).rounded() / 10
                ]
            ]
        }
        
        print(productsData)
        
        var prodDescription: String = """
        [
            {
              "id": 0,
              "name": "High-Back Upholstered Dining Chair",
              "overview": "A stylish dining chair with a high back, slim legs, and soft fabric upholstery for comfort and elegance.",
              "design": "Tall, slightly curved backrest for ergonomic support, padded seat, and tapered metal legs with a gold or brass finish.",
              "material": "Soft fabric upholstery, possibly velvet or textured weave, with metal legs in a luxurious finish.",
              "style": "Modern, contemporary, and elegant; suits dining rooms, bedrooms, and offices.",
              "keywords": ["Dining Chair", "Upholstered", "Modern", "Elegant", "Fabric", "Metal Legs", "Gold Finish", "Neutral", "High-Back"]
            },
            {
              "id": 1,
              "name": "Upholstered Armchair",
              "overview": "A deep-seated, dark green upholstered armchair with plush padding and a high backrest for comfort.",
              "design": "Boxy yet plush with soft armrests, minimal visible frame, and a seamless look.",
              "material": "Velvet or soft polyester with a textured weave for depth.",
              "style": "Modern, contemporary, and classic; suits living rooms, lounges, and reading nooks.",
              "keywords": ["Armchair", "Lounge Chair", "Upholstered", "Modern", "Cozy", "Fabric", "Velvet", "Dark Green"]
            },
            {
                "id": 2,
                "name": "Modern Curved Loveseat",
                "overview": "A sleek loveseat with a curved backrest, slim metal legs, and smooth fabric upholstery for modern comfort.",
                "design": "Curved backrest flowing into armrests, compact two-seater size with tapered metal legs.",
                "material": "Soft fabric upholstery with foam padding, metal legs in brass or matte black finish.",
                "style": "Perfect for modern, minimalist, and contemporary spaces; suits living rooms, offices, and small apartments.",
                "keywords": ["Loveseat", "Sofa", "Modern", "Minimalist", "Contemporary", "Fabric", "Metal Legs", "Curved Back", "Neutral Gray"]
              },
              {
                "id": 3,
                "name": "Wooden Pedestal Coffee Table",
                "overview": "A round wooden coffee table with a solid pedestal base, blending modern and rustic aesthetics.",
                "design": "Circular tabletop with subtle wood grain, supported by a sturdy, tapered pedestal base for stability.",
                "material": "Natural wood with a warm brown finish, smooth surface with a matte or semi-gloss sheen.",
                "style": "Ideal for modern, rustic, and Scandinavian interiors; suits living rooms and lounge areas.",
                "keywords": ["Coffee Table", "Wooden Table", "Modern", "Rustic", "Scandinavian", "Solid Wood", "Pedestal Base", "Warm Brown"]
              }
        ]
        """
        
        var outputFloorPlan: String = """
        ---------------------------------------------
        ---------------------------------------------
        ---------------------------------------------
        ---------------------------------------------
        ---------------------------------------------
        ---------------------------------------------
        ---------------------------------------------
        ---------------------------------------------
        ---------------------------------------------
        ---------------------------------------------
        ---------------------------------------------
        ---------------------------------------------
        ---------------------------------------------
        ---------------------------------------------
        ---------------------------------------------
        ---------------------------------------------
        ---------------------------------------------
        ---------------------------------------------
        ---------------------------------------------
        ---------------------------------------------
        ---------------------------------------------
        ---------------------------------------------
        ---------------------------------------------
        ---------------------------------------------
        ---------------------------------------------
        ---------------------------------------------
        ---------------------------------------------
        ---------------------------------------------
        ---------------------------------------------
        ---------------------------------------------
"""
        // Prompt: ask for textual instructions only
        // update prompty to input textual representation of the room
        let prompt = """
        You are a professional interior designer. With a strong math geometry background\
        
        Design a floor plan layout for my room with overall dimensions 4.5 x 3.0 (width x depth). The room is textually represented using ASCII numerical characters and '-'s. The empty room is textuaally represented by a 45 by 30 grid of '-' characters shown below. Each '-' represents 0.1 units in the room. 
        Current floor plan : 
        \(outputFloorPlan) \
        
        Input furniture data (JSON): \(jsonString(from: productsData)) \
        
        Input furniture descriptions (JSON): \(prodDescription) \
        
        Represent each piece of furniture from the inputted furniture data using its unique "id" value. Use the "dimensions" data to determine the size of the furniture. Make sure none of the pieces of furniture collide. 
        Use the descriptions for each piece of furntiure to determine the optimal placement of each piece in the room. Descriptions for each piece of furniture are given in the input furniture descriptions data. 
        Example of a chair placed in the room with Id 2, width 0.5, and depth 0.4. Width of 0.5 corresponds to 5 units on the textual grid, similarly depth 0.4 is corresponds to 4 units on the textural grid. So the chair should cover 4 x 5 units on the grid, as shown below.               
                            -----------------------------------
                            -----------------------------------
                            ------22222------------------------
                            ------22222------------------------
                            ------22222------------------------
                            ------22222------------------------
                            -----------------------------------
                            -----------------------------------
        Please create a logical floorplan using all pieces of furniture listed in the input product data. Ensure that no pieces of furniture collide with each other. Each piece of furniture from the input furniture data should be placed only once in the room. Output the floorplan using the '-' and ASCII numerical characters. The final floor plan should have final dimensions 45 characters by 30 characters with all the pieces of furniture placed in it. 
        
        Return only the floorplan represented with text. All pieces of furniture MUST be placed in the room. 
        """
//        let prompt = """
//        You are a professional interior designer. \
//        
//        I have one images:
//
//        1) My current 3D scene snapshot: data:image/png;base64,\(snapBase64)
//
//        Input (JSON):
//                        //           \(jsonString(from: productsData)) \
//        For each product in the input json, provide plain-English instructions on how I should move or rotate each piece of furniture in the 3D scene, which only varies along the X and Z axes in 0–3.48, to make the layout more meaningful. Example: "Move product 0 +0.2 along the x-axis and rotate 90 degrees along the y-axis clockwise."
//            
//        Return only textual instructions in a friendly, concise format. 
//        """
            
            
        let requestBody: [String: Any] = [
            "model": "gpt-4o",
            "messages": [
                [
                    "role": "system",
                    "content": "You are a professional interior designer. Only return the floorplan using ASCII numerical characters"
                ],
                [
                    "role": "user",
                    "content": [
                        ["type": "text", "text": prompt]
//                        ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(refBase64)"]],
//                        ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(snapBase64)"]]
                    ]
                ]
            ],
            "max_tokens": 1000,
            "temperature": 0.7
        ]
        
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            completion(nil)
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)
        
        
        let task = URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                print("Error requesting textual instructions: \(error)")
                completion(nil)
                return
            }
            guard let data = data else {
                print("No data from LLM for textual instructions.")
                completion(nil)
                return
            }
            do {
//                // Print raw response
//                if let responseString = String(data: data, encoding: .utf8) {
//                    print("Second iteration raw response:\n\(responseString)")
//                }
//                
                // Decode JSON
                let response = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
//                print("Decoded Response: \(response)")
                
                // Extract and print the final message content
                if let text = response.choices.first?.message.content {
                    print("Final Extracted Text Response: \(text)")
                    outputFloorPlan = text
                    completion(text)
                } else {
                    print("No content in response.")
                    completion(nil)
                }
            } catch {
                print("Failed to decode textual instructions: \(error)")
                completion(nil)
            }
        }
        task.resume()
    }
    
    // MARK: - extract furniture centers from grid
    func extractFurnitureCenters(from text: String) -> [Character: [(Double, Double)]] {
        var furniturePositions = [Character: [(Int, Int)]]()
        
        let rows = text.components(separatedBy: "\n")
        let rowCount = rows.count
        
        for (rowIndex, row) in rows.enumerated() {
            for (colIndex, char) in row.enumerated() {
                if char.isNumber {
                    furniturePositions[char, default: []].append((rowIndex, colIndex))
                }
            }
        }
        
        var furnitureCenters = [Character: [(Double, Double)]]()
        
        for (furniture, positions) in furniturePositions {
            // calc bounding box of furniture
            let minRow = positions.map {$0.0}.min() ?? 0
            let maxRow = positions.map {$0.0}.max() ?? 0
            let minCol = positions.map {$0.1}.min() ?? 0
            let maxCol = positions.map {$0.1}.max() ?? 0
            
            let centerRow = Double(minRow + maxRow + 1) / 20.0
            let centerCol = Double(minCol + maxCol + 1) / 20.0
            
            furnitureCenters[furniture, default: []].append((centerRow, centerCol))
        }
        
        return furnitureCenters
    }
    
    
    // MARK: - Update Trafnsforms
    func updateTransforms(with newTransforms: [Int: SCNMatrix4]) {
        DispatchQueue.main.async {
            guard let scnView = self.scnView else { return }
            
            let (transOffset, rotOffset) = computeInverseRoomOffset() // compute global offset
            
            for (id, transform) in newTransforms {
                let nodeName = "model_\(id)"
                if let modelNode = scnView.scene?.rootNode.childNode(withName: nodeName, recursively: true) {
                    // edit to only udpdate translation
//                    let translation = SCNMatrix4Translate(transform, transform.m41 + transOffset.x, transform.m42 + transOffset.y, transform.m43 + transOffset.z)
                    let translation = SCNVector3(transform.m41 + transOffset.x, transform.m42 + transOffset.y, transform.m43 + transOffset.z)
//                    modelNode.transform = translation
                    modelNode.position = translation
                    modelNode.scale = SCNVector3(0.75, 0.75, 0.75)

                    print("Updated transform for model \(id) trandform:")
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
