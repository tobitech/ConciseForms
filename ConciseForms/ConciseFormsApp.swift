//
//  ConciseFormsApp.swift
//  ConciseForms
//
//  Created by Oluwatobi Omotayo on 30/06/2022.
//

import ComposableArchitecture
import SwiftUI

@main
struct ConciseFormsApp: App {
  var body: some Scene {
    WindowGroup {
      NavigationView {
//        VanillaSwiftUIFormView(
//          viewModel: SettingsViewModel()
//        )
        TCAFormView(
          store: Store(
            initialState: SettingsState(),
            reducer: settingsReducer,
            environment: SettingsEnvironment(
              mainQueue: DispatchQueue.main.eraseToAnyScheduler(),
              userNotifications: .live
            )
          )
        )
      }
    }
  }
}
