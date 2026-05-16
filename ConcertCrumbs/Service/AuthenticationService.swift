//
//  AuthenticationService.swift
//  ConcertTracker
//
//  Created by Connor Schembor on 1/7/23.
//

import AuthenticationServices
import CryptoKit
import Foundation
import FirebaseAuth

protocol AuthenticationServiceProtocol {
    func logIn(email: String, password: String)
    func logOut()
    func signUp(email: String, password: String)
}

class AuthenticationService: NSObject, ObservableObject, AuthenticationServiceProtocol {

    @Published var user: User? = nil

    private var authHandler: AuthStateDidChangeListenerHandle? = nil
    private var currentNonce: String? = nil

    override init() {
        super.init()
        self.user = Auth.auth().currentUser
        self.authHandler = Auth.auth().addStateDidChangeListener({ [weak self] (auth, signedInUser) in
            guard let self else { return }
            if let signedInUser {
                self.user = signedInUser
            } else {
                self.user = nil
            }
        })
    }

    func logIn(email: String, password: String) {

        Auth.auth().signIn(withEmail: email, password: password) { authResult, error in

            if let authResult,
               let credential = authResult.credential {

                // successfully logged in

            }
        }
    }

    func logOut() {
        try? Auth.auth().signOut()
    }

    func setupRequestWithScopeAndNonce(request: ASAuthorizationAppleIDRequest) {
        let nonce = randomNonceString()
        self.currentNonce = nonce
        request.requestedScopes = [.email]
        request.nonce = sha256(nonce)
    }

    func handleAuthenticationResult(result: Result<ASAuthorization, Error>) {

        if case .failure(let error) = result {
            print("Error: \(error.localizedDescription)")
            return
        }

        guard case .success(let authorization) = result else {
            return
        }

        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            guard let nonce = currentNonce else {
                fatalError("Invalid state: A login callback was received, but no login request was sent.")
            }
            guard let appleIDToken = appleIDCredential.identityToken else {
                print("Unable to fetch identity token")
                return
            }
            guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                print("Unable to serialize token string from data: \(appleIDToken.debugDescription)")
                return
            }
            // Initialize a Firebase credential.
            let credential = OAuthProvider.credential(withProviderID: "apple.com",
                                                      idToken: idTokenString,
                                                      rawNonce: nonce)
            // Sign in with Firebase.
            Auth.auth().signIn(with: credential) { (authResult, error) in
                if (error != nil) {
                    // Error. If error.code == .MissingOrInvalidNonce, make sure
                    // you're sending the SHA256-hashed nonce as a hex string with
                    // your request to Apple.
                    return
                }
                // User is signed in to Firebase with Apple.
                // ...
            }
        }
    }

    func signInWithApple() {
        let nonce = randomNonceString()
        self.currentNonce = nonce
        let appleIdProvider = ASAuthorizationAppleIDProvider()
        let request = appleIdProvider.createRequest()
        request.requestedScopes = [.email]
        request.nonce = sha256(nonce)

        let authorizationController = ASAuthorizationController(authorizationRequests: [request])
        authorizationController.delegate = self
//        authorizationController.presentationContextProvider = self
        authorizationController.performRequests()
    }

    func signUp(email: String, password: String) {

        Auth.auth().createUser(withEmail: email, password: password) { authResult, error in

            if let authResult,
               let credential = authResult.credential {

                // suggessfully signed up
            }
        }
    }
}

extension AuthenticationService: ASAuthorizationControllerDelegate {

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        if let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential {
            guard let nonce = currentNonce else {
                fatalError("Invalid state: A login callback was received, but no login request was sent.")
            }
            guard let appleIDToken = appleIDCredential.identityToken else {
                print("Unable to fetch identity token")
                return
            }
            guard let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
                print("Unable to serialize token string from data: \(appleIDToken.debugDescription)")
                return
            }
            // Initialize a Firebase credential.
            let credential = OAuthProvider.credential(withProviderID: "apple.com",
                                                      idToken: idTokenString,
                                                      rawNonce: nonce)
            // Sign in with Firebase.
            Auth.auth().signIn(with: credential) { (authResult, error) in
                if (error != nil) {
                    // Error. If error.code == .MissingOrInvalidNonce, make sure
                    // you're sending the SHA256-hashed nonce as a hex string with
                    // your request to Apple.
                    return
                }
                // User is signed in to Firebase with Apple.
                // ...
            }
        }
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {

    }
}

extension AuthenticationService {

    // Adapted from https://auth0.com/docs/api-auth/tutorials/nonce#generate-a-cryptographically-random-nonce
    private func randomNonceString(length: Int = 32) -> String {
      precondition(length > 0)
      let charset: [Character] =
        Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
      var result = ""
      var remainingLength = length

      while remainingLength > 0 {
        let randoms: [UInt8] = (0 ..< 16).map { _ in
          var random: UInt8 = 0
          let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
          if errorCode != errSecSuccess {
            fatalError(
              "Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)"
            )
          }
          return random
        }

        randoms.forEach { random in
          if remainingLength == 0 {
            return
          }

          if random < charset.count {
            result.append(charset[Int(random)])
            remainingLength -= 1
          }
        }
      }

      return result
    }

    private func sha256(_ input: String) -> String {
      let inputData = Data(input.utf8)
      let hashedData = SHA256.hash(data: inputData)
      let hashString = hashedData.compactMap {
        String(format: "%02x", $0)
      }.joined()

      return hashString
    }
}
