//
//  X360Error.swift
//  X3602S4A
//
//  Created by Edward Janne on 7/3/17.
//  Copyright © 2017 DrMechano. All rights reserved.
//

import Foundation

enum X360Error : Error {
    case registryIDFailure(result:kern_return_t)
    case registryNameFailure(result:kern_return_t)
    case devicePlugInFailure(result:kern_return_t)
    case deviceNubFailure(result:kern_return_t)
    case productIDFailure(result:kern_return_t)
    case vendorIDFailure(result:kern_return_t)
    case numConfigFailure(result:kern_return_t)
    case configDescriptorFailure(result:kern_return_t)
    case usbDeviceOpenFailure(result:kern_return_t)
    case setConfigurationFailure(result:kern_return_t)
    case createInterfaceIteratorFailure(result:kern_return_t)
    case createInterfacePlugInFailure(result:kern_return_t)
    case createInterfaceNubFailure(result:kern_return_t)
    case noInterfaces
}

