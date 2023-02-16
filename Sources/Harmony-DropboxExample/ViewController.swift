//
//  ViewController.swift
//  Harmony-DriveExample
//
//  Created by Joseph Mattiello on 2/16/23.
//  Copyright © 2023 Joseph Mattiello. All rights reserved.
//

import CoreData
import Harmony
import Harmony_Dropbox
import HarmonyExample
import Roxas

#if canImport(UIKit)
import UIKit

extension HarmonyExample.ViewController {
	func authenticateTest() {
		DropboxService.shared.clientID = "1075055855134-qilcmemb9e2pngq0i1n0ptpsc0pq43vp.apps.googleusercontent.com"

		DropboxService.shared.authenticateInBackground { result in
			switch result {
			case .success: print("Background authentication successful")
			case let .failure(error): print(error.localizedDescription)
			}
		}
	}

	func authenticate(withPresentingViewController viewController: UIViewController) {
		DropboxService.shared.authenticate(withPresentingViewController: viewController) { result in
			switch result {
			case .success: print("Authentication successful")
			case let .failure(error): print(error.localizedDescription)
			}
		}
	}

	var service: any Service { DropboxService.shared }
}
#endif
