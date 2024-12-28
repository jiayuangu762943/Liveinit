////
////  ChatInterface.swift
////  Homey.AI
////
////  Created by 顾嘉元 on 2024/4/23.
////
//
//import Foundation
//import SwiftUI
//
//
//struct ChatInterfaceView: View {
//    var roomId: UUID?
//    var selectedCards: Set<String>?
//    @ObservedObject var model: Model
//    @State private var typedMessage = ""
//    @State private var sending = false
////    @State private var messages: [OpenAIChatMessage] = []
//    
//    var body: some View {
//        VStack {
//            // Messages list
//            ScrollView {
//                ForEach(model.getMessages(roomId: self.roomId!)) { msg in
//                    HStack {
//                        if msg.role == .user {
//                            Spacer()
//                            Text((msg.content[0] as? TextContent)!.text)
//                                .padding()
//                                .background(Color.blue)
//                                .cornerRadius(15)
//                                .foregroundColor(.white)
//                        } else {
//                            Text((msg.content[0] as? TextContent)!.text)
//                                .padding()
//                                .background(Color.gray)
//                                .cornerRadius(15)
//                                .foregroundColor(.white)
//                            Spacer()
//                        }
//                    }.padding(3)
//                }
//            }
//            
//            // Input field
//            HStack {
//                TextField("Message", text: $typedMessage)
//                    .textFieldStyle(RoundedBorderTextFieldStyle())
//                    .frame(minHeight: CGFloat(30))
//                
//                // Send button
//                Button(action: {
//                    sendMessage(msg: typedMessage)
//                }, label: {
//                    if (sending){
//                        Image(systemName: "stop.circle.fill")
//                    }else{
//                        Image(systemName: "arrowshape.up.fill")
//                    }
//                })
//                .padding()
//                .background(Color.white)
//                .cornerRadius(10)
//                .foregroundColor(.black)
//            }.padding()
//        }
//        .navigationBarTitle("Chat", displayMode: .inline)
//    }
//    
//    func sendMessage(msg: String) {
//        guard !typedMessage.isEmpty else { return }
//            
//        // Append user message to model
//        model.addUserMessage(roomId: self.roomId!, text: typedMessage)
//        typedMessage = "" // Clear the text field immediately after capturing the message
//        sending = true
//        Task {
//            await recMessage(msg: msg)
//        }
//    }
//    func recMessage(msg: String) async {
//        guard let llmResponse = await LLMManager().sendMessage(roomId: self.roomId!, message: msg, imageUrls:nil ) else {
//            print("Failed to receive LLM response")
//            return
//        }
//
//        DispatchQueue.main.async {
//            self.model.addLLMMessage(roomId: self.roomId!, text: (llmResponse.choices.first?.message.content[0] as? TextContent)?.text ?? "No LLM response")
//            sending = false
//        }
//    }
//}
//
//#Preview {
//    ChatInterfaceView( model: Model())
//}
//
