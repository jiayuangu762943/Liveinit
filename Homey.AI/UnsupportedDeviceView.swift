//
//  UnsupportedDeviceView.swift
//  Homey.AI
//
//  Created by 顾嘉元 on 2024/4/19.
//

import Foundation
import SwiftUI

struct UnsupportedDeviceView: View {
    var body: some View {
        VStack {
            Text("Unsupported Device")
                .font(.title)
                .foregroundColor(.red)
                .padding()
            
            Text("This device does not support Lidar.")
                .padding()
        }
    }
}
#Preview {
    UnsupportedDeviceView()
}
