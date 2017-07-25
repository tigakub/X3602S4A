//
//  X360.swift
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
import IOKit.usb.IOUSBUserClient

//from IOUSBLib.h
public let kIOUSBDeviceUserClientTypeID = CFUUIDGetConstantUUIDWithBytes(nil,
                                                            0x9d, 0xc7, 0xb7, 0x80, 0x9e, 0xc0, 0x11, 0xd4,
                                                            0xa5, 0x4f, 0x00, 0x0a, 0x27, 0x05, 0x28, 0x61)

public let kIOUSBInterfaceUserClientTypeID = CFUUIDGetConstantUUIDWithBytes(nil,
                                                            0x2d, 0x97, 0x86, 0xc6, 0x9e, 0xf3, 0x11, 0xD4,
                                                            0xad, 0x51, 0x00, 0x0a, 0x27, 0x05, 0x28, 0x61)

public let kIOUSBDeviceInterfaceID = CFUUIDGetConstantUUIDWithBytes(nil,
                                                            0x5c, 0x81, 0x87, 0xd0, 0x9e, 0xf3, 0x11, 0xd4,
                                                            0x8b, 0x45, 0x00, 0x0a, 0x27, 0x05, 0x28, 0x61)

public let kIOUSBDeviceInterfaceID197  = CFUUIDGetConstantUUIDWithBytes(nil,
                                                            0xC8, 0x09, 0xB8, 0xD8, 0x08, 0x84, 0x11, 0xD7,
                                                            0xBB, 0x96, 0x00, 0x03, 0x93, 0x3E, 0x3E, 0x3E)

public let kIOUSBDeviceInterfaceID500  = CFUUIDGetConstantUUIDWithBytes(nil,
                                                            0xA3, 0x3C, 0xF0, 0x47, 0x4B, 0x5B, 0x48, 0xE2,
                                                            0xB5, 0x7D, 0x02, 0x07, 0xFC, 0xEA, 0xE1, 0x3B)

public let kIOUSBInterfaceInterfaceID = CFUUIDGetConstantUUIDWithBytes(nil,
                                                            0x73, 0xc9, 0x7a, 0xe8, 0x9e, 0xf3, 0x11, 0xD4,
                                                            0xb1, 0xd0, 0x00, 0x0a, 0x27, 0x05, 0x28, 0x61)

public let kIOUSBInterfaceInterfaceID197 = CFUUIDGetConstantUUIDWithBytes(nil,
                                                            0xC6, 0x3D, 0x3C, 0x92, 0x08, 0x84, 0x11, 0xD7,
                                                            0x96, 0x92, 0x00, 0x03, 0x93, 0x3E, 0x3E, 0x3E)

public let kIOUSBInterfaceInterfaceID800 = CFUUIDGetConstantUUIDWithBytes(nil,
                                                            0x33, 0xA8, 0x5D, 0xB0, 0x0C, 0x3B, 0x43, 0x28,
                                                            0x8F, 0x02, 0xFD, 0xA8, 0x1B, 0x11, 0x7F, 0x4C)

//from IOCFPlugin.h
public let kIOCFPlugInInterfaceID = CFUUIDGetConstantUUIDWithBytes(nil,
                                                            0xc2, 0x44, 0xe8, 0x58, 0x10, 0x9c, 0x11, 0xd4,
                                                            0x91, 0xd4, 0x00, 0x50, 0xe4, 0xc6, 0x42, 0x6f)

struct Pipe
{
    var direction:UInt8 = 0
    var number:UInt8 = 0
    var transferType:UInt8 = 0
    var maxPacketSize:UInt16 = 0
    var interval:UInt8 = 0
}

public class X360 : NSObject
{
    var deviceId:io_object_t = 0
    var deviceLocation:UInt32 = 0
    var userName:String = ""
    var deviceName:String = ""
    var deviceNubPtr:UnsafeMutablePointer<UnsafeMutablePointer<IOUSBDeviceInterface500>?>? = nil
    var deviceNub:IOUSBDeviceInterface500! = nil
    var interfaceNubPtr:UnsafeMutablePointer<UnsafeMutablePointer<IOUSBInterfaceInterface800>?>? = nil
    var interfaceNub:IOUSBInterfaceInterface800! = nil
    var ctrlPipe = Pipe()
    var dataPipe = Pipe()
    var joinGroup:DispatchGroup? = nil
    var dataPipeQueue:DispatchQueue? = nil
    var isAlive = Atomic(true)
    var x360Data = X360Data()
    var x360DataOld = X360Data()
    var leftDead:Int = 1024
    var rightDead:Int = 1024
    
    init(deviceId aDeviceId:io_object_t) {
        deviceId = aDeviceId
        
        super.init()
    }
    
    deinit {
        stop()
    }
    
    func start() throws -> Void {
        // Get the device name
        var deviceNameCStr = [CChar](repeating:0, count:128)
        var result = IORegistryEntryGetName(deviceId, &deviceNameCStr)
        if(result != kIOReturnSuccess) {
            throw X360Error.registryNameFailure(result:result)
        }
        
        guard let deviceNameTmp = String(cString:&deviceNameCStr, encoding:.utf8) else {
            throw X360Error.registryNameFailure(result:result)
        }
        
        deviceName = deviceNameTmp
        
        // Get the device plug in interface
        var devicePlugInPtr:UnsafeMutablePointer<UnsafeMutablePointer<IOCFPlugInInterface>?>?
        var score:Int32 = 0
        result = IOCreatePlugInInterfaceForService(
            deviceId,
            kIOUSBDeviceUserClientTypeID,
            kIOCFPlugInInterfaceID,
            &devicePlugInPtr,
            &score
        )
        if result != kIOReturnSuccess {
            throw X360Error.devicePlugInFailure(result:result)
        }
        
        guard let devicePlugIn = devicePlugInPtr?.pointee?.pointee else {
            throw X360Error.devicePlugInFailure(result:result)
        }
        
        // Get the device nub
        result = withUnsafeMutablePointer(to:&deviceNubPtr) { ptr in
            ptr.withMemoryRebound(to:Optional<LPVOID>.self, capacity:1) { reboundPtr in
                devicePlugIn.QueryInterface(
                    devicePlugInPtr,
                    CFUUIDGetUUIDBytes(kIOUSBDeviceInterfaceID197),
                    reboundPtr
                )
            }
        }
        IODestroyPlugInInterface(devicePlugInPtr)
        if result != kIOReturnSuccess {
            throw X360Error.deviceNubFailure(result:result)
        }
        
        guard let deviceNubTmp = deviceNubPtr?.pointee?.pointee else {
            throw X360Error.deviceNubFailure(result:result)
        }
        
        deviceNub = deviceNubTmp
        
        // Get the number of configurations
        var numConfigs:UInt8 = 0
        result = deviceNub.GetNumberOfConfigurations(deviceNubPtr, &numConfigs)
        if (result != kIOReturnSuccess) || (numConfigs < 1) {
            throw X360Error.numConfigFailure(result:result)
        }
        
        // Get the default configuration descriptor
        var configDescPtr:IOUSBConfigurationDescriptorPtr? = nil
        result = deviceNub.GetConfigurationDescriptorPtr(deviceNubPtr, 0, &configDescPtr)
        if result != kIOReturnSuccess {
            throw X360Error.configDescriptorFailure(result:result)
        }
        
        guard let configDesc = configDescPtr?.pointee else {
            throw X360Error.configDescriptorFailure(result:result)
        }
        
        
        // Open the device
        result = deviceNub.USBDeviceOpenSeize(deviceNubPtr)
        if result != kIOReturnSuccess {
            throw X360Error.usbDeviceOpenFailure(result:result)
        }
        
        result = deviceNub.ResetDevice(deviceNubPtr)
        if result != kIOReturnSuccess {
            print("Could not reset device")
        }
        
        // Set default configuration
        result = deviceNub.SetConfiguration(deviceNubPtr, configDesc.bConfigurationValue)
        if result != kIOReturnSuccess {
            throw X360Error.setConfigurationFailure(result:result)
        }
        
        result = deviceNub.GetLocationID(deviceNubPtr, &deviceLocation)
        if result == kIOReturnSuccess {
            print("Device location id: \(deviceLocation)")
        }
        
        // Obtain interface iterator
        var interfaceRequest = IOUSBFindInterfaceRequest(
            bInterfaceClass:UInt16(kIOUSBFindInterfaceDontCare),
            bInterfaceSubClass:93,
            bInterfaceProtocol:1,
            bAlternateSetting:UInt16(kIOUSBFindInterfaceDontCare)
        )
        var interfaceIterator:io_iterator_t = 0
        
        result = deviceNub.CreateInterfaceIterator(deviceNubPtr, &interfaceRequest, &interfaceIterator)
        if result != kIOReturnSuccess {
            throw X360Error.createInterfaceIteratorFailure(result:result)
        }
        
        var foundInterface = false
        // Iterate through the returned interface ids
        while case let interfaceId = IOIteratorNext(interfaceIterator), interfaceId != 0 {
            // Get the interface plugin
            var interfacePlugInPtr:UnsafeMutablePointer<UnsafeMutablePointer<IOCFPlugInInterface>?>?
            result = IOCreatePlugInInterfaceForService(
                interfaceId,
                kIOUSBInterfaceUserClientTypeID,
                kIOCFPlugInInterfaceID,
                &interfacePlugInPtr,
                &score)
            IOObjectRelease(interfaceId)
            if result != kIOReturnSuccess {
                continue
            }
            
            guard let interfacePlugIn = interfacePlugInPtr?.pointee?.pointee else {
                continue
            }
            
            // Get the interface nub
            result = withUnsafeMutablePointer(to:&interfaceNubPtr) { ptr in
                ptr.withMemoryRebound(to:Optional<LPVOID>.self, capacity:1) { reboundPtr in
                    interfacePlugIn.QueryInterface(
                        interfacePlugInPtr,
                        CFUUIDGetUUIDBytes(kIOUSBInterfaceInterfaceID197),
                        reboundPtr
                    )
                }
            }
            IODestroyPlugInInterface(interfacePlugInPtr)
            if result != kIOReturnSuccess {
                continue
            }
            
            guard let interfaceNubTmp = interfaceNubPtr?.pointee?.pointee else {
                continue
            }
            
            interfaceNub = interfaceNubTmp
            
            // Open the interface
            result = interfaceNub.USBInterfaceOpenSeize(interfaceNubPtr)
            if result != kIOReturnSuccess {
                continue
            }
            
            // Iterate through the endpoints in the interface
            var numEndpoints:UInt8 = 0
            result = interfaceNub.GetNumEndpoints(interfaceNubPtr, &numEndpoints)
            if (result != kIOReturnSuccess) || (numEndpoints < 1) {
                continue
            }
            
            var direction:UInt8 = 0
            var number:UInt8 = 0
            var transferType:UInt8 = 0
            var maxPacketSize:UInt16 = 0
            var interval:UInt8 = 0
            
            for i in 0..<numEndpoints {
                result = interfaceNub.GetPipeProperties(interfaceNubPtr, i,
                    &direction,
                    &number,
                    &transferType,
                    &maxPacketSize,
                    &interval
                )
                
                switch(Int(transferType)) {
                    case kUSBControl:
                        ctrlPipe.direction = direction
                        ctrlPipe.number = number
                        ctrlPipe.transferType = transferType
                        ctrlPipe.maxPacketSize = maxPacketSize
                        ctrlPipe.interval = interval
                    case kUSBInterrupt:
                        dataPipe.direction = direction
                        dataPipe.number = number
                        dataPipe.transferType = transferType
                        dataPipe.maxPacketSize = maxPacketSize
                        dataPipe.interval = interval
                    default:
                        continue
                }
                
                joinGroup = DispatchGroup()
                dataPipeQueue = DispatchQueue(label:"X360Data")
                
                dataPipeQueue?.async(group:joinGroup!, qos:.default, flags:.assignCurrentContext) {
                    var result:kern_return_t
                    var buf = [UInt8](repeating:0, count:20)
                    let packetSize:UInt32 = 20
                    while self.isAlive.value {
                        var readSize = packetSize
                        result = self.interfaceNub.ReadPipe(self.interfaceNubPtr, self.dataPipe.number, &buf, &readSize)
                        switch(result) {
                            case kIOReturnSuccess:
                                if readSize == packetSize {
                                    self.parseTelemetry(data:buf)
                                } else {
                                    self.handleMsg(data:buf, count:Int(readSize))
                                }
                            default:
                                break;
                        }
                    }
                }
            }
            
            IOObjectRelease(interfaceIterator)
            
            foundInterface = true
        }
        
        if !foundInterface {
            throw X360Error.noInterfaces
        }
    }
    
    func handleMsg(data:[UInt8], count:Int) {
    }
    
    func parseTelemetry(data:[UInt8]) {
        // let msgType = data[0]
        // let packetSize = data[1]
        
        x360Data.dpadUp.val = ((data[2] & 1) == 0 ? 0 : 1)
        x360Data.dpadDown.val = ((data[2] & 2) == 0 ? 0 : 1)
        x360Data.dpadLeft.val = ((data[2] & 4) == 0 ? 0 : 1)
        x360Data.dpadRight.val = ((data[2] & 8) == 0 ? 0 : 1)
        x360Data.start.val = ((data[2] & 0x10) == 0 ? 0 : 1)
        x360Data.back.val = ((data[2] & 0x20) == 0 ? 0 : 1)
        x360Data.stickLeftClick.val = ((data[2] & 0x40) == 0 ? 0 : 1)
        x360Data.stickRightClick.val = ((data[2] & 0x80) == 0 ? 0 : 1)
        x360Data.bumperLeft.val = ((data[3] & 1) == 0 ? 0 : 1)
        x360Data.bumperRight.val = ((data[3] & 2) == 0 ? 0 : 1)
        x360Data.guide.val = ((data[3] & 4) == 0 ? 0 : 1)
        x360Data.a.val = ((data[3] & 0x10) == 0 ? 0 : 1)
        x360Data.b.val = ((data[3] & 0x20) == 0 ? 0 : 1)
        x360Data.x.val = ((data[3] & 0x40) == 0 ? 0 : 1)
        x360Data.y.val = ((data[3] & 0x80) == 0 ? 0 : 1)
        x360Data.triggerLeft.val = data[4]
        x360Data.triggerRight.val = data[5]
        x360Data.stickLeftX.val = Int16(bitPattern:((UInt16(data[7]) << 8) | UInt16(data[6])))
        x360Data.stickLeftY.val = Int16(bitPattern:((UInt16(data[9]) << 8) | UInt16(data[8])))
        x360Data.stickRightX.val = Int16(bitPattern:((UInt16(data[11]) << 8) | UInt16(data[10])))
        x360Data.stickRightY.val = Int16(bitPattern:((UInt16(data[13]) << 8) | UInt16(data[12])))
        
        // print("d up:\(x360Data.dpadUp) d:\(x360Data.dpadDown) l:\(x360Data.dpadLeft) r:\(x360Data.dpadRight) sl(\(x360Data.stickLeftX), \(x360Data.stickLeftY)) sr(\(x360Data.stickRightX),\(x360Data.stickRightY))")
        let x360DataMirror = Mirror(reflecting:x360Data)
        for (_,attr) in x360DataMirror.children.enumerated() {
            if let attrLabel = attr.label {
                if let attrValue = attr.value as? FlaggedVar<UInt8>, attrValue.dirty {
                    switch(attrLabel) {
                        case "dummy1": break
                        case "dummy2": break
                        case "dummy3": break
                        default:
                            let getURL = "http://127.0.0.1:42001/vars-update=\(deviceName)_\(attrLabel)=\(attrValue.val)"
                            print(getURL)
                            var post = URLRequest(url:URL(string:getURL)!)
                            post.httpMethod = "GET"
                            let task = URLSession.shared.dataTask(with:post) { (data, response, error) in
                                guard data != nil, error == nil else {
                                    if error != nil {
                                        print(error!.localizedDescription)
                                    } else {
                                        print("?", terminator:"")
                                    }
                                    return
                                }
                                
                                guard let httpStatus = response as? HTTPURLResponse, httpStatus.statusCode == 200 else {
                                    print("x", terminator:"")
                                    return
                                }
                                
                                /*
                                if(post.httpBody != nil) {
                                    print(params)
                                }
                                */
                                // print(".", terminator:"")
                            }
                            task.resume()
                    }
                }
                if let attrValue = attr.value as? FlaggedVar<Int16>, attrValue.dirty {
                    switch(attrLabel) {
                        case "dummy1": break
                        case "dummy2": break
                        case "dummy3": break
                        default:
                            let getURL = "http://127.0.0.1:42001/vars-update=\(deviceName)_\(attrLabel)=\(attrValue.val)"
                            print(getURL)
                            var post = URLRequest(url:URL(string:getURL)!)
                            post.httpMethod = "GET"
                            let task = URLSession.shared.dataTask(with:post) { (data, response, error) in
                                guard data != nil, error == nil else {
                                    if error != nil {
                                        print(error!.localizedDescription)
                                    } else {
                                        print("?", terminator:"")
                                    }
                                    return
                                }
                                
                                guard let httpStatus = response as? HTTPURLResponse, httpStatus.statusCode == 200 else {
                                    print("x", terminator:"")
                                    return
                                }
                                
                                /*
                                if(post.httpBody != nil) {
                                    print(params)
                                }
                                */
                                // print(".", terminator:"")
                            }
                            task.resume()
                    }
                }
            }
        }
        
        var active = false
        if x360Data.dpadUp.val != 0 {
            active = true
        } else if x360Data.dpadDown.val != 0 {
            active = true
        } else if x360Data.dpadLeft.val != 0 {
            active = true
        } else if x360Data.dpadRight.val != 0 {
            active = true
        } else if x360Data.start.val != 0 {
            active = true
        } else if x360Data.back.val != 0 {
            active = true
        } else if x360Data.stickLeftClick.val != 0 {
            active = true
        } else if x360Data.stickRightClick.val != 0 {
            active = true
        } else if x360Data.bumperLeft.val != 0 {
            active = true
        } else if x360Data.bumperRight.val != 0 {
            active = true
        } else if x360Data.guide.val != 0 {
            active = true
        } else if x360Data.a.val != 0 {
            active = true
        } else if x360Data.b.val != 0 {
            active = true
        } else if x360Data.x.val != 0 {
            active = true
        } else if x360Data.y.val != 0 {
            active = true
        } else if x360Data.triggerLeft.val > 0 {
            active = true
        } else if x360Data.triggerRight.val > 0 {
            active = true
        } else if Swift.abs(Int(x360Data.stickLeftX.val)) > leftDead {
            active = true
        } else if Swift.abs(Int(x360Data.stickLeftY.val)) > leftDead {
            active = true
        } else if Swift.abs(Int(x360Data.stickRightX.val)) > rightDead {
            active = true
        } else if Swift.abs(Int(x360Data.stickRightY.val)) > rightDead {
            active = true
        }
        
        if(active) {
            NotificationCenter.default.post(name:.X360Telemetry, object:["device":self.deviceId])
        } else {
            NotificationCenter.default.post(name:.X360Idle, object:["device":self.deviceId])
        }
    }
    
    func stop() {
        isAlive.value = false
        
        _ = joinGroup?.wait(timeout:.distantFuture)
        
        if interfaceNub != nil {
            _ = interfaceNub.USBInterfaceClose(interfaceNubPtr)
        }
        
        if deviceNub != nil {
            _ = deviceNub.USBDeviceClose(deviceNubPtr)
        }
        
        IOObjectRelease(deviceId)
    }
}
