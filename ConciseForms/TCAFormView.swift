//
//  TCAFormView.swift
//  ConciseForms
//
//  Created by Oluwatobi Omotayo on 01/07/2022.
//

import ComposableArchitecture
import SwiftUI

struct SettingsState: Equatable {
  var alert: AlertState? = nil
  var digest = Digest.off
  var displayName = ""
  var protectPosts = false
  var sendNotifications = false
}

enum SettingsAction: Equatable {
  case digestChange(Digest)
  case dismissAlert
  case displayNameChanged(String)
  case protectMyPostsChanged(Bool)
  case resetButtonTapped
  case sendNotificationsChanged(Bool)
}

struct SettingsEnvironment {
}

let settingsReducer = Reducer<SettingsState, SettingsAction, SettingsEnvironment> { state, action, environment in
  
  return .none
}

struct TCAFormView: View {
  
  let store: Store<SettingsState, SettingsAction>
  
  var body: some View {
    WithViewStore(self.store) { viewStore in
      Form {
        Section(header: Text("Profile")) {
          TextField("Display name", text: .constant(""))
          Toggle("Protect my posts", isOn: .constant(false))
        }
        
        Section(header: Text("Communications")) {
          Toggle("Send notifications", isOn: .constant(false))
          
          if true {
            Picker("Top posts digest", selection: .constant(Digest.off)) {
              ForEach(Digest.allCases, id: \.self) { digest in
                Text(digest.rawValue)
                  .tag(digest)
              }
            }
          }
        }
        
        // Let's make sure we can pass data the other way from model to UI
        Button("Reset") {
          // self.viewModel.reset()
        }
      }
      .alert(item: .constant(AlertState?.none)) { alert in
        Alert(title: Text(alert.title))
      }
      .navigationTitle("Settings")
    }
  }
}

struct TCAFormView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      TCAFormView(
        store: Store(
          initialState: SettingsState(),
          reducer: settingsReducer,
          environment: SettingsEnvironment()
        )
      )
    }
  }
}
