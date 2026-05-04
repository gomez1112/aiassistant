import SwiftUI

enum AppTab: Hashable {
    case chat
    case outputs
    case library

    var title: String {
        switch self {
        case .chat: "Chat"
        case .outputs: "Outputs"
        case .library: "Library"
        }
    }

    var systemImage: String {
        switch self {
        case .chat: "bubble.left.and.bubble.right.fill"
        case .outputs: "doc.richtext"
        case .library: "books.vertical.fill"
        }
    }
}
