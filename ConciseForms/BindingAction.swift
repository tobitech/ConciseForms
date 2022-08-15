//
//  BindingAction.swift
//  ConciseForms
//
//  Created by Oluwatobi Omotayo on 15/08/2022.
//

import ComposableArchitecture
import SwiftUI

struct BindingAction<Root>: Equatable {
  
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
  
  static func == (lhs: BindingAction<Root>, rhs: BindingAction<Root>) -> Bool {
    lhs.keyPath == rhs.keyPath && lhs.value == rhs.value
  }
}

extension Reducer {
  func binding(
    // case paths just like key paths (for structs) allows us to isolate
    // certain properties in an enum
    action formAction: CasePath<Action, BindingAction<State>>
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


extension ViewStore {
  func binding<Value>(
    keyPath: WritableKeyPath<State, Value>,
    send action: @escaping (BindingAction<State>) -> Action
  ) -> Binding<Value> where Value: Hashable {
    self.binding(
      get: { $0[keyPath: keyPath] },
      send: { action(.init(keyPath, $0)) }
    )
  }
}


// here we are overloading the pattern matching operator in swift.
// based on the argument provided,
// you get to say true/false does this pattern match.
// if it matches you go into the case of the switch
// if it doesn't you go on to the next case.
// in our case the pattern we want to match is keypath
func ~= <Root, Value> (
  keyPath: WritableKeyPath<Root, Value>,
  formAction: BindingAction<Root>
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
