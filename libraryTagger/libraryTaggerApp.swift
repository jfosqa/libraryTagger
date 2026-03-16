//
//  libraryTaggerApp.swift
//  libraryTagger
//
//  Created by Jon Foley on 3/16/26.
//

import SwiftUI
import CoreData

@main
struct libraryTaggerApp: App {
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
        }
    }
}
