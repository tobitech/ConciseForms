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
  case notificationsSettingsResponse(UserNotificationsClient.Settings)
  case resetButtonTapped
  
  case form(FormAction<SettingsState>)
}

struct FormAction<Root>: Equatable {
  
  let keyPath: PartialKeyPath<Root>
  let value: AnyHashable
  let setter: (inout Root) -> Void
  
  init<Value>(
    _ keyPath: WritableKeyPath<Root, Value>,
    _ value: Value
  ) where Value: Hashable {
    self.keyPath = keyPath
    self.value = AnyHashable(value)
    self.setter = { $0[keyPath: keyPath] = value }
  }
  
  // assuming anything that returns Self is an initialise somehow.
  static func set<Value>(
    _ keyPath: WritableKeyPath<Root, Value>,
    _ value: Value
  ) -> Self where Value: Hashable {
    .init(keyPath, value)
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
    
  case .resetButtonTapped:
    state = .init()
    return .none
    
  case .form(\.displayName):
    state.displayName = String(state.displayName.prefix(16))
    return .none
    
  case .form(\.sendNotifications):
    guard state.sendNotifications else {
      return .none
    }
    
    state.sendNotifications = false
    
    return environment.userNotifications.getNotificationSettings()
      .receive(on: environment.mainQueue)
      .map(ConciseSettingsAction.notificationsSettingsResponse)
      .eraseToEffect()

  case .form:
    return .none
  }
}
  .form(action: /ConciseSettingsAction.form)

// based on the argument provided,
// you get to say true/false does this pattern match.
// if it matches you go into the case of the switch
// if it doesn't you go on to the next case.
// in our case the pattern we want to match is keypath
func ~= <Root, Value> (
  keyPath: WritableKeyPath<Root, Value>,
  formAction: FormAction<Root>
) -> Bool {
  formAction.keyPath == keyPath
}

// it's similar to this
//func foo() {
//  switch 42 {
//  case 10...:
//    print("10 or more")
//  default:
//    break
//  }
//
//  (1...10) ~= 42
//}

extension Reducer {
  func form(
    // case paths just like key paths (for structs) allows us to isolate
  // certain properties in an enum
    action formAction: CasePath<Action, FormAction<State>>
  ) -> Self {
    Self { state, action, environment in
      guard let formAction = formAction.extract(from: action) else {
        return self.run(&state, action, environment)
      }
      
      formAction.setter(&state)
      
      return self.run(&state, action, environment)
    }
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
            Toggle(
              "Mobile",
              isOn: viewStore.binding(
                keyPath: \.sendMobileNotifications,
                send: ConciseSettingsAction.form
              )
            )
            
            Toggle(
              "Email",
              isOn: viewStore.binding(
                keyPath: \.sendEmailNotifications,
                send: ConciseSettingsAction.form
              )
            )
            
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
