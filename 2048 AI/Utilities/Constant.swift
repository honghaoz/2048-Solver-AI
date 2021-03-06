// Copyright © 2019 ChouTi. All rights reserved.

import UIKit

class Log {
  func debug(_ s: String = "") {
    #if DEBUG
      print("DEBUG: ", s)
    #endif
  }

  func verbose(_ s: String = "") {
    #if DEBUG
      print("VERBOSE: ", s)
    #endif
  }

  func error(_ s: String = "") {
    print("ERROR: ", s)
  }
}

class Global {
  static let log = Log()
  static let verbose = Log()
  static let error = Log()

  #if DEBUG
    static let DEBUG = true
  #else
    static let DEBUG = false
  #endif
}

var log = Global.log
var verboseLog = Global.verbose
var error = Global.error

let DEBUG = Global.DEBUG

// MARK: - Device Related

var isIOS7: Bool = !isIOS8
let isIOS8: Bool = floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_7_1

var screenWidth: CGFloat { return UIScreen.main.bounds.size.width }
var screenHeight: CGFloat { return UIScreen.main.bounds.size.height }

var screenSize: CGSize { return UIScreen.main.bounds.size }
var screenBounds: CGRect { return UIScreen.main.bounds }

var isIpad: Bool { return UIDevice.current.userInterfaceIdiom == .pad }

var is3_5InchScreen: Bool { return screenHeight ~= 480.0 }
var is4InchScreen: Bool { return screenHeight ~= 568.0 }
var isIphone6: Bool { return screenHeight ~= 667.0 }
var isIphone6Plus: Bool { return screenHeight ~= 736.0 }

var is320ScreenWidth: Bool { return screenWidth ~= 320.0 }
