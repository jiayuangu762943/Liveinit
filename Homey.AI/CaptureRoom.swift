//
//  CaptureRoom.swift
//  YourAppName
//
//  Created by Your Name on Date.
//

import SwiftUI
import SceneKit
import UIKit
import FirebaseStorage

// MARK: - Data Models for the Provided JSON Structure

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

// MARK: - SwiftUI View

struct CaptureRoomView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var scnView: SCNView?
    @State var selectedImage: UIImage
    @Binding var searchResponse: [ProductGroupedResult]
    @State private var isBottomSheetPresented = false
    @State private var isSceneInitialized = false
    
    var body: some View {
        NavigationView {
            VStack {
                ZStack {
                    SCNViewContainer { view in
                        scnView = view
                        if !isSceneInitialized {
                            clearScene()
                            isSceneInitialized = true
                        }
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
                // On appear, load models if we have grouped results
                print("onAppear: searchResponse")
                print(searchResponse)
                if !searchResponse.isEmpty {
                    
                    loadModelsIntoScene()
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
            if let objects = (scnView.scene?.rootNode.childNode(withName: "Object_grp", recursively: true)) {
                objects.removeFromParentNode()
            }
        }
    }
    
    // MARK: - Load Models into Scene
    // We use top product from each boundingPoly in productGroupedResults to load models
    func loadModelsIntoScene() {
        print("loadModelsIntoScene: \(searchResponse.count)")
       let productEntries = searchResponse.enumerated().compactMap { (index, groupedResult) -> (Int, ProductResult, BoundingPoly)? in
           guard let topProduct = groupedResult.results.first else { return nil }
           return (index, topProduct, groupedResult.boundingPoly)
       }
        
        // Create a dispatch group to manage async tasks
        let dispatchGroup = DispatchGroup()
        var downloadedIndexes: [Int] = []
        for (index, product, _) in productEntries {
            dispatchGroup.enter()
            downloadModel(index: index, product: product) {
                downloadedIndexes.append(index)
                dispatchGroup.leave()
            }
        }

        dispatchGroup.notify(queue: .main, execute:{
            // Now that all models are downloaded, call once to get all transformations
            let productsData: [[String: Any]] = productEntries.map { (index, product, poly) in
                let vertices = poly.normalizedVertices.map { ["x": $0.x ?? 0, "y": $0.y ?? 0] }
                return [
                  "id": index,
                  "name": product.product.displayName ?? "furniture",
                  "boundingPoly": vertices
                ]
            }

            self.getAllPositionsAndOrientations(productsData: productsData) { transformDict in
                // Apply the transforms
                for (index, transform) in transformDict {
                    // We already downloaded the model file at "index"
                    let localURL = self.localURLForIndex(index)
                    self.addModelToScene(from: localURL, transform: transform, index: index)
                }
            }
        })
    }
    func downloadModel(index: Int, product: ProductResult, completion: @escaping () -> Void) {
        let modelFileName = "\(index + 1).usdz"
        let storageRef = Storage.storage(url: "gs://temporal-ground-437002-b8.firebasestorage.app").reference()
        let modelRef = storageRef.child("onehundred").child(modelFileName)
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        let localURL = documentsDirectory?.appendingPathComponent(modelFileName)

        modelRef.write(toFile: localURL!) { url, error in
            if let error = error {
                print("Error downloading file: \(error.localizedDescription)")
            } else {
                print("Downloaded model to: \(localURL!)")
            }
            completion()
        }
    }
//    
//    func downloadAndAddModel(product: ProductResult, boundingPoly: BoundingPoly, index: Int) {
//        // Convert product name to a stable identifier to name the model file, e.g. "1.usdz", "2.usdz", ...
//        // For demonstration, we just use index for naming.
//        print("downloadAndAddModel")
//        let modelFileName = "\(index + 1).usdz"
//        
//        // TODO: Adjust the Firebase storage path as needed. For demonstration:
//        let storageRef = Storage.storage(url: "gs://temporal-ground-437002-b8.firebasestorage.app").reference()
//        let modelRef = storageRef.child("onehundred").child(modelFileName)
//        
//        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
//        let localURL = documentsDirectory?.appendingPathComponent(modelFileName)
//        
//        guard let localURL = localURL else {
//            print("Could not create local URL for model.")
//            return
//        }
//        
//        // Download the model file
//        modelRef.write(toFile: localURL) { url, error in
//            if let error = error {
//                print("Error downloading file: \(error.localizedDescription)")
//            } else {
//                print("Downloaded model to: \(localURL)")
//                // After downloading, get position and orientation from OpenAI
//                self.getPositionAndOrientation(for: product, boundingPoly: boundingPoly) { result in
//                    switch result {
//                    case .success(let transform):
//                        self.addModelToScene(from: localURL, transform: transform, index: index)
//                    case .failure(let error):
//                        print("Error getting position and orientation: \(error.localizedDescription)")
//                        // Proceed with a default transform if needed
//                        let defaultTransform = SCNMatrix4Identity
//                        self.addModelToScene(from: localURL, transform: defaultTransform, index: index)
//                    }
//                }
//            }
//        }
//    }
    
    func parseBulkResponse(data: Data) throws -> [Int: SCNMatrix4] {
        let decoder = JSONDecoder()
        let openAIResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String:Any]
        
        // Extract the content from the "choices"
        guard
          let choices = openAIResponse?["choices"] as? [[String: Any]],
          let message = choices.first?["message"] as? [String:Any],
          let content = message["content"] as? String,
          let contentData = content.data(using: .utf8)
        else {
            throw NSError(domain: "Missing or invalid content", code: -1, userInfo: nil)
        }

        let bulkResponse = try decoder.decode(BulkResponse.self, from: contentData)
        
        var result: [Int: SCNMatrix4] = [:]
        for product in bulkResponse.products {
            var transform = SCNMatrix4Identity
            transform = SCNMatrix4Translate(transform, product.position.x, product.position.y, product.position.z)
            transform = SCNMatrix4Rotate(transform, product.orientation.rotationX * .pi / 180, 1, 0, 0)
            transform = SCNMatrix4Rotate(transform, product.orientation.rotationY * .pi / 180, 0, 1, 0)
            transform = SCNMatrix4Rotate(transform, product.orientation.rotationZ * .pi / 180, 0, 0, 1)
            result[product.id] = transform
        }
        return result
    }
    
    
    func localURLForIndex(_ index: Int) -> URL {
        let modelFileName = "\(index + 1).usdz"
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsDirectory.appendingPathComponent(modelFileName)
    }
    func jsonString(from object: Any) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: object, options: []),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }
    
    
    func getAllPositionsAndOrientations(productsData: [[String:Any]], completion: @escaping ([Int: SCNMatrix4]) -> Void) {
        guard let apiKey = getOpenAIAPIKey() else {
            completion([:])
            return
        }

        let prompt = """
        You are a professional interior designer. I have several products with bounding polygons in a room scene. For each product, provide the optimal 3D position and orientation (in degrees).

        Input (JSON):
        \(jsonString(from: productsData)) // Convert dictionary to JSON string

        For each product in the "products" array, return a JSON with the same structure:
        {
          "products": [
            {
              "id": 0,
              "position": { "x":1.0, "y":0.0, "z":-2.0 },
              "orientation": { "rotationX":0, "rotationY":90, "rotationZ":0 }
            },
            ...
          ]
        }

        The furniture should remain upright (no pitch rotation).
        """
        
        var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
          "model": "gpt-4o",
          "messages": [
             ["role": "user", "content": prompt]
          ],
          "max_tokens": 500,
          "temperature": 0.7
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
          if let error = error {
             print("Error: \(error)")
             completion([:])
             return
          }
          guard let data = data else {
             print("No data received")
             completion([:])
             return
          }
          
          // Parse the response similar to before, but now expecting a JSON with multiple products
          if let responseString = String(data: data, encoding: .utf8) {
              print("OpenAI Bulk Response: \(responseString)")
          }

          // Decode the JSON and convert each product's position/orientation into SCNMatrix4
          do {
              let transformDict = try self.parseBulkResponse(data: data)
              completion(transformDict)
          } catch {
              print("Failed to parse bulk response: \(error)")
              completion([:])
          }
        }
        task.resume()
    }
    
    // MARK: - Get Position and Orientation (with boundingPoly info)
    func getPositionAndOrientation(for product: ProductResult, boundingPoly: BoundingPoly, completion: @escaping (Result<SCNMatrix4, Error>) -> Void) {
        guard let base64Image = imageToBase64(self.selectedImage) else {
            completion(.failure(NSError(domain: "Image encoding error", code: -1, userInfo: nil)))
            return
        }
        
        // Construct the prompt with bounding polygon details
        let polyDescription = boundingPoly.normalizedVertices.enumerated().map { (i, v) -> String in
            "Vertex \(i): x=\(v.x ?? 0), y=\(v.y ?? 0)"
        }.joined(separator: "; ")
        
        let productName = (product.product.displayName?.trimmingCharacters(in: .whitespaces).isEmpty == false) ? product.product.displayName! : "furniture"
        let prompt = """
        You are a professional interior designer, please provide the optimal 3D position and orientation (in degrees) for placing a '\(productName)' in a room scene. The normalized bounding polygon for the detected product is: \(polyDescription) with (0,0) being the top left and (1,1) being the bottom right corner of the image. 
        Return the position as x, y, z coordinates and orientation as rotationX, rotationY, rotationZ in degrees.
        Use this output format:
        position: x=1.0, y=0.0, z=-2.0
        Orientation: rotationX=0, rotationY=90, rotationZ=0.
        The furniture should remain upright (no pitch rotation).
        """
        
        guard let apiKey = getOpenAIAPIKey() else {
            completion(.failure(NSError(domain: "API key not found", code: -1, userInfo: nil)))
            return
        }
        
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestBody: [String: Any] = [
            "model": "gpt-4o",
            "messages": [
                ["role": "user", "content": prompt],
                ["role": "user", "content": "Image (Base64): \(base64Image)"]
            ],
            "max_tokens": 150,
            "n": 1,
            "temperature": 0.7
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody, options: [])
        } catch {
            completion(.failure(error))
            return
        }
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "No data received", code: -1, userInfo: nil)))
                return
            }
            
            // Print the raw response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("OpenAI Raw Response: \(responseString)")
            }
            
            do {
                let transform = try self.parsePositionAndOrientation(from: data)
                print("Received transform from OpenAI:", transform)
                completion(.success(transform))
            } catch {
                completion(.failure(error))
            }
        }
        task.resume()
    }
    
    func imageToBase64(_ image: UIImage) -> String? {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            print("Failed to convert image to JPEG format")
            return nil
        }
        return imageData.base64EncodedString()
    }
    
    func parsePositionAndOrientation(from data: Data) throws -> SCNMatrix4 {
        let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]

        if let choices = jsonResponse?["choices"] as? [[String: Any]],
           let message = choices.first?["message"] as? [String: Any],
           let content = message["content"] as? String {
            let transform = self.transformFromString(content)
            return transform
        } else {
            throw NSError(domain: "Failed to parse position and orientation", code: -1, userInfo: nil)
        }
    }

    func transformFromString(_ string: String) -> SCNMatrix4 {
        var position = SCNVector3(0, 0, 0)
        var rotation = SCNVector3(0, 0, 0)

        let positionPattern = "position:\\s*x=([-\\d\\.]+),\\s*y=([-\\d\\.]+),\\s*z=([-\\d\\.]+)"
        let rotationPattern = "Orientation:\\s*rotationX=([-\\d\\.]+),\\s*rotationY=([-\\d\\.]+),\\s*rotationZ=([-\\d\\.]+)"

        if let positionRegex = try? NSRegularExpression(pattern: positionPattern, options: []),
           let match = positionRegex.firstMatch(in: string, options: [], range: NSRange(location: 0, length: string.count)) {
            if let xRange = Range(match.range(at: 1), in: string),
               let yRange = Range(match.range(at: 2), in: string),
               let zRange = Range(match.range(at: 3), in: string) {
                position.x = Float(string[xRange]) ?? 0
                position.y = Float(string[yRange]) ?? 0
                position.z = Float(string[zRange]) ?? 0
            }
        }

        if let rotationRegex = try? NSRegularExpression(pattern: rotationPattern, options: []),
           let match = rotationRegex.firstMatch(in: string, options: [], range: NSRange(location: 0, length: string.count)) {
            if let xRange = Range(match.range(at: 1), in: string),
               let yRange = Range(match.range(at: 2), in: string),
               let zRange = Range(match.range(at: 3), in: string) {
                rotation.x = Float(string[xRange]) ?? 0
                rotation.y = Float(string[yRange]) ?? 0
                rotation.z = Float(string[zRange]) ?? 0
            }
        }

        var transform = SCNMatrix4Identity
        transform = SCNMatrix4Translate(transform, position.x, position.y, position.z)
        transform = SCNMatrix4Rotate(transform, rotation.x * .pi / 180, 1, 0, 0)
        transform = SCNMatrix4Rotate(transform, rotation.y * .pi / 180, 0, 1, 0)
        transform = SCNMatrix4Rotate(transform, rotation.z * .pi / 180, 0, 0, 1)

        return transform
    }

    // MARK: - Add Model to Scene
    func addModelToScene(from localURL: URL, transform: SCNMatrix4, index: Int) {
        DispatchQueue.main.async {
            guard let scnView = self.scnView else { return }

            if FileManager.default.fileExists(atPath: localURL.path) {
                do {
                    let modelScene = try SCNScene(url: localURL, options: nil)
                    let modelNode = SCNNode()

                    for child in modelScene.rootNode.childNodes {
                        modelNode.addChildNode(child)
                    }
                    
                    
                    let upward = SCNMatrix4Rotate(transform, -Float.pi/2, 1, 0, 0)
                    // Apply the transform and scale
                    modelNode.transform = upward
                    modelNode.scale = SCNVector3(1, 1, 1)

                    // Position model on the floor by default (assuming y = -1 is the floor)
                    modelNode.position.y = -1

                    scnView.scene?.rootNode.addChildNode(modelNode)
                    print("Successfully added model to scene")
                    
                } catch {
                    print("Error loading model: \(error.localizedDescription)")
                }
            } else {
                print("Model file does not exist at path: \(localURL.path)")
            }
        }
    }

    // MARK: - Get OpenAI API Key
    func getOpenAIAPIKey() -> String? {
        return Constants.OPENAI_API_KEY
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
            RemoteImage(name: product.image)
                .aspectRatio(contentMode: .fit)
                .frame(width: 100, height: 100)
                .cornerRadius(10)

            VStack(alignment: .leading, spacing: 5) {
                Text(product.product.displayName ?? "")
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


