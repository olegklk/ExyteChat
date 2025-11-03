//
//  ActivityIndicator.swift
//
//
//  Created by Alisa Mylnikova on 01.09.2023.
//

import SwiftUI
//import ActivityIndicatorView

public struct ActivityIndicator: View {

    @Environment(\.chatTheme) var theme
    var size: CGFloat = 30
    var showBackground = true
    @State private var isSpinnerAnimating = false
    
    public init(size: CGFloat = 30) {
        self.size = size
    }

    public var body: some View {
        ZStack {
            if showBackground {
                Color(UIColor.secondarySystemBackground).opacity(0.8)
                    .frame(width: 100, height: 100)
                    .cornerRadius(8)
            }

//            ActivityIndicatorView(isVisible: .constant(true), type: .flickeringDots())
//                .foregroundColor(theme.colors.activityIndicator)
//                .frame(width: size, height: size)
            VeroActivitySpinnerView(isAnimating: $isSpinnerAnimating)
                .foregroundColor(theme.colors.activityIndicator)
                .frame(width: size, height: size)
        }
        .onAppear {
            isSpinnerAnimating = true
        }
    }
}
