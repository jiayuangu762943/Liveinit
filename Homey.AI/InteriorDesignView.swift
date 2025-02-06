import SwiftUI

struct InteriorDesignView: View {
    @State private var selectedRoom = "Living"
    @State private var selectedSize = "Medium"
    @State private var selectedBudget = "$$"
    @State private var selectedStyle = "Minimalistic"
    @State private var selectedRoomImage: UIImage?
    @State private var showCaptureRoomView = false
    @State private var searchResults: [ProductGroupedResult] = []

    let roomOptions = ["Living", "Bedroom", "Dining"]
    let sizeOptions = ["Small", "Medium", "Large"]
    let budgetOptions = ["$", "$$", "$$$"]
    let styles = ["Scandinavian", "Minimalistic", "Organic Modern"]

    // Replace these with actual images in your assets
    let styleImages: [String: [String]] = [
        "Scandinavian": ["scandinavian1", "scandinavian2", "scandinavian3", "scandinavian4"],
        "Minimalistic": ["minimalist1", "minimalist2"],
        "Organic Modern": ["organic1", "organic2", "organic3", "organic4"]
    ]

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
                    CustomStyleOptionView(styleName: "Scandinavian")
                        .onTapGesture {
                            selectedStyle = "Scandinavian"
                        }
                    
                    Spacer()
                    CustomStyleOptionView(styleName: "Minimalistic")
                        .onTapGesture {
                            selectedStyle = "Minimalistic"
                        }
                    
                    Spacer()
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
                // If we have a selected image, we can call performProductSearch asynchronously
                if selectedRoomImage != nil {
                    Task {
                        await performProductSearch()
                    }
                }
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
        .fullScreenCover(isPresented: $showCaptureRoomView) {
            if let selectedImage = selectedRoomImage {
                CaptureRoomView(selectedImage: selectedImage, searchResponse: $searchResults)
            }
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

        guard let requestData = try? JSONSerialization.data(withJSONObject: requestDictionary) else {
            print("Could not serialize request data")
            return
        }

        let urlString = "https://vision.googleapis.com/v1/images:annotate?key=\(Constants.GVision_API_KEY)"
        guard let url = URL(string: urlString) else {
            print("Invalid URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = requestData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
                print("Server error")
                return
            }
            
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            print("decoding")
            let productSearchAPIResponse = try decoder.decode(ProductSearchAPIResponse.self, from: data)
            print("interior design view : decoded")
            // Extracting product search results
            if let productSearchResults = productSearchAPIResponse.responses.first?.productSearchResults {
                // Extracting top-level results (not grouped) for the ProductSheetView
                
                let allGroupedProductResults = productSearchResults.productGroupedResults

                // Assign to searchResults
                DispatchQueue.main.async {
                    self.searchResults = allGroupedProductResults
                    self.showCaptureRoomView = true
                }
                
            } else {
                print("No results found")
            }
            
            
            
        } catch {
            print("Error what: \(error.localizedDescription)")

            
        }
    }
}

struct CustomStyleOptionView: View {
    let styleName: String
    
    var body: some View {
        VStack {
            Image(styleName) // Ensure these images exist or replace with placeholders
                .resizable()
                .frame(width: 100, height: 100)
                .cornerRadius(10)
            Text(styleName)
                .font(.subheadline)
        }
        .padding()
        .cornerRadius(10)
        .shadow(radius: 5)
    }
}

struct InteriorDesignView_Previews: PreviewProvider {
    static var previews: some View {
        InteriorDesignView()
    }
}

