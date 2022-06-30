//
//  ConciseFormsApp.swift
//  ConciseForms
//
//  Created by Oluwatobi Omotayo on 30/06/2022.
//

import SwiftUI

@main
struct ConciseFormsApp: App {
  var body: some Scene {
    WindowGroup {
      ContentView(
        viewModel: SettingsViewModel()
      )
    }
  }
}
