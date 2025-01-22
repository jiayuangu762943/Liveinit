//
//  HardCodeCaptureRoom.swift
//  Homey.AI
//
//  Created by 顾嘉元 on 2025/1/16.
//


import SwiftUI
import SceneKit
import UIKit
import FirebaseStorage


// MARK: - SwiftUI View

struct HardCodeCaptureRoom: View {
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
        // Prompt: ask for textual instructions only
        let prompt = """
        You are a professional interior designer. \
        
        I have one images:

        1) My current 3D scene snapshot: data:image/png;base64,\(snapBase64)

        Input (JSON):
                        //           \(jsonString(from: productsData)) \
        For each product in the input json, provide plain-English instructions on how I should move or rotate each piece of furniture in the 3D scene, which only varies along the X and Z axes in 0–3.48, to make the layout more meaningful. Example: "Move product 0 +0.2 along the x-axis."
            
        Return only textual instructions in a friendly, concise format. 
        """
            
            
        let requestBody: [String: Any] = [
            "model": "gpt-4o",
            "messages": [
                [
                    "role": "system",
                    "content": "You are a professional interior designer. Return only textual instructions, no JSON in this step."
                ],
                [
                    "role": "user",
                    "content": [
                        ["type": "text", "text": prompt],
//                        ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(refBase64)"]],
                        ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(snapBase64)"]]
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
                if let responseString = String(data: data, encoding: .utf8) {
                    print("Second iteration raw response:\n\(responseString)")
                }
                let response = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
//                print("text response: \(response)")
                if let text = response.choices.first?.message.content {
                    completion(text)
                } else {
                    completion(nil)
                }
            } catch {
                print("Failed to decode textual instructions: \(error)")
                completion(nil)
            }
        }
        task.resume()
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
        return snapshot
    }
    func compressedImageData(from image: UIImage, quality: CGFloat = 0.3) -> Data? {
        // Adjust quality from 0.0 to 1.0 (lowest to highest)
        return image.jpegData(compressionQuality: quality)
    }
    
    // MARK: - Send Snapshot to LLM (One Call Per Iteration)
    func requestPositionsAndOrientations(instruction: String, completion: @escaping ([Int : SCNMatrix4]?) -> Void) {
        // 1) Define a hardcoded BulkResponse with desired transforms
        //    Adjust the "id" and x/y/z/rotation values as needed
        let hardcodedBulkResponse = BulkResponse(products: [
            BulkResponse.ProductTransform(
                id: 0,
                position: .init(x: 0.50, y: 0.00, z: 0.50),
                orientation: .init(rotationX: 90, rotationY: 0, rotationZ: 0)
            ),
            BulkResponse.ProductTransform(
                id: 1,
                position: .init(x: 3.00, y: 0.00, z: 0.50),
                orientation: .init(rotationX: 90, rotationY: 0, rotationZ: 0)
            ),
            BulkResponse.ProductTransform(
                id: 2,
                position: .init(x: 1.75, y: 0.00, z: 1.75),
                orientation: .init(rotationX: 90, rotationY: 0, rotationZ: 0)
            ),
            BulkResponse.ProductTransform(
                id: 3,
                position: .init(x: 0.50, y: 0.00, z: 3.00),
                orientation: .init(rotationX: 90, rotationY: 0, rotationZ: 0)
            ),
            BulkResponse.ProductTransform(
                id: 4,
                position: .init(x: 2.00, y: 0.00, z: 2.50),
                orientation: .init(rotationX: 90, rotationY: 0, rotationZ: 0)
            ),
            BulkResponse.ProductTransform(
                id: 5,
                position: .init(x: 2.50, y: 0.00, z: 1.00),
                orientation: .init(rotationX: 90, rotationY: 0, rotationZ: 0)
            )
        ])
        
        // 2) Convert the hardcoded BulkResponse to [Int: SCNMatrix4]
        var transformDict: [Int : SCNMatrix4] = [:]
        for product in hardcodedBulkResponse.products {
            var transform = SCNMatrix4Identity
            
            // Position
            // (If you want negative X, keep -1* product.position.x)
            transform = SCNMatrix4Translate(
                transform,
                product.position.x,
                product.position.y,
                product.position.z
            )
            
            // Rotation
            transform = SCNMatrix4Rotate(transform, product.orientation.rotationX * .pi / 180, 1, 0, 0)
            transform = SCNMatrix4Rotate(transform, product.orientation.rotationY * .pi / 180, 0, 1, 0)
            transform = SCNMatrix4Rotate(transform, product.orientation.rotationZ * .pi / 180, 0, 0, 1)
            
            // Additional pitch if you want it (as in original code)
            transform = SCNMatrix4Rotate(transform, -90 * .pi / 180, 1, 0, 0)
            
            transformDict[product.id] = transform
        }
        
        // 3) Directly call completion with the hardcoded transforms
        completion(transformDict)
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
