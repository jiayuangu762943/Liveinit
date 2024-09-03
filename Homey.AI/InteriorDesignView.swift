import SwiftUI

struct InteriorDesignView: View {
    @State private var selectedRoom = "Living"
    @State private var selectedSize = "Medium"
    @State private var selectedBudget = "$$"
    @State private var selectedStyle = "Minimalistic"
    @State private var selectedRoomImage: UIImage?
    @State private var showCaptureRoomView = false
    @State private var searchResults: [ProductSearchResult] = []

    let roomOptions = ["Living", "Bedroom", "Dining"]
    let sizeOptions = ["Small", "Medium", "Large"]
    let budgetOptions = ["$", "$$", "$$$"]
    let styles = ["Scandinavian", "Minimalistic", "Organic Modern"]

    // Sample images for each style (Replace with your actual images)
    let styleImages: [String: [String]] 
    = [
        "Scandinavian": ["scandinavian1", "scandinavian2", "scandinavian3", "scandinavian4"],
        "Minimalistic": ["studio_bedroom", "studio_bedroom2", "studio_bedroom3", "studio_bedroom4"],
        "Organic Modern": ["organic1", "organic2", "organic3", "organic4"]
    ]

    // Replace with your actual values
    let PROJECT_ID = Constants.PROJECT_ID
    let LOCATION_ID = Constants.LOCATION_ID
    let PRODUCT_SET_ID = Constants.PRODUCT_SET_ID

    var body: some View {
        VStack(spacing: 16) {
            // Top controls: Room, Size, and Budget pickers
            HStack {
                Picker(selection: $selectedRoom, label: Text("Room")) {
                    ForEach(roomOptions, id: \.self) { room in
                        Text(room).tag(room)
                    }
                }
                .pickerStyle(MenuPickerStyle())

                Picker(selection: $selectedSize, label: Text("Size")) {
                    ForEach(sizeOptions, id: \.self) { size in
                        Text(size).tag(size)
                    }
                }
                .pickerStyle(MenuPickerStyle())

                Picker(selection: $selectedBudget, label: Text("Budget")) {
                    ForEach(budgetOptions, id: \.self) { budget in
                        Text(budget).tag(budget)
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }
            .padding(.horizontal)

            // Image Selection Section
            VStack(alignment: .leading) {
                Text("Select a Room Image")
                    .font(.headline)
                    .padding(.horizontal)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        if let images = styleImages[selectedStyle] {
                            ForEach(images, id: \.self) { imageName in
                                Image(imageName)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 150)
                                    .clipped()
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.blue, lineWidth: selectedRoomImage == UIImage(named: imageName) ? 4 : 0)
                                    )
                                    .onTapGesture {
                                        selectedRoomImage = UIImage(named: imageName)
                                    }
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                
                // Style selection
                Text("Your Custom Style")
                    .font(.title2)
                    .bold()
                    .padding(.top, 20)
                
                HStack {
                    Spacer()
                    
                    // Style option 1: Scandinavian (static, not clickable in this example)
                    CustomStyleOptionView(styleName: "Scandinavian")
                        .onTapGesture {
                            selectedStyle = "Scandinavian"
                        }
                    
                    Spacer()
                    
                    // Style option 2: Minimalistic (clickable)
                    CustomStyleOptionView(styleName: "Minimalistic")
                        .onTapGesture {
                            selectedStyle = "Minimalistic"
                        }
                    
                    Spacer()
                    
                    // Style option 3: Organic Modern (clickable)
                    CustomStyleOptionView(styleName: "Organic Modern")
                        .onTapGesture {
                            selectedStyle = "Organic Modern"
                        }
                    
                    Spacer()
                }
                .padding(.bottom, 20)
            }

            // Discover Button
            Button(action: {
                self.showCaptureRoomView = true
//                if selectedRoomImage != nil {
//                    Task{
//                        await performProductSearch()
//                    }
//                }
            }) {
                HStack {
                    Image(systemName: "magnifyingglass.circle.fill")
                        .font(.title)
                    Text("Discover")
                        .font(.headline)
                }
                .padding()
                .foregroundColor(.white)
                .background(selectedRoomImage != nil ? Color.blue : Color.gray)
                .cornerRadius(10)
            }
            .disabled(selectedRoomImage == nil)

            Spacer()
            
            
        }
        .padding(.vertical)
        // Navigate to CaptureRoomView with search results
        .fullScreenCover(isPresented: $showCaptureRoomView) {
//            CaptureRoomView(searchResults: searchResults, selectedImage: self.selectedRoomImage!)
            CaptureRoomView(selectedImage: self.selectedRoomImage!)

        }
    }
    
    func performProductSearch() async {
        guard let selectedImage = selectedRoomImage else {
            print("No image selected")
            return
        }

        guard let imageData = selectedImage.jpegData(compressionQuality: 0.8) else {
            print("Could not get JPEG representation of UIImage")
            return
        }

        let base64Image = imageData.base64EncodedString()

        // Build the JSON payload
        let requestDictionary: [String: Any] = [
            "requests": [
                [
                    "image": [
                        "content": base64Image
                    ],
                    "features": [
                        [
                            "type": "PRODUCT_SEARCH"
                        ]
                    ],
                    "imageContext": [
                        "productSearchParams": [
                            "productSet": "projects/\(PROJECT_ID)/locations/\(LOCATION_ID)/productSets/\(PRODUCT_SET_ID)",
                            "productCategories": [
                                "homegoods-v2"
                            ],
                            "filter": ""
                        ]
                    ]
                ]
            ]
        ]

        // Serialize the request to JSON
        guard let requestData = try? JSONSerialization.data(withJSONObject: requestDictionary) else {
            print("Could not serialize request data")
            return
        }

        // Set up the URL
        let urlString = "https://vision.googleapis.com/v1/images:annotate?key=\(Constants.GVision_API_KEY)"
        guard let url = URL(string: urlString) else {
            print("Invalid URL")
            return
        }

        // Set up the request
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = requestData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            // Perform the request
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                print("Server error")
                return
            }

            let visionResponse = try JSONDecoder().decode(VisionAPIResponse.self, from: data)

            if let results = visionResponse.responses.first?.productSearchResults?.results {
                let searchResults = results.map { resultItem in
                    ProductSearchResult(
                        productId: resultItem.product.name ?? "",
                        score: resultItem.score ?? 0,
                        imageUri: resultItem.image ?? "",
                        displayName: resultItem.product.displayName ?? "",
                        category: (resultItem.product.productLabels?[1].value)!
                    )
                }
                DispatchQueue.main.async {
                    self.searchResults = searchResults
                    self.showCaptureRoomView = true // Navigate to CaptureRoomView
                }
            } else {
                print("No results found")
            }
        } catch {
            print("Error: \(error.localizedDescription)")
        }
    }
   
}

// Data Models
//struct ProductSearchResult: Identifiable,Decodable {
//        let id = UUID()
//        let productId: String
//        let score: Float
//        let imageUri: String
//        let displayName: String
//
//        var parsedProductId: String {
//            let components = productId.components(separatedBy: "/")
//            if let index = components.firstIndex(of: "products"), index + 1 < components.count {
//                return components[index + 1]
//            } else {
//                return ""
//            }
//        }
//
//        var parsedImageId: String {
//            let components = imageUri.components(separatedBy: "/")
//            if let index = components.firstIndex(of: "referenceImages"), index + 1 < components.count {
//                return components[index + 1]
//            } else {
//                return ""
//            }
//        }
//
//        var imageURL: String {
//            // Update this if your images are stored elsewhere
//            let BUCKET_NAME = "homey-furniture-image"
//            return "https://storage.googleapis.com/\(BUCKET_NAME)/images/\(parsedImageId).jpg"
//        }
//
//        var modelURL: String {
//            let BUCKET_NAME = "homey-furniture-image"
//            return "https://storage.googleapis.com/\(BUCKET_NAME)/usdz/\(parsedProductId).usdz"
//        }
//}

struct VisionAPIResponse: Codable {
    let responses: [ProductSearchResponse]
}

struct ProductSearchResponse: Codable {
    let productSearchResults: ProductSearchResults?
}

struct ProductSearchResults: Codable {
    let indexTime: String?
    let results: [ProductSearchResultItem]?
}

struct ProductSearchResultItem: Codable {
    let product: Product
    let score: Float?
    let image: String?
}

struct Product: Codable {
    let name: String?
    let displayName: String?
    let productCategory: String?
    let productLabels: [ProductLabel]?
}

struct ProductLabel: Codable {
    let key: String?
    let value: String?
}

struct CustomStyleOptionView: View {
    let styleName: String
    
    var body: some View {
        VStack {
            Image(styleName) // Ensure the images match the style name
                .resizable()
                .frame(width: 100)
                .cornerRadius(10)
            Text(styleName)
                .font(.subheadline)
        }
        .padding()
//        .background(Color.white)
        .cornerRadius(10)
        .shadow(radius: 5)
    }
}

// Preview
struct LivingRoomView_Previews: PreviewProvider {
    static var previews: some View {
        InteriorDesignView()
    }
}
