//
//  Item.swift
//  graphic-monitor
//
//  Created by Edwin González on 6/06/26.
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
