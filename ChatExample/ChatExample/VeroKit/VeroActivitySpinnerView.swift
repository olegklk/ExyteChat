//
//  VeroActivitySpinnerView.swift
//  YourSwiftUIProject
//
//  Created by AI Assistant
//

import SwiftUI

/// A native SwiftUI view for displaying a rotating activity spinner.
struct VeroActivitySpinnerView: View {
    
    // MARK: - Properties
    
    /// A binding that controls the animation's state (started/stopped).
    @Binding var isAnimating: Bool
    
    /// The name of the image to use for the spinner.
    private let imageName: String

    /// Internal state to trigger the rotation animation.
    @State private var isSpinning = false

    // MARK: - Initialization
    
    /// Initializes the spinner with a custom image.
    /// - Parameters:
    ///   - isAnimating: A binding to the animation's state.
    ///   - imageName: The name of the image in the Asset Catalogs or Bundle.
    init(isAnimating: Binding<Bool>, imageName: String) {
        self._isAnimating = isAnimating
        self.imageName = imageName
    }
    
    /// Initializes the spinner with the default image name.
    /// - Parameter isAnimating: A binding to the animation's state.
    init(isAnimating: Binding<Bool>) {
        self._isAnimating = isAnimating
        self.imageName = "spinner"
    }

    // MARK: - Body
    
    var body: some View {
        Group {
            if isAnimating {
                Image(imageName)
                    .resizable()
                    .scaledToFit()
                    .rotationEffect(.degrees(isSpinning ? 360 : 0))
                    .animation(
                        .linear(duration: 1.1)
                        .repeatForever(autoreverses: false),
                        value: isSpinning
                    )
            }
        }
        .onChange(of: isAnimating) { newValue in
            isSpinning = newValue
        }
    }
}


// MARK: - Preview Provider
#if DEBUG
struct VeroActivitySpinnerView_Previews: PreviewProvider {
    static var previews: some View {
        InteractivePreview()
    }
    
    struct InteractivePreview: View {
        @State private var isAnimating = true
        
        var body: some View {
            VStack(spacing: 30) {
                Text("Interactive Spinner Preview")
                    .font(.headline)
                
                Toggle("Is Animating", isOn: $isAnimating)
                    .padding()
                
                VeroActivitySpinnerView(isAnimating: $isAnimating, imageName: "spinner")
                    .frame(width: 80, height: 80)
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(10)
            }
            .padding()
        }
    }
}
#endif
