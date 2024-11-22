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

// MARK: - CaptureRoomView (SwiftUI)

struct CaptureRoomView: View {
    @Environment(\.presentationMode) var presentationMode
    @State private var scnView: SCNView?
    @State var searchResults: [ProductSearchResult] = [
        ProductSearchResult(productId: "product01", score: 0.8, imageUri: "gs://homey-test1/images/simple_wooden_table.png", displayName: "wooden_table", category: "table"),
    ]
    @State private var isBottomSheetPresented = false
    @State private var isSceneInitialized = false
    @State var selectedImage: UIImage

    var body: some View {
        NavigationView {
            VStack {
                ZStack {
                    // SceneKit View
                    SCNViewContainer { view in
                        scnView = view  // Setup the SCNView when ready
                        print("width: \(scnView?.bounds.width ?? 0), height = \(scnView?.bounds.height ?? 0)")
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
                    // Dismiss the view
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
                print("Received searchResults: \(searchResults)")
                isBottomSheetPresented = true
                loadModelsIntoScene()
            }
            .sheet(isPresented: $isBottomSheetPresented) {
                ProductSheetView(searchResults: searchResults)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())

        
    }
    
    // Function to clear the scene
    func clearScene() {
        if let scnView = self.scnView {
            if scnView.scene == nil {
                scnView.scene = SCNScene()
            }
            let rootNode = scnView.scene!.rootNode

            if let objects = (scnView.scene?.rootNode.childNode(withName: "Object_grp", recursively: true)) {
                objects.removeFromParentNode()
            }
        }
    }

    // MARK: - Load Models into Scene

    func loadModelsIntoScene() {
//        for (i, product) in self.searchResults.enumerated()  {
//            downloadAndAddModel(product: product, index: i)
//        }
        
        let transforms: [SCNMatrix4] = [
                // Sofa
                SCNMatrix4Mult(
                    SCNMatrix4MakeTranslation(-2.0, -1.0, -2.8),
                    SCNMatrix4MakeRotation(Float.pi, 0, 1, 0)
                ),
                
                // accent Chair
//                SCNMatrix4Mult(
                SCNMatrix4MakeTranslation(-1.2, -1.0, 4),
//                    SCNMatrix4MakeRotation(Float.pi / 4, 0, 1, 0)
//                ),
                
                // accent Chair
//                SCNMatrix4Mult(
                SCNMatrix4MakeTranslation(-2.8, -1.0, 4),
//                    SCNMatrix4MakeRotation(3 * Float.pi / 4, 0, 1, 0)
//                ),
                
                // Coffee Table
                SCNMatrix4MakeTranslation(-2.0, -1.0, 4.7), // No rotation needed
                
        ]
        for i in 0...3 {
            addModelToScene(from: URL(fileURLWithPath: ""), transform: transforms[i], index: i)
        }
    }

    func downloadAndAddModel(product: ProductSearchResult, index: Int) {
        let storageRef = Storage.storage(url: "gs://temporal-ground-437002-b8.firebasestorage.app").reference()
//        let modelRef = storageRef.child(product.modelStoragePath)
        //TODO
        let modelRef = product.category == "table" ? storageRef.child("/table/Simple_Wood_Table.usdz") :  storageRef.child("/chair/High-poly_Modern_Wood_Chair.usdz")

        // Create local filesystem URL
        let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        let localURL = documentsDirectory?.appendingPathComponent("\(product.displayName).usdz")
            
        guard let localURL = localURL else {
            print("Could not create local URL")
            return
        }

        // Download the model file
        let downloadTask = modelRef.write(toFile: localURL) { url, error in
            if let error = error {
                print("Error downloading file: \(error.localizedDescription)")
            } else {
                print("Downloaded model to: \(localURL)")
                // After downloading, get position and orientation
                self.getPositionAndOrientation(for: product) { result in
                    switch result {
                    case .success(let transform):
                        // Add the model to the scene with the obtained transform
                        self.addModelToScene(from: localURL, transform: transform, index: index)
                    case .failure(let error):
                        print("Error getting position and orientation: \(error.localizedDescription)")
                        // Optionally, proceed with a default transform
                        let defaultTransform = SCNMatrix4Identity
                        self.addModelToScene(from: localURL, transform: defaultTransform, index: index)
                    }
                }
                
            }
        }
    }

    // MARK: - Get Position and Orientation

    func getPositionAndOrientation(for product: ProductSearchResult, completion: @escaping (Result<SCNMatrix4, Error>) -> Void) {
        // Prepare your prompt or data for the API
        guard let base64Image = imageToBase64(self.selectedImage) else {
                completion(.failure(NSError(domain: "Image encoding error", code: -1, userInfo: nil)))
                return
        }
        
        let prompt = "As an interior designer, please provide the optimal position and orientation (in degrees) for placing a '\(product.displayName)' in a 3D room scene. Return the position as x, y, z coordinates and orientation as rotationX, rotationY, rotationZ in degrees. Use this output format:  position: x=1.0, y=0.0, z=-2.0\nOrientation: rotationX=0, rotationY=90, rotationZ=0. Important: the furniture is always upright in the scene so there is no rotation in the pitch axis."

        // Set up the API request
        guard let apiKey = getOpenAIAPIKey() else {
            completion(.failure(NSError(domain: "API key not found", code: -1, userInfo: nil)))
            return
        }
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        // Prepare the request body
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

        // Perform the API call
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            guard let data = data else {
                completion(.failure(NSError(domain: "No data received", code: -1, userInfo: nil)))
                return
            }

            // Parse the response to extract position and orientation
            do {
                let transform = try self.parsePositionAndOrientation(from: data)
                print("get openai positions", transform)
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
        // Parse the JSON response
        let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]

        // Extract the assistant's reply
        if let choices = jsonResponse?["choices"] as? [[String: Any]],
           let message = choices.first?["message"] as? [String: Any],
           let content = message["content"] as? String {
            // Parse the content to extract position and orientation
            let transform = self.transformFromString(content)
            return transform
        } else {
            throw NSError(domain: "Failed to parse position and orientation", code: -1, userInfo: nil)
        }
    }

    func transformFromString(_ string: String) -> SCNMatrix4 {
        // Example expected format from the assistant:
        // "Position: x=1.0, y=0.0, z=-2.0\nOrientation: rotationX=0, rotationY=90, rotationZ=0"

        var position = SCNVector3(0, 0, 0)
        var rotation = SCNVector3(0, 0, 0)

        // Use regular expressions to extract values
        let positionPattern = "Position:\\s*x=([-\\d\\.]+),\\s*y=([-\\d\\.]+),\\s*z=([-\\d\\.]+)"
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

        // Create a transform matrix
        var transform = SCNMatrix4Identity
        transform = SCNMatrix4Translate(transform, position.x, position.y, position.z)
        transform = SCNMatrix4Rotate(transform, rotation.x * .pi / 180, 1, 0, 0)
        transform = SCNMatrix4Rotate(transform, -1 * .pi / 180, 0, 1, 0)
        transform = SCNMatrix4Rotate(transform, rotation.z * .pi / 180, 0, 0, 1)

        return transform
    }

    // MARK: - Add Model to Scene
    private func printChildNodes(node: SCNNode, indent: String = "") {
        print("\(indent)Node name: \(node.name ?? "Unnamed")")
        for childNode in node.childNodes {
            printChildNodes(node: childNode, indent: "\(indent)  ")
        }
    }
    
    func addModelToScene(from localURL: URL, transform: SCNMatrix4, index: Int) {
        let names = ["white_sofa", "accent_chair", "accent_chair",  "coffee_table"]
        DispatchQueue.main.async {
            guard let scnView = self.scnView else { return }
//
//            if FileManager.default.fileExists(atPath: localURL.path) {
        print("addModelToScene2")

                print("add mode lto scene \(localURL.path)")
                do {
//                    let modelScene = try SCNScene(url: localURL, options: nil)
                    let modelScene = SCNScene(named: "\(names[index]).usdz")!
                    // Create a node to hold the model
                    let modelNode = SCNNode()
                    
                    // Add all child nodes from the model scene to the model node
                    for child in modelScene.rootNode.childNodes {
                        modelNode.addChildNode(child)
                    }
                    
                    //TODO: Convert degrees to radians
                    
                    // Apply the transform
                    modelNode.transform = transform
                    
                    // Apply rotation if needed
                    
//                    tableNode.position = SCNVector3(0, 0, -1.5) // Position the table near the wall
//                    tableNode.eulerAngles = SCNVector3(0, 0, 0)
//                    chairNode.position = SCNVector3(0, 0, -1) // Place the chair in front of the table
//                    chairNode.eulerAngles = SCNVector3(0, Float.pi / 8, 0)
//                
//                    let rotationAngle = Float(-90 * Double.pi / 180)
                    
                    
                    
//                    modelNode.position = SCNVector3(-2, -1, 4)
                    
//                    modelNode.eulerAngles = index == 0 ? SCNVector3(0, Float.pi / 8, 0) : SCNVector3(0, Float.pi / 4, 0)
                    // (X: 0 degrees, Y: 90 degrees, Z: 0 degrees)


//                    modelNode.transform = SCNMatrix4Rotate(modelNode.transform, rotationAngle, 1, 0, 0)
                    

//                    modelNode.eulerAngles = SCNVector3(Float.pi / 4, Float.pi / 4, 0) // (X: 90 degrees, Y: 45 degrees, Z: 0 degrees)

                    // Apply scaling
                    modelNode.scale =  SCNVector3(1, 1, 1)
                    
                    // Position the model on the floor
                    modelNode.position.y = -1
                    
                    // Ensure scene exists
//                    if scnView.scene == nil {
//                        scnView.scene = SCNScene()
//                    }
                    
                    // Add the model node to the scene
                    scnView.scene?.rootNode.addChildNode(modelNode)
                    print("Successfully added model to scene")
                    
                } catch {
                    print("Error loading model: \(error.localizedDescription)")
                }
//            } else {
//                print("Model file does not exist at path: \(localURL.path)")
//            }
        }
    }

    // MARK: - Get OpenAI API Key

    func getOpenAIAPIKey() -> String? {
        // Implement secure retrieval of your OpenAI API key
        // For example, read from a configuration file or keychain
        return Constants.OPENAI_API_KEY
    }
}

// MARK: - ProductSheetViewController (UIViewController)

class ProductSheetViewController: UIViewController {
    private let searchResults: [ProductSearchResult]

    init(searchResults: [ProductSearchResult]) {
        self.searchResults = searchResults
        super.init(nibName: nil, bundle: nil)
        configureSheetPresentation()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // Configure the sheet presentation
    func configureSheetPresentation() {
        modalPresentationStyle = .pageSheet
        if let sheet = sheetPresentationController {
            // Define custom detent
            let smallId = UISheetPresentationController.Detent.Identifier("small")
            let smallDetent = UISheetPresentationController.Detent.custom(identifier: smallId) { context in
                return 100 // Height of the initial bar at the bottom
            }

            // Set detents
            sheet.detents = [smallDetent, .medium(), .large()]
            sheet.prefersGrabberVisible = true
            sheet.preferredCornerRadius = 16
            sheet.selectedDetentIdentifier = smallId // Start at small detent
            sheet.largestUndimmedDetentIdentifier = .large
            sheet.prefersScrollingExpandsWhenScrolledToEdge = false
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // Use SwiftUI View inside UIKit
        let hostingController = UIHostingController(rootView: ProductSheetView(searchResults: searchResults))
        addChild(hostingController)
        view.addSubview(hostingController.view)
        hostingController.didMove(toParent: self)

        // Set constraints for the SwiftUI view to fill the parent controller
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor)
        ])

        view.backgroundColor = .white
    }
}

// MARK: - ProductSheetView (SwiftUI)

struct ProductSheetView: View {
    let searchResults: [ProductSearchResult]

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                ForEach(searchResults) { result in
                    ProductCardView(product: result)
                        .onTapGesture {
                            // Handle product selection if needed
                        }
                }
            }
            .padding()
        }
    }
}

// MARK: - ProductCardView (SwiftUI)

struct ProductCardView: View {
    var product: ProductSearchResult

    var body: some View {
        HStack {
            // Load the image from the URL using RemoteImage
            RemoteImage(name: product.imageUri)
                .aspectRatio(contentMode: .fit)
                .frame(width: 100, height: 100)
                .cornerRadius(10)

            VStack(alignment: .leading, spacing: 5) {
                Text(product.displayName)
                    .font(.headline)
                    .lineLimit(1)
                Text("Product ID: \(product.parsedProductId)")
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




// MARK: - ImageCache (Singleton)

class ImageCache {
    static let shared = ImageCache()
    private init() {}

    private var cache = NSCache<NSString, UIImage>()

    func getImage(forKey key: String) -> UIImage? {
        return cache.object(forKey: key as NSString)
    }

    func setImage(_ image: UIImage, forKey key: String) {
        cache.setObject(image, forKey: key as NSString)
    }
}

// MARK: - ProductSearchResult Model

struct ProductSearchResult: Identifiable {
    let id = UUID()
    let productId: String
    let score: Float
    let imageUri: String
    let displayName: String
    let category: String
    
    // Extract the parsed product ID (e.g., "product_id96")
    var parsedProductId: String {
        let components = productId.components(separatedBy: "/")
        if let index = components.firstIndex(of: "products"), index + 1 < components.count {
            return components[index + 1]
        } else {
            return ""
        }
    }
    
    // Extract the numerical part from parsedProductId
    var parsedProductIdNumber: Int? {
        let pattern = "product_id(\\d+)"
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: parsedProductId, options: [], range: NSRange(location: 0, length: parsedProductId.count)),
           let range = Range(match.range(at: 1), in: parsedProductId) {
            return Int(parsedProductId[range])
        }
        return nil
    }
    
    // Map product ID number to model filename based on category
    var modelFilename: String {
        let chairModels = [
            "Cover_Chair.usdz",
            "Gothic_Chair.usdz",
            "High-poly_Modern_Wood_Chair.usdz",
            "Living_Room_Chair.usdz",
            "Office_Chair.usdz",
            "Rounded_Chair.usdz",
            "Rustic_chair.usdz",
            "West_Elm_Slope_Leather_Chair.usdz",
            "Wrinkly_Chair.usdz",
            "black_cusion_four_leg.usdz",
            "black_highblack_office_hair.usdz",
            "black_leather_layDown_chair.usdz",
            "blue_Office_chair.usdz",
            "dark_green_high_back_sofa_Chair.usdz",
            "dark_wooden_fourLegs_soft_mesh.usdz",
            "high_back_Office_Chair.usdz",
            "lightGrey_bamboo_Outdoor_Chair_pillow.usdz",
            "light_blue_cusion_chair.usdz",
            "light_wooden_fourLegs_hard_sit.usdz",
            "metal_white_back_black_cusion_chair.usdz",
            "victorian_pillows_back_Chair.usdz"
        ]

        let tableModels = [
            "CC0_-_Table.usdz",
            "Chinese_square_table.usdz",
            "Coffee_Tables_Three_Legs_with_Rattan_I_Low-Poly.usdz",
            "Industrial_Table.usdz",
            "Simple_Office_Table.usdz",
            "Simple_Wood_Table.usdz",
            "Victorian_Wooden_table.usdz",
            "brown_yellow_Round_Table.usdz",
            "lattice_coffee_table.usdz",
            "low_round_two_layer_table.usdz",
            "wooden_Bar_Table.usdz",
            "wooden_aged_Table.usdz"
        ]
        
        guard let productIdNumber = parsedProductIdNumber else {
            return "default.usdz" // Fallback model
        }
        
        if category.lowercased() == "chair" {
            let index = productIdNumber % chairModels.count
            return chairModels[index]
        } else if category.lowercased() == "table" {
            let index = productIdNumber % tableModels.count
            return tableModels[index]
        } else {
            return "default.usdz" // Fallback model for other categories
        }
    }
    
    // Construct the model storage path using the mapped filename
    var modelStoragePath: String {
        return "\(category)/\(modelFilename)"
    }
    var parsedImageId: String {
        let components = imageUri.components(separatedBy: "/")
        if let index = components.firstIndex(of: "referenceImages"), index + 1 < components.count {
            return components[index + 1]
        } else {
            return ""
        }
    }

    var imageURL: String {
        let components = imageUri.components(separatedBy: "/")
        if let index = components.firstIndex(of: "referenceImages"), index + 1 < components.count {
            return "https://storage.googleapis.com/\(Constants.BUCKET_NAME)/image/\(components[index + 1]).png"
        }
        return ""
        
//        return "https://storage.googleapis.com/\(Constants.BUCKET_NAME)/image/image0.png"

    }

   
}


// MARK: - UISheetPresentationController.Detent.Identifier Extension

extension UISheetPresentationController.Detent.Identifier {
    static let small = UISheetPresentationController.Detent.Identifier("small")
}

// MARK: - Preview Provider

struct CaptureRoomView_Previews: PreviewProvider {
    static var previews: some View {
        
        CaptureRoomView(selectedImage: UIImage(named: "studio_bedroom")!)
    }
}
