//
//  MenuBarController.swift
//  KanbanBar
//
//  Created by Asbjørn Rørvik on 07/08/2025.
//

import SwiftUI
import AppKit

class MenuBarController: NSObject {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    
    override init() {
        super.init()
        setupMenuBar()
        setupPopover()
    }
    
    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let statusButton = statusItem?.button {
            statusButton.image = NSImage(systemSymbolName: "rectangle.3.group", accessibilityDescription: "KanbanBar")
            statusButton.action = #selector(togglePopover)
            statusButton.target = self
            
            // Support both light and dark mode
            statusButton.image?.isTemplate = true
        }
    }
    
    private func setupPopover() {
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 500, height: 650)
        popover?.behavior = .transient
        popover?.contentViewController = NSHostingController(rootView: MainPopoverView())
    }
    
    @objc private func togglePopover() {
        guard let statusButton = statusItem?.button else { return }
        
        if let popover = popover {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: statusButton.bounds, of: statusButton, preferredEdge: .minY)
                
                // Activate the app to bring popover to front
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
}