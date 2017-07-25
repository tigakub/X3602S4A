//
//  ViewController.swift
//  X3602S4A
//
//  Created by Edward Janne on 7/3/17.
//  Copyright © 2017 DrMechano. All rights reserved.
//

import Cocoa

class ViewController: NSViewController, NSTableViewDataSource, NSTableViewDelegate, NSTextFieldDelegate /*, NSControlTextEditingDelegate */ {

    let x360Monitor = X360Monitor()
    
    @IBOutlet var deviceTable:NSTableView! = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let theTable = deviceTable {
            theTable.sortDescriptors = [NSSortDescriptor(key:"prefix", ascending:true)]
        }
        
        NotificationCenter.default.addObserver(forName:.USBDeviceConnected, object:nil, queue:nil) { (notification) in
            if let theTable = self.deviceTable {
                if let dict = notification.object as? [String:io_object_t] {
                    if let deviceId = dict["device"] {
                        let theArray = self.x360Monitor.controllerOrder as NSArray
                        var sortedIndex = 0
                        if theArray.count > 0 {
                            sortedIndex = theArray.index(of:deviceId, inSortedRange:NSMakeRange(0, theArray.count), options:[.insertionIndex]) { (id1, id2)->ComparisonResult in
                                let object1 = id1 as! io_object_t
                                let object2 = id2 as! io_object_t
                                let name1 = self.x360Monitor.controllers[object1]!.deviceName
                                let name2 = self.x360Monitor.controllers[object2]!.deviceName
                                if name1 < name2 { return .orderedAscending }
                                else { return .orderedDescending }
                            }
                        }
                        //print("Inserting row into table at \(sortedIndex)")
                        if sortedIndex < self.x360Monitor.controllerOrder.count {
                            self.x360Monitor.controllerOrder.insert(deviceId, at:sortedIndex)
                        } else {
                            self.x360Monitor.controllerOrder.append(deviceId)
                        }
                        if theTable.numberOfRows >= self.x360Monitor.controllerOrder.count {
                            return
                        }
                        let theIndexSet:IndexSet = IndexSet(integer:sortedIndex)
                        theTable.insertRows(at:theIndexSet, withAnimation:.slideDown)
                    }
                }
            }
        }
        
        NotificationCenter.default.addObserver(forName:.USBDeviceDisconnected, object:nil, queue:nil) { (notification) in
            if let theTable = self.deviceTable {
                if let dict = notification.object as? [String:io_object_t] {
                    if let deviceId = dict["device"] {
                        if let theIndex = self.x360Monitor.controllerOrder.index(of:deviceId) {
                            self.x360Monitor.controllerOrder.remove(at:theIndex)
                            let theIndexSet:IndexSet = IndexSet(integer:theIndex)
                            theTable.removeRows(at:theIndexSet, withAnimation:.slideUp)
                        }
                    }
                }
            }
        }
        
        NotificationCenter.default.addObserver(forName:.X360Telemetry, object:nil, queue:nil) { (notification) in
            if let theTable = self.deviceTable {
                if let dict = notification.object as? [String:io_object_t] {
                    if let deviceId = dict["device"] {
                        if let theIndex = self.x360Monitor.controllerOrder.index(of:deviceId) {
                            if let theView = theTable.view(atColumn:1, row:theIndex, makeIfNecessary:false) as? NSTextField {
                                DispatchQueue.main.async {
                                    theView.backgroundColor = NSColor(red:1.0, green:0.0, blue:0.0, alpha:0.5)
                                }
                            }
                        }
                    }
                }
            }
        }
        
        NotificationCenter.default.addObserver(forName:.X360Idle, object:nil, queue:nil) { (notification) in
            if let theTable = self.deviceTable {
                if let dict = notification.object as? [String:io_object_t] {
                    if let deviceId = dict["device"] {
                        if let theIndex = self.x360Monitor.controllerOrder.index(of:deviceId) {
                            if let theView = theTable.view(atColumn:1, row:theIndex, makeIfNecessary:false) as? NSTextField {
                                DispatchQueue.main.async {
                                    theView.backgroundColor = NSColor(white:1.0, alpha:0.0)
                                    theView.setNeedsDisplay();
                                }
                            }
                        }
                    }
                }
            }
        }
        
        x360Monitor.start()
    }

    override var representedObject: Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    public func numberOfRows(in tableView: NSTableView) -> Int {
        //print("Reporting device count: \(x360Monitor.controllerOrder.count)")
        return x360Monitor.controllerOrder.count
    }
    
    public func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 20.0
    }
    
    public func tableView(_ tableView:NSTableView, viewFor tableColumn:NSTableColumn?, row:Int) -> NSView? {
        //print("Attempting to obtain table cell view for row \(row) column \(tableColumn!.identifier)")
        var aTextField:NSTextField? = tableView.make(withIdentifier:"deviceLocation", owner:self) as? NSTextField
        if aTextField == nil {
            let aFrameRect = NSMakeRect(0, 0, tableView.frame.width, 0)
            let theTextField = NSTextField(frame:aFrameRect)
            theTextField.delegate = self
            theTextField.isEditable = false
            theTextField.backgroundColor = NSColor(red:1.0, green:1.0, blue:1.0, alpha:0.0)
            theTextField.isBordered = false
            aTextField = theTextField
        }
        
        if row < x360Monitor.controllerOrder.count {
            let deviceId = x360Monitor.controllerOrder[row]
            if let device = x360Monitor.controllers[deviceId] {
                let locationId = device.deviceLocation
                if let theColumn = tableColumn {
                    switch(theColumn.identifier) {
                        case "locationId":
                            aTextField!.stringValue = "\(String(format:"%2X", locationId))"
                        case "prefix":
                            aTextField!.stringValue = device.deviceName
                            aTextField!.isEditable = true
                            aTextField!.tag = Int(bitPattern:(UInt(deviceId)))
                            aTextField!.action = #selector(deviceNameChanged)
                            /*
                            if let name = x360Monitor.nameDictionary[locationId] {
                                aTextField!.stringValue = name
                            } else {
                                aTextField!.isEditable = true
                                aTextField!.tag = Int(bitPattern:(UInt(locationId)))
                                aTextField!.action = #selector(deviceNameChanged)
                                let newName = "Controller_\(x360Monitor.nameDictionary.count)"
                                aTextField!.stringValue = newName
                                x360Monitor.nameDictionary[locationId] = newName
                            }
                            */
                        default:
                            break
                    }
                }
            }
        }
        
        return aTextField
    }
    
    @IBAction func deviceNameChanged(_ sender: NSTextField) {
        let deviceId = UInt32(UInt(bitPattern:sender.tag))
        let device = x360Monitor.controllers[deviceId]!
        let locationId = device.deviceLocation
        x360Monitor.nameDictionary[locationId] = sender.stringValue
        device.deviceName = sender.stringValue
        if x360Monitor.controllerOrder.count > 1 {
            let index = x360Monitor.controllerOrder.index(of:deviceId)!
            x360Monitor.controllerOrder.remove(at:index)
            var sortedIndex = 0
            let theArray = self.x360Monitor.controllerOrder as NSArray
            sortedIndex = theArray.index(of:deviceId, inSortedRange:NSMakeRange(0, theArray.count), options:[.insertionIndex]) { (id1, id2)->ComparisonResult in
                let object1 = id1 as! io_object_t
                let object2 = id2 as! io_object_t
                let name1 = self.x360Monitor.controllers[object1]!.deviceName
                let name2 = self.x360Monitor.controllers[object2]!.deviceName
                if name1 < name2 { return .orderedAscending }
                else { return .orderedDescending }
            }
            if sortedIndex < theArray.count {
                x360Monitor.controllerOrder.insert(deviceId, at:sortedIndex)
            } else {
                x360Monitor.controllerOrder.append(deviceId)
            }
            
            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 1) {
                self.deviceTable!.reloadData()
                self.deviceTable!.selectRowIndexes(IndexSet(integer:sortedIndex), byExtendingSelection:false)
            }
        }
    }
}

