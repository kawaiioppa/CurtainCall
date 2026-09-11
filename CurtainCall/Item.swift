//
//  Item.swift
//  CurtainCall
//
//  Created by kimseokhyun on 9/11/26.
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
