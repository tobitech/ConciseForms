//
//  ConciseFormsTests.swift
//  ConciseFormsTests
//
//  Created by Oluwatobi Omotayo on 01/07/2022.
//

import ComposableArchitecture
import XCTest
@testable import ConciseForms

class ConciseFormsTests: XCTestCase {
  
  let scheduler = DispatchQueue.immediate.eraseToAnyScheduler()
  
  func testBasics() throws {
    let store = TestStore(
      initialState: SettingsState(),
      reducer: settingsReducer,
      environment: SettingsEnvironment(
        mainQueue: scheduler,
        userNotifications: UserNotificationsClient(
          getNotificationSettings: { fatalError() },
          registerForRemoteNotifications: { fatalError() },
          requestAuthorisation: { _ in fatalError() }
        )
      )
    )
    
    store.assert(
      .send(.displayNameChanged("oluwatobi")) {
        $0.displayName = "oluwatobi"
      },
      .send(.displayNameChanged("oluwatobi omotayo, israel")) {
        $0.displayName = "oluwatobi omotay"
      },
      .send(.protectMyPostsChanged(true)) {
        $0.protectPosts = true
      },
      .send(.digestChanged(.weekly)) {
        $0.digest = .weekly
      }
    )
  }
  
  func testNotifications_HappyPath() {
    
    var didRegisterForRemoteNotifications = false
    
    let store = TestStore(
      initialState: SettingsState(),
      reducer: settingsReducer,
      environment: SettingsEnvironment(
        mainQueue: scheduler,
        userNotifications: UserNotificationsClient(
          getNotificationSettings: {
            .init(value: UserNotificationsClient.Settings(authorizationStatus: .notDetermined))
          },
          registerForRemoteNotifications: {
            .fireAndForget {
              didRegisterForRemoteNotifications = true
            }
          },
          requestAuthorisation: { _ in
              .init(value: true)
          }
        )
      )
    )
    
    store.assert(
      .send(.sendNotificationsChanged(true)),
      .receive(.notificationsSettingsResponse(.init(authorizationStatus: .notDetermined))) {
        $0.sendNotifications = true
      },
      .receive(.authorizationResponse(.success(true)))
    )
    
    XCTAssertTrue(didRegisterForRemoteNotifications)
  }
}
