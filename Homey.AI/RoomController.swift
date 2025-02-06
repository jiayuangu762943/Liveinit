//
//  RoomController.swift
//  Homey.AI
//
//  Created by 顾嘉元 on 2024/4/19.
//

import Foundation
import RoomPlan
import SwiftUI
import RealityKit

class RoomController :  RoomCaptureViewDelegate, ObservableObject {
    var roomBuilder = RoomBuilder(options: [.beautifyObjects])
    var finalRoom: CapturedRoom?
    func encode(with coder: NSCoder) {
        fatalError("Not Needed")
    }
    
    required init?(coder: NSCoder) {
        fatalError("Not Needed")
    }
    
    init() {
              captureView = RoomCaptureView(frame: .zero)
              captureView.delegate = self
    }
    static var instance = RoomController() //Singleton
    
    var captureView  : RoomCaptureView
    var sessionConfig : RoomCaptureSession.Configuration = RoomCaptureSession.Configuration()
    var finalResult : CapturedRoom?
    
    func captureView(shouldPresent roomDataForProcessing: CapturedRoomData, error: (Error)?) -> Bool {
        return true
    }
    
   
    func captureView(didPresent processedResult: CapturedRoom, error: (Error)?) {
        finalResult = processedResult
        
    }
    
    func export(){
        var modelProvider = CapturedRoom.ModelProvider()
        guard let chairURL = Bundle.main.url(forResource: "chair", withExtension: "usdz") else {
                print("Failed to find chair.usdz in app bundle.")
                return
        }
        guard let tableURL = Bundle.main.url(forResource: "table", withExtension: "usdz") else {
                print("Failed to find table.usdz in app bundle.")
                return
        }
        if let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            // Note: Creating a URL directly like this will cause a runtime error if the URL initialization fails.
            // It's safer to check the URL creation and handle potential nil values.
            

            try? modelProvider.setModelFileURL(chairURL, for: CapturedRoom.Object.Category.chair)
            try? modelProvider.setModelFileURL(tableURL, for: CapturedRoom.Object.Category.table)

            let exportURL = directory.appendingPathComponent("scanned.usdz")
            do {
                try self.finalResult?.export(to: exportURL, modelProvider: modelProvider, exportOptions: .model) //, modelProvider: modelProvider, exportOptions: .model
                print("exported?")
            } catch {
                print("Export failed with error: \(error)")
            }
        }
    }
    
    func getCapturedRoom() -> CapturedRoom{
        return self.finalResult!
    }
    
//    to start scanning
    func startSession() {
        captureView.captureSession.run(configuration: sessionConfig)
    }
    
//    to stop session
    func stopSession() {
        captureView.captureSession.stop()
    }
    
    func createFolders(){
        // Parse attributes and categories to create folder hierarchy
        for category in CapturedRoom.Object.Category.allCases {
            let docURL = URL(string: NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0])!
            let categoryStr = String(describing:category).replacingOccurrences(of: "CapturedRoom.Object.Category.", with: "")
            let dataPath = docURL.appendingPathComponent(categoryStr)
            try? FileManager.default.createDirectory(at: dataPath, withIntermediateDirectories: true)

            for attributes in category.supportedCombinations {
                let attributeStr = String(describing: attributes)
                let attrDataPath = dataPath.appendingPathComponent(attributeStr)
                try? FileManager.default.createDirectory(at: attrDataPath, withIntermediateDirectories: true)
            }
        }
    }
}

extension RoomController :  RoomCaptureSessionDelegate {
    func captureSession(_ session: RoomCaptureSession,
                            didEndWith data: CapturedRoomData, error: Error?)
        {
        if let error = error {
            print("Error: \(error)")
        }
        print("are you around")
        Task {
            self.finalRoom = try! await roomBuilder.capturedRoom(from: data)
            if let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                let url = directory.appendingPathComponent("scanned.usdz")
                try finalRoom!.export(to: url)
                
                // Share or save model to file
//                                let shareVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)
//                                present(shareVC, animated: true, completion: nil)
            }
        }
    }
}

struct RoomCaptureViewRepresentable : UIViewRepresentable {
    
    func makeUIView(context: Context) -> RoomCaptureView{
        RoomController.instance.captureView
    }
    
    func updateUIView(_ uiView: RoomCaptureView, context: Context) {
        
    }
}
