//
//  Mutex.swift
//  X3602S4A
//
//  Created by Edward Janne on 7/3/17.
//  Copyright © 2017 DrMechano. All rights reserved.
//

import Foundation

class Mutex
{
    var sem = DispatchSemaphore(value:1)
    
    func critical(block:()->()) {
        wait()
        block()
        signal()
    }
    
    func wait() {
        _ = sem.wait(timeout:.distantFuture)
    }

    func signal() {
        sem.signal()
    }
    
    func atomicGet<T>(variable:T)->T {
        var result:T
        wait()
        result = variable
        signal()
        return result
    }
    
    func atomicSet<T>(variable:inout T, toValue:T) {
        wait()
        variable = toValue
        signal()
    }
}
