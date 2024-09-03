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
import Firebase
import FirebaseCore



class AppDelegate: NSObject, UIApplicationDelegate {
  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    FirebaseApp.configure()

    return true
  }
}

@main
struct HomeyAIApp: App {
    // register app delegate for Firebase setupl
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    
    var body: some Scene {
        WindowGroup {
            NavigationView {
                    ContentView()
//                    .environmentObject(StorageService())
            }
                
        }
    }
}
