//
//  ChatModel.swift
//  Homey.AI
//
//  Created by 顾嘉元 on 2024/4/23.

//

import Foundation


class Model: ObservableObject{
    var rooms: [Dictionary<String, Any>]?

    func getRoomData() -> [Dictionary<String, Any>]{
        self.rooms = [["name" : "Home", "uuid" : UUID(), "thumbnail": "homepic.jpg"], ["name": "Living Room", "uuid": UUID(), "thumbnail": "livingpic.jpg"]]
        return self.rooms!
    }
    
}
