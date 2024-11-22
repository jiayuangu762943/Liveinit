////
////  StorageService.swift
////  Homey.AI
////
////  Created by 顾嘉元 on 2024/4/30.
////
//
//import Amplify
//import Foundation
//
//class StorageService: ObservableObject {
//    func upload(_ data: Data, name: String) async {
//        let task = Amplify.Storage.uploadData(
//            key: name,
//            data: data,
//            options: .init(accessLevel: .protected)
//        )
//        do {
//            let result = try await task.value
//            print("Upload data completed with result: \(result)")
//        } catch {
//            print("Upload data failed with error: \(error)")
//        }
//    }
//
//    func download(withName name: String) async -> Data? {
//        let task = Amplify.Storage.downloadData(
//            key: name,
//            options: .init(accessLevel: .protected)
//        )
//        do {
//            let result = try await task.value
//            print("Download data completed")
//            return result
//        } catch {
//            print("Download data failed with error: \(error)")
//            return nil
//        }
//    }
//
//    func remove(withName name: String) async {
//        do {
//            let result = try await Amplify.Storage.remove(
//                key: name,
//                options: .init(accessLevel: .protected)
//            )
//            print("Remove completed with result: \(result)")
//        } catch {
//            print("Remove failed with error: \(error)")
//        }
//    }
//}
