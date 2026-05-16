//
//  ContentView.swift
//  ConcertTracker
//
//  Created by Connor Schembor on 5/28/22.
//

import AuthenticationServices
import SwiftUI

struct InitUsernameView: View {

    @Environment(\.colorScheme) var colorScheme
    
    @State private var username: String  = ""
    @State private var bands: [String]  = []

    // TODO: expose this via a VM instead of directly using it in the view
    private let authService = AuthenticationService()

    var body: some View {
        
        NavigationStack {
            VStack {
//                Spacer()

                Text(Constants.Login.headerText)
                    .padding()

                // TODO: add spacing

                SignInWithAppleButton(
                    onRequest: self.authService.setupRequestWithScopeAndNonce,
                    onCompletion: self.authService.handleAuthenticationResult
                )
                .signInWithAppleButtonStyle(self.signInButtonStyle)
                .padding()
                .clipShape(Capsule())
                .frame(height: 80)
            }
        }
    }

    var signInButtonStyle: SignInWithAppleButton.Style {
        if self.colorScheme == .dark {
            return .whiteOutline
        }

        return .black
    }
}

struct AView: View {

    @State private var isPresented = false
    @State private var username: String  = ""
    @State private var bands: [String]  = []

    var body: some View {

        NavigationStack {
            Button("Other login option") {
                isPresented = true
            }
            .sheet(isPresented: $isPresented) {
                TextField(Constants.Login.usernameText, text: $username)
                    .disableAutocorrection(true)
                    .padding()
                    .textFieldStyle(.roundedBorder)

                SecureField(Constants.Login.passwordText, text: $username)
                    .disableAutocorrection(true)
                    .padding()
                    .textFieldStyle(.roundedBorder)

                Button(Constants.Login.submitButtonText) {
                    let service = UserDefaultsService()
                    service.setValue(username, for: UserDefaultsValues.usernameKey)
                }
                .padding()
                .clipShape(Capsule())
                .backgroundStyle(.white)
                .foregroundColor(.black)
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(.black, style: StrokeStyle(lineWidth: 4))
                )
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        InitUsernameView()
    }
}
