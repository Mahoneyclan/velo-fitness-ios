import SwiftUI

struct StatCardView: View {
    let title: String
    let value: String
    let sub: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.veloMuted)
                .tracking(1.5)

            Text(value)
                .font(.system(size: 34, weight: .black, design: .rounded))
                .foregroundStyle(color)
                .minimumScaleFactor(0.6)
                .lineLimit(1)

            if !sub.isEmpty {
                Text(sub)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Color.veloMuted)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 18)
        .frame(minWidth: 150, alignment: .leading)
        .background(Color.veloCard)
        .overlay(
            Rectangle()
                .frame(height: 3)
                .foregroundStyle(color),
            alignment: .top
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.veloBorder, lineWidth: 1)
        )
    }
}

struct SectionHeader: View {
    let text: String
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 16, weight: .black, design: .rounded))
            .foregroundStyle(Color.veloOrange)
            .tracking(2)
            .padding(.bottom, 4)
    }
}

struct ChartCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SectionHeader(text: title)
            content()
        }
        .padding(18)
        .background(Color.veloCard)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.veloBorder, lineWidth: 1))
    }
}
