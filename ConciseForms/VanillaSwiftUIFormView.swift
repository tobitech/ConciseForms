//
//  VanillaSwiftUIFormView.swift
//  ConciseForms
//
//  Created by Oluwatobi Omotayo on 30/06/2022.
//

import SwiftUI
import UserNotifications

struct AlertState: Identifiable {
  var title: String
  var id: String { self.title }
}

class SettingsViewModel: ObservableObject {
  @Published var alert: AlertState?
  @Published var digest = Digest.off
  @Published var displayName = "" {
    didSet {
      // without this guard statement, we will run into an infinite loop.
      guard self.displayName.count > 16 else { return }
      self.displayName = String(self.displayName.prefix(16))
    }
  }
  @Published var protectPosts = false
  @Published var sendNotifications = false {
    didSet {
      guard self.sendNotifications else { return }
      
      // let's check if the user has been previously denied.
      UNUserNotificationCenter.current().getNotificationSettings { settings in
        guard settings.authorizationStatus != .denied else {
          self.alert = AlertState(title: "You need to enable permission from iOS Settings")
          self.sendNotifications = false
          return
        }
        
        UNUserNotificationCenter.current().requestAuthorization(options: .alert) { granted, error in
          if !granted || error != nil {
            DispatchQueue.main.async {
              self.sendNotifications = false
            }
          }
        }
      }
    }
  }
  
  func reset() {
    self.digest = .off
    self.displayName = ""
    self.protectPosts = false
    self.sendNotifications = false
  }
}

struct VanillaSwiftUIFormView: View {
  
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
    .alert(item: self.$viewModel.alert) { alert in
      Alert(title: Text(alert.title))
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
      VanillaSwiftUIFormView(
        viewModel: SettingsViewModel()
      )
    }
  }
}
