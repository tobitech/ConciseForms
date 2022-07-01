//
//  TCAFormView.swift
//  ConciseForms
//
//  Created by Oluwatobi Omotayo on 01/07/2022.
//

import ComposableArchitecture
import SwiftUI

struct UserNotificationsClient {
  // we are wrapping it in an `Effect` because the operation done on the UNNotificationCenter endpoint is asynchronous
  // If it were synchronous we would just use a plain old closure.
  // Wrapping it with Effect also gives us all the functionalities and operators that combine provides.
  // Never because it does't produce an error.
  var getNotificationSettings: () -> Effect<Settings, Never>
  // this one doesn't return any data and doesn't produce an error, more like fire and forget.
  var registerForRemoteNotifications: () -> Effect<Never, Never>
  var requestAuthorisation: (UNAuthorizationOptions) -> Effect<Bool, Error>
  
  struct Settings: Equatable {
    var authorizationStatus: UNAuthorizationStatus
  }
}

extension UserNotificationsClient.Settings {
  init(rawValue: UNNotificationSettings) {
    self.authorizationStatus = rawValue.authorizationStatus
  }
}

// Let's provide a production or live implementation for our notifications client.
extension UserNotificationsClient {
  static let live = Self(
    getNotificationSettings: {
      // we need to return an Effect here.
      // TCA comes with some helpers to create certain flavours of effects.
      // 1:  to create an effect that emits a single time asynchronously, you can use the .future effect. it exposes a callback that you will invoke once you have your value.
      .future { callback in
        UNUserNotificationCenter.current().getNotificationSettings { settings in
          callback(.success(UserNotificationsClient.Settings(rawValue: settings)))
        }
      }
    },
    registerForRemoteNotifications: {
      .fireAndForget {
        UIApplication.shared.registerForRemoteNotifications()
      }
    },
    requestAuthorisation: { options in
        .future { callback in
          UNUserNotificationCenter.current().requestAuthorization(options: options) { granted, error in
            if let error = error {
              callback(.failure(error))
            } else {
              callback(.success(granted))
            }
          }
        }
    }
  )
}

struct SettingsState: Equatable {
  var alert: AlertState? = nil
  var digest = Digest.off
  var displayName = ""
  var protectPosts = false
  var sendNotifications = false
}

enum SettingsAction: Equatable {
  case authorizationResponse(Result<Bool, NSError>)
  case digestChanged(Digest)
  case dismissAlert
  case displayNameChanged(String)
  case notificationsSettingsResponse(UserNotificationsClient.Settings)
  case protectMyPostsChanged(Bool)
  case resetButtonTapped
  case sendNotificationsChanged(Bool)
}

struct SettingsEnvironment {
  var mainQueue: AnySchedulerOf<DispatchQueue>
  var userNotifications: UserNotificationsClient
}

let settingsReducer = Reducer<SettingsState, SettingsAction, SettingsEnvironment> { state, action, environment in
  switch action {
  case .authorizationResponse(.failure):
    state.sendNotifications = false
    return .none
    
  case let .authorizationResponse(.success(granted)):
    state.sendNotifications = granted
    return granted
    ? environment.userNotifications.registerForRemoteNotifications()
    // we can cast Effect<Never, Never> to any effect since it doesn't return anything with this helper below.
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
      // optimistically set the toggle on so that we can now request for permission.
      state.sendNotifications = true
      return environment.userNotifications.requestAuthorisation(.alert)
        .receive(on: environment.mainQueue)
        .mapError { $0 as NSError }
      // we need to always return an effect that doesn't error out so that we can handle the error ourselves.
      // so we will use this helper operator from TCA to turn it to an effect of Result type and Never.
        .catchToEffect()
        .map(SettingsAction.authorizationResponse)

    case .denied:
      state.sendNotifications = false
      state.alert = .init(title: "You need to enable permission from iOS Settings")
      return .none
    
    // this for handling unknown cases that can be added to the API in the future.
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
    // we shouldn't eagerly switch sendNotifications to `on`
    // state.sendNotifications = sendNotifications
    
    // instead we check is the user trying to turn it on?
    guard sendNotifications else {
      state.sendNotifications = sendNotifications
      return .none
    }
    
    return environment.userNotifications.getNotificationSettings()
    // it's good that combine has an operator to get things back on to the main queue.
      .receive(on: environment.mainQueue)
      .map(SettingsAction.notificationsSettingsResponse)
      .eraseToEffect()
//      .map { SettingsAction.notificationsSettingsResponse($0) }
  }
}

struct TCAFormView: View {
  
  let store: Store<SettingsState, SettingsAction>
  
  var body: some View {
    WithViewStore(self.store) { viewStore in
      Form {
        Section(header: Text("Profile")) {
          TextField(
            "Display name",
            text: viewStore.binding(
              get: \.displayName,
              send: SettingsAction.displayNameChanged
//            get: { settingsState in settingsState.displayName },
//            send: { newDisplayName in SettingsAction.displayNameChanged(newDisplayName) }
            )
          )
          Toggle(
            "Protect my posts",
            isOn: viewStore.binding(
              get: \.protectPosts,
              send: SettingsAction.protectMyPostsChanged
            )
          )
        }
        
        Section(header: Text("Communications")) {
          Toggle(
            "Send notifications",
            isOn: viewStore.binding(
              get: \.sendNotifications,
              send: SettingsAction.sendNotificationsChanged
            )
          )
          
          if viewStore.sendNotifications {
            Picker(
              "Top posts digest",
              selection: viewStore.binding(
                get: \.digest,
                send: SettingsAction.digestChanged
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
          send: SettingsAction.dismissAlert
        )
      ) { alert in
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
