//
//  MessageBuilder+webPredicate.swift (DetoxInvokeHandler)
//  Created by Asaf Korem (Wix.com) on 2023.
//

import Foundation

/// Builders for web-elements predicates.
extension MessageBuilder {
  func webAt(index: UInt) -> Self {
    message["webAtIndex"] = index
    return self
  }

  func setIdWebPredicate(_ value: String) -> Self {
    return setWebPredicate("id", value)
  }

  func setNameWebPredicate(_ value: String) -> Self {
    return setWebPredicate("name", value)
  }

  func setClassNameWebPredicate(_ value: String) -> Self {
    return setWebPredicate("class", value)
  }

  func setCssSelectorWebPredicate(_ value: String) -> Self {
    return setWebPredicate("css", value)
  }

  func setLabelWebPredicate(_ value: String) -> Self {
    return setWebPredicate("label", value)
  }

  func setValueWebPredicate(_ value: String) -> Self {
    return setWebPredicate("value", value)
  }

  func setXpathWebPredicate(_ value: String) -> Self {
    return setWebPredicate("xpath", value)
  }

  func setHrefWebPredicate(_ value: String) -> Self {
    return setWebPredicate("href", value)
  }

  func setHrefContainsWebPredicate(_ value: String) -> Self {
    return setWebPredicate("hrefContains", value)
  }

  func setTagWebPredicate(_ value: String) -> Self {
    return setWebPredicate("tag", value)
  }

  func setTypeWebPredicate(_ value: String) -> Self {
    return setWebPredicate("accessibilityType", value)
  }

  fileprivate func setWebPredicate(_ type: String, _ value: String) -> Self {
    let webPredicate: [String: AnyHashable] = [
      "type": type,
      "value": value
    ]
    message["webPredicate"] = webPredicate
    return self
  }
}
