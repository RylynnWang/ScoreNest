//
//  Item.swift
//  ScoreNest
//
//  Created by 王御嘉 on 2025/10/30.
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
