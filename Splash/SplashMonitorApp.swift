import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    
    /// Tracks whether we are in the process of a real quit (force quit) or
    /// just hiding the window when menuBarOnlyMode is active.
    var isReallyQuitting = false
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Desactivar agrupación automática en pestañas para evitar pestañas duplicadas al reabrir
        NSWindow.allowsAutomaticWindowTabbing = false
        
        // Cargar icono de la aplicación explícitamente para el Dock
        if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let iconImage = NSImage(contentsOf: iconURL) {
            NSApp.applicationIconImage = iconImage
        }
        
        // Apply initial activation policy based on saved preference
        applyActivationPolicy()
    }
    
    /// Applies the correct NSApplication activation policy based on current settings.
    /// - `.accessory`: No Dock icon, no task switcher entry — menu bar only.
    /// - `.regular`: Normal app with Dock icon and task switcher entry.
    func applyActivationPolicy() {
        let menuBarOnly = Preferences.menuBarOnlyMode
        let showMenuBar  = Preferences.showMenuBarIcon

        if menuBarOnly && showMenuBar {
            NSApp.setActivationPolicy(.accessory)
        } else {
            NSApp.setActivationPolicy(.regular)
            // Re-attach Dock icon so it re-appears correctly
            if let iconURL = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
               let iconImage = NSImage(contentsOf: iconURL) {
                NSApp.applicationIconImage = iconImage
            }
        }
    }
    
    // MARK: - Cmd+Q interception for Menu Bar Only Mode
    
    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let menuBarOnly = Preferences.menuBarOnlyMode
        let showMenuBar  = Preferences.showMenuBarIcon

        // If the user triggered a "real" quit via the menu bar item, let it through
        if isReallyQuitting {
            return .terminateNow
        }
        
        if menuBarOnly && showMenuBar {
            // Instead of quitting, hide all windows and switch to accessory mode
            NSApp.setActivationPolicy(.accessory)
            for window in sender.windows {
                window.orderOut(nil)
            }
            return .terminateCancel
        }
        
        return .terminateNow
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        let menuBarOnly = Preferences.menuBarOnlyMode

        // When clicked in Dock (if visible) or relaunched, restore the window
        if !flag {
            // Switch back to regular so Dock icon appears
            if !menuBarOnly {
                NSApp.setActivationPolicy(.regular)
            }
            for window in sender.windows where window.canBecomeMain && !(window is NSPanel) {
                window.makeKeyAndOrderFront(self)
                NSApp.activate(ignoringOtherApps: true)
                return true
            }
        }
        return true
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Kill splash server and release all memory
        SplashService.shared.stopServerSync()
        SplashService.shared.resetState()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        let menuBarOnly = Preferences.menuBarOnlyMode
        let showMenuBar  = Preferences.showMenuBarIcon

        if menuBarOnly && showMenuBar {
            // Switch to accessory (hide Dock icon) instead of quitting
            NSApp.setActivationPolicy(.accessory)
            return false
        }
        
        // If menu bar icon is active, keep app running when window is closed
        return !showMenuBar
    }
}

@main
struct SplashMonitorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup("Splash Monitor", id: "main") {
            MainWindowView()
                .frame(minWidth: 850, minHeight: 600)
                .onChange(of: Preferences.menuBarOnlyMode) {
                    appDelegate.applyActivationPolicy()
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("About Splash Monitor" /*FIXME: "Acerca de Splash Monitor" */) {
                    NotificationCenter.default.post(name: NSNotification.Name("ShowAboutView"), object: nil)
                    NSApp.activate(ignoringOtherApps: true)
                    for window in NSApp.windows where window.canBecomeMain {
                        window.makeKeyAndOrderFront(nil)
                    }
                }
            }
            // Override the standard Quit menu item to support Menu Bar Only mode
            CommandGroup(replacing: .appTermination) {
                Button("Quit Splash Monitor" /*FIXME: "Salir de Splash Monitor" */) {
                    if Preferences.menuBarOnlyMode && Preferences.showMenuBarIcon {
                        // Hide to menu bar instead of quitting
                        NSApp.setActivationPolicy(.accessory)
                        for window in NSApp.windows {
                            window.orderOut(nil)
                        }
                    } else {
                        appDelegate.isReallyQuitting = true
                        NSApp.terminate(nil)
                    }
                }
                .keyboardShortcut("q", modifiers: .command)
                
                if Preferences.menuBarOnlyMode && Preferences.showMenuBarIcon {
                    Divider()
                    Button("Quit Completely" /*FIXME: "Salir completamente" */) {
                        appDelegate.isReallyQuitting = true
                        NSApp.terminate(nil)
                    }
                    .keyboardShortcut("q", modifiers: [.command, .shift])
                }
            }
        }
        
        MenuBarExtra(isInserted: Preferences.$showMenuBarIcon) {
            MenuBarView()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: SplashService.shared.isRunning ? "bolt.fill" : "bolt.slash")
                
                if SplashService.shared.isRunning {
                    switch Preferences.menuBarDisplayMode {
                    case "speed":
                        Text("\(SplashService.shared.formattedDecodeSpeed) t/s")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                    case "tokens":
                        Text("\(SplashService.shared.formattedTokensDecode) tok")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                    case "model":
                        let short = SplashService.shared.activeModel.components(separatedBy: "/").last ?? SplashService.shared.activeModel
                        Text(short.replacingOccurrences(of: "-Splash", with: ""))
                            .font(.system(size: 11, weight: .medium))
                    default:
                        EmptyView()
                    }
                }
            }
        }
        .menuBarExtraStyle(.window)
    }
}
