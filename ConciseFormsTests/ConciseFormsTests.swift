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
  
}
