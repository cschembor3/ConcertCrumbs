//
//  SplashScreen.swift
//  ConcertTracker
//
//  Created by Connor Schembor on 1/22/23.
//

import Foundation
import SwiftUI

struct SplashScreen: View {

    @EnvironmentObject var authService: AuthenticationService

    var body: some View {

        Group {
            if authService.user != nil {
                ArtistsView(viewModel: ArtistsViewModel())
            } else {
                InitUsernameView()
            }
        }
    }
}
