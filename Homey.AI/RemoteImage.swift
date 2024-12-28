//
//  RemoteImage.swift
//  Homey.AI
//
//  Created by 顾嘉元 on 2024/4/30.
//

import Foundation
import SwiftUI
import FirebaseStorage

struct RemoteImage: View {
    @StateObject private var imageLoader = ImageLoader()
    @State private var image: UIImage? = nil
    var name: String

    // Computed property to construct the image filename from 'name'
    private var imageFileName: String {
        let extractedNumber = extractFirstNumber(from: name)! 
        return "\(extractedNumber).png"
    }

    var body: some View {
        Group {
            if let uiImage = imageLoader.image {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                // Placeholder while loading
                Rectangle()
                    .foregroundColor(Color(UIColor.systemGray5))
                    .overlay(
                        ProgressView()
                    )
                    .onAppear {
                        imageLoader.loadImage(imageName: imageFileName)
                    }
            }
        }
    }
}

// MARK: - ImageLoader Class

class ImageLoader: ObservableObject {
    @Published var image: UIImage?

    /// Loads an image from Firebase Storage given its filename.
    /// - Parameter imageName: The name of the image file to download.
    func loadImage(imageName: String) {
        // Step 1: Reference Firebase Storage
        let storageRef = Storage.storage(url: "gs://temporal-ground-437002-b8.firebasestorage.app").reference()
        let imageRef = storageRef.child("onehundredImgs").child(imageName)

        // Step 2: Download image data
        // Set a reasonable max size (e.g., 5MB)
        imageRef.getData(maxSize: 5 * 1024 * 1024) { [weak self] data, error in
            if let error = error {
                print("Error downloading image '\(imageName)': \(error.localizedDescription)")
                return
            }
            guard let data = data else {
                print("No data received for image '\(imageName)'.")
                return
            }
            if let uiImage = UIImage(data: data) {
                DispatchQueue.main.async {
                    self?.image = uiImage
                }
            } else {
                print("Failed to convert data to UIImage for image '\(imageName)'.")
            }
        }
    }
}
