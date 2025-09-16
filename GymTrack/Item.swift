//
//  Item.swift
//  GymTrack
//
//  Created by Colin Ryan on 9/16/25.
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
