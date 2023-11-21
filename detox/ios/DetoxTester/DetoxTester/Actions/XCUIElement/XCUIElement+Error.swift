//
//  XCUIElement+Error.swift (DetoxTesterApp)
//  Created by Asaf Korem (Wix.com) on 2023.
//

import Foundation
import XCTest

extension XCUIElement {
  /// Represents an error caused by `XCUIElement` extensions.
  public enum Error: Swift.Error {
    /// Tried to type text into a non string value.
    case invalidKeyboardTypeActionNonStringValue

    /// Failed to focus on element with the keyboard.
    case failedToFocusKeyboardOnElement(element: XCUIElement)

    /// Failed to paste new text on text input.
    case failedToPasteNewText(onAction: String)

    /// Failed to hit an element (element is not hittable).
    case elementNotHittable(element: XCUIElement)

    /// Failed to scroll an element (element is not scrollable).
    case elementNotScrollable(element: XCUIElement)

    /// Failed to scroll to an element (failed to find the element).
    case failedToScrollToElement(element: XCUIElement)

    /// Failed to evaluate JS code on element.
    case failedToEvaluateScript(
      element: XCUIElement, host: XCUIElement, script: String, args: [String])
  }
}

extension XCUIElement.Error: CustomStringConvertible {
  public var description: String {
    switch self {
      case .invalidKeyboardTypeActionNonStringValue:
        return "Cannot type text value into a view without a string value"

      case .failedToFocusKeyboardOnElement(let element):
        return "Failed to focus on element with the keyboard (element " +
        "identifier: `\(element.cleanIdentifier)`)"

      case .failedToPasteNewText(let onAction):
        return "Failed to paste new text on text input, on action: \(onAction)"

      case .elementNotHittable(let element):
        return "Failed to hit element with identifier " +
        "`\(element.exists ? element.cleanIdentifier : element.debugDescription)`, " +
        "element is not hittable"

      case .elementNotScrollable(let element):
        return "Failed to scroll element with identifier " +
        "`\(element.exists ? element.cleanIdentifier : element.debugDescription)`, " +
        "element is not scrollable"

      case .failedToScrollToElement(let element):
        return "Failed to scroll to element with identifier " +
        "`\(element.exists ? element.cleanIdentifier : element.debugDescription)`"

      case .failedToEvaluateScript(
        element: let element,
        host: let host,
        script: let script,
        args: let args
      ):
        return "Failed to evaluate JS code on element: `\(element.debugDescription)`" +
        " with hosting web-view: `\(host.debugDescription)`, script: `\(script)`, args: `\(args)`"
    }
  }
}
