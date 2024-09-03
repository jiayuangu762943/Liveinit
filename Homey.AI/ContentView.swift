import SwiftUI
import AuthenticationServices

struct ScrollCards: View{
    @EnvironmentObject private var authenticationService: AuthenticationService
    @State private var isLoading = true
    
    var selectedCards: Set<String>?
    var body: some View {
        let roomData = Model().getRoomData()
        
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                ForEach(0..<roomData.count, id: \.self) { id in
                    NavigationLink(destination: CaptureRoomView(roomName: roomData[id]["name"] as! String, model: Model(), uuid:roomData[id]["uuid"] as! UUID, selectedCards:selectedCards )){
                            Text(roomData[id]["name"] as! String)
//                            RemoteImage(name: image)
//                                        .frame(width: 30, height: 30)
                        
                    }
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

struct ContentView: View {
    var selectedCards: Set<String>?
    @EnvironmentObject private var authenticationService: AuthenticationService

    var body: some View {
            NavigationStack{
                VStack(spacing:10) {
                    Text("Homey.AI")
                        .font(.title)
                        .padding(10)
                        .bold()
                    Text("Inspire Home Design Creativity")
                        .multilineTextAlignment(.center)
                    
                    ScrollView {ScrollCards(selectedCards: selectedCards)}
                    
                    HStack{
                        NavigationLink(destination: RoomPlanView()) {
                            Text("Start Scanning")
                                .padding(3)
                        }
                        .buttonStyle(.borderedProminent)
                        .cornerRadius(30).padding(.trailing, 5)
                        
                        NavigationLink(destination: UserPreferenceView1(roomImgUrl: S3Manager().getPreferenceImgUrl(), selectedImgs:  selectedCards )) {
                            Text("Preference")
                                .padding(3)
                            Image(systemName:"person.fill")
                            
                        }.buttonStyle(.borderedProminent).cornerRadius(30)
                    }
                    
                }
                .padding(.horizontal,16)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Sign in") {
                        Task {
                            await authenticationService.signIn(presentationAnchor: window)
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Sign Out") {
                        Task {
                            await authenticationService.signOut()
                        }
                    }
                }
            }
        
    }
    
    private var window: ASPresentationAnchor {
            if let delegate = UIApplication.shared.connectedScenes.first?.delegate as? UIWindowSceneDelegate,
               let window = delegate.window as? UIWindow {
                return window
            }
            return ASPresentationAnchor()
    }
}

#Preview {
    ContentView()
}
