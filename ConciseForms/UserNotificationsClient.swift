//
//  UserNotificationsClient.swift
//  ConciseForms
//
//  Created by Oluwatobi Omotayo on 15/08/2022.
//

import ComposableArchitecture
import UserNotifications
import UIKit

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
