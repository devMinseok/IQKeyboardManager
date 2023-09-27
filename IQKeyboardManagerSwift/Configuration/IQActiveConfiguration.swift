//
//  IQActiveConfiguration.swift
// https://github.com/hackiftekhar/IQKeyboardManager
// Copyright (c) 2013-20 Iftekhar Qurashi.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import UIKit

@available(iOSApplicationExtension, unavailable)
internal class IQActiveConfiguration {

    private let keyboardListener: IQKeyboardListener = IQKeyboardListener()
    private let textFieldViewListener: IQTextFieldViewListener = IQTextFieldViewListener()

    private var changeObservers: [AnyHashable: ConfigurationCompletion] = [:]
    private var windowObserver: IQPropertyObserver<UIView, UIWindow?>?

    @objc public enum Event: Int {
        case hide
        case show
        case change

        var name: String {
            switch self {
            case .hide:
                return "hide"
            case .show:
                return "show"
            case .change:
                return "change"
            }
        }
    }

    private var lastEvent: Event = .hide

    var rootControllerConfiguration: IQRootControllerConfiguration?

    var isReady: Bool {
        if textFieldViewInfo != nil,
           let rootControllerConfiguration = rootControllerConfiguration {
            return rootControllerConfiguration.isReady
        }
        return false
    }

    init() {
        addKeyboardListener()
        addTextFieldViewListener()
    }

    private func sendEvent() {

        if let textFieldViewInfo = textFieldViewInfo,
           let rootControllerConfiguration = rootControllerConfiguration,
           rootControllerConfiguration.isReady {
            if keyboardInfo.keyboardShowing {
                if lastEvent == .hide {
                    self.notify(event: .show, keyboardInfo: keyboardInfo, textFieldViewInfo: textFieldViewInfo)
                } else {
                    self.notify(event: .change, keyboardInfo: keyboardInfo, textFieldViewInfo: textFieldViewInfo)
                }
            } else if lastEvent != .hide {
                self.notify(event: .hide, keyboardInfo: keyboardInfo, textFieldViewInfo: textFieldViewInfo)

                self.rootControllerConfiguration = nil
                windowObserver?.invalidate()
                windowObserver = nil

            }
        }
    }

    private func updateRootController(info: IQTextFieldViewInfo?) {

        guard let info = info,
              let controller: UIViewController = info.textFieldView.iq.parentContainerViewController() else {
            if let rootControllerConfiguration = rootControllerConfiguration,
               rootControllerConfiguration.hasChanged {
                animate(alongsideTransition: {
                    rootControllerConfiguration.restore()
                }, completion: nil)
            }
            rootControllerConfiguration = nil
            return
        }

        let newConfiguration = IQRootControllerConfiguration(rootController: controller)

        if newConfiguration.rootController.view.window != rootControllerConfiguration?.rootController.view.window {

            // If there was an old configuration but windows now changed
            if let rootControllerConfiguration = rootControllerConfiguration,
               rootControllerConfiguration.hasChanged {
                animate(alongsideTransition: {
                    rootControllerConfiguration.restore()
                }, completion: nil)
            }

            rootControllerConfiguration = newConfiguration

            windowObserver?.invalidate()

            windowObserver = IQPropertyObserver(object: newConfiguration.rootController.view, keyPath: \.window, debounce: 0.1, changeHandler: { [self] _, _ in
                if let rootControllerConfiguration = rootControllerConfiguration,
                   rootControllerConfiguration.isReady {
                    if lastEvent == .show || lastEvent == .change {
                        self.notify(event: .change, keyboardInfo: keyboardInfo, textFieldViewInfo: info)
                    }
                }
            })
        }
    }
}

@available(iOSApplicationExtension, unavailable)
extension IQActiveConfiguration {

    var keyboardInfo: IQKeyboardInfo {
        return keyboardListener.keyboardInfo
    }

    private func addKeyboardListener() {
        keyboardListener.registerSizeChange(identifier: "IQActiveConfiguration", changeHandler: { [self] name, _ in
            self.sendEvent()

            if name == .didHide {
                updateRootController(info: nil)
            }
        })
    }

    public func animate(alongsideTransition transition: @escaping () -> Void, completion: (() -> Void)? = nil) {
        keyboardListener.animate(alongsideTransition: transition, completion: completion)
    }
}

@available(iOSApplicationExtension, unavailable)
extension IQActiveConfiguration {

    var textFieldViewInfo: IQTextFieldViewInfo? {
        return textFieldViewListener.textFieldViewInfo
    }

    private func addTextFieldViewListener() {
        textFieldViewListener.registerTextFieldViewChange(identifier: "IQActiveConfiguration", changeHandler: { [self] info in
            if info.name == .beginEditing {
                updateRootController(info: info)
                self.sendEvent()
            }
        })
    }
}

@available(iOSApplicationExtension, unavailable)
extension IQActiveConfiguration {

    typealias ConfigurationCompletion = (_ event: Event, _ keyboardInfo: IQKeyboardInfo, _ textFieldInfo: IQTextFieldViewInfo) -> Void

    func registerChange(identifier: AnyHashable, changeHandler: @escaping ConfigurationCompletion) {
        changeObservers[identifier] = changeHandler
    }

    func unregisterChange(identifier: AnyHashable) {
        changeObservers[identifier] = nil
    }

    private func notify(event: Event, keyboardInfo: IQKeyboardInfo, textFieldViewInfo: IQTextFieldViewInfo) {
        lastEvent = event

        for block in changeObservers.values {
            block(event, keyboardInfo, textFieldViewInfo)
        }
    }
}
