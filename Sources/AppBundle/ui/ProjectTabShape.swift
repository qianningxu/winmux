import SwiftUI

struct ProjectTabShape: Shape {
    func path(in rect: CGRect) -> Path {
        let r = min(WinMuxBarStyle.cornerRadius, rect.height / 2)
        var p = Path()
        p.move(to: CGPoint(x: -r, y: rect.maxY))
        p.addQuadCurve(to: CGPoint(x: 0, y: rect.maxY - r), control: CGPoint(x: 0, y: rect.maxY))
        p.addLine(to: CGPoint(x: 0, y: r))
        p.addQuadCurve(to: CGPoint(x: r, y: 0), control: .zero)
        p.addLine(to: CGPoint(x: rect.maxX - r, y: 0))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: r), control: CGPoint(x: rect.maxX, y: 0))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        p.addQuadCurve(to: CGPoint(x: rect.maxX + r, y: rect.maxY), control: CGPoint(x: rect.maxX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}
