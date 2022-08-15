//
//  ConciseTCAFormView.swift
//  ConciseForms
//
//  Created by Oluwatobi Omotayo on 01/07/2022.
//

import ComposableArchitecture
import SwiftUI

enum SettingsAction: Equatable {
  case authorizationResponse(Result<Bool, NSError>)
  case notificationsSettingsResponse(UserNotificationsClient.Settings)
  case resetButtonTapped
  
  case binding(BindingAction<InconciseSettingsState>)
}

struct SettingsEnvironment {
  var mainQueue: AnySchedulerOf<DispatchQueue>
  var userNotifications: UserNotificationsClient
}

let settingsReducer = Reducer<InconciseSettingsState, SettingsAction, SettingsEnvironment> { state, action, environment in
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
    
  case let .notificationsSettingsResponse(settings):
    switch settings.authorizationStatus {
      
    case .notDetermined, .authorized, .provisional, .ephemeral:
      state.sendNotifications = true
      return environment.userNotifications.requestAuthorisation(.alert)
        .receive(on: environment.mainQueue)
        .mapError { $0 as NSError }
        .catchToEffect()
        .map(SettingsAction.authorizationResponse)
      
    case .denied:
      state.sendNotifications = false
      state.alert = .init(title: "You need to enable permission from iOS Settings")
      return .none

    @unknown default:
      return .none
    }
    
  case .resetButtonTapped:
    state = .init()
    return .none
    
  case .binding(\.displayName):
    state.displayName = String(state.displayName.prefix(16))
    return .none
    
  case .binding(\.sendNotifications):
    guard state.sendNotifications else {
      return .none
    }
    
    state.sendNotifications = false
    
    return environment.userNotifications.getNotificationSettings()
      .receive(on: environment.mainQueue)
      .map(SettingsAction.notificationsSettingsResponse)
      .eraseToEffect()

  case .binding:
    return .none
  }
}
  .binding(action: /SettingsAction.binding)


struct ConciseTCAFormView: View {
  
  let store: Store<InconciseSettingsState, SettingsAction>
  
  var body: some View {
    WithViewStore(self.store) { viewStore in
      Form {
        Section(header: Text("Profile")) {
          TextField(
            "Display name",
            text: viewStore.binding(
              keyPath: \.displayName,
              send: SettingsAction.binding
            )
          )
          Toggle(
            "Protect my posts",
            isOn: viewStore.binding(
              keyPath: \.protectPosts,
              send: SettingsAction.binding
            )
          )
        }
        
        Section(header: Text("Communications")) {
          Toggle(
            "Send notifications",
            isOn: viewStore.binding(
              keyPath: \.sendNotifications,
              send: SettingsAction.binding
            )
          )
          
          if viewStore.sendNotifications {
            Toggle(
              "Mobile",
              isOn: viewStore.binding(
                keyPath: \.sendMobileNotifications,
                send: SettingsAction.binding
              )
            )
            
            Toggle(
              "Email",
              isOn: viewStore.binding(
                keyPath: \.sendEmailNotifications,
                send: SettingsAction.binding
              )
            )
            
            Picker(
              "Top posts digest",
              selection: viewStore.binding(
                keyPath: \.digest,
                send: SettingsAction.binding
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
          keyPath: \.alert,
          send: SettingsAction.binding
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
          initialState: InconciseSettingsState(),
          reducer: settingsReducer,
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
