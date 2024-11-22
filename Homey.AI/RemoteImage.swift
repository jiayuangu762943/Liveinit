//
//  RemoteImage.swift
//  Homey.AI
//
//  Created by 顾嘉元 on 2024/4/30.
//

import Foundation
import SwiftUI

struct RemoteImage: View {
    @StateObject private var imageLoader = ImageLoader()
    @State private var image: UIImage? = nil
    var name: String

    // Computed property to construct the URL from 'name'
    private var url: String {
        let BUCKET_NAME = "homey-furniture-image" // Replace with your bucket name
        return "https://storage.googleapis.com/\(BUCKET_NAME)/image/\(name)"
    }

    var body: some View {
        Group {
            if let uiImage = imageLoader.image {
                Image(uiImage: uiImage)
                    .resizable()
            } else {
                // Placeholder while loading
                Rectangle()
                    .foregroundColor(Color(UIColor.systemGray5))
                    .overlay(
                        ProgressView()
                    )
                    .onAppear {
                        imageLoader.loadImage(from: url)
                    }
            }
        }
    }
}

class ImageLoader: ObservableObject {
    @Published var image: UIImage?

    func loadImage(from urlString: String) {
        // Step 1: Retrieve OAuth token (replace with your implementation)
        fetchOAuthToken { [weak self] token in
            guard let self = self, let token = token, let url = URL(string: urlString) else {
                return
            }

            // Step 2: Create URL request and add OAuth token to the header
            var request = URLRequest(url: url)
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

            // Step 3: Perform network request
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                if let data = data, let uiImage = UIImage(data: data) {
                    DispatchQueue.main.async {
                        self.image = uiImage
                    }
                } else {
                    print("Failed to load image from URL: \(urlString), error: \(error?.localizedDescription ?? "Unknown error")")
                }
            }
            task.resume()
        }
    }

    // Function to fetch OAuth token (you need to implement it based on your authentication flow)
    private func fetchOAuthToken(completion: @escaping (String?) -> Void) {
        // Replace with your actual logic to get an OAuth token.
        // For example, use Firebase, Google Sign-In SDK, or App Service Account credentials.
        
        // Example using Google Cloud SDK to get a token
        // You might use `gcloud auth` or use a service account to get a token.
        let token = Constants.accessToken // Replace with actual OAuth token fetching logic
        completion(token)
    }
}
