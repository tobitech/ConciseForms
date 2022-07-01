//
//  ConciseTCAFormView.swift
//  ConciseForms
//
//  Created by Oluwatobi Omotayo on 01/07/2022.
//

import ComposableArchitecture
import SwiftUI

enum ConciseSettingsAction: Equatable {
  case authorizationResponse(Result<Bool, NSError>)
  case digestChanged(Digest)
  case dismissAlert
  case displayNameChanged(String)
  case notificationsSettingsResponse(UserNotificationsClient.Settings)
  case protectMyPostsChanged(Bool)
  case resetButtonTapped
  case sendNotificationsChanged(Bool)
  
//  case form((inout SettingsState) -> Void)
  
  // instead of hold a closure, we could hold on to a keypath.
  // also assuming we could define generics on an enum case.
  // maybe that will be possible in the future
  case form<Value>(WritableKeyPath<SettingsState, Value>, Value)
  
  static func == (lhs: ConciseSettingsAction, rhs: ConciseSettingsAction) -> Bool {
    fatalError()
  }
}

let conciseSettingsReducer = Reducer<SettingsState, ConciseSettingsAction, SettingsEnvironment> { state, action, environment in
  switch action {
  case .authorizationResponse(.failure):
    state.sendNotifications = false
    return .none
    
  case let .authorizationResponse(.success(granted)):
    state.sendNotifications = granted
    return granted
    ? environment.userNotifications.registerForRemoteNotifications()
      .fireAndForget()
    : .none
    
  case let .digestChanged(digest):
    state.digest = digest
    return .none
    
  case .dismissAlert:
    state.alert = nil
    return .none
    
  case let .displayNameChanged(displayName):
    state.displayName = String(displayName.prefix(16))
    return .none
    
  case let .notificationsSettingsResponse(settings):
    switch settings.authorizationStatus {
      
    case .notDetermined, .authorized, .provisional, .ephemeral:
      state.sendNotifications = true
      return environment.userNotifications.requestAuthorisation(.alert)
        .receive(on: environment.mainQueue)
        .mapError { $0 as NSError }
        .catchToEffect()
        .map(ConciseSettingsAction.authorizationResponse)
      
    case .denied:
      state.sendNotifications = false
      state.alert = .init(title: "You need to enable permission from iOS Settings")
      return .none

    @unknown default:
      return .none
    }
    
  case let .protectMyPostsChanged(protectMyPosts):
    state.protectPosts = protectMyPosts
    return .none
    
  case .resetButtonTapped:
    state = .init()
    return .none
    
  case let .sendNotificationsChanged(sendNotifications):
    guard sendNotifications else {
      state.sendNotifications = sendNotifications
      return .none
    }
    
    return environment.userNotifications.getNotificationSettings()
      .receive(on: environment.mainQueue)
      .map(ConciseSettingsAction.notificationsSettingsResponse)
      .eraseToEffect()
    
//  case let .form(update):
//    update(&state)
//    return .none
    
    // instead of binding on a closure, we could bind on a keypath and value.
  case let .form(keyPath, value):
    state[keyPath: keyPath] = value
    
    // since key paths are equatable and even hashable,
    // we could even check what keypath was sent.
    if keyPath == \SettingsState.displayName {
      // TODO: truncate name
    } else if keyPath == \SettingsState.sendNotifications {
      // TODO: request notification authorization
    }
    return .none
  }
}

struct ConciseTCAFormView: View {
  
  let store: Store<SettingsState, ConciseSettingsAction>
  
  var body: some View {
    WithViewStore(self.store) { viewStore in
      Form {
        Section(header: Text("Profile")) {
          TextField(
            "Display name",
            text: Binding(
              get: { viewStore.dispplayName },
              set: {
//                viewStore.send(.form { $0.displayName = newDisplayNamae })
                viewStore.send(.form(\.displayName, $0))
              }
            )
//            text: viewStore.binding(
//              get: \.displayName,
//              send: ConciseSettingsAction.displayNameChanged
//            )
          )
          Toggle(
            "Protect my posts",
            isOn: viewStore.binding(
              get: \.protectPosts,
              send: ConciseSettingsAction.protectMyPostsChanged
            )
          )
        }
        
        Section(header: Text("Communications")) {
          Toggle(
            "Send notifications",
            isOn: viewStore.binding(
              get: \.sendNotifications,
              send: ConciseSettingsAction.sendNotificationsChanged
            )
          )
          
          if viewStore.sendNotifications {
            Picker(
              "Top posts digest",
              selection: viewStore.binding(
                get: \.digest,
                send: ConciseSettingsAction.digestChanged
              )
            ) {
              ForEach(Digest.allCases, id: \.self) { digest in
                Text(digest.rawValue)
                  .tag(digest)
              }
            }
          }
        }
        
        Button("Reset") {
          viewStore.send(.resetButtonTapped)
        }
      }
      .alert(
        item: viewStore.binding(
          get: \.alert,
          send: ConciseSettingsAction.dismissAlert
        )
      ) { alert in
        Alert(title: Text(alert.title))
      }
      .navigationTitle("Settings")
    }
  }
}

struct ConciseTCAFormView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      ConciseTCAFormView(
        store: Store(
          initialState: SettingsState(),
          reducer: conciseSettingsReducer,
          environment: SettingsEnvironment(
            mainQueue: DispatchQueue.main.eraseToAnyScheduler(),
            userNotifications: UserNotificationsClient(
              getNotificationSettings: { Effect(value: .init(authorizationStatus: .denied)) },
              registerForRemoteNotifications: { fatalError() },
              requestAuthorisation: { _ in fatalError() }
            )
          )
        )
      )
    }
  }
}
