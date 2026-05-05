//
//  LMS_BankingApp.swift
//  LMS-Banking
//
//  Created by Nevin Abraham on 16/04/26.
//

import SwiftUI

@main
struct LMS_BankingApp: App {

    init() {
        JailbreakDetector.exitIfJailbroken()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .fontDesign(.rounded)
        }
    }
}
