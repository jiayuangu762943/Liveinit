//
//  RoomPlanView.swift
//  Homey.AI
//
//  Created by 顾嘉元 on 2024/4/19.
//

import Foundation
import SwiftUI
import RoomPlan
//import RoomPlan


struct RoomPlanView: View {
    var roomController = RoomController.instance
    @State private var doneScanning : Bool = false
    var body: some View {
        ZStack{
            RoomCaptureViewRepresentable()
                .onAppear(perform: {
                    roomController.startSession()
                })
            
            VStack{
                Spacer()
                HStack{
                    if doneScanning == false {
                        Button(action: {
                            roomController.stopSession()
                            self.doneScanning = true
                            
                        }, label: {
                            Text("Done Scanning")
                                .padding(1).fixedSize(horizontal: false, vertical: true)
                        })
                        .buttonStyle(.borderedProminent)
                        .cornerRadius(30)
                    }else{
                        Button(action: {
                            roomController.export()
                        }, label: {
                            Text("Export")
                                .padding(1).fixedSize(horizontal: false, vertical: true)
                        })
                        .buttonStyle(.borderedProminent)
                        .cornerRadius(30)
                    }
//                    Spacer()
                    NavigationLink(destination: CaptureRoomView()){
                        Text("Style your room")
                            .padding(1).fixedSize(horizontal: false, vertical: true)
                        Image(systemName: "house.fill" )
                    }
                    .backgroundStyle(.black) .buttonStyle(.borderedProminent)
                    .cornerRadius(30)
                    
                }
              
            }
            .padding(.bottom,10)
        }
    }
}

#Preview {
    RoomPlanView()
}
