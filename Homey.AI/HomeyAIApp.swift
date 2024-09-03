//
//  HomeyAIApp.swift
//  Homey.AI
//
//  Created by 顾嘉元 on 2024/4/30.
//

import Foundation
import UIKit
import SwiftUI
import Amplify
import AWSCognitoAuthPlugin
import AWSS3StoragePlugin

@main
struct HomeyAIApp: App {
    init() {
       do {
           try Amplify.add(plugin: AWSCognitoAuthPlugin())
           try Amplify.add(plugin: AWSS3StoragePlugin())
           try Amplify.configure()
           print("Initialized Amplify");
       } catch {
           print("Could not initialize Amplify: \(error)")
       }
   }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(AuthenticationService())
                .environmentObject(StorageService())
        }
    }
}
