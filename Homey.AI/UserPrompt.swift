//
//  UserPrompt.swift
//  Homey.AI
//
//  Created by Lareina Yang on 2/20/25.
//

import SwiftUI

struct UserPromptView: View {
    @State private var selectedCategory = "Living Room"
    @State private var userInput = ""
    @State private var selectedPrompt: String? = nil

    let categories = ["Dining Room", "Bedroom", "Living Room"]

    let prompts = [
        "Design A Budget-Friendly Living Space For Four Individuals In A Sleek, Modern Aesthetic, Keeping Costs Under $1,000.",
        "Incorporate A Sectional Sofa And A Large Coffee Table In The Bohemian-Style Living Room For Six People, Under $3500. Use Good Quality.",
        "Design A Modern-Style Living Room Of 300 Square Feet That Accommodates Eight People. Keep The Cost As Low As Possible.",
        "Design A Rustic-Style Living Room Tailored For Three People. Use Natural Materials Such As Wood And Stone, Along With Cozy Textiles.",
        "Design A Coastal-Style Living Room For Two Individuals. Utilize A Light And Airy Color Palette Inspired By The Sea, Such As Soft Blues, Whites, And Sandy Tones."
    ]

    var body: some View {
        VStack {
            // Header
            HStack {
                Text("Visualize")
                    .font(.title)
                    .fontWeight(.bold)
                
                Spacer()
                
                HStack(spacing: 16) {
                    Image(systemName: "cart")
                    Image(systemName: "bell")
                    Image(systemName: "plus.circle")
                }
                .font(.title2)
            }
            .padding(.horizontal)
            .padding(.top, 16)
            
            // Input Field + Discover Button
            HStack {
                TextField("User Input - Prompt", text: $userInput)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.leading)

                Button(action: {
                    print("Discover button clicked with prompt: \(userInput)")
                }) {
                    Text("Discover")
                        .fontWeight(.bold)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .padding(.trailing)
            }
            .padding(.vertical, 8)

            // Category Selection
            HStack {
                ForEach(categories, id: \.self) { category in
                    Button(action: {
                        selectedCategory = category
                    }) {
                        Text(category)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(selectedCategory == category ? Color.blue.opacity(0.2) : Color.gray.opacity(0.2))
                            .cornerRadius(10)
                    }
                }
            }
            .padding(.top, 8)
            
            // Prompt List
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(prompts, id: \.self) { prompt in
                        Button(action: {
                            userInput = prompt
                            selectedPrompt = prompt
                        }) {
                            Text(prompt)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(selectedPrompt == prompt ? Color.blue.opacity(0.2) : Color.gray.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(selectedPrompt == prompt ? Color.blue : Color.clear, lineWidth: 1)
                                )
                                .cornerRadius(10)
                                .padding(.horizontal)
                        }
                    }
                }
                .padding(.top, 8)
            }
            
            Spacer()
            
            // Bottom Navigation
            HStack {
                ForEach(["house", "magnifyingglass", "chart.bar.fill", "bookmark", "person"], id: \.self) { icon in
                    Spacer()
                    Image(systemName: icon)
                        .font(.title2)
                    Spacer()
                }
            }
            .padding()
            .background(Color.white.shadow(radius: 2))
        }
    }
}

struct UserPromptView_Previews: PreviewProvider {
    static var previews: some View {
        UserPromptView()
    }
}
