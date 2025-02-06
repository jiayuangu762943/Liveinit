//import SwiftUI
//import SceneKit
//import UIKit
//import FirebaseStorage
////
////// MARK: - Data Models
////
//struct OpenAIChatResponse: Decodable {
//    let id: String?
//    let object: String?
//    let created: Int?
//    let choices: [Choice]
//}
//
//struct Choice: Decodable {
//    let index: Int
//    let message: Message
//    let finish_reason: String?
//}
//
//struct Message: Decodable {
//    let role: String
//    let content: String
//}
//
//struct ProductLabel: Decodable {
//    let key: String
//    let value: String
//}
//
//struct ProductInfo: Decodable {
//    let name: String
//    let displayName: String?
//    let productCategory: String
//    let productLabels: [ProductLabel]?
//}
//
//struct ProductResult: Decodable {
//    let product: ProductInfo
//    let score: Float
//    let image: String
//}
//
//struct NormalizedVertex: Decodable {
//    let x: Float?
//    let y: Float?
//}
//
//struct BoundingPoly: Decodable {
//    let normalizedVertices: [NormalizedVertex]
//}
//
//struct ProductGroupedResult: Decodable {
//    let boundingPoly: BoundingPoly
//    let results: [ProductResult]
//}
//
//struct ProductSearchResults: Decodable {
//    let indexTime: String
//    let results: [ProductResult]
//    let productGroupedResults: [ProductGroupedResult]
//}
//
//struct ResponseItem: Decodable {
//    let productSearchResults: ProductSearchResults
//}
//
//struct ProductSearchAPIResponse: Decodable {
//    let responses: [ResponseItem]
//}
//
//// MARK: - A simpler one-product-at-a-time JSON response
//// The LLM will specify only ONE product ID and transform per iteration
//
//struct SinglePlacementResponse: Codable {
//    struct ProductTransform: Codable {
//        let id: Int
//        let position: Position
//        let orientation: Orientation
//    }
//    struct Position: Codable { let x: Float; let y: Float; let z: Float }
//    struct Orientation: Codable { let rotationX: Float; let rotationY: Float; let rotationZ: Float }
//
//    let product: ProductTransform
//}
//
//// MARK: - Extractor for numeric ID from Firebase image path
//
//func extractFirstNumber(from input: String) -> String? {
//    let components = input.split(separator: "/")
//    for component in components {
//        if component.hasPrefix("product_id") || component.hasPrefix("image") {
//            let number = component.filter { "0123456789".contains($0) }
//            if !number.isEmpty {
//                return String(number)
//            }
//        }
//    }
//    return nil
//}
//
//struct CaptureRoomView: View {
//    @Environment(\.presentationMode) var presentationMode
//    @State private var scnView: SCNView?
//    @State var selectedImage: UIImage
//    @Binding var searchResponse: [ProductGroupedResult]
//    @State private var isBottomSheetPresented = false
//
//    // Keep track of which products are already placed in the scene
//    @State private var placedFurniture = Set<Int>()
//
//    // Store your entire conversation with the LLM
//    @State private var chatHistory: [[String: String]] = [
//        [
//            "role": "system",
//            "content": """
//              You are a professional interior designer and an expert in 3D interior design with a strong math background. The room is 3.48 by 3.48.
//              In each iteration, choose exactly one product to place or reposition in the scene. Return JSON in this shape:
//
//              {
//                "product": {
//                  "id": 2,
//                  "position": { "x": 1.23, "y": 0.0, "z": 2.34 },
//                  "orientation": { "rotationX": 0.0, "rotationY": 90.0, "rotationZ": 0.0 }
//                }
//              }
//
//              where "id" is the integer ID of the product, and the position/orientation are the new transform. 
//              No extra text—just valid JSON. 
//            """
//        ]
//    ]
//
//    // For logging/diagnostics
//    @State private var lastLLMResponse: String = ""
//    private let iterationLimit = 20  // fallback limit so we don't loop forever
//
//    var body: some View {
//        NavigationView {
//            VStack {
//                ZStack {
//                    SCNViewContainer { view in
//                        scnView = view
//                    }
//                }
//            }
//            .navigationBarTitle("Capture Room", displayMode: .inline)
//            .navigationBarItems(
//                leading: Button(action: {
//                    presentationMode.wrappedValue.dismiss()
//                }) {
//                    HStack {
//                        Image(systemName: "chevron.left")
//                        Text("Back")
//                    }
//                },
//                trailing: Button("Products") {
//                    isBottomSheetPresented = true
//                }
//            )
//            .onAppear {
//                print("onAppear: searchResponse")
//                if !searchResponse.isEmpty {
//                    // Start the one-by-one placement logic
//                    placeFurnitureOneByOne(currentIteration: 1)
//                }
//            }
//            .sheet(isPresented: $isBottomSheetPresented) {
//                if !searchResponse.isEmpty {
//                    let allResults = searchResponse.compactMap { $0.results.first }
//                    ProductSheetView(searchResults: allResults)
//                        .presentationDetents([.medium, .large])
//                        .presentationDragIndicator(.visible)
//                } else {
//                    Text("No products yet.")
//                        .presentationDetents([.medium, .large])
//                        .presentationDragIndicator(.visible)
//                }
//            }
//        }
//        .navigationViewStyle(StackNavigationViewStyle())
//    }
//}
//
//// MARK: - Main Iteration Logic (One Product at a Time)
//extension CaptureRoomView {
//
//    func placeFurnitureOneByOne(currentIteration: Int) {
//        guard currentIteration <= iterationLimit else {
//            print("Reached iteration limit. Stopping.")
//            return
//        }
//
//        // If all furniture is placed, we could optionally ask the LLM
//        // if it wants to rearrange or finalize. For now, we'll just stop.
//        let totalFurnitureCount = searchResponse.count
//        
//
//        // 1) Ensure we have a scene
//        guard let scnView = self.scnView else { return }
//        if scnView.scene == nil {
//            scnView.scene = SCNScene()
//        }
//        setupCustomCamera(for: scnView)
//
//        // 2) Snapshot the current scene
//        guard let snapshot = takeSnapshot() else {
//            print("Failed to take snapshot.")
//            return
//        }
//
//        // 3) Ask LLM: "Which single product do you want to place or move next?"
//        requestPlacementForOneProduct(sceneSnapshot: snapshot, iteration: currentIteration) { placement in
//            guard let placement = placement else {
//                print("No valid single-product placement from LLM. Stopping.")
//                return
//            }
//
//            // 4) Download or load this product if not already loaded
//            let productID = placement.product.id
//            self.loadModelIfNeeded(productID: productID) {
//                // 5) Apply the transform
//                self.applyTransform(placement.product)
//
//                // Mark it placed
//                self.placedFurniture.insert(productID)
//
//                // 6) Proceed to the next iteration
//                self.placeFurnitureOneByOne(currentIteration: currentIteration + 1)
//            }
//        }
//    }
//
//    // Request from the LLM a *single* product transform in JSON
//    func requestPlacementForOneProduct(
//        sceneSnapshot: UIImage, iteration: Int,
//        completion: @escaping (SinglePlacementResponse?) -> Void
//    ) {
//        guard let apiKey = getOpenAIAPIKey() else {
//            completion(nil)
//            return
//        }
//
//        // Prepare base64 snapshot
//        guard let snapData = sceneSnapshot.jpegData(compressionQuality: 0.3) else {
//            completion(nil)
//            return
//        }
//        var snapBase64 = snapData.base64EncodedString()
//        
//        // Build an array describing each product:
//        // whether it is placed or not, etc.
//        let productEntries = searchResponse.enumerated().compactMap {
//            (index, groupedResult) -> [String: Any]? in
//            guard let topProduct = groupedResult.results.first else { return nil }
//            guard let extractedNumber = extractFirstNumber(from: topProduct.image) else { return nil }
//
//            // Is this product placed?
//            let isPlaced = placedFurniture.contains(index)
//
//            return [
//                "id": index,
//                "name": topProduct.product.displayName ?? "furniture",
//                "alreadyPlaced": isPlaced,
//                "number": extractedNumber
//            ]
//        }
//        
//        if (iteration < 6){
//            snapBase64 = ""
//        }
//
//        // 1) Add user prompt to chatHistory
//        let userPrompt = """
//        Here is the current 3D scene snapshot (base64): data:image/jpeg;base64,\(snapBase64)
//
//        Products data (JSON):
//        \(jsonString(from: productEntries))
//
//        Some products may already be placed. 
//        Choose exactly one product to place or move. Return valid JSON:
//
//        {
//          "product": {
//            "id": <the chosen product id>,
//            "position": {"x": 0.00, "y": 0.00, "z": 0.00},
//            "orientation": {"rotationX": 0.00, "rotationY": 0.00, "rotationZ": 0.00}
//          }
//        }
//
//        No extra text or code fences.
//        """
//        chatHistory.append([
//            "role": "user",
//            "content": userPrompt
//        ])
//
//        // 2) Send entire chatHistory
//        let requestBody: [String: Any] = [
//            "model": "gpt-4o",
//            "messages": chatHistory,
//            "max_tokens": 1000,
//            "temperature": 0.7
//        ]
//
//        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
//            completion(nil)
//            return
//        }
//
//        var request = URLRequest(url: url)
//        request.httpMethod = "POST"
//        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
//        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
//
//        do {
//            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
//        } catch {
//            print("Error encoding JSON for request: \(error)")
//            completion(nil)
//            return
//        }
//
//        let task = URLSession.shared.dataTask(with: request) { data, _, error in
//            if let error = error {
//                print("Error requesting single placement: \(error)")
//                completion(nil)
//                return
//            }
//            guard let data = data else {
//                print("No data from LLM.")
//                completion(nil)
//                return
//            }
//
//            // Optionally log raw response
//            if let debugStr = String(data: data, encoding: .utf8) {
//                print("LLM single-product response:\n\(debugStr)")
//                self.lastLLMResponse = debugStr
//            }
//
//            // Decode the top-level OpenAI structure
//            do {
//                let response = try JSONDecoder().decode(OpenAIChatResponse.self, from: data)
//                if let contentString = response.choices.first?.message.content {
//                    // Append to chat
//                    DispatchQueue.main.async {
//                        self.chatHistory.append([
//                            "role": "assistant",
//                            "content": contentString
//                        ])
//                    }
//                    // Now parse it into SinglePlacementResponse
//                    do {
//                        let placedResp = try JSONDecoder().decode(SinglePlacementResponse.self,
//                            from: Data(contentString.utf8))
//                        completion(placedResp)
//                    } catch {
//                        print("Failed to decode SinglePlacementResponse: \(error)")
//                        completion(nil)
//                    }
//                } else {
//                    print("No content in choices.")
//                    completion(nil)
//                }
//            } catch {
//                print("Failed to decode top-level OpenAIChatResponse: \(error)")
//                completion(nil)
//            }
//        }
//        task.resume()
//    }
//}
//
//// MARK: - SceneKit Helpers
//extension CaptureRoomView {
//    func getOpenAIAPIKey() -> String? {
//        return Constants.OPENAI_API_KEY
//    }
//
//    func jsonString(from object: Any) -> String {
//        guard let data = try? JSONSerialization.data(withJSONObject: object, options: []),
//              let json = String(data: data, encoding: .utf8) else {
//            return "{}"
//        }
//        return json
//    }
//
//    func setupCustomCamera(for scnView: SCNView) {
//        guard let scene = scnView.scene else { return }
//
//        // Remove existing cameras if needed
//        for child in scene.rootNode.childNodes where child.camera != nil {
//            child.removeFromParentNode()
//        }
//
//        let cameraNode = SCNNode()
//        cameraNode.camera = SCNCamera()
//        cameraNode.position = SCNVector3(0, 5, 5)
//        cameraNode.eulerAngles = SCNVector3(Float.pi / 4, 0, 0)
//        scene.rootNode.addChildNode(cameraNode)
//    }
//
//    func takeSnapshot() -> UIImage? {
//        guard let scnView = self.scnView else { return nil }
//        guard scnView.scene != nil else { return nil }
//
//        setupCustomCamera(for: scnView)
//        let rawSnapshot = scnView.snapshot()
//
//        // Optionally resize
//        let targetSize = CGSize(width: 300, height: 300)
//        UIGraphicsBeginImageContextWithOptions(targetSize, false, 1.0)
//        rawSnapshot.draw(in: CGRect(origin: .zero, size: targetSize))
//        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
//        UIGraphicsEndImageContext()
//        return resizedImage
//    }
//
//    // Download model if not already downloaded. Then load or do nothing
//    func loadModelIfNeeded(productID: Int, completion: @escaping () -> Void) {
//        guard productID < searchResponse.count, productID >= 0 else {
//            completion()
//            return
//        }
//        let groupedResult = searchResponse[productID]
//        guard let topProduct = groupedResult.results.first else {
//            completion()
//            return
//        }
//        guard let extractedNumber = extractFirstNumber(from: topProduct.image) else {
//            completion()
//            return
//        }
//
//        let modelFileName = "\(extractedNumber).usdz"
//        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
//        let localURL = documentsDirectory.appendingPathComponent(modelFileName)
//
//        if FileManager.default.fileExists(atPath: localURL.path) {
//            // Already downloaded -> just add node if needed
//            addNodeIfNeeded(from: localURL, index: productID)
//            completion()
//        } else {
//            // Download from Firebase
//            let storageRef = Storage.storage(url: "gs://temporal-ground-437002-b8.firebasestorage.app").reference()
//            let modelRef = storageRef.child("onehundred").child(modelFileName)
//
//            modelRef.write(toFile: localURL) { _, error in
//                if let error = error {
//                    print("Error downloading file: \(error.localizedDescription)")
//                } else {
//                    print("Downloaded model to: \(localURL)")
//                }
//                self.addNodeIfNeeded(from: localURL, index: productID)
//                completion()
//            }
//        }
//    }
//
//    func addNodeIfNeeded(from localURL: URL, index: Int) {
//        guard let scnView = self.scnView else { return }
//        guard let scene = scnView.scene else {
//            scnView.scene = SCNScene()
//            return
//        }
//
//        let nodeName = "model_\(index)"
//        if scene.rootNode.childNode(withName: nodeName, recursively: true) == nil {
//            do {
//                let modelScene = try SCNScene(url: localURL, options: nil)
//                let containerNode = SCNNode()
//                for child in modelScene.rootNode.childNodes {
//                    containerNode.addChildNode(child)
//                }
//                containerNode.name = nodeName
//                scene.rootNode.addChildNode(containerNode)
//                print("Added node for product \(index)")
//            } catch {
//                print("Error loading scene from \(localURL): \(error)")
//            }
//        } else {
//            print("Node for product \(index) already exists in scene.")
//        }
//    }
//
//    // Apply transform to a product in the scene
//    func applyTransform(_ transformData: SinglePlacementResponse.ProductTransform) {
//        guard let scnView = self.scnView else { return }
//        let nodeName = "model_\(transformData.id)"
//
//        let newTransform: SCNMatrix4 = {
//            var t = SCNMatrix4Identity
//            // position
//            t = SCNMatrix4Translate(t, -transformData.position.x,
//                                       transformData.position.y,
//                                       transformData.position.z)
//            // rotations
//            t = SCNMatrix4Rotate(t, transformData.orientation.rotationX * .pi/180, 1, 0, 0)
//            t = SCNMatrix4Rotate(t, transformData.orientation.rotationY * .pi/180, 0, 1, 0)
//            t = SCNMatrix4Rotate(t, transformData.orientation.rotationZ * .pi/180, 0, 0, 1)
//            // pitch furniture upright
//            t = SCNMatrix4Rotate(t, -90 * .pi/180, 1, 0, 0)
//            return t
//        }()
//
//        DispatchQueue.main.async {
//            if let modelNode = scnView.scene?.rootNode.childNode(withName: nodeName, recursively: true) {
//                modelNode.transform = newTransform
//                modelNode.scale = SCNVector3(0.75, 0.75, 0.75)
//                print("Updated transform for product \(transformData.id)")
//            } else {
//                print("Node not found for product \(transformData.id). Possibly not added yet.")
//            }
//        }
//    }
//}
//
//// MARK: - Bottom Sheet for product listings
//
//struct ProductSheetView: View {
//    let searchResults: [ProductResult]
//
//    var body: some View {
//        ScrollView {
//            VStack(spacing: 16) {
//                ForEach(Array(searchResults.enumerated()), id: \.offset) { index, result in
//                    ProductCardView(product: result, index: index)
//                }
//            }
//            .padding()
//        }
//    }
//}
//
//struct ProductCardView: View {
//    var product: ProductResult
//    var index: Int
//
//    var body: some View {
//        HStack {
//            if let imageNumber = extractFirstNumber(from: product.image) {
//                RemoteImage(name: "\(imageNumber).png")
//                    .aspectRatio(contentMode: .fit)
//                    .frame(width: 100, height: 100)
//                    .cornerRadius(10)
//            } else {
//                Rectangle()
//                    .foregroundColor(Color(UIColor.systemGray5))
//                    .frame(width: 100, height: 100)
//                    .cornerRadius(10)
//                    .overlay(
//                        Text("No Image")
//                            .foregroundColor(.white)
//                    )
//            }
//
//            VStack(alignment: .leading, spacing: 5) {
//                Text(product.product.displayName ?? "Unnamed Product")
//                    .font(.headline)
//                    .lineLimit(1)
//                Text("Category: \(product.product.productCategory)")
//                    .font(.subheadline)
//                    .lineLimit(1)
//                Text(String(format: "Score: %.2f", product.score))
//                    .font(.subheadline)
//            }
//            Spacer()
//        }
//        .padding()
//        .background(Color(UIColor.secondarySystemBackground))
//        .cornerRadius(10)
//        .shadow(radius: 5)
//    }
//}
