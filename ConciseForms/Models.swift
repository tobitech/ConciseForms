//
//  Models.swift
//  ConciseForms
//
//  Created by Oluwatobi Omotayo on 15/08/2022.
//

import Foundation

// In production we might need that AnyEquatable erased type
// the library shouldn't force you to make something hashable if you don't want to.
struct AlertState: Equatable, Hashable, Identifiable {
  var title: String
  var id: String { self.title }
}

enum Digest: String, CaseIterable {
  case off
  case daily
  case weekly
  case monthly
}
