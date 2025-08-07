//
//  KanbanBarApp.swift
//  KanbanBar
//
//  Created by Asbjørn Rørvik on 07/08/2025.
//

import SwiftUI

@main
struct KanbanBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarController = MenuBarController()
        
        // Hide dock icon and main window
        NSApp.setActivationPolicy(.accessory)
    }
}
