import SwiftUI
import SceneKit

struct ScrollCards: View{
    
    @State private var isLoading = true
    
    var selectedCards: Set<String>?
    var body: some View {
        let roomData = Model().getRoomData()
        
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                ForEach(0..<roomData.count, id: \.self) { id in
//                    NavigationLink(destination: CaptureRoomView(roomName: roomData[id]["name"] as! String, model: Model(), uuid:roomData[id]["uuid"] as! UUID, selectedCards:selectedCards )){
//                            Text(roomData[id]["name"] as! String)
////                            RemoteImage(name: image)
////                                        .frame(width: 30, height: 30)
//                        
//                    }
                }
                .padding()
            }
        
    }
}

func loadImageFromDisk(withFileName fileName: String) -> UIImage? {
    let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    let filePath = documentDirectory?.appendingPathComponent("\(fileName).jpg")
    
    if let path = filePath, let imageData = try? Data(contentsOf: path), let image = UIImage(data: imageData) {
        return image
    }
    return nil
}

//struct ContentView: View {
//    var selectedCards: Set<String>?
//    @EnvironmentObject private var authenticationService: AuthenticationService
//
//    var body: some View {
//            NavigationStack{
//                VStack(spacing:10) {
//                    Text("Homey.AI")
//                        .font(.title)
//                        .padding(10)
//                        .bold()
//                    Text("Inspire Home Design Creativity")
//                        .multilineTextAlignment(.center)
//                    
//                    ScrollView {ScrollCards(selectedCards: selectedCards)}
//                    
//                    HStack{
//                        NavigationLink(destination: RoomPlanView()) {
//                            Text("Start Scanning")
//                                .padding(3)
//                        }
//                        .buttonStyle(.borderedProminent)
//                        .cornerRadius(30).padding(.trailing, 5)
//                        
//                        NavigationLink(destination: UserPreferenceView1(roomImgUrl: S3Manager().getPreferenceImgUrl(), selectedImgs:  selectedCards )) {
//                            Text("Preference")
//                                .padding(3)
//                            Image(systemName:"person.fill")
//                            
//                        }.buttonStyle(.borderedProminent).cornerRadius(30)
//                    }
//                    
//                }
//                .padding(.horizontal,16)
//            }
//            .toolbar {
//                ToolbarItem(placement: .navigationBarTrailing) {
//                    Button("Sign in") {
//                        Task {
//                            await authenticationService.signIn(presentationAnchor: window)
//                        }
//                    }
//                }
//                ToolbarItem(placement: .navigationBarLeading) {
//                    Button("Sign Out") {
//                        Task {
//                            await authenticationService.signOut()
//                        }
//                    }
//                }
//            }
//        
//    }
//    
//    private var window: ASPresentationAnchor {
//            if let delegate = UIApplication.shared.connectedScenes.first?.delegate as? UIWindowSceneDelegate,
//               let window = delegate.window as? UIWindow {
//                return window
//            }
//            return ASPresentationAnchor()
//    }
//}
struct ContentView: View {
    @State private var scnView: SCNView?
    
    @State private var selectedRoom = "Bedroom"
    @State private var selectedSize = "300sqft"
    @State private var selectedBudget = "$1000"
    @State private var promptTemplates = [
        "I want to design a living room for 6 people mainly used for family time, with a minimalist look",
        "Create a cozy living room for 4 perfect for relaxation and reading, with warm lighting, soft textures, and comfortable seating."
    ]
    @State private var isLoading = false
    @State private var selectedPrompt: String = ""
    @State private var styleImages: [String: [String]] = [:]
    @State private var navigateToInteriorDesign = false

    let roomOptions = ["Living Room", "Dining Room", "Bedroom"]
    let sizeOptions = ["Small", "Medium", "Large"]
    let budgetOptions = ["$", "$$", "$$$"]

    
    var body: some View {
        NavigationStack {
            VStack {
                // Top banner
                HStack {
                    Text("LIVINIT")
                        .font(.title)
                        .foregroundColor(.white)
                        .bold()
                    Spacer()
                    Button(action: {
                        // Handle New Project button tap
                    }) {
                        Text("New Project")
                            .padding()
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
                .padding()
                .background(Constants.Purple)
                
                HStack(spacing: 0) {
                    Menu {
                        Button("Living Room") { selectedRoom = "Living Room" }
                        Button("Bedroom") { selectedRoom = "Bedroom" }
                        Button("Kitchen") { selectedRoom = "Kitchen" }
                    } label: {
                        Label(selectedRoom, systemImage: "chevron.down")
                            .padding()
                            .foregroundStyle(Color.black)
                            .cornerRadius(8)
                            .shadow(radius: 2)
                    }
                    Spacer()
                    Menu {
                        Button("$500") { selectedBudget = "$500" }
                        Button("$1000") { selectedBudget = "$1000" }
                        Button("$2000") { selectedBudget = "$2000" }
                    } label: {
                        Label(selectedBudget, systemImage: "chevron.down")
                            .padding()
                            .foregroundStyle(Color.black)
                            .cornerRadius(8)
                            .shadow(radius: 2)
                    }
                    
//                    Spacer()
                    Menu {
                        Button("150sqft") { selectedSize = "450sqft" }
                        Button("300sqft") { selectedBudget = "300sqft" }
                        Button("500sqft") { selectedBudget = "500sqft" }
                    } label: {
                        Label(selectedSize, systemImage: "chevron.down")
                            .padding()
                            .foregroundStyle(Color.black)
                            .cornerRadius(8)
                            .shadow(radius: 2)
                    }
                }
                .padding(.horizontal)
                
                // Image placeholder for room preview
                ZStack {
                    // SceneKit View
                    SCNViewContainer { view in
                        scnView = view  // Setup the SCNView when ready
                        print("\(scnView?.bounds.width ?? 0), height = \(scnView?.bounds.height ?? 0)")
//                        if !isSceneInitialized {
//                            clearScene()
//                            isSceneInitialized = true
//                        }
                    }
                    
                    
                } // Add your image to the assets
//                    .resizable()
                    .scaledToFit()
//                    .frame(height: 300)
                    .background(Color.gray.opacity(0.2)) // Placeholder background

                
                VStack(spacing: 8) {
                    // Suggestions and description
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(promptTemplates, id: \.self) { prompt in
                                SuggestionView(text: prompt,
                                               isLoading: isLoading,
                                               isSelected: prompt == selectedPrompt
                                )
                                .onTapGesture {
                                    selectedPrompt = prompt
                                }
                            }
                        }
                        //                    .padding()
                    }
                    
                    // Buttons for visualization
                    HStack {
                        NavigationLink(
                            destination: InteriorDesignView(),
                            /*(styleImages: styleImages),*/
                            isActive: $navigateToInteriorDesign
                        ) {
                            Button("Style" , action: {
                                self.navigateToInteriorDesign = true
//                                fetchStyleImages()
                            })
                            //                        .frame(maxWidth: .infinity)
                            .padding(10)
                            .background(Constants.Purple)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        TextField("Enter your prompt", text: $selectedPrompt)
//                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding(10)
                            
                    }
                    .padding()
                }
            }
            .padding()
            
            // Bottom Navigation Bar
//            HStack {
//                Spacer()
//                BottomBarItem(icon: "eye.fill", label: "Visualize")
//                Spacer()
//                BottomBarItem(icon: "rectangle.grid.2x2.fill", label: "Style Discovery")
//                Spacer()
//                BottomBarItem(icon: "folder.fill", label: "My Designs")
//                Spacer()
//                BottomBarItem(icon: "cart.fill", label: "Cart")
//                Spacer()
//            }
//            .padding()
//            .background(Color.purple)
//            .foregroundColor(.white)
        }
    }
    
    func fetchStyleImages() {
        isLoading = true

        // Update the URL to point to your GCP Cloud Run service
        guard let url = URL(string: "https://rag-functions-975557135630.us-central1.run.app") else {
            print("Invalid URL")
            isLoading = false
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"  // Adjust if your API uses a different method
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Prepare the JSON payload with selectedPrompt
        let payload = ["selectedPrompt": selectedPrompt]
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: payload, options: [])
            request.httpBody = jsonData
        } catch {
            print("Error serializing JSON: \(error)")
            isLoading = false
            return
        }

        // If your Cloud Run service requires authentication, add it here
        // request.setValue("Bearer \(yourAccessToken)", forHTTPHeaderField: "Authorization")

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            // Handle networking errors
            if let error = error {
                print("Error fetching style images: \(error)")
                DispatchQueue.main.async {
                    self.isLoading = false
                }
                return
            }

            // Check for HTTP errors
            if let httpResponse = response as? HTTPURLResponse,
               !(200...299).contains(httpResponse.statusCode) {
                print("Server error with status code: \(httpResponse.statusCode)")
                DispatchQueue.main.async {
                    self.isLoading = false
                }
                return
            }

            // Ensure data is not nil
            guard let data = data else {
                print("No data received")
                DispatchQueue.main.async {
                    self.isLoading = false
                }
                return
            }

            do {
                // Assuming the Cloud Run service returns styleImages in the format [String: [String]]
                let fetchedStyleImages = try JSONDecoder().decode([String: [String]].self, from: data)

                DispatchQueue.main.async {
                    self.styleImages = fetchedStyleImages
                    self.isLoading = false
                    self.navigateToInteriorDesign = true // Trigger navigation if needed
                }
            } catch {
                print("Error decoding style images: \(error)")
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            }
        }
        task.resume()
    }
    // Update the prompt templates dynamically based on selection
    func updatePromptTemplates() {
        isLoading = true
        generatePromptTemplates(room: selectedRoom, size: selectedSize, budget: selectedBudget) { result in
            switch result {
            case .success(let prompts):
                promptTemplates = prompts
            case .failure(let error):
                print("Error generating prompts: \(error.localizedDescription)")
                promptTemplates = ["Failed to generate prompts. Please try again."]
            }
            isLoading = false
        }
    }
    
    
    
    struct OpenAIResponse: Codable {
        let id: String?
        let object: String?
        let created: Int?
        let model: String?
        let system_fingerprint: String?
        let choices: [Choice]
        let usage: Usage?
    }

    struct Choice: Codable {
        let index: Int?
        let message: Message
        let logprobs: LogProbs?
        let finish_reason: String?
    }

    struct Message: Codable {
        let role: String
        let content: String
    }

    struct LogProbs: Codable {
        // Define this if needed, or use an empty struct
    }

    struct Usage: Codable {
        let prompt_tokens: Int?
        let completion_tokens: Int?
        let total_tokens: Int?
        let completion_tokens_details: CompletionTokensDetails?
    }

    struct CompletionTokensDetails: Codable {
        let reasoning_tokens: Int?
    }

    func generatePromptTemplates(room: String, size:String, budget: String, completion: @escaping (Result<[String], Error>) -> Void) {
        let apiKey = Constants.OPENAI_API_KEY // Replace with your actual API key
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Construct the prompt
        let prompt = "Generate interior design ideas for a \(room.lowercased()) of size \(size) with a budget of \(budget) less than 15 words. Important: include the number of people in the output! Exmaple: Design a living room with sofa, tv, chairs, and tables for 4 people with minimalistic style."
        let requestBody: [String: Any] = [
            "model": "gpt-4o-mini", // Use the correct model
            "messages": [
                ["role": "system", "content": "You are an assistant providing interior design suggestions."],
                ["role": "user", "content": prompt]
            ],
            "max_tokens": 150,
            "temperature": 0.7,
            "n": 2 // Number of completions
        ]
        
        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "Data error", code: -1, userInfo: nil)))
                return
            }
            
            // Print the HTTP status code
            if let httpResponse = response as? HTTPURLResponse {
                print("Status Code: \(httpResponse.statusCode)")
            }
            
            // Print the raw JSON response for debugging
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Response JSON: \(jsonString)")
            }
            
            // Decode the response using Codable
            do {
                let decoder = JSONDecoder()
                let openAIResponse = try decoder.decode(OpenAIResponse.self, from: data)
                let prompts = openAIResponse.choices.map { $0.message.content.trimmingCharacters(in: .whitespacesAndNewlines) }
                completion(.success(prompts))
            } catch {
                // Print decoding error
                print("Decoding error: \(error)")
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
        
}

struct BottomBarItem: View {
    var icon: String
    var label: String
    
    var body: some View {
        VStack {
            Image(systemName: icon)
                .font(.title)
            Text(label)
                .font(.footnote)
        }
    }
}

struct SuggestionView: View {
    var text: String
    var isLoading: Bool
    var isSelected: Bool

    var body: some View {
        VStack {
            Text(text)
                .padding()
//                .background(Color.white)
                .cornerRadius(10)
                .overlay(
                    // Add a bold black border if the suggestion is selected
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isSelected ? Color.black : Color.clear, lineWidth: isSelected ? 1 : 0)
                )
                .shadow(color: Color.gray.opacity(0.3), radius: 5, x: 0, y: 2)
                .frame(width: 300)

        }
    }
}

#Preview {
    ContentView()
}
