//
//  ContentView.swift
//  ConcertTracker
//
//  Created by Connor Schembor on 5/28/22.
//

import AuthenticationServices
import SwiftUI

struct LoginView: View {

    @Environment(\.colorScheme) var colorScheme
    @State private var username: String  = ""

    // TODO: expose this via a VM instead of directly using it in the view
    private let authService = AuthenticationService()

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [.purple, .green.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack {

                    Text(Constants.Login.headerText)
                        .font(.largeTitle)

                    // TODO: add spacing

                    SignInWithAppleButton(
                        onRequest: self.authService.setupRequestWithScopeAndNonce,
                        onCompletion: self.authService.handleAuthenticationResult
                    )
                    .signInWithAppleButtonStyle(self.signInButtonStyle)
                    .padding()
                    .clipShape(Capsule())
                    .frame(height: 80)
                    .frame(maxWidth: 400)
                    .padding(.horizontal, 50)
                }
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

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView()
            .environmentObject(AuthenticationService())
    }
}
