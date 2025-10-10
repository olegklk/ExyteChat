//
//  Utils.swift
//  ChatExample
//
//  Created by Oleg Kolokolov on 30.09.2025.
//

import Foundation
import ChatAPIClient

enum AppScreen: String, Hashable {
    case userSetup, chatList, chat, newChat
}

struct NavigationItem: Hashable, Equatable {
    let id = UUID()
    let screenType: AppScreen
    var conversation: Conversation?
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: NavigationItem, rhs: NavigationItem) -> Bool {
        lhs.id == rhs.id
    }
}
