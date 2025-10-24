//
//  Created by Alex.M on 23.06.2022.
//

import SwiftUI
import ExyteChat

@main
struct ChatExampleApp: App {
    let veroTheme = ChatTheme(
        colors: ChatTheme.Colors(
                sendButtonBackground: .clear
            ),
            images: .init(
                arrowSend:Image("action_chat_send", bundle: .current)
        )
    )
    
    var body: some Scene {
        WindowGroup {
            UserSetupView()
                .chatTheme(veroTheme)
                .preferredColorScheme(.dark)
        }
    }
}
