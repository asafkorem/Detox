//
//  XCUIElement+Keyboard.swift (DetoxTesterApp)
//  Created by Asaf Korem (Wix.com) on 2022.
//

import Foundation
import DetoxInvokeHandler
import XCTest

/// Extends `XCUIElement` with keyboard actions.
extension XCUIElement {
  /// Indicates whether the text field element has keyboard focus.
  public var hasKeyboardFocusOnTextField: Bool {
    logProperties()
    
    let textField = textField ?? self
    return textField.hasKeyboardFocus || textField.hasFocus
  }

  private var hasKeyboardFocus: Bool {
    return value(forKey: "hasKeyboardFocus") as? Bool ?? false
  }

  private var textField: XCUIElement? {
    return textFields.run().first
  }

  /// Taps the keyboard key with the given type.
  func tapKey(_ keyType: Action.TapKeyType) throws {
    try focusKeyboard()

    switch keyType {
      case .returnKey:
        typeText(XCUIKeyboardKey.return.rawValue)

      case  .backspaceKey:
        typeText(XCUIKeyboardKey.delete.rawValue)
    }
  }

  /// Focuses the keyboard on the element.
  func focusKeyboard() throws {
    if hasKeyboardFocus == true {
      return
    }

    coordinate(
      withNormalizedOffset: CGVector(dx: 0.9, dy: 0.9)
    ).shortPress()

    guard hasKeyboardFocus == true else {
      throw Error.failedToFocusKeyboardOnElement(element: self)
    }
  }

  /// Changes the text in the element with the given text and change type.
  func changeText(_ changeType: Action.ChangeTextType, app: XCUIApplication) throws {
    if let textField = textField {
      uiLog("found underlying text field, changing text on the text field (\(textField)")
      try textField.changeText(changeType, app: app)
      return
    }

    guard value is String else {
      throw Error.invalidKeyboardTypeActionNonStringValue
    }

    switch changeType {
      case .clear:
        try deleteText(app: app)

      case .type(let text):
        try addText(text)

      case .replace(let text):
        try deleteAndPasteText(text, app: app)
    }
  }

  /// Selects all text in the element.
  func selectAllText(app: XCUIApplication, completion: (() -> Void)?) throws {
    try focusKeyboard()

    shortPress()

    tapOnSelectAllIfPresent(app: app, completion: nil)
  }


  private func deleteText(app: XCUIApplication) throws {
    try selectAllText(app: app) { [self] in
      typeText(String(XCUIKeyboardKey.delete.rawValue))
    }
  }

  private func addText(_ text: String) throws {
    try focusKeyboard()

    typeText(text)
  }

  private func deleteAndPasteText(_ text: String, app: XCUIApplication) throws {
    UIPasteboard.general.string = text

    try selectAllText(app: app, completion: nil)
    try tapOnPasteText(app: app, completion: pressOnAllowPaste)
  }

  private func tapOnSelectAllIfPresent(app: XCUIApplication, completion: (() -> Void)?) {
    let currentValue = value as? String
    if currentValue?.isEmpty == false {
      let selectAll = app.menuItems[localize("Select All")]
      if selectAll.waitForExistence(timeout: 0.5) {
        selectAll.tap()

        if let completion = completion {
          completion()
        }
      }
    }
  }

  private func tapOnPasteText(app: XCUIApplication, completion: () -> Void) throws {
    let paste = app.menuItems[localize("Paste")]
    if paste.waitForExistence(timeout: 0.5) {
      paste.tap()
      completion()
    } else {
      throw Error.failedToPasteNewText(onAction: "paste")
    }
  }

  private func pressOnAllowPaste() {
    let allowPaste = XCUIApplication.springBoard.alerts.buttons[localize("Allow Paste")]
    if allowPaste.waitForExistence(timeout: 0.5) {
      allowPaste.tap()
    }
  }
}
