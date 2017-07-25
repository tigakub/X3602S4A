//
//  X360Data.swift
//  X3602S4A
//
//  Created by Edward Janne on 7/3/17.
//  Copyright © 2017 DrMechano. All rights reserved.
//

import Foundation

public struct X360Data {
    var dpadUp = FlaggedVar<UInt8>(val:0)
    var dpadDown = FlaggedVar<UInt8>(val:0)
    var dpadLeft = FlaggedVar<UInt8>(val:0)
    var dpadRight = FlaggedVar<UInt8>(val:0)
    var start = FlaggedVar<UInt8>(val:0)
    var back = FlaggedVar<UInt8>(val:0)
    var stickLeftClick = FlaggedVar<UInt8>(val:0)
    var stickRightClick = FlaggedVar<UInt8>(val:0)
    var bumperLeft = FlaggedVar<UInt8>(val:0)
    var bumperRight = FlaggedVar<UInt8>(val:0)
    var guide = FlaggedVar<UInt8>(val:0)
    var dummy1 = FlaggedVar<UInt8>(val:0)
    var a = FlaggedVar<UInt8>(val:0)
    var b = FlaggedVar<UInt8>(val:0)
    var x = FlaggedVar<UInt8>(val:0)
    var y = FlaggedVar<UInt8>(val:0)
    var triggerLeft = FlaggedVar<UInt8>(val:0)
    var triggerRight = FlaggedVar<UInt8>(val:0)
    var stickLeftX = FlaggedVar<Int16>(val:0)
    var stickLeftY = FlaggedVar<Int16>(val:0)
    var stickRightX = FlaggedVar<Int16>(val:0)
    var stickRightY = FlaggedVar<Int16>(val:0)
    var dummy2 = FlaggedVar<UInt32>(val:0)
    var dummy3 = FlaggedVar<UInt16>(val:0)
}

