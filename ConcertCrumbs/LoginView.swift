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
    @EnvironmentObject private var authService: AuthenticationService
    @State private var username: String  = ""

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

                    Spacer()

                    VStack {
                        Image("icon")
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 200)

                        Text(Constants.Login.headerText)
                            .font(.largeTitle)
                    }

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

                    Spacer()
                    Spacer()
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
