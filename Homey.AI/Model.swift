//
//  ChatModel.swift
//  Homey.AI
//
//  Created by 顾嘉元 on 2024/4/23.

//

import Foundation


class Model: ObservableObject{
    @Published var messages: Dictionary<UUID, [OpenAIChatMessage]> = [:]
    var rooms: [Dictionary<String, Any>]?

    func addUserMessage(roomId: UUID, text: String) {
        let message = OpenAIChatMessage(id: UUID(), role: .user, content: [TextContent(text: text)])
        var roomMessages = self.messages[roomId] ?? []
        roomMessages.append(message)
        self.messages[roomId] = roomMessages  // This updates the dictionary and triggers @Published
    
    }
        
    
    // Function to add a LLM message
    func addLLMMessage(roomId: UUID, text: String) {
        let message = OpenAIChatMessage(id: UUID(), role: .system, content: [TextContent(text: text)])
        var roomMessages = self.messages[roomId] ?? []
        roomMessages.append(message)
        DispatchQueue.main.async {
            self.messages[roomId] = roomMessages  // Ensure this runs on the main thread
        }
    }
    
    func fetchMessages(){
        
    }
    
    func fetchRooms(){
        
    }
    
    func getMessages(roomId: UUID) -> [OpenAIChatMessage]{
        return self.messages[roomId] ?? []
    }
    
    func getRoomData() -> [Dictionary<String, Any>]{
        self.rooms = [["name" : "Home", "uuid" : UUID(), "thumbnail": "homepic.jpg"], ["name": "Living Room", "uuid": UUID(), "thumbnail": "livingpic.jpg"]]
        return self.rooms!
    }
    
}
