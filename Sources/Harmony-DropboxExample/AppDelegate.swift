//
//  AppDelegate.swift
//  Harmony-DropboxExample
//
//  Created by Joseph Mattiello on 2/16/23.
//  Copyright © 2023 Joseph Mattiello. All rights reserved.
//

import Harmony
import Harmony_Dropbox
import HarmonyExample
import HarmonyTestData
import os.log

#if canImport(UIKit)
import RoxasUIKit
import UIKit

@UIApplicationMain
final class DropboxAppDelegate: HarmonyExample.AppDelegate {
	override public func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
		ServiceManager.shared.services.append(DropboxService.shared)
		return super.application(application, didFinishLaunchingWithOptions: options)
	}
}
#elseif canImport(AppKit)
import AppKit

@NSApplicationMain
final class DropboxAppDelegate: HarmonyExample.AppDelegate {
	override func applicationDidFinishLaunching(_ notification: Notification) {
		ServiceManager.shared.services.append(DropboxService.shared)
		super.applicationDidFinishLaunching(notification)
	}
}
#else
#error("Unsupported platform")
#endif
