//
//  Atomic.swift
//  X3602S4A
//
//  Created by Edward Janne on 7/3/17.
//  Copyright © 2017 DrMechano. All rights reserved.
//

import Foundation

class Atomic<T> : Mutex
{
	var _value:T
	var value:T {
		get {
			wait()
			let r = _value
			signal()
			return r
		}
		set(newValue) {
			critical {
				_value = newValue
			}
		}
	}
	
	init(_ iValue:T) {
		_value = iValue
	}
}
