//
//  FlaggedVar.swift
//  X3602S4A
//
//  Created by Edward Janne on 7/4/17.
//  Copyright © 2017 DrMechano. All rights reserved.
//

import Foundation

class FlaggedVar<T:Comparable> {
    var val:T {
        get {
            dirty = false
            return _val
        }
        set(aVal) {
            dirty = (aVal != _val)
            _val = aVal
        }
    }
    var _val:T
    var dirty:Bool = true
    
    init(val:T) {
        _val = val
    }
}
