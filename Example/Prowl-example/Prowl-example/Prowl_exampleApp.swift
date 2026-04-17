//
//  Prowl_exampleApp.swift
//  Prowl-example
//
//  Created by Elmee on 17/04/2026.
//

import Prowl
import ProwlCore
import SwiftUI

@main
struct Prowl_exampleApp: App {
    init() {
        Prowl.start()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
