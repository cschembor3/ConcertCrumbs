//
//  AccountView.swift
//  ConcertTracker
//
//  Created by Connor Schembor on 5/9/26.
//

import SwiftUI

struct AccountView: View {

    @EnvironmentObject private var authService: AuthenticationService
    @State private var presentSignOutAlert: Bool = false

    private var initials: String {
        let name = authService.user?.displayName ?? authService.user?.email ?? ""
        return name.components(separatedBy: " ")
            .compactMap { $0.first.map(String.init) }
            .prefix(2)
            .joined()
            .uppercased()
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.accentColor.opacity(0.15))
                                .frame(width: 60, height: 60)
                            if initials.isEmpty {
                                Image(systemName: "person.fill")
                                    .font(.title2)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text(initials)
                                    .font(.title2.bold())
                                    .foregroundStyle(.secondary)
                            }
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            if let name = authService.user?.displayName, !name.isEmpty {
                                Text(name)
                                    .font(.headline)
                            }
                            if let email = authService.user?.email {
                                Text(email)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    Button("Sign out", role: .destructive) {
                        presentSignOutAlert = true
                    }
                }
                .alert("Are you sure you want to sign out?", isPresented: $presentSignOutAlert) {
                    Button("Yes", role: .destructive) {
                        authService.logOut()
                    }
                }
            }
            .navigationTitle("Account")
        }
    }
}
