//
//  S3Manager.swift
//  Homey.AI
//
//  Created by 顾嘉元 on 2024/5/12.
//

import Foundation
class S3Manager{
    func getPreferenceImgUrl() -> [String]{
        let base = "https://homeyaib5bf8dc2af9e413d8cd6987869008a5362b22-dev.s3.us-west-1.amazonaws.com/"
        
        return ["https://homeyaib5bf8dc2af9e413d8cd6987869008a5362b22-dev.s3.us-west-1.amazonaws.com/futuristic.png", "https://homeyaib5bf8dc2af9e413d8cd6987869008a5362b22-dev.s3.us-west-1.amazonaws.com/plaster.png", "https://homeyaib5bf8dc2af9e413d8cd6987869008a5362b22-dev.s3.us-west-1.amazonaws.com/stone.png", "https://homeyaib5bf8dc2af9e413d8cd6987869008a5362b22-dev.s3.us-west-1.amazonaws.com/wooden.png"]
    }
    func getS3Name() -> [String]{
        return ["ballroom_chair", "High_Top", "Round_White_Table_Cloth", "Stage_Set_with_Stairs", "Stage", "Sofa_Chair",  "Victorian_chair", "Office_Chair_Modern", "Office_Chair"]
    }
    func getFurnitureSet() -> String{
        let s3Name = getS3Name()
        var output = ""
        for i in 0..<(s3Name.count - 1){
            output += s3Name[i] + ", "
        }
        output += s3Name[(s3Name.count - 1)] + ". "
        return output
//        return "ballroom_chair, High_Top, Round_White_Table_Cloth, Stage_Set_with_Stairs, Stage, Sofa_Chair, Cover_Chair, Victorian_chair, Office_Chair_Modern, Office_Chair"
//        return "Sofa_Chair"
    }
    
    func getFurniturePics() -> [String] {
        var s3Name = getS3Name()
        for index in 0..<s3Name.count{
            s3Name[index] = "https://homeyaib5bf8dc2af9e413d8cd6987869008a5362b22-dev.s3.us-west-1.amazonaws.com/" + s3Name[index] + ".png"
        }
        
        print(s3Name)
        return s3Name
    }
    
    func getFurnitureDimensions() -> String{
        let s3Name = getS3Name()
//        let s3Name = ["Sofa_Chair"]
        let s3Dimensions = [(50, 40), (10, 10),  (200, 200), (1000, 300), (700, 300), (100, 100), (60,60), (70,70), (60,60)]
//        let s3Dimensions = [(100, 100)]
        var res = ""
        for index in 0..<s3Name.count{
            res += s3Name[index]
            res += " is "
            res += String(s3Dimensions[index].0)
            res += " by "
            res += String(s3Dimensions[index].1)
            res += "."
        }
        
        return res
    }
}
