//
//  UserPreferenceView.swift
//  Homey.AI
//
//  Created by 顾嘉元 on 2024/4/26.
//

import Foundation
import SwiftUI
struct CheckmarkView: View {
    var isChecked: Bool
    
    var body: some View {
        ZStack {
            if isChecked {
                Image(systemName: "checkmark.circle.fill")
                    .font(.largeTitle)
                    .foregroundColor(.purple)
                    .transition(.scale(scale: 0.1, anchor: .center).combined(with: .opacity))
            }
        }
    }
}
struct CardView: View {
    var imageUrl: String
    var isSelected: Bool

    var body: some View {
        AsyncImage(url: URL(string: imageUrl)) { image in
                    image.resizable()
                } placeholder: {
                    ProgressView()
                }
                .scaledToFit()
//        Image(imageName)
//                    .resizable()
//                    .scaledToFit()
                    .frame(width: 200, height: 130)
                    .cornerRadius(8)
                    .foregroundColor(.white)
                    .overlay(
                        CheckmarkView(isChecked: isSelected)
                        .padding([.top, .leading], 4),
                        alignment: .topLeading // Positioning the checkmark at the top left corner
                    )
                    .animation(.default, value: isSelected)
        }
}

struct UserPreferenceView1: View{
//    let roomStyle = ["stone", "wooden", "plaster", "future"]
    var roomImgUrl: [String]?
    @State var selectedImgs: Set<String>
    init(roomImgUrl: [String]? = nil, selectedImgs: Set<String>? = nil) {
        self.roomImgUrl = roomImgUrl
        self.selectedImgs = selectedImgs ?? []
    }
    var body: some View {
        VStack{
            Text("Room Style")
                .font(.headline)
                .padding(5)
                .bold()
                .foregroundStyle(.purple)
            ScrollView{
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 20) {
                    ForEach(0..<roomImgUrl!.count, id: \.self) { id in
                        
                        CardView(imageUrl: roomImgUrl![id], isSelected: selectedImgs.contains(roomImgUrl![id]))
                                                    .onTapGesture {
                            if selectedImgs.contains(roomImgUrl![id]) {
                                selectedImgs.remove(roomImgUrl![id])
                            } else {
                                selectedImgs.insert(roomImgUrl![id])
                            }
                            
                        }.padding(10)
                        
                    }
                    .padding()
                }
                
            }
            
        }
        .navigationTitle("Select Cards")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
//                NavigationLink(destination: ContentView(selectedCards: (selectedImgs ?? []))) { //ResultView(selectedIds: Array(selectedIds)
//                    Text("Done")
//                }
            }
        }
    }
}


#Preview {
    UserPreferenceView1()
}
