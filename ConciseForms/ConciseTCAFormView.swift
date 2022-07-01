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
//  case digestChanged(Digest)
//  case dismissAlert
//  case displayNameChanged(String)
  case notificationsSettingsResponse(UserNotificationsClient.Settings)
//  case protectMyPostsChanged(Bool)
  case resetButtonTapped
//  case sendNotificationsChanged(Bool)
  
//  case form((inout SettingsState) -> Void)
  
  // instead of hold a closure, we could hold on to a keypath.
  // also assuming we could define generics on an enum case.
  // maybe that will be possible in the future.
  // but one thing we can do is define our own type so that we can do the generics works in there then it
  // will define how form is created.
  // case form(PartialKeyPath<SettingsState>, Any)
  
  case form(FormAction<SettingsState>)
  
  // we can now get rid of this since KeyPaths are equatable.
//  static func == (lhs: ConciseSettingsAction, rhs: ConciseSettingsAction) -> Bool {
//    fatalError()
//  }
}

// Having our own type gives us the ability to restrict
// the ways form actions are created.
// we are adding a Root generic so that the type is reusuable in other screens not just Settings.
struct FormAction<Root>: Equatable {
  
  let keyPath: PartialKeyPath<Root>
  // doing it this way makes sure you can only create
  // form action when you provide a value type
  // that matches the type that was erased by the PartialKeyPath
  // using this because Swift doesn't provide an AnyEquatable erased type and AnyHashable conforms to Equatable.
  // Check Episode exercise on creating custom type erased AnyEquatable ourselves.
  let value: AnyHashable
  // since we're using PartialKeyPath we are not able to write to the root, so we need to hold on to more information that will allow us set the value with this setter function.
  let setter: (inout Root) -> Void
  
  init<Value>(
    _ keyPath: WritableKeyPath<Root, Value>,
    _ value: Value
  ) where Value: Hashable {
    self.keyPath = keyPath
    self.value = AnyHashable(value)
    self.setter = { $0[keyPath: keyPath] = value }
  }
  
  static func == (lhs: FormAction<Root>, rhs: FormAction<Root>) -> Bool {
    lhs.keyPath == rhs.keyPath && lhs.value == rhs.value
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
    
//  case let .digestChanged(digest):
//    state.digest = digest
//    return .none
    
//  case .dismissAlert:
//    state.alert = nil
//    return .none
    
//  case let .displayNameChanged(displayName):
//    state.displayName = String(displayName.prefix(16))
//    return .none
    
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
    
//  case let .protectMyPostsChanged(protectMyPosts):
//    state.protectPosts = protectMyPosts
//    return .none
    
  case .resetButtonTapped:
    state = .init()
    return .none
    
//  case let .sendNotificationsChanged(sendNotifications):
//    guard sendNotifications else {
//      state.sendNotifications = sendNotifications
//      return .none
//    }
//
//    return environment.userNotifications.getNotificationSettings()
//      .receive(on: environment.mainQueue)
//      .map(ConciseSettingsAction.notificationsSettingsResponse)
//      .eraseToEffect()
    
//  case let .form(update):
//    update(&state)
//    return .none
    
    // instead of binding on a closure, we could bind on a keypath and value.
//  case let .form(keyPath, value):
  case let .form(formAction):
    formAction.setter(&state)
    // this isn't possible because of PartialKeyPaths are not writeable.
//    state[keyPath: formAction.keyPath] = formAction.value
    
    // since key paths are equatable and even hashable,
    // we could even check what keypath was sent.
    if formAction.keyPath == \SettingsState.displayName {
      // TODO: truncate name
      state.displayName = String(state.displayName.prefix(16))
    } else if formAction.keyPath == \SettingsState.sendNotifications {
      // TODO: request notification authorization
      guard state.sendNotifications else {
        return .none
      }
      
      // we don't want to eagerly set the value and we need to undo setting it with keypath that is the first thing done above in this case.
      state.sendNotifications = false
      
      return environment.userNotifications.getNotificationSettings()
        .receive(on: environment.mainQueue)
        .map(ConciseSettingsAction.notificationsSettingsResponse)
        .eraseToEffect()
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
            text: viewStore.binding(
              keyPath: \.displayName,
              send: ConciseSettingsAction.form
            )
          )
          Toggle(
            "Protect my posts",
            isOn: viewStore.binding(
              keyPath: \.protectPosts,
              send: ConciseSettingsAction.form
            )
          )
        }
        
        Section(header: Text("Communications")) {
          Toggle(
            "Send notifications",
            isOn: viewStore.binding(
              keyPath: \.sendNotifications,
              send: ConciseSettingsAction.form
            )
          )
          
          if viewStore.sendNotifications {
            Picker(
              "Top posts digest",
              selection: viewStore.binding(
                keyPath: \.digest,
                send: ConciseSettingsAction.form
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
          send: ConciseSettingsAction.form
        )
      ) { alert in
        Alert(title: Text(alert.title))
      }
      .navigationTitle("Settings")
    }
  }
}

extension ViewStore {
  func binding<Value>(
    keyPath: WritableKeyPath<State, Value>,
    send action: @escaping (FormAction<State>) -> Action
  ) -> Binding<Value> where Value: Hashable {
    self.binding(
      get: { $0[keyPath: keyPath] },
      send: { action(.init(keyPath, $0)) }
    )
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
