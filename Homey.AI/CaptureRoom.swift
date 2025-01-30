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
        
        // Load models into the scene based on current transforms
        loadModelsIntoScene(iteration: currentIteration) { success in
            if success {
                if let scnView = self.scnView {
                    // Create a top-down or angled camera
                    setupCustomCamera(for: scnView)
                }
                // Take snapshot of the current scene
                if let snapshot = self.takeSnapshot() {
//                    // Send snapshot to LLM to get updated transforms
//                    self.sendSnapshotToLLM(snapshot: snapshot) { newTransforms in
//                        if let newTransforms = newTransforms, !newTransforms.isEmpty {
//                            // Update the transforms
//                            self.updateTransforms(with: newTransforms)
//                            
//                            // Proceed to next iteration
//                            self.performIteration(currentIteration: currentIteration + 1)
//                        } else {
//                            print("No updates from LLM. Terminating iterations.")
//                        }
//                    }
                    // 3) First step: get textual instructions
                    if (currentIteration > 1){
                        self.requestTextualInstructions(
                            referenceImage: self.selectedImage,
                            sceneSnapshot: snapshot
                        ) { instructionText in
                            
                            guard let instructionText = instructionText else {
                                print("No textual instructions from LLM. Stopping.")
                                return
                            }
                            print("LLM textual instructions: \(instructionText)")
                            
                            // 4) Second step: convert instructions → updated positions/orientations JSON
                            self.requestPositionsAndOrientations(
                                instruction: instructionText
                            ) { transformDict in
                                guard let transformDict = transformDict, !transformDict.isEmpty else {
                                    print("No transforms from LLM. Stopping.")
                                    return
                                }
                                print("transformDict: \(transformDict)")
                                // 5) Apply new transforms
                                self.updateTransforms(with: transformDict)
                                
                                // 6) Next iteration
                                self.performIteration(currentIteration: currentIteration + 1)
                            }
                        }
                    }else{
                        self.requestPositionsAndOrientations(
                            instruction: "Place all models into scene"
                        ) { transformDict in
                            guard let transformDict = transformDict, !transformDict.isEmpty else {
                                print("No transforms from LLM. Stopping.")
                                return
                            }
                            print("transformDict: \(transformDict)")
                            // 5) Apply new transforms
                            self.updateTransforms(with: transformDict)
                            
                            // 6) Next iteration
                            self.performIteration(currentIteration: currentIteration + 1)
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
//        print("productEntries: \(productEntries)")
        
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
                
//                modelNode.scale = SCNVector3(0.3048, 0.3048, 0.3048)
                
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
    
    // MARK: - Step 1: Request Textual Instructions
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
          guard    let snapData = sceneSnapshot.jpegData(compressionQuality: 0.3) else {
            completion(nil)
            return
        }
//        let refBase64 = refData.base64EncodedString()
        let snapBase64 = snapData.base64EncodedString()
        let productEntries = searchResponse.enumerated().compactMap {
            (index, groupedResult) -> (Int, ProductResult, BoundingPoly, String)? in
            guard let topProduct = groupedResult.results.first else { return nil }
            guard let extractedNumber = extractFirstNumber(from: topProduct.image) else { return nil }
            return (index, topProduct, groupedResult.boundingPoly, extractedNumber)
        }
        // update productsData to get the size of each object and dimensions
        let productsData: [[String: Any]] = productEntries.enumerated().map { (localIndex, entry) in
            let (index, product, poly, number) = entry
            
            let vertices = poly.normalizedVertices.map {
                ["x": $0.x ?? 0, "y": $0.y ?? 0]
            }
            
            // Calculate dimensions from the bounding polygon
            let xCoordinates = poly.normalizedVertices.compactMap { $0.x }
            let yCoordinates = poly.normalizedVertices.compactMap { $0.y }
            
            let width = (xCoordinates.max() ?? 0) - (xCoordinates.min() ?? 0)
            let height = (yCoordinates.max() ?? 0) - (yCoordinates.min() ?? 0)
            
            return [
                "id": index,
                "name": product.product.displayName ?? "furniture",
//                "boundingPoly": vertices,
//                "number": number,
                "dimensions": [
                    "width": (width * 10).rounded() / 10,
                    "height": (height * 10).rounded() / 10
                ]
            ]
        }
        
        print(productsData)
        
        var outputFloorPlan: String = """
        -----------------------------------
        -----------------------------------
        -----------------------------------
        -----------------------------------
        -----------------------------------
        -----------------------------------
        -----------------------------------
        -----------------------------------
        -----------------------------------
        -----------------------------------
        -----------------------------------
        -----------------------------------
        -----------------------------------
        -----------------------------------
        -----------------------------------
        -----------------------------------
        -----------------------------------
        -----------------------------------
        -----------------------------------
        -----------------------------------
        -----------------------------------
        -----------------------------------
        -----------------------------------
        -----------------------------------
        -----------------------------------
        -----------------------------------
        -----------------------------------
        -----------------------------------
        -----------------------------------
        -----------------------------------
        -----------------------------------
        -----------------------------------
        -----------------------------------
        -----------------------------------
        -----------------------------------
"""
        // Prompt: ask for textual instructions only
        // update prompty to input textual representation of the room
        let prompt = """
        You are a professional interior designer. \
        
        Design a floor plan layout for my room with overall dimensions 3.5 x 3.5. The room is textually represented using ASCII numerical characters and '-'s. The empty room is textuaally represented by a 35 by 35 grid of '-' characters shown below. Each '-' represents 0.1 units in the room. 
        Current floor plan : 
        \(outputFloorPlan) \
        
        Input furniture data (JSON): \(jsonString(from: productsData)) \
        Represent each piece of furniture from the inputted furniture data using its unique "id" value. Use the "dimensions" data to determine the size of the furniture. Make sure none of the pieces of furniture collide. 
        Example of a chair placed in the room with Id 2, width 0.5, and height 0.4. Width of 0.5 corresponds to 5 units on the textual grid, similarly height 0.4 is corresponds to 4 units on the textural grid. So the chair should cover 4 x 5 units on the grid, as shown below.               
                            -----------------------------------
                            -----------------------------------
                            ------22222------------------------
                            ------22222------------------------
                            ------22222------------------------
                            ------22222------------------------
                            -----------------------------------
                            -----------------------------------
        Please create a logical floorplan using all pieces of furniture listed in the input product data. Ensure that no pieces of furniture collide with each other. Place the furniture from largest footprint to smallest. Each piece of furniture from the input furniture data should be placed only once in the room. Output the floorplan using the '-' and ASCII numerical characters. The final floor plan should have final dimensions 35 characters by 35 characters. 
                
        Return only the floorplan represented with text. 
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
//                    outputFloorPlan = text
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
//        let task = URLSession.shared.dataTask(with: request) { data, _, error in
//            if let error = error {
//                print("Error requesting textual instructions: \(error)")
//                completion(nil)
//                return
//            }
//            guard let data = data else {
//                print("No data from LLM for textual instructions.")
//                completion(nil)
//                return
//            }
//            do {
//                if let responseString = String(data: data, encoding: .utf8) {
//                    print("Second iteration raw response:\n\(responseString)")
//                }
//                let response = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
////                print("text response: \(response)")
//                if let text = response.choices.first?.message.content {
//                    completion(text)
//                } else {
//                    completion(nil)
//                }
//            } catch {
//                print("Failed to decode textual instructions: \(error)")
//                completion(nil)
//            }
//        }
//        task.resume()
    }
    
    // MARK: - Take Snapshot
    func takeSnapshot() -> UIImage? {
        guard let scnView = self.scnView else { return nil }
        guard let scene = scnView.scene else { return nil }
        
        // First, set up a custom camera node
        setupCustomCamera(for: scnView)
        
        // If the scene has multiple cameras, you can explicitly choose which one:
        if let cameraNode = scene.rootNode.childNode(withName: "MyCameraNode", recursively: true) {
            scnView.pointOfView = cameraNode
        }
        
        // Now take the snapshot
        let snapshot = scnView.snapshot()
//        
//        guard let imageData = snapshot.pngData() else {
//            print("Failed to convert snapshot to PNG data.")
//            return nil
//        }
//        let documentsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
//        let tempURL = documentsDir.appendingPathComponent("debug_snapshot.png")
//        do {
//            try imageData.write(to: tempURL)
//            print("Wrote snapshot to: \(tempURL.path)")
//        } catch {
//            print("Failed to write snapshot: \(error)")
//        }
        
        // 2) Scale it down to, say, 300×300
        let targetSize = CGSize(width: 300, height: 300)
        UIGraphicsBeginImageContextWithOptions(targetSize, false, 1.0)
        snapshot.draw(in: CGRect(origin: .zero, size: targetSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return resizedImage
    }
    func compressedImageData(from image: UIImage, quality: CGFloat = 0.3) -> Data? {
        // Adjust quality from 0.0 to 1.0 (lowest to highest)
        return image.jpegData(compressionQuality: quality)
    }
    
    // MARK: - Send Snapshot to LLM (One Call Per Iteration)
    func requestPositionsAndOrientations(instruction: String, completion: @escaping ([Int : SCNMatrix4]?) -> Void) {
        guard let apiKey = getOpenAIAPIKey() else {
            completion(nil)
            return
        }
        
        // Build a JSON chunk for the LLM. For now, you might just send a textual prompt,
        // or combine it with boundingPoly, etc., whichever makes sense.
        // For illustration, we’ll show the same prompt you had earlier:
        
        let productEntries = searchResponse.enumerated().compactMap {
            (index, groupedResult) -> (Int, ProductResult, BoundingPoly, String)? in
            guard let topProduct = groupedResult.results.first else { return nil }
            guard let extractedNumber = extractFirstNumber(from: topProduct.image) else { return nil }
            return (index, topProduct, groupedResult.boundingPoly, extractedNumber)
        }
        
//        update to save the 2D dimensions
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
        print("Previous Positions and Orientation: \(self.lastPosOrienString)")
//
//        adjust prompt to take in textual representation of the room
        let prompt = """
        You are an expert in 3D interior design with a strong math background. 
        Update Instructions: \(instruction)
        Previous Positions and Orientation: \(self.lastPosOrienString)
        Products (JSON):
        //           \(jsonString(from: productsData)) \
        
        Your task:
        - Use the instructions to update the X, Y, Z positions (in meters) and rotationX, rotationY, rotationZ (in degrees) for each product so that:
            * They remain within the 0–3.48 boundary on the X and Z axes.
            * They do not collide with each other.
            * Each piece of furniture is oriented correctly and pitched by +90 degrees if needed.
        - Return only valid JSON in the following format (without code fences or extra text). Use two decimal places for all floats:

        {
          "products": [
            {
              "id": 0,
              "position": { "x": 1.00, "y": 0.00, "z": 2.00 },
              "orientation": { "rotationX": 0.00, "rotationY": 90.00, "rotationZ": 0.00 }
            },
            ...
          ]
        }

        IMPORTANT: Return only a valid JSON object without any code fences, formatting, or additional text. Use two decimal places.

        """

//        let imageDataURL = "data:image/jpeg;base64,\(base64Image)"
        
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
                    "content": "You are an expert in 3D interior design with a strong math background. Given an area of a certain size, you can generate a list of items that are appropriate to that area, in the right place. Return only a valid JSON (no code fences and no ` charater) and nothing else."
                ],
                [
                    "role": "user",
                    "content": [
                        ["type": "text", "text": prompt],
//                        ["type": "image_url", "image_url": ["url": imageDataURL]],
//                        ["type": "image_url", "image_url": ["url": roomImageURL]]
                    ]
                ]
            ],
//            "max_tokens": 1500,
//            "temperature": 0.7
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
//                print("LLM Response: \(responseString)")
//                self.lastPosOrienString = responseString
            }
            
            // Attempt to parse the "content" as BulkResponse
            do {
                let jsonResponse = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
                if let content = jsonResponse.choices.first?.message.content {
                    let decoder = JSONDecoder()
                    let updatedBulkResponse = try decoder.decode(BulkResponse.self,
                                                                from: content.data(using: .utf8)!)
                    
                    let encoder = JSONEncoder()
                    encoder.outputFormatting = [.prettyPrinted] // optional for readable indentation
                    // 2) Encode the array of products
                    let data = try encoder.encode(updatedBulkResponse.products)
                    // 3) Convert Data to String
                    if let jsonString = String(data: data, encoding: .utf8) {
                        self.lastPosOrienString = jsonString
                        
                    } else {
                        print("Failed to convert products JSON to String.")
                    }
                    
                    
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
