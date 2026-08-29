//
//  PrintlyApp.swift
//  Printly
//
//  Created by 马卿 on 2026/8/29.
//

import SwiftUI
import CoreData

@main
struct PrintlyApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
