//
//  ConciseTCAFormView.swift
//  ConciseForms
//
//  Created by Oluwatobi Omotayo on 01/07/2022.
//

import ComposableArchitecture
import SwiftUI

struct SettingsState: Equatable {
  @BindableState var alert: AlertState? = nil
  @BindableState var digest = Digest.off
  @BindableState var displayName = ""
  var isLoading = false
  @BindableState var protectPosts = false
  @BindableState var sendNotifications = false
  @BindableState var sendMobileNotifications = false
  @BindableState var sendEmailNotifications = false
}

enum SettingsAction: BindableAction {
  case authorizationResponse(Result<Bool, NSError>)
  case binding(BindingAction<SettingsState>)
  case notificationsSettingsResponse(UserNotificationsClient.Settings)
  case resetButtonTapped
  
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
    
  case .binding(\.$displayName):
    state.displayName = String(state.displayName.prefix(16))
    return .none
    
  case .binding(\.$sendNotifications):
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
// higher-order reducer just like debug, logging.
.binding()


struct ConciseTCAFormView: View {
  
  let store: Store<SettingsState, SettingsAction>
  
  var body: some View {
    WithViewStore(self.store) { viewStore in
      Form {
        Section(header: Text("Profile")) {
          TextField(
            "Display name",
            text: viewStore.binding(\.$displayName)
          )
          Toggle(
            "Protect my posts",
            isOn: viewStore.binding(\.$protectPosts)
          )
        }
        
        Section(header: Text("Communications")) {
          Toggle(
            "Send notifications",
            isOn: viewStore.binding(\.$sendNotifications)
          )
          
          if viewStore.sendNotifications {
            Toggle(
              "Mobile",
              isOn: viewStore.binding(\.$sendMobileNotifications)
            )
            
            Toggle(
              "Email",
              isOn: viewStore.binding(\.$sendEmailNotifications)
            )
            
            Picker(
              "Top posts digest",
              selection: viewStore.binding(\.$digest)
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
        item: viewStore.binding(\.$alert)
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
