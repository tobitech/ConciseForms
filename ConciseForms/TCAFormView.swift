//
//  TCAFormView.swift
//  ConciseForms
//
//  Created by Oluwatobi Omotayo on 01/07/2022.
//

import SwiftUI

struct TCAFormView: View {
  
  var body: some View {
    Form {
      Section(header: Text("Profile")) {
        TextField("Display name", text: .constant(""))
        Toggle("Protect my posts", isOn: .constant(false))
      }
      
      Section(header: Text("Communications")) {
        Toggle("Send notifications", isOn: .constant(false))
        
        if true {
          Picker("Top posts digest", selection: .constant(Digest.off)) {
            ForEach(Digest.allCases, id: \.self) { digest in
              Text(digest.rawValue)
                .tag(digest)
            }
          }
        }
      }
      
      // Let's make sure we can pass data the other way from model to UI
      Button("Reset") {
        // self.viewModel.reset()
      }
    }
    .alert(item: .constant(AlertState?.none)) { alert in
      Alert(title: Text(alert.title))
    }
    .navigationTitle("Settings")
  }
}

struct TCAFormView_Previews: PreviewProvider {
  static var previews: some View {
    NavigationView {
      TCAFormView()
    }
  }
}
