////
////  LLMManager.swift
////  EventARApp
////
////  Created by 顾嘉元 on 2024/4/10.
////
//
//import Foundation
//import Alamofire
//
//class LLMManager{
//    private let endpointUrl = "https://api.openai.com/v1/chat/completions"
////    let userPrompt: String = "The room's dimensions are width x height, origin at (0.0, 0.0, 0.0). This is the living room where we sit, gather, and relax. Before you generate the JSON output, reflect whether the placement of furnitures would make the any part of furniture go out of bounds of the room"
//    
//    let furnitureChoice: String = """
//    You are an area generator expert. Given an area of a certain size, you can generate a list of items that are appropriate to that area and aligned with the users' preferences, in the right place and as indicated by the selected images. The images of all furniture are sent too.
//    
//    You operate in a 3D Space. You work in a X,Y,Z coordinate system. X denotes width, Y denotes height, Z denotes depth. 0.0, 0.0, 0.0 is the default space origin.
//    
//    There are images sent along with this that represent the user's taste of home design. Make sure your recommendation of furnitures are aligned with that. Don't confuse the user's taste of design image with the image of furnitures.
//    
//    The room's dimensions are width x height, origin at (0.0, 0.0, 0.0). Before you generate the comma separated list of furnitures, reflect whether the placement of furnitures would make any part of furniture go out of bounds of the room.
//    
//    The name of the area is room_name. The size of the area on X and Z axis in centimeters, the origin point of the area (which is at the center of the area).
//    
//    
//    You answer by only generating a comma separated list of furnitures. Example: ["Victorian_chair", "Office_Chair_Modern", "Office_Chair"]
//    
//    Important! You can only choose items from this set = {furniture_set}. all_furniture_dimensions
//    """
////    - area_name: name of the area
////    - X: coordinate of the area on X axis
////    - Y: coordinate of the area on Y axis
////    - Z: coordinate of the area on Z axis
////    - area_size_X: dimension in cm of the area on X axis
////    - area_size_Z: dimension in cm of the area on Z axis
////    - area_objects_list: list of all the objects in the area
////        Also keep in mind that the objects should be disposed all over the area in respect to the origin point of the area, and you can use negative values as well to display items correctly, since the origin of the area is always at the center of the area.
//
//    let furniturePosture = """
//    You are a home interior design expert. And now you have decided that you are going to place this set of furnitures: furniture_choice. all_furniture_dimensions The images of all furniture are sent too.
//    
//    You operate in a 3D Space. You work in a X,Y,Z coordinate system. X denotes width, Y denotes height, Z denotes depth. 0.0, 0.0, 0.0 is the default space origin. The room's dimensions are width x height, origin at (0.0, 0.0, 0.0).
//    
//    You need to generate a JSON of furniture objects with location and orientation information (X, Y, Z coordinates).
//    
//    For each furniture object you need to store:
//    - object_name: name of the object
//    - X: coordinate of the object on X axis
//    - Y: coordinate of the object on Y axis
//    - Z: coordinate of the object on Z axis
//    
//        
//    
//    Keep in mind, objects should be placed in the area to create the most meaningful layout possible, and they shouldn't overlap. All objects must be within the bounds of the area size; Objects can't intersect with each other, so keep in mind their size and perimeter when placing the objects in the area. That's really important!
//    
//    
//    Remember, you only generate a JSON, nothing else. The 'object_name' field for each furniture in the JSON must use the name in the set. Each furniture in the set must be assigned x, y, z coordinates in the JSON. The coordinates have to be non-negative values. It's very important.
//    
//    JSON example: {
//        "area_name": "Reception",
//        "X": 0.0,
//        "Y": 0.0,
//        "Z": 0.0,
//        "area_size_X": 700,
//        "area_size_Z": 1000,
//        "area_objects_list": [
//            {
//                "object_name": "Sofa_Chair",
//                "X": 120,
//                "Y": 0.0,
//                "Z": 130
//            },
//            {
//                "object_name": "High_Top",
//                "X": 600,
//                "Y": 0.0,
//                "Z": 700
//            }
//            ]
//    }
//    """
//    //    Never place objects further than 1/2 the length or 1/2 the depth of the area from the origin. The 6ft_Table is 2m by 2m. Wooden_lecturn is 75cm by 25cm. High_Top is 50cm by 50cm.
//    
//    let assistantPrompt = """
//    {
//        "area_name": "Reception",
//        "X": 0.0,
//        "Y": 0.0,
//        "Z": 0.0,
//        "area_size_X": 700,
//        "area_size_Z": 1000,
//        "area_objects_list": [
//            {
//                "object_name": "ballroom_chair",
//                "X": 120,
//                "Y": 0.0,
//                "Z": 130
//            },
//            {
//                "object_name": "High_Top",
//                "X": 600,
//                "Y": 0.0,
//                "Z": 700
//            }
//            ]
//    }
//    """
//    
//    
//    
//    //    public var openAI: OpenAIKit?
//    
//    init(){
//        //        openAI = OpenAIKit(apiToken: apiToken, organization: organizationName)
//    }
//    
//    
//    func setUserPrompt(prompt: String){
//        
//    }
//    
//    func sendMessage(roomId: UUID, message: String , imageUrls: Set<URL>?) async -> OpenAIChatResponse?{
////        var context = Model().getMessages(roomId: roomId)
//        var contents = [MessageContent]()
//            
//        
//        contents.append(TextContent(text: message))
//        
//        
//        if let imageUrls = imageUrls {
//            for url in imageUrls{
//                contents.append(ImageContent(image_url: url))
//            }
//        }
//        
//        let message = OpenAIChatMessage(id: UUID(), role: .user, content: contents)
//        let body = OpenAIChatBody(model: "gpt-4-turbo", messages: [message])
//        
//        let headers: HTTPHeaders = [
//            "Authorization": "Bearer \(Constants.OPENAI_API_KEY)",
//            "Content-Type": "application/json"
//        ]
//        do {
//            let request = AF.request(endpointUrl, method: .post, parameters: body, encoder: JSONParameterEncoder.default, headers: headers)
//
//            // Fetch and log the raw response string
//            let responseString = try await request.serializingString().value
//            print("Raw JSON response: \(responseString)")
//
//            // Decode the JSON response to your Swift model
//            let response = try JSONDecoder().decode(OpenAIChatResponse.self, from: responseString.data(using: .utf8)!)
//            return response
//        } catch {
//            print("Error occurred: \(error)")
//            return nil
//        }
//        
////        return try! await AF.request(endpointUrl, method: .post, parameters: body,
////                                     headers:headers).serializingDecodable(OpenAIChatResponse.self).value
//    }
//    
//    func sendMessageFurnitureChoice(w width: CGFloat, h height: CGFloat, imageUrls: Set<String>?) async -> OpenAIChatResponse?{
//        let tmp = furnitureChoice.replacingOccurrences(of: "width", with: String(format: "%.2f", width))
//        let furnitureChoiceTmp2 = tmp.replacingOccurrences(of: "height", with: String(format: "%.2f", height))
//        
//        let furnitureChoiceTmp = furnitureChoiceTmp2.replacingOccurrences(of: "furniture_set", with: S3Manager().getFurnitureSet()) //all_furniture_dimensions
//        let processedFurnitureChoicePrompt = furnitureChoiceTmp.replacingOccurrences(of: "all_furniture_dimensions", with: S3Manager().getFurnitureDimensions())
//
//        var contents = [MessageContent]()
////        contents.append(TextContent(text: processedUserPrompt))
//        contents.append(TextContent(text: processedFurnitureChoicePrompt))
////        contents.append(TextContent(text: assistantPrompt))
//        if let imageUrls = imageUrls {
//            for urlStr in imageUrls{
//                let url = URL(string: urlStr)
//                contents.append(ImageContent(image_url: url!))
//            }
//        }
//        
//        for furniturePicStr in S3Manager().getFurniturePics(){
//            let url = URL(string: furniturePicStr)
//            contents.append(ImageContent(image_url: url!))
//        }
//        
//        
//        let message = OpenAIChatMessage(id: UUID(), role: .user, content: contents)
//        let body = OpenAIChatBody(model: "gpt-4-turbo", messages: [message])
//        
//        let headers: HTTPHeaders = [
//            "Authorization": "Bearer \(Constants.OPENAI_API_KEY)",
//            "Content-Type": "application/json"
//        ]
//        do {
//            let request = AF.request(endpointUrl, method: .post, parameters: body, encoder: JSONParameterEncoder.default, headers: headers)
//
//            // Fetch and log the raw response string
//            let responseString = try await request.serializingString().value
//            print("Raw JSON response: \(responseString)")
//
//            // Decode the JSON response to your Swift model
//            let response = try JSONDecoder().decode(OpenAIChatResponse.self, from: responseString.data(using: .utf8)!)
//            return response
//        } catch {
//            print("Error occurred: \(error)")
//            return nil
//        }
//        
//    }
//    
//    func sendMessageFurniturePosture(choiceStr:String, w width: CGFloat, h height: CGFloat, imageUrls: Set<String>?) async -> OpenAIChatResponse?{
//        let filledPrev = furniturePosture.replacingOccurrences(of: "furniture_choice", with: choiceStr)
//        let tmp = filledPrev.replacingOccurrences(of: "width", with: String(format: "%.2f", width))
//        let furniturePosTmp2 = tmp.replacingOccurrences(of: "height", with: String(format: "%.2f", height))
//        
//        let furniturePosTmp = furniturePosTmp2.replacingOccurrences(of: "furniture_set", with: S3Manager().getFurnitureSet()) //all_furniture_dimensions
//        let processedFurniturePosPrompt = furniturePosTmp.replacingOccurrences(of: "all_furniture_dimensions", with: S3Manager().getFurnitureDimensions())
//
//        var contents = [MessageContent]()
////        contents.append(TextContent(text: processedUserPrompt))
//        contents.append(TextContent(text: processedFurniturePosPrompt))
//        
//        if let imageUrls = imageUrls {
//            for urlStr in imageUrls{
//                let url = URL(string: urlStr)
//                contents.append(ImageContent(image_url: url!))
//            }
//        }
//        //add all furniture pics to the payload
////        for furniturePicStr in S3Manager().getFurniturePics(){
////            let url = URL(string: furniturePicStr)
////            contents.append(ImageContent(image_url: url!))
////        }
//        
//        
//        let message = OpenAIChatMessage(id: UUID(), role: .user, content: contents)
//        let body = OpenAIChatBody(model: "gpt-4-turbo", messages: [message])
//        
//        let headers: HTTPHeaders = [
//            "Authorization": "Bearer \(Constants.OPENAI_API_KEY)",
//            "Content-Type": "application/json"
//        ]
//        do {
//            let request = AF.request(endpointUrl, method: .post, parameters: body, encoder: JSONParameterEncoder.default, headers: headers)
//
//            // Fetch and log the raw response string
//            let responseString = try await request.serializingString().value
//            print("Raw JSON response: \(responseString)")
//
//            // Decode the JSON response to your Swift model
//            let response = try JSONDecoder().decode(OpenAIChatResponse.self, from: responseString.data(using: .utf8)!)
//            return response
//        } catch {
//            print("Error occurred: \(error)")
//            return nil
//        }
//        
//    }
//
//}
////------------------------------------
//
//
//struct OpenAIChatBody: Encodable {
//    let model: String
//    let messages: [OpenAIChatMessage]
//
//    enum CodingKeys: String, CodingKey {
//        case model, messages
//    }
//    
//    func encode(to encoder: Encoder) throws {
//        var container = encoder.container(keyedBy: CodingKeys.self)
//        try container.encode(model, forKey: .model)
//        try container.encode(messages, forKey: .messages)
//    }
//}
//
//// Define a content protocol that both text and image can conform to
//protocol MessageContent: Codable {
//    var type: String { get }
//    static func decode(from decoder: Decoder) throws -> Self
//}
//
//// Text content structure
//struct TextContent: MessageContent {
//    let type = "text"
//    let text: String
//
//    init(text: String) {
//        self.text = text
//    }
//
//    static func decode(from decoder: Decoder) throws -> Self {
//        let container = try decoder.container(keyedBy: CodingKeys.self)
//        let text = try container.decode(String.self, forKey: .text)  // Decoding text directly as a String
//        return TextContent(text: text)
//    }
//
//    private enum CodingKeys: String, CodingKey {
//        case text = "content"  // Align the key to match the JSON response
//    }
//}
//
//// Image content structure
//struct ImageContent: MessageContent {
//    let type = "image_url"
//    let image_url: URL
//    
//    static func decode(from decoder: Decoder) throws -> Self {
//        let container = try decoder.container(keyedBy: CodingKeys.self)
//        let url = try container.decode(URL.self, forKey: .image_url)
//        return ImageContent(image_url: url)
//    }
//    
//    private enum CodingKeys: String, CodingKey {
//        case image_url
//    }
//}
//
//// Modify OpenAIChatMessage to handle any type of content
//struct OpenAIChatMessage: Codable, Identifiable {
//    let id: UUID?
//    let role: SenderRole
//    var content: [MessageContent] // Adjust the handling of this to accommodate different types.
//
//    enum CodingKeys: String, CodingKey {
//        case id, role, content
//    }
//    
//    func encode(to encoder: Encoder) throws {
//        var container = encoder.container(keyedBy: CodingKeys.self)
//        try container.encodeIfPresent(id, forKey: .id)  // Only encode if present
//        try container.encode(role, forKey: .role)
//
//        var contentContainer = container.nestedUnkeyedContainer(forKey: .content)
//        for contentItem in content {
//            try contentItem.encode(to: encoder)
//        }
//    }
//
//    init(id: UUID?, role: SenderRole, content: [MessageContent]) {
//        self.id = id
//        self.role = role
//        self.content = content
//    }
//
//    init(from decoder: Decoder) throws {
//        let container = try decoder.container(keyedBy: CodingKeys.self)
//        id = try container.decodeIfPresent(UUID.self, forKey: .id)
//        role = try container.decode(SenderRole.self, forKey: .role)
//        
//        var contentItems = [MessageContent]()
//        if var contentContainer = try? container.nestedUnkeyedContainer(forKey: .content) {
//            while !contentContainer.isAtEnd {
//                let typeDecoder = try contentContainer.superDecoder()
//                let type = try typeDecoder.container(keyedBy: DynamicCodingKeys.self)
//                let contentType = try type.decode(String.self, forKey: DynamicCodingKeys(stringValue: "type")!)
//                switch contentType {
//                case "text":
//                    contentItems.append(try TextContent.decode(from: typeDecoder))
//                case "image_url":
//                    contentItems.append(try ImageContent.decode(from: typeDecoder))
//                default:
//                    throw DecodingError.dataCorruptedError(in: contentContainer, debugDescription: "Unknown type")
//                }
//            }
//        } else {
//            let singleTextContent = try TextContent.decode(from: decoder)
//            contentItems.append(singleTextContent)
//        }
//        
//        content = contentItems
//    }
//}
//
//struct DynamicCodingKeys: CodingKey {
//    var stringValue: String
//    init?(stringValue: String) {
//        self.stringValue = stringValue
//    }
//    
//    var intValue: Int? = nil
//    init?(intValue: Int) {
//        return nil
//    }
//}
//
//
//enum SenderRole: String, Codable {
//    case user, system, assistant
//}
//
