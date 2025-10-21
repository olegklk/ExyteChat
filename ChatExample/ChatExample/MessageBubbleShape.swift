import SwiftUI

struct MessageBubbleShape: Shape {
    let isCurrentUser: Bool
    let showTail: Bool
    
    init(isCurrentUser: Bool = false, showTail: Bool = true) {
        self.isCurrentUser = isCurrentUser
        self.showTail = showTail
    }
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        if showTail {
            if isCurrentUser {
                drawRightTailBubble(in: rect, path: &path)
            } else {
                drawLeftTailBubble(in: rect, path: &path)
            }
        } else {
            drawNoTailBubble(in: rect, path: &path)
        }
        
        return path
    }
    
    private func drawLeftTailBubble(in rect: CGRect, path: inout Path) {
        let frame = rect
        
        path.move(to: CGPoint(x: frame.maxX - 8.05, y: frame.minY))
        
        path.addCurve(to: CGPoint(x: frame.maxX, y: frame.minY + 8.06),
                     control1: CGPoint(x: frame.maxX - 3.57, y: frame.minY),
                     control2: CGPoint(x: frame.maxX + 0.05, y: frame.minY + 3.63))
        
        path.addLine(to: CGPoint(x: frame.maxX, y: frame.maxY - 10.4))
        
        path.addCurve(to: CGPoint(x: frame.maxX - 8.1, y: frame.maxY - 2.3),
                     control1: CGPoint(x: frame.maxX, y: frame.maxY - 5.92),
                     control2: CGPoint(x: frame.maxX - 3.62, y: frame.maxY - 2.3))
        
        path.addCurve(to: CGPoint(x: frame.minX + 14.35, y: frame.maxY - 2.29),
                     control1: CGPoint(x: frame.maxX - 8.1, y: frame.maxY - 2.3),
                     control2: CGPoint(x: frame.minX + 16.43, y: frame.maxY - 2.27))
        
        path.addCurve(to: CGPoint(x: frame.minX + 12.5, y: frame.maxY - 2.3),
                     control1: CGPoint(x: frame.minX + 13.11, y: frame.maxY - 2.3),
                     control2: CGPoint(x: frame.minX + 12.93, y: frame.maxY - 2.3))
        
        path.addLine(to: CGPoint(x: frame.minX + 12.4, y: frame.maxY - 2.3))
        
        path.addCurve(to: CGPoint(x: frame.minX + 9.22, y: frame.maxY - 1.6),
                     control1: CGPoint(x: frame.minX + 11.22, y: frame.maxY - 2.3),
                     control2: CGPoint(x: frame.minX + 10.15, y: frame.maxY - 2.06))
        
        path.addCurve(to: CGPoint(x: frame.minX + 3.1, y: frame.maxY - 0.3),
                     control1: CGPoint(x: frame.minX + 7.36, y: frame.maxY - 0.67),
                     control2: CGPoint(x: frame.minX + 5.26, y: frame.maxY - 0.3))
        
        path.addCurve(to: CGPoint(x: frame.minX + 1.33, y: frame.maxY - 0.4),
                     control1: CGPoint(x: frame.minX + 2.47, y: frame.maxY - 0.3),
                     control2: CGPoint(x: frame.minX + 1.88, y: frame.maxY - 0.34))
        
        path.addCurve(to: CGPoint(x: frame.minX + 0.7, y: frame.maxY - 0.5),
                     control1: CGPoint(x: frame.minX + 1.01, y: frame.maxY - 0.44),
                     control2: CGPoint(x: frame.minX + 0.65, y: frame.maxY - 0.5))
        
        path.addCurve(to: CGPoint(x: frame.minX, y: frame.maxY - 1.2),
                     control1: CGPoint(x: frame.minX + 0.32, y: frame.maxY - 0.5),
                     control2: CGPoint(x: frame.minX, y: frame.maxY - 0.82))
        
        path.addCurve(to: CGPoint(x: frame.minX, y: frame.maxY - 1.25),
                     control1: CGPoint(x: frame.minX, y: frame.maxY - 1.25),
                     control2: CGPoint(x: frame.minX, y: frame.maxY - 1.25))
        
        path.addCurve(to: CGPoint(x: frame.minX + 0.43, y: frame.maxY - 1.9),
                     control1: CGPoint(x: frame.minX, y: frame.maxY - 1.51),
                     control2: CGPoint(x: frame.minX + 0.18, y: frame.maxY - 1.77))
        
        path.addCurve(to: CGPoint(x: frame.minX + 0.97, y: frame.maxY - 2.29),
                     control1: CGPoint(x: frame.minX + 0.5, y: frame.maxY - 1.93),
                     control2: CGPoint(x: frame.minX + 0.82, y: frame.maxY - 2.16))
        
        path.addCurve(to: CGPoint(x: frame.minX + 2.28, y: frame.maxY - 3.89),
                     control1: CGPoint(x: frame.minX + 1.41, y: frame.maxY - 2.68),
                     control2: CGPoint(x: frame.minX + 1.86, y: frame.maxY - 3.21))
        
        path.addCurve(to: CGPoint(x: frame.minX + 4.45, y: frame.maxY - 12.57),
                     control1: CGPoint(x: frame.minX + 3.52, y: frame.maxY - 5.87),
                     control2: CGPoint(x: frame.minX + 4.32, y: frame.maxY - 8.71))
        
        path.addCurve(to: CGPoint(x: frame.minX + 4.45, y: frame.minY + 8.2),
                     control1: CGPoint(x: frame.minX + 4.45, y: frame.maxY - 12.91),
                     control2: CGPoint(x: frame.minX + 4.45, y: frame.minY + 9.29))
        
        path.addLine(to: CGPoint(x: frame.minX + 4.45, y: frame.minY + 8.1))
        
        path.addCurve(to: CGPoint(x: frame.minX + 12.55, y: frame.minY),
                     control1: CGPoint(x: frame.minX + 4.45, y: frame.minY + 3.62),
                     control2: CGPoint(x: frame.minX + 8.07, y: frame.minY))
        
        path.addLine(to: CGPoint(x: frame.maxX - 8.05, y: frame.minY))
        
        path.closeSubpath()
    }
    
    private func drawRightTailBubble(in rect: CGRect, path: inout Path) {
        let frame = rect
        
        path.move(to: CGPoint(x: frame.minX + 8.05, y: frame.minY))
        
        path.addCurve(to: CGPoint(x: frame.minX, y: frame.minY + 8.06),
                     control1: CGPoint(x: frame.minX + 3.57, y: frame.minY),
                     control2: CGPoint(x: frame.minX - 0.05, y: frame.minY + 3.63))
        
        path.addLine(to: CGPoint(x: frame.minX, y: frame.maxY - 10.4))
        
        path.addCurve(to: CGPoint(x: frame.minX + 8.1, y: frame.maxY - 2.3),
                     control1: CGPoint(x: frame.minX, y: frame.maxY - 5.92),
                     control2: CGPoint(x: frame.minX + 3.62, y: frame.maxY - 2.3))
        
        path.addCurve(to: CGPoint(x: frame.maxX - 14.35, y: frame.maxY - 2.29),
                     control1: CGPoint(x: frame.minX + 8.1, y: frame.maxY - 2.3),
                     control2: CGPoint(x: frame.maxX - 16.43, y: frame.maxY - 2.27))
        
        path.addCurve(to: CGPoint(x: frame.maxX - 12.5, y: frame.maxY - 2.3),
                     control1: CGPoint(x: frame.maxX - 13.11, y: frame.maxY - 2.3),
                     control2: CGPoint(x: frame.maxX - 12.93, y: frame.maxY - 2.3))
        
        path.addLine(to: CGPoint(x: frame.maxX - 12.4, y: frame.maxY - 2.3))
        
        path.addCurve(to: CGPoint(x: frame.maxX - 9.22, y: frame.maxY - 1.6),
                     control1: CGPoint(x: frame.maxX - 11.22, y: frame.maxY - 2.3),
                     control2: CGPoint(x: frame.maxX - 10.15, y: frame.maxY - 2.06))
        
        path.addCurve(to: CGPoint(x: frame.maxX - 3.1, y: frame.maxY - 0.3),
                     control1: CGPoint(x: frame.maxX - 7.36, y: frame.maxY - 0.67),
                     control2: CGPoint(x: frame.maxX - 5.26, y: frame.maxY - 0.3))
        
        path.addCurve(to: CGPoint(x: frame.maxX - 1.33, y: frame.maxY - 0.4),
                     control1: CGPoint(x: frame.maxX - 2.47, y: frame.maxY - 0.3),
                     control2: CGPoint(x: frame.maxX - 1.88, y: frame.maxY - 0.34))
        
        path.addCurve(to: CGPoint(x: frame.maxX - 0.7, y: frame.maxY - 0.5),
                     control1: CGPoint(x: frame.maxX - 1.01, y: frame.maxY - 0.44),
                     control2: CGPoint(x: frame.maxX - 0.65, y: frame.maxY - 0.5))
        
        path.addCurve(to: CGPoint(x: frame.maxX, y: frame.maxY - 1.2),
                     control1: CGPoint(x: frame.maxX - 0.32, y: frame.maxY - 0.5),
                     control2: CGPoint(x: frame.maxX, y: frame.maxY - 0.82))
        
        path.addCurve(to: CGPoint(x: frame.maxX, y: frame.maxY - 1.25),
                     control1: CGPoint(x: frame.maxX, y: frame.maxY - 1.25),
                     control2: CGPoint(x: frame.maxX, y: frame.maxY - 1.25))
        
        path.addCurve(to: CGPoint(x: frame.maxX - 0.43, y: frame.maxY - 1.9),
                     control1: CGPoint(x: frame.maxX, y: frame.maxY - 1.51),
                     control2: CGPoint(x: frame.maxX - 0.18, y: frame.maxY - 1.77))
        
        path.addCurve(to: CGPoint(x: frame.maxX - 0.97, y: frame.maxY - 2.29),
                     control1: CGPoint(x: frame.maxX - 0.5, y: frame.maxY - 1.93),
                     control2: CGPoint(x: frame.maxX - 0.82, y: frame.maxY - 2.16))
        
        path.addCurve(to: CGPoint(x: frame.maxX - 2.28, y: frame.maxY - 3.89),
                     control1: CGPoint(x: frame.maxX - 1.41, y: frame.maxY - 2.68),
                     control2: CGPoint(x: frame.maxX - 1.86, y: frame.maxY - 3.21))
        
        path.addCurve(to: CGPoint(x: frame.maxX - 4.45, y: frame.maxY - 12.57),
                     control1: CGPoint(x: frame.maxX - 3.52, y: frame.maxY - 5.87),
                     control2: CGPoint(x: frame.maxX - 4.32, y: frame.maxY - 8.71))
        
        path.addCurve(to: CGPoint(x: frame.maxX - 4.45, y: frame.minY + 8.2),
                     control1: CGPoint(x: frame.maxX - 4.45, y: frame.maxY - 12.91),
                     control2: CGPoint(x: frame.maxX - 4.45, y: frame.minY + 9.29))
        
        path.addLine(to: CGPoint(x: frame.maxX - 4.45, y: frame.minY + 8.1))
        
        path.addCurve(to: CGPoint(x: frame.maxX - 12.55, y: frame.minY),
                     control1: CGPoint(x: frame.maxX - 4.45, y: frame.minY + 3.62),
                     control2: CGPoint(x: frame.maxX - 8.07, y: frame.minY))
        
        path.addLine(to: CGPoint(x: frame.minX + 8.05, y: frame.minY))
        
        path.closeSubpath()
    }
    
    private func drawNoTailBubble(in rect: CGRect, path: inout Path) {
        let cornerRadius: CGFloat = 8
        let frame = rect
        
        path.move(to: CGPoint(x: frame.minX + cornerRadius, y: frame.minY))
        path.addLine(to: CGPoint(x: frame.maxX - cornerRadius, y: frame.minY))
        path.addArc(center: CGPoint(x: frame.maxX - cornerRadius, y: frame.minY + cornerRadius),
                   radius: cornerRadius,
                   startAngle: .degrees(-90),
                   endAngle: .degrees(0),
                   clockwise: false)
        path.addLine(to: CGPoint(x: frame.maxX, y: frame.maxY - cornerRadius))
        path.addArc(center: CGPoint(x: frame.maxX - cornerRadius, y: frame.maxY - cornerRadius),
                   radius: cornerRadius,
                   startAngle: .degrees(0),
                   endAngle: .degrees(90),
                   clockwise: false)
        path.addLine(to: CGPoint(x: frame.minX + cornerRadius, y: frame.maxY))
        path.addArc(center: CGPoint(x: frame.minX + cornerRadius, y: frame.maxY - cornerRadius),
                   radius: cornerRadius,
                   startAngle: .degrees(90),
                   endAngle: .degrees(180),
                   clockwise: false)
        path.addLine(to: CGPoint(x: frame.minX, y: frame.minY + cornerRadius))
        path.addArc(center: CGPoint(x: frame.minX + cornerRadius, y: frame.minY + cornerRadius),
                   radius: cornerRadius,
                   startAngle: .degrees(180),
                   endAngle: .degrees(270),
                   clockwise: false)
        path.closeSubpath()
    }
}
