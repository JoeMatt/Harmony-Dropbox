//
//  DropboxService.swift
//  Harmony-Dropbox
//
//  Created by Riley Testut on 3/4/19.
//  Copyright © 2019 Riley Testut. All rights reserved.
//

import CoreData
import Foundation
@_exported import Harmony

#if canImport(UIKit)
import UIKit

	// TODO: For tvOS support, make a PR for SwiftyDropbox with this change.
/*
import SwiftyDropbox
class LoadingViewController: UIViewController {
	private let loadingSpinner: UIActivityIndicatorView

	override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
		if #available(iOS 13.0, tvOS 13.0, *) {
			loadingSpinner = UIActivityIndicatorView(style: .large)
		} else {
			loadingSpinner = UIActivityIndicatorView(style: .whiteLarge)
		}
		super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
	}
}
*/
#endif

import SwiftyDropbox
public typealias Account = SwiftyDropbox.Account

internal extension UserDefaults {
    static let harmonyDropboxAccountID = "harmony-dropbox_accountID"
}

extension DropboxService {
    enum DropboxError: LocalizedError {
        case nilDirectoryName

        var errorDescription: String? {
            switch self {
            case .nilDirectoryName: return NSLocalizedString("There is no provided Dropbox directory name.", comment: "")
            }
        }
    }

    private struct OAuthError: LocalizedError {
        var oAuthError: OAuth2Error
        var errorDescription: String?

        init(error: OAuth2Error, description: String) {
            oAuthError = error
            errorDescription = description
        }
    }

    enum CallError<T>: Error {
        case error(SwiftyDropbox.CallError<T>)

        init(_ callError: SwiftyDropbox.CallError<T>) {
            self = .error(callError)
        }

        init?(_ callError: SwiftyDropbox.CallError<T>?) {
            guard let callError = callError else { return nil }
            self = .error(callError)
        }
    }
}

public class DropboxService: NSObject, Harmony.Service {
    public typealias CompletionHandler = Result<Harmony.Account, Harmony.AuthenticationError>

    public static let shared = DropboxService()

    public let localizedName = NSLocalizedString("Dropbox", comment: "")
    public let identifier = "com.rileytestut.Harmony.Dropbox"


    public var clientID: String? {
        didSet {
            guard let clientID = clientID else { return }
            #if os(macOS)
                DropboxClientsManager.setupWithAppKeyDesktop(clientID)
            #elseif os(tvOS)
			DropboxClientsManager.reauthorizeClient(clientID)
			#else
                DropboxClientsManager.setupWithAppKey(clientID)
            #endif
        }
    }

    public var preferredDirectoryName: String?

    internal private(set) var dropboxClient: DropboxClient?
    internal let responseQueue = DispatchQueue(label: "com.rileytestut.Harmony.Dropbox.responseQueue")

    private var authorizationCompletionHandlers = [(CompletionHandler) -> Void]()

    private var accountID: String? {
        get {
            UserDefaults.standard.string(forKey: UserDefaults.harmonyDropboxAccountID)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: UserDefaults.harmonyDropboxAccountID)
        }
    }

    private(set) var propertyGroupTemplate: (String, FileProperties.PropertyGroupTemplate)?

    override private init() {
        super.init()
    }
}

public extension DropboxService {
    #if canImport(UIKit)
        func authenticate(withPresentingViewController viewController: UIViewController, completionHandler: @escaping (CompletionHandler) -> Void) {
            authenticate(withPresentingViewController: viewController,
                         loadingStatusDelegate: nil,
                         completionHandler: completionHandler)
        }

        func authenticate(withPresentingViewController viewController: UIViewController, loadingStatusDelegate: LoadingStatusDelegate? = nil, completionHandler: @escaping (CompletionHandler) -> Void) {
            authorizationCompletionHandlers.append(completionHandler)

            #if false // Legacy method
                DropboxClientsManager.authorizeFromController(UIApplication.shared, controller: viewController) { url in
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                }
            #else // New OAuth2 Method
			#if !os(tvOS)
			// TODO: tvOS auth @JoeMatt
                DropboxClientsManager.authorizeFromControllerV2(.shared, controller: viewController, loadingStatusDelegate: loadingStatusDelegate, openURL: { url in
                    UIApplication.shared.open(url, options: [:], completionHandler: nil)
                }, scopeRequest: nil)
			#endif
            #endif
        }
    #else // Not UIKit
        func authenticate(completionHandler: @escaping (CompletionHandler) -> Void) {
            authorizationCompletionHandlers.append(completionHandler)
            ///     API clients set up by `DropboxClientsManager` will get token refresh logic for free.
            ///     If you need to set up `DropboxClient`/`DropboxTeamClient` without `DropboxClientsManager`,
            ///     you will have to set up the clients with an appropriate `AccessTokenProvider`.
            DropboxClientsManager.authorizeFromControllerV2(
                sharedApplication: .shared,
                controller: nil,
                loadingStatusDelegate: nil,
                openURL: { _ in
                    //				UIApplication.shared.open(url, options: [:], completionHandler: nil)
                }, scopeRequest: nil
            )
        }

    #endif

    func authenticateInBackground(completionHandler: @escaping (CompletionHandler) -> Void) {
        guard let accountID = accountID else { return completionHandler(.failure(.noSavedCredentials)) }

        authorizationCompletionHandlers.append(completionHandler)

        DropboxClientsManager.reauthorizeClient(accountID)

        finishAuthentication()
    }

    func deauthenticate(completionHandler: @escaping (Result<Void, DeauthenticationError>) -> Void) {
        DropboxClientsManager.unlinkClients()

        accountID = nil
        completionHandler(.success)
    }

    @discardableResult
    func handleDropboxURL(_ url: URL) -> Bool {
        let result = DropboxClientsManager.handleRedirectURL(url) { result in
            switch result {
            case .cancel:
                self.authorizationCompletionHandlers.forEach { $0(.failure(.other(GeneralError.cancelled))) }
                self.authorizationCompletionHandlers.removeAll()

            case .none, .success:
                self.finishAuthentication()

            case let .error(error, description):
                print("Error authorizing with Dropbox. \(error) \(String(describing: description))")

                let oAuthError = OAuthError(error: error, description: description ?? "")
                self.authorizationCompletionHandlers.forEach { $0(.failure(.other(oAuthError))) }

                self.authorizationCompletionHandlers.removeAll()
            }
        }
        return result
    }
}

private extension DropboxService {
    func finishAuthentication() {
        func finish(_ result: CompletionHandler) {
            // Reset self.authorizationCompletionHandlers _before_ calling all the completion handlers.
            // This stops us from accidentally calling completion handlers twice in some instances.
            let completionHandlers = authorizationCompletionHandlers
            authorizationCompletionHandlers.removeAll()

            completionHandlers.forEach { $0(result) }
        }

        guard let dropboxClient = DropboxClientsManager.authorizedClient else { return finish(.failure(.notAuthenticated)) }

        dropboxClient.users.getCurrentAccount().response { account, error in
            do {
                let account = try self.process(Result(account, error))

                self.createSyncDirectoryIfNeeded { result in
                    switch result {
                    case .success:
                        // Validate metadata first so we can also retrieve property group template ID.
                        let dummyMetadata = HarmonyMetadataKey.allHarmonyKeys.reduce(into: [:]) { $0[$1] = $1 as Any }
                        self.validateMetadata(dummyMetadata) { result in
                            switch result {
                            case .success:
                                // We could just always use DropboxClientsManager.authorizedClient,
                                // but this way dropboxClient is nil until _all_ authentication steps are finished.
                                self.dropboxClient = dropboxClient
                                self.accountID = account.accountId

                                let account = Harmony.Account(name: account.name.displayName, emailAddress: account.email)
                                finish(.success(account))

                            case let .failure(error):
                                finish(.failure(AuthenticationError(error)))
                            }
                        }

                    case let .failure(error):
                        finish(.failure(AuthenticationError(error)))
                    }
                }
            } catch {
                finish(.failure(AuthenticationError(error)))
            }
        }
    }

    func createSyncDirectoryIfNeeded(completionHandler: @escaping (Result<Void, Error>) -> Void) {
        do {
            guard let dropboxClient = DropboxClientsManager.authorizedClient else { throw AuthenticationError.notAuthenticated }

            let path = try remotePath(filename: nil)
            dropboxClient.files.getMetadata(path: path).response(queue: responseQueue) { _, error in
                // Retrieved metadata successfully, which means folder exists, so no need to do anything else.
                guard let error = error else { return completionHandler(.success) }

                if case let .routeError(error, _, _, _) = error, case .path(.notFound) = error.unboxed {
                    dropboxClient.files.createFolderV2(path: path).response(queue: self.responseQueue) { _, error in
                        do {
                            try self.process(Result(error))

                            completionHandler(.success)
                        } catch {
                            completionHandler(.failure(error))
                        }
                    }
                } else {
                    completionHandler(.failure(CallError(error)))
                }
            }
        } catch {
            completionHandler(.failure(error))
        }
    }
}

extension DropboxService {
    func process<T, E>(_ result: Result<T, CallError<E>>) throws -> T {
        do {
            do {
                let value = try result.get()
                return value
            } catch {
                do {
                    throw error
                } catch CallError<E>.error(.authError(let authError, _, _, _)) {
                    switch authError {
                    case .invalidAccessToken: throw AuthenticationError.notAuthenticated
                    case .expiredAccessToken: throw AuthenticationError.tokenExpired
                    default: break
                    }
                } catch CallError<E>.error(.rateLimitError) {
                    throw ServiceError.rateLimitExceeded
                } catch CallError<E>.error(.clientError(let error as URLError)) {
                    throw ServiceError.connectionFailed(error)
                } catch CallError<E>.error(.routeError(let boxedError, _, _, _)) {
                    switch boxedError.unboxed {
                    case let error as Files.DownloadError:
                        if case .path(.notFound) = error {
                            throw ServiceError.itemDoesNotExist
                        }

                        if case .path(.restrictedContent) = error {
                            throw ServiceError.restrictedContent
                        }

                    case let error as Files.GetMetadataError:
                        if case .path(.notFound) = error {
                            throw ServiceError.itemDoesNotExist
                        }

                    case let error as Files.DeleteError:
                        if case .pathLookup(.notFound) = error {
                            throw ServiceError.itemDoesNotExist
                        }

                    case let error as Files.ListRevisionsError:
                        if case .path(.notFound) = error {
                            throw ServiceError.itemDoesNotExist
                        }

                    default: break
                    }
                } catch {
                    // Ignore, just here to prevent propagating to outer do-catch.
                }

                // If we haven't re-thrown the error as a HarmonyError by now, throw it now.
                throw ServiceError(error)
            }
        } catch let error as HarmonyError {
            throw error
        } catch {
            assertionFailure("Non-HarmonyError thrown from DropboxService.process(_:)")
            throw error
        }
    }

    func validateMetadata<T>(_ metadata: [HarmonyMetadataKey: T], completionHandler: @escaping (Result<String, Error>) -> Void) {
        let fields = metadata.keys.map { FileProperties.PropertyFieldTemplate(name: $0, description_: $0, type: .string_) }

        do {
            guard let dropboxClient = DropboxClientsManager.authorizedClient else { throw AuthenticationError.notAuthenticated }

            if let (templateID, propertyGroupTemplate) = propertyGroupTemplate {
                let existingFields = Set(propertyGroupTemplate.fields.map { $0.name })

                let addedFields = fields.filter { !existingFields.contains($0.name) }
                guard !addedFields.isEmpty else { return completionHandler(.success(templateID)) }

                dropboxClient.file_properties.templatesUpdateForUser(templateId: templateID, name: nil, description_: nil, addFields: addedFields).response(queue: responseQueue) { result, error in
                    do {
                        let result = try self.process(Result(result, error))

                        let templateID = result.templateId
                        self.fetchPropertyGroupTemplate(forTemplateID: templateID) { result in
                            switch result {
                            case .success: completionHandler(.success(templateID))
                            case let .failure(error): completionHandler(.failure(error))
                            }
                        }
                    } catch {
                        completionHandler(.failure(error))
                    }
                }
            } else {
                dropboxClient.file_properties.templatesListForUser().response(queue: responseQueue) { result, error in
                    do {
                        let result = try self.process(Result(result, error))

                        if let templateID = result.templateIds.first {
                            self.fetchPropertyGroupTemplate(forTemplateID: templateID) { result in
                                switch result {
                                case .success: self.validateMetadata(metadata, completionHandler: completionHandler)
                                case let .failure(error): completionHandler(.failure(error))
                                }
                            }
                        } else {
                            dropboxClient.file_properties.templatesAddForUser(name: "Harmony", description_: "Harmony syncing metadata.", fields: fields).response(queue: self.responseQueue) { result, error in
                                do {
                                    let result = try self.process(Result(result, error))

                                    let templateID = result.templateId
                                    self.fetchPropertyGroupTemplate(forTemplateID: templateID) { result in
                                        switch result {
                                        case .success: completionHandler(.success(templateID))
                                        case let .failure(error): completionHandler(.failure(error))
                                        }
                                    }
                                } catch {
                                    completionHandler(.failure(error))
                                }
                            }
                        }
                    } catch {
                        completionHandler(.failure(error))
                    }
                }
            }
        } catch {
            completionHandler(.failure(error))
        }
    }

    func fetchPropertyGroupTemplate(forTemplateID templateID: String, completionHandler: @escaping (Result<FileProperties.PropertyGroupTemplate, Error>) -> Void) {
        do {
            guard let dropboxClient = DropboxClientsManager.authorizedClient else { throw AuthenticationError.notAuthenticated }

            dropboxClient.file_properties.templatesGetForUser(templateId: templateID).response(queue: responseQueue) { result, error in
                do {
                    let result = try self.process(Result(result, error))
                    self.propertyGroupTemplate = (templateID, result)

                    completionHandler(.success(result))
                } catch {
                    completionHandler(.failure(error))
                }
            }
        } catch {
            completionHandler(.failure(error))
        }
    }

    func remotePath(filename: String?) throws -> String {
        guard let directoryName = preferredDirectoryName else { throw DropboxError.nilDirectoryName }

        var remotePath = "/" + directoryName

        if let filename = filename {
            remotePath += "/" + filename
        }

        return remotePath
    }
}
