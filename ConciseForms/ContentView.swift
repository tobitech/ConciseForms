//
//  ContentView.swift
//  ConciseForms
//
//  Created by Oluwatobi Omotayo on 30/06/2022.
//

import SwiftUI

class SettingsViewModel: ObservableObject {
  @Published var displayName = ""
  @Published var protectPosts = false
  @Published var sendNotifications = false
  @Published var digest = Digest.off
  
  func reset() {
    self.digest = .off
    self.displayName = ""
    self.protectPosts = false
    self.sendNotifications = false
  }
}

struct ContentView: View {
  
  @ObservedObject var viewModel: SettingsViewModel
  
  var body: some View {
    Form {
      Section(header: Text("Profile")) {
        TextField("Display name", text: self.$viewModel.displayName)
        Toggle("Protect my posts", isOn: self.$viewModel.protectPosts)
      }
      
      Section(header: Text("Communications")) {
        Toggle("Send notifications", isOn: self.$viewModel.sendNotifications)
        if self.viewModel.sendNotifications {
          Picker("Top posts digest", selection: self.$viewModel.digest) {
            ForEach(Digest.allCases, id: \.self) { digest in
              Text(digest.rawValue)
                .tag(digest)
            }
          }
        }
      }
      
      // Let's make sure we can pass data the other way from model to UI
      Button("Reset") {
        self.viewModel.reset()
      }
    }
    .navigationTitle("Settings")
  }
}

enum Digest: String, CaseIterable {
  case off
  case daily
  case weekly
  case monthly
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      ContentView(
        viewModel: SettingsViewModel()
      )
    }
  }
}
