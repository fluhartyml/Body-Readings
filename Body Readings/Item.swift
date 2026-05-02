//
//  Item.swift
//  Body Readings
//
//  Created by Michael Fluharty on 5/2/26.
//

import Foundation
import SwiftData

@Model
final class Item {
    var timestamp: Date
    
    init(timestamp: Date) {
        self.timestamp = timestamp
    }
}
