//
//  DetoxManager.swift
//  Detox
//
//  Created by Leo Natan (Wix) on 5/22/20.
//  Copyright © 2020 Wix. All rights reserved.
//

import UIKit
import DetoxSync
import LNViewHierarchyDumper
import WebKit

fileprivate let recordingManager : DetoxInstrumentsManager = {
	return DetoxInstrumentsManager()
}()

fileprivate let log = DetoxLog(category: "DetoxManager")

@objc(DTXDetoxManager)
public class DetoxManager : NSObject, WebSocketDelegate {
	private let webSocket : WebSocket
	private var isReady = false

	@objc(sharedManager)
	public static var shared : DetoxManager = {
		return DetoxManager()
	}()

	override init() {
		webSocket = WebSocket()

		super.init()

		webSocket.delegate = self

		NotificationCenter.default.addObserver(self, selector: #selector(appDidLaunch(_:)), name: UIApplication.didFinishLaunchingNotification, object: nil)
		NotificationCenter.default.addObserver(self, selector: #selector(appDidEnterBackground(_:)), name: UIApplication.didEnterBackgroundNotification, object: nil)

		if let recordingPath = UserDefaults.standard.string(forKey: "recordingPath") {
			var props : [String: Any] = ["recordingPath": recordingPath]
			if let _ = UserDefaults.standard.string(forKey: "samplingInterval") {
				let samplingIntervalDouble = UserDefaults.standard.double(forKey: "samplingInterval")
				props["samplingInterval"] = samplingIntervalDouble
			}

			self.handlePerformanceRecording(props: props, isFromLaunch: true, completionHandler: nil)
		}
	}

	private func safeSend(action: String, params: [String: Any] = [:], messageId: NSNumber) {
		log.info("safe sending requested: \(action)")
		DTXSyncManager.enqueueMainQueueIdleClosure {
			log.info("safe sending on the main-thread: \(action)")
			self.webSocket.sendAction(action, params: params, messageId: messageId)
			log.info("did safe sending for action: \(action)")
		}
	}

	@objc
	private func appDidLaunch(_ note: Notification) {
		DTXSyncManager.enqueueMainQueueIdleClosure {
			self.isReady = true
			//			self.sendGeneralReadyMessage()
		}
	}

	@objc
	private func appDidEnterBackground(_ note: Notification) {
		var bgTask : UIBackgroundTaskIdentifier! = nil
		bgTask = UIApplication.shared.beginBackgroundTask(withName: "DetoxBackground") {
			UIApplication.shared.endBackgroundTask(bgTask)
		}
	}

	private func start() {
		start(synchronizationSettings: nil)
	}

	@objc(startWithSynchronizationSettings:)
	public func start(synchronizationSettings settings: [String: Any]?) {
		if let settings = settings {
			setSynchronizationSettings(settings, messageId: nil)
		}

		let options = UserDefaults.standard
		let detoxServer = options.string(forKey: "detoxTestTargetServer") ?? "ws://localhost:8997"
		let detoxSessionId = options.string(forKey: "detoxSessionId") ?? Bundle.main.bundleIdentifier!

		webSocket.connect(toServer: URL(string: detoxServer)!, withSessionId: detoxSessionId)
	}

	private func handlePerformanceRecording(props: [String: Any]?, isFromLaunch launch: Bool, completionHandler: (() -> Void)?) {
		var completionBlocked = false

		if let props = props, let _ = props["recordingPath"] as? String {
			if launch {
				recordingManager.continueRecording(withConfiguration: props)
			} else {
				recordingManager.startRecording(withConfiguration: props)
			}
		} else {
			completionBlocked = true
			recordingManager.stopRecording { error in
				if let error = error {
					log.error("Error while stopping recording: \(error)")
				}

				if let completionHandler = completionHandler {
					if Thread.isMainThread {
						completionHandler()
					} else {
						DispatchQueue.main.async {
							completionHandler()
						}
					}
				}
			}
		}

		if completionBlocked == false {
			completionHandler?()
		}
	}

	private func stopAndCleanupRecording() {
		handlePerformanceRecording(props: nil, isFromLaunch: false, completionHandler: nil)
	}


	@objc(notifyOnCrashWithDetails:)
	public func notifyOnCrash(details: [String: Any]) {
		log.error("App crashed: \(details["errorDetails"]!)")

		let semaphore = DispatchSemaphore(value: 1)

		recordingManager.stopRecording { error in
			semaphore.signal()
		}

		semaphore.wait()

		webSocket.sendAction("AppWillTerminateWithError", params: details, messageId: -10000)
	}

	private func setSynchronizationSettings(_ settings: [String: Any], messageId: NSNumber?) {
		settings.forEach { key, value in
			switch key {
				case "maxTimerWait":
					let maxTimerWait = (value as! NSNumber).doubleValue / 1000
					DTXSyncManager.maximumAllowedDelayedActionTrackingDuration = maxTimerWait
					DTXSyncManager.maximumTimerIntervalTrackingDuration = maxTimerWait
					return
				case "waitForDebugger":
					Thread.sleep(forTimeInterval: Double(truncating: value as! NSNumber) / 1000)
					return
				case "blacklistURLs":
					DTXSyncManager.urlBlacklist = value as! [String]
					DTXSyncManager.urlBlacklist = value as! [String]
					return
				case "enabled":
					DTXSyncManager.synchronizationDisabled = !((value as! NSNumber).boolValue)
					return
				default:
					log.error("Unknown synchronization setting received: \(key)")
					return
			}
		}
		//
		//		if let messageId = messageId {
		//			safeSend(action: "setSyncSettingsDone", messageId: messageId)
		//		}
	}

	// MARK: WebSocketDelegate

	func webSocketDidConnect(_ webSocket: WebSocket) {
		if ReactNativeSupport.isReactNativeApp {
			isReady = true
			//			sendGeneralReadyMessage()
		}
	}

	func webSocket(didFailWith error: Error) {
		log.error("Web socket failed to connect with error: \(error.localizedDescription)")

		DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: self.start)
	}

	func webSocket(didReceiveAction type: String, params: [String : Any], messageId: NSNumber) {
		switch type {
			case "reloadReactNative":
				guard ReactNativeSupport.isReactNativeApp else {
					self.safeSend(action: "reactNativeDidReload", messageId: messageId)
					return
				}

				DTXSyncManager.enqueueMainQueueIdleClosure {
					ReactNativeSupport.reloadApp()
				}

				ReactNativeSupport.waitForReactNativeLoad {
					self.safeSend(action: "reactNativeDidReload", messageId: messageId)
				}

			case "waitUntilReady":
				log.info("waiting until ready...")
				self.safeSend(action: "isReady", messageId: messageId)

			case "shakeDevice":
				DTXSyncManager.enqueueMainQueueIdleClosure {
					UIDevice.dtx_shake()
					self.safeSend(action: "deviceDidShake", messageId: messageId)
				}

			case "getAttributes":
				let elementIDsAndFrames = params["elementIDsAndFrames"] as! [[String: Any]]
				let elements: [UIView] = elementIDsAndFrames.map { element in
					let targetIdentifier = element["identifier"] as! String
					let targetFrame = element["frame"] as! [NSNumber]

					return findElement(
						byIdentifier: targetIdentifier,
						andFrame: targetFrame
					)
				}

				self.safeSend(
					action: "attributes",
					params: [
						"elements": elements.map { $0.dtx_attributes }
					],
					messageId: messageId
				)

			case "findElementsByText":
				DTXSyncManager.enqueueMainQueueIdleClosure {
					let text = params["text"] as! String
					let isRegex = params["isRegex"] as! Bool

					let predicate = NSPredicate { evaluatedObject, _ in
						guard let evaluatedObject = evaluatedObject as? NSObject else {
							return false
						}

						let evaluatedText = evaluatedObject.dtx_text
						return isRegex ? evaluatedText.matchesJSRegex(to: text) : evaluatedText == text
					}

					let array = UIView.dtx_findViewsInKeySceneWindows(passing: predicate) as! [UIView]
					let mappedArray = array.compactMap { element in
						var currentElement = element
						while let superview = currentElement.superview, superview.isAccessibilityElement {
							currentElement = superview
						}

						return currentElement.isAccessibilityElement ? currentElement : nil
					}

					self.safeSend(
						action: "elementsDidFound",
						params: [
							"elementsIDsAndFrames":
								mappedArray.map { element in
									let frameInScreen = UIAccessibility.convertToScreenCoordinates(element.bounds, in: element)

									return [
										"identifier": element.accessibilityIdentifier!,
										"frame": NSCoder.string(for: frameInScreen)
									]
								}
						],
						messageId: messageId
					)
				}

			case "findElementsByType":
				DTXSyncManager.enqueueMainQueueIdleClosure {
					let typeString = params["type"] as! String
					let expectedClass: AnyClass? = NSClassFromString(typeString)
					let expectedProtocol: Protocol? = NSProtocolFromString(typeString)

					let predicate = NSPredicate { evaluatedObject, _ in
						guard let evaluatedObject = evaluatedObject as? AnyObject else {
							return false
						}

						if let expectedClass = expectedClass {
							return evaluatedObject.isKind(of: expectedClass)
						} else if let expectedProtocol = expectedProtocol {
							return evaluatedObject.conforms(to: expectedProtocol)
						} else {
							return false
						}
					}

					let array = UIView.dtx_findViewsInKeySceneWindows(passing: predicate) as! [UIView]
					let mappedArray = array.compactMap { element in
						var currentElement = element
						while let superview = currentElement.superview, superview.isAccessibilityElement {
							currentElement = superview
						}

						return currentElement.isAccessibilityElement ? currentElement : nil
					}

					self.safeSend(
						action: "elementsDidFound",
						params: [
							"elementsIDsAndFrames":
								mappedArray.map { element in
									let frameInScreen = UIAccessibility.convertToScreenCoordinates(element.bounds, in: element)

									return [
										"identifier": element.accessibilityIdentifier!,
										"frame": NSCoder.string(for: frameInScreen)
									]
								}
						],
						messageId: messageId
					)
				}

			case "findElementsByTraits":
				DTXSyncManager.enqueueMainQueueIdleClosure {
					let traitsStrings = params["traits"] as! [String]

					var traits: UIAccessibilityTraits = .none
					let traitStringToTrait: [String: UIAccessibilityTraits] = [
						"none": .none,
						"button": .button,
						"link": .link,
						"image": .image,
						"searchField": .searchField,
						"keyboardKey": .keyboardKey,
						"staticText": .staticText,
						"header": .header,
						"tabBar": .tabBar,
						"summaryElement": .summaryElement,
						"selected": .selected,
						"notEnabled": .notEnabled,
						"adjustable": .adjustable,
						"allowsDirectInteraction": .allowsDirectInteraction,
						"updatesFrequently": .updatesFrequently,
						"causesPageTurn": .causesPageTurn,
						"playsSound": .playsSound,
						"startsMediaSession": .startsMediaSession
					]

					traitsStrings.forEach { traits.insert(traitStringToTrait[$0]!) }

					let predicate = NSPredicate { evaluatedObject, _ in
						guard let evaluatedObject = evaluatedObject as? AnyObject else {
							return false
						}

						return evaluatedObject.isAccessibilityElement == true &&
						(evaluatedObject.accessibilityTraits!.rawValue & traits.rawValue) == traits.rawValue
					}

					let array = UIView.dtx_findViewsInKeySceneWindows(passing: predicate) as! [UIView]
					let mappedArray = array.compactMap { element in
						var currentElement = element
						while let superview = currentElement.superview, superview.isAccessibilityElement {
							currentElement = superview
						}

						return currentElement.isAccessibilityElement ? currentElement : nil
					}

					self.safeSend(
						action: "elementsDidFound",
						params: [
							"elementsIDsAndFrames":
								mappedArray.map { element in
									let frameInScreen = UIAccessibility.convertToScreenCoordinates(element.bounds, in: element)

									return [
										"identifier": element.accessibilityIdentifier!,
										"frame": NSCoder.string(for: frameInScreen)
									]
								}
						],
						messageId: messageId
					)
				}

			case "requestCurrentStatus":
				log.info("requesting current status")
				DTXSyncManager.status { status in
					self.webSocket.sendAction(
						"currentStatusResult",
						params: ["messageId": messageId, "status": status],
						messageId: messageId
					)
				}

			case "deliverPayload":
				let delay = (params["delayPayload"] as? Bool) ?? false

				let closure : () -> Void
				let sendDoneAction : () -> Void = {
					self.safeSend(action: "didDeliverPayload", messageId: messageId)
				}

				if let urlParam = params["url"] as? String {
					guard let urlToOpen = URL(string: urlParam) else {
						fatalError("Invalid URL")
					}

					var options : [UIApplication.LaunchOptionsKey: Any] = [UIApplication.LaunchOptionsKey.url: urlToOpen]
					if let sourceApp = params["sourceApp"] as? String {
						options[UIApplication.LaunchOptionsKey.sourceApplication] = sourceApp
					}

					closure = {
						DetoxAppDelegateProxy.shared.dispatch(openURL: urlToOpen, options: options, delayUntilActive: delay)
						sendDoneAction()
					}
				} else if let notificationParam = params["detoxUserNotificationDataURL"] as? String {
					let userNotificationDataURL = URL(fileURLWithPath: notificationParam)

					closure = {
						DetoxAppDelegateProxy.shared.dispatch(userNotificationFrom: userNotificationDataURL, delayUntilActive: delay)
						sendDoneAction()
					}
				} else if let activityParam = params["detoxUserActivityDataURL"] as? String {
					let userActivityDataURL = URL(fileURLWithPath: activityParam)

					closure = {
						DetoxAppDelegateProxy.shared.dispatch(userActivityFrom: userActivityDataURL, delayUntilActive: delay)
						sendDoneAction()
					}
				}
				else
				{
					fatalError("Unknown payload received")
				}

				guard delay == false else {
					closure()
					return
				}

				DTXSyncManager.enqueueMainQueueIdleClosure(closure)
				return

			case "setDatePicker":
				let targetIdentifier = params["elementID"] as! String
				let targetFrame = params["elementFrame"] as! [NSNumber]

				let targetElement = findElement(
					byIdentifier: targetIdentifier,
					andFrame: targetFrame
				) as! UIDatePicker

				let timeIntervalSince1970 = (params["timeIntervalSince1970"] as! NSNumber).doubleValue
				targetElement.dtx_adjust(to: .init(timeIntervalSince1970: timeIntervalSince1970))
				// TODO: why is not the same??
				//				targetElement.setDate(.init(timeIntervalSince1970: timeIntervalSince1970), animated: true)

				self.safeSend(
					action: "didSetDatePicker",
					messageId: messageId
				)

			case "performAccessibilityAction":
				let targetIdentifier = params["elementID"] as! String
				let targetFrame = params["elementFrame"] as! [NSNumber]

				let targetElement = findElement(
					byIdentifier: targetIdentifier,
					andFrame: targetFrame
				)

				let actionName = params["actionName"] as! String
				guard let action = targetElement.accessibilityCustomActions?.first(where: { $0.name == actionName }) else {
					self.safeSend(
						action: "didPerformAccessibilityAction",
						params: [
							"didFound": false
						],
						messageId: messageId
					)

					return
				}

				action.target?.performSelector(onMainThread: action.selector, with: action, waitUntilDone: true)

				self.safeSend(
					action: "didPerformAccessibilityAction",
					params: [
						"didFound": true
					],
					messageId: messageId
				)

			case "setSyncSettings":
				let maxTimerWait = params["maxTimerWait"] as? NSNumber
				let blacklistURLs = params["blacklistURLs"] as? [String]
				let disabled = params["disabled"] as? NSNumber

				if let maxTimerWait = maxTimerWait {
					DTXSyncManager.maximumAllowedDelayedActionTrackingDuration = maxTimerWait.doubleValue
					DTXSyncManager.maximumTimerIntervalTrackingDuration = maxTimerWait.doubleValue
				}

				if let blacklistURLs = blacklistURLs {
					DTXSyncManager.urlBlacklist = blacklistURLs
					DTXSyncManager.urlBlacklist = blacklistURLs
				}

				if let disabled = disabled {
					DTXSyncManager.synchronizationDisabled = disabled.boolValue
				}

				self.safeSend(
					action: "didSetSyncSettings",
					messageId: messageId
				)

			case "evaluateJavaScript":
				let webViewIdentifier = params["webViewIdentifier"] as! String
				let webViewFrame = params["webViewFrame"] as! [NSNumber]

				let script = params["script"] as! String

				let webView = findElement(
					byIdentifier: webViewIdentifier,
					andFrame: webViewFrame
				) as! WKWebView

				log.info("evaluating JS script: \(script) on web-view \(webView.debugDescription)")

				var observation: NSKeyValueObservation?
				observation = webView.observe(
					\.isLoading,
					 options: [.new, .old, .initial]
				) { [weak self] (object, change) in
					if change.newValue == false {
						observation?.invalidate()

						webView.evaluateJavaScript(script, completionHandler: { (result, error) in
							var params: [String: String] = [:]
							params["result"] = result as? String
							params["error"] = error?.localizedDescription

							self?.safeSend(
								action: "didEvaluateJavaScript",
								params: params,
								messageId: messageId
							)
						})
					}
				}

			case "longPressAndDrag":
				let elementIdentifier = params["elementID"] as! String
				let elementFrame = params["elementFrame"] as! [NSNumber]

				let targetIdentifier = params["targetElementID"] as! String
				let targetElementFrame = params["targetElementFrame"] as! [NSNumber]

				let duration = params["duration"] as! NSNumber
				let normalizedPositionX = params["normalizedPositionX"] as? NSNumber
				let normalizedPositionY = params["normalizedPositionY"] as? NSNumber
				let normalizedTargetPositionX = params["normalizedTargetPositionX"] as? NSNumber
				let normalizedTargetPositionY = params["normalizedTargetPositionY"] as? NSNumber
				let speedParam = params["speed"] as? String
				let holdDurationParam = params["holdDuration"] as? NSNumber


				let element = findElement(
					byIdentifier: elementIdentifier,
					andFrame: elementFrame
				)

				let target = findElement(
					byIdentifier: targetIdentifier,
					andFrame: targetElementFrame
				)

				let normalizedStartingPoint = getNormalizedPoint(xPosition: normalizedPositionX, yPosition: normalizedPositionY)
				let normalizedTargetingPoint = getNormalizedPoint(xPosition: normalizedTargetPositionX, yPosition: normalizedTargetPositionY)

				var speed = CGFloat(0.5)
				if let speedString = speedParam {
					switch speedString {
						case "slow":
							speed = 0.1
							break;
						case "fast":
							speed = 0.5
							break
						default:
							fatalError("Unknown speed")
					}
				}

				let holdDuration : TimeInterval
				if let param = holdDurationParam?.doubleValue {
					holdDuration = param.toSeconds()
				} else {
					holdDuration = 1.0
				}

				element.dtx_longPress(
					at: normalizedStartingPoint,
					duration: duration.doubleValue,
					target: target,
					normalizedTargetPoint: normalizedTargetingPoint,
					velocity: speed,
					lastHoldDuration: holdDuration
				)

				self.safeSend(
					action: "didLongPressAndDrag",
					messageId: messageId
				)

			case "verifyVisibility":
				let targetIdentifier = params["elementID"] as! String
				let targetFrame = params["elementFrame"] as! [NSNumber]
				let threshold = params["threshold"] as! NSNumber

				let targetElement = findElement(byIdentifier: targetIdentifier, andFrame: targetFrame)

				self.safeSend(
					action: "didVerifyVisibility",
					params: [
						"isVisible": targetElement.dtx_isVisible(withPercent: threshold)
					],
					messageId: messageId
				)

			case "verifyText":
				let targetIdentifier = params["elementID"] as! String
				let targetFrame = params["elementFrame"] as! [NSNumber]
				let text = params["text"] as! String

				let targetElement = findElement(byIdentifier: targetIdentifier, andFrame: targetFrame)

				log.error("element: \(targetElement), element text: \(targetElement.dtx_text)")

				self.safeSend(
					action: "didVerifyText",
					params: [
						"hasText": targetElement.dtx_text == text
					],
					messageId: messageId
				)

			case "isElementFocused":
				let targetIdentifier = params["elementID"] as! String
				let targetFrame = params["elementFrame"] as! [NSNumber]
				let targetElement = findElement(byIdentifier: targetIdentifier, andFrame: targetFrame)

				let isElementFocused = targetElement.dtx_isFocused()
				log.error("element: \(targetElement), is focused: \(isElementFocused)")

				self.safeSend(
					action: "didElementFocusCheck",
					params: [
						"isFocused": isElementFocused
					],
					messageId: messageId
				)

			case "setRecordingState":
				handlePerformanceRecording(props: params, isFromLaunch: false) {
					self.safeSend(action: "didSetRecordingState", messageId: messageId)
				}
				return

			case "captureViewHierarchy":
				let urlString = params["viewHierarchyURL"] as? String

				let url = (urlString != nil) ?
				URL(fileURLWithPath: urlString!) :
				URL(fileURLWithPath: NSTemporaryDirectory())
					.appendingPathComponent("\(NSUUID().uuidString).viewhierarchy")

				precondition(url.lastPathComponent.hasSuffix(".viewhierarchy"), "Provided view Hierarchy URL is not in the expected format, ending with “.viewhierarchy”")
				var errorParam: String?
				if UserDefaults.standard.bool(forKey: "detoxDisableHierarchyDump") == false {
					do {
						try LNViewHierarchyDumper.shared.dumpViewHierarchy(to: url)
					} catch {
						errorParam = error.localizedDescription
					}
				} else {
					errorParam = "User ran process with -detoxDisableHierarchyDump YES"
				}

				self.safeSend(
					action: "didCaptureViewHierarchy",
					params: errorParam != nil ? ["error": errorParam!] : ["path": url.path],
					messageId: messageId
				)

			default:
				log.error("Unknown action type received: \(type)")
				fatalError("Unknown action type received: \(type)")
		}
	}

	func findElement(byIdentifier identifier: String, andFrame frame: [NSNumber]) -> UIView {
		var matchingFrames = [String: CGRect]()
		let predicate = NSPredicate { evaluatedObject, _ in
			guard
				let element = evaluatedObject as? UIView
			else {
				return false
			}

			let elementIdentifier = element.accessibilityIdentifier

			let origin = element.convert(CGPointZero, to: nil)

			let evaluatedFrame = CGRect(origin: origin, size: element.frame.size)
			if elementIdentifier == identifier {
				matchingFrames[elementIdentifier!] = evaluatedFrame
				return true
			}

			return false
		}

		let matchingViews: [UIView] =
		UIView.dtx_findViewsInKeySceneWindows(passing: predicate) as! [UIView]

		guard matchingViews.count > 0 else {
			fatalError("Failed to connect XCUIElement with source UIView with " +
								 "identifier: `\(identifier)` and frame: `\(frame)`. " +
								 "Found UIViews: \(matchingFrames.debugDescription)")
		}

		// There's some instability between the element's size and the rendered size.
		return matchingViews.sorted {
			let frameRect = CGRect(
				x: frame[0].doubleValue,
				y: frame[1].doubleValue,
				width: frame[2].doubleValue,
				height: frame[3].doubleValue
			)

			return rectIntersectionRatio(r1: $0.frame, r2: frameRect) >
			rectIntersectionRatio(r1: $1.frame, r2: frameRect)
		}.first!
	}

	private func rectIntersectionRatio(r1:CGRect, r2:CGRect) -> CGFloat {
		if (r1.intersects(r2)) {
			let interRect = r1.intersection(r2);

			return (
				(interRect.width * interRect.height) /
				(((r1.width * r1.height) + (r2.width * r2.height)) / 2.0)
			)
		}

		return 0;
	}

	func getNormalizedPoint(xPosition: NSNumber?, yPosition: NSNumber?) -> CGPoint {
		let xPos, yPos: Double

		if let pos = xPosition?.doubleValue, pos.isNaN == false {
			xPos = pos
		} else {
			xPos = Double.nan
		}

		if let pos = yPosition?.doubleValue, pos.isNaN == false {
			yPos = pos
		} else {
			yPos = Double.nan
		}

		return CGPoint(x: xPos, y: yPos)
	}

	func webSocket(didCloseWith reason: String?) {
		if let reason = reason {
			log.error("Web socket closed with reason: \(reason)")
		} else {
			log.error("Web socket closed")
		}

		stopAndCleanupRecording()
		DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: self.start)
	}
}
