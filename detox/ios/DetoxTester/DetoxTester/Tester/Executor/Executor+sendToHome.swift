//
//  Executor+sendToHome.swift (DetoxTesterApp)
//  Created by Asaf Korem (Wix.com) on 2023.
//

import Foundation

/// Extends the Executor with handler for launching the home screen.
extension Executor {
  /// Opens the iOS home screen.
  func sendToHome(messageId: NSNumber) {
    XCUIDevice.shared.press(.home)
    sendAction(.reportSendToHomeDone, messageId: messageId)
  }
}
