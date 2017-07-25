//
//  X360Monitor.swift
//  X3602S4A
//
//  Created by Edward Janne on 7/3/17.
//  Copyright © 2017 DrMechano. All rights reserved.
//

import Foundation
import IOKit
import IOKit.usb
import IOKit.usb.IOUSBLib
import IOKit.usb.USB
import IOKit.usb.USBSpec

//let kX360VendorId:UInt16 = 0x46D
//let kX360ProductId:UInt16 = 0xC21D
//let kX360VendorId:UInt16 = 0x05AC
//let kX360ProductId:UInt16 = 0x055B
let kX360VendorId:UInt16 = 0x45e
let kX360ProductId:UInt16 = 0x28e

public extension Notification.Name {
    static let USBDeviceConnected = Notification.Name("USBDeviceConnected")
    static let USBDeviceDisconnected = Notification.Name("USBDeviceDisconnected")
    static let X360Telemetry = Notification.Name("X360Telemetry")
    static let X360Idle = Notification.Name("X360Idle")
}

public class X360Monitor
{
    var controllers = [io_object_t:X360]()
    var controllerOrder = [io_object_t]()
    var nameDictionary = [io_object_t:String]()
    
    public func start() {
        let notifyPort = IONotificationPortCreate(kIOMasterPortDefault)
        IONotificationPortSetDispatchQueue(notifyPort, DispatchQueue(label:"X360Monitor"))
        
        let matchingDict = IOServiceMatching(kIOUSBDeviceClassName) as NSMutableDictionary
        matchingDict[kUSBVendorID] = NSNumber(value:kX360VendorId)
        matchingDict[kUSBProductID] = NSNumber(value:kX360ProductId)
        
        var connectionIterator:io_iterator_t = 0
        var disconnectionIterator:io_iterator_t = 0
        
        let connectCallback:IOServiceMatchingCallback = { (userData, iterator) in
            let this = Unmanaged<X360Monitor>.fromOpaque(userData!).takeUnretainedValue()
            this.x360sConnected(iterator:iterator)
        }
        
        let disconnectCallback:IOServiceMatchingCallback = { (userData, iterator) in
            let this = Unmanaged<X360Monitor>.fromOpaque(userData!).takeUnretainedValue()
            this.x360sDisconnected(iterator:iterator)
        }
        
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        
        IOServiceAddMatchingNotification(notifyPort, kIOFirstMatchNotification, matchingDict, connectCallback, selfPtr, &connectionIterator)
        IOServiceAddMatchingNotification(notifyPort, kIOTerminatedNotification, matchingDict, disconnectCallback, selfPtr, &disconnectionIterator)
        
        x360sConnected(iterator:connectionIterator)
        x360sDisconnected(iterator:disconnectionIterator)
    }
    
    func x360sConnected(iterator:io_iterator_t) {
        while case let deviceId = IOIteratorNext(iterator), deviceId != 0 {
            let x360 = X360(deviceId:deviceId)
            do {
                try x360.start()
                x360.deviceId = deviceId
                controllers[deviceId] = x360
                let locationId = x360.deviceLocation
                if let name = nameDictionary[locationId] {
                    x360.deviceName = name
                } else {
                    let newName = "CTX\(nameDictionary.count)"
                    x360.deviceName = newName
                    nameDictionary[locationId] = newName
                }
                //print("Posting connection notification for device \(deviceId)")
                NotificationCenter.default.post(name:.USBDeviceConnected, object:["device":deviceId])
            } catch(let e) {
                //print(e.localizedDescription)
            }
        }
    }
    
    func x360sDisconnected(iterator:io_iterator_t) {
        while case let deviceId = IOIteratorNext(iterator), deviceId != 0 {
            NotificationCenter.default.post(name:.USBDeviceDisconnected, object:["device":deviceId])
            controllers.removeValue(forKey:deviceId)
        }
    }
}
