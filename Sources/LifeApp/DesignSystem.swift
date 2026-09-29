import AppKit
import SwiftUI

enum LifeStyle {
  static let accents: [Color] = [.indigo, .blue, .purple, .orange, .green, .pink, .teal, .gray]
  // Darker selection colors keep small white navigation labels readable in light appearance.
  static let selectionColors: [Color] = [
    Color(red: 0.34, green: 0.28, blue: 0.70), Color(red: 0.15, green: 0.35, blue: 0.66),
    Color(red: 0.46, green: 0.28, blue: 0.66), Color(red: 0.59, green: 0.29, blue: 0.10),
    Color(red: 0.17, green: 0.39, blue: 0.29), Color(red: 0.62, green: 0.24, blue: 0.43),
    Color(red: 0.12, green: 0.39, blue: 0.42), Color(red: 0.34, green: 0.37, blue: 0.43),
  ]
  static func accent(_ page: String) -> Color { accents[pages.firstIndex(of: page) ?? 0] }
  static let subtitles = [
    "把时间留给重要的事，也留给自己。", "专注眼前的一件事，让今天有条不紊。",
    "从一个想法，到一次踏实的推进。", "记录每一次努力，看见自己的积累。",
    "好好吃饭，也是一种照顾自己的方式。", "留一点时间，享受纯粹的快乐。",
    "收下灵感，让想法慢慢长成。", "一切留在本机，由你掌握。",
  ]
}

struct GlassSurface: ViewModifier {
  var radius: CGFloat = 22
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
  @Environment(\.colorScheme) private var scheme
  func body(content: Content) -> some View {
    if reduceTransparency {
      content.background(
        Color(nsColor: .windowBackgroundColor), in: RoundedRectangle(cornerRadius: radius)
      )
      .overlay(RoundedRectangle(cornerRadius: radius).stroke(.primary.opacity(0.14), lineWidth: 1))
    } else if #available(macOS 26.0, *) {
      content.glassEffect(.regular, in: .rect(cornerRadius: radius))
    } else {
      content.background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: radius))
        .overlay(
          RoundedRectangle(cornerRadius: radius).strokeBorder(
            LinearGradient(
              colors: [
                .white.opacity(scheme == .dark ? 0.24 : 0.8), .white.opacity(0.08),
                .primary.opacity(0.06),
              ], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
        )
        .shadow(color: .black.opacity(scheme == .dark ? 0.18 : 0.06), radius: 16, x: 0, y: 8)
    }
  }
}
extension View {
  func lifeGlass(radius: CGFloat = 22) -> some View { modifier(GlassSurface(radius: radius)) }
  func lifeCard(radius: CGFloat = 20) -> some View { modifier(CardSurface(radius: radius)) }
}
struct CardSurface: ViewModifier {
  var radius: CGFloat
  @Environment(\.colorScheme) private var scheme
  @Environment(\.colorSchemeContrast) private var contrast
  func body(content: Content) -> some View {
    content
      .background(
        Color(nsColor: .controlBackgroundColor).opacity(scheme == .dark ? 0.72 : 0.94),
        in: RoundedRectangle(cornerRadius: radius)
      )
      .overlay(
        RoundedRectangle(cornerRadius: radius).strokeBorder(
          .primary.opacity(contrast == .increased ? 0.28 : 0.055), lineWidth: 1)
      )
      .shadow(color: .black.opacity(scheme == .dark ? 0.12 : 0.025), radius: 10, x: 0, y: 4)
  }
}
struct LifeBackdrop: View {
  @Environment(\.colorScheme) private var scheme
  var body: some View {
    ZStack {
      Color(nsColor: .windowBackgroundColor)
      LinearGradient(
        colors: [
          Color.indigo.opacity(scheme == .dark ? 0.12 : 0.07), .clear, Color.teal.opacity(0.045),
        ], startPoint: .topLeading, endPoint: .bottomTrailing)
      GeometryReader { geometry in
        Ellipse().fill(Color.indigo.opacity(0.08)).frame(width: 430, height: 310)
          .blur(radius: 90).offset(x: geometry.size.width - 370, y: -120)
      }
    }.allowsHitTesting(false).accessibilityHidden(true)
  }
}
struct NavigationItem: View {
  let index: Int
  let selected: Bool
  let action: () -> Void
  @State private var hovering = false
  @Environment(\.colorScheme) private var scheme
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  var body: some View {
    Button(action: action) {
      HStack(spacing: 12) {
        Image(systemName: symbols[index]).font(.system(size: 17, weight: .medium))
          .frame(width: 24, height: 24).foregroundStyle(
            selected
              ? .white
              : (scheme == .dark
                ? LifeStyle.accents[index] : LifeStyle.selectionColors[index].opacity(0.85)))
        Text(pages[index]).font(.system(size: 13, weight: selected ? .semibold : .medium))
          .foregroundStyle(selected ? Color.white : Color.primary.opacity(0.8))
          .accessibilityIdentifier("nav-title-\(index)")
        Spacer(minLength: 0)
        if selected {
          Circle().fill(.white.opacity(0.8)).frame(width: 4, height: 4).accessibilityHidden(true)
        }
      }.padding(.horizontal, 14).frame(height: 40).contentShape(RoundedRectangle(cornerRadius: 13))
        .background {
          if selected {
            RoundedRectangle(cornerRadius: 13).fill(
              LinearGradient(
                colors: [
                  LifeStyle.selectionColors[index].opacity(0.95), LifeStyle.selectionColors[index],
                ],
                startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .shadow(color: LifeStyle.accents[index].opacity(0.2), radius: 8, y: 4)
          } else {
            RoundedRectangle(cornerRadius: 13).fill(.primary.opacity(hovering ? 0.055 : 0))
          }
        }
    }.buttonStyle(NavigationPressStyle()).accessibilityIdentifier("nav-\(index)")
      .onHover { hovering = $0 }
      .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: hovering)
      .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: selected)
      .help(pages[index])
  }
}
struct LifeEmptyState: View {
  let title: String
  let systemImage: String
  let description: Text
  init(_ title: String, systemImage: String, description: Text) {
    self.title = title
    self.systemImage = systemImage
    self.description = description
  }
  var body: some View {
    VStack(spacing: 14) {
      Image(systemName: systemImage).font(.system(size: 28, weight: .light)).foregroundStyle(.tint)
        .frame(width: 68, height: 68).background(
          .tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 21))
      Text(title).font(.system(size: 17, weight: .semibold))
      description.font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
    }.frame(maxWidth: .infinity).padding(.vertical, 42).padding(.horizontal, 20).lifeCard()
  }
}
struct MetricTile: View {
  let label: String
  let value: String
  let detail: String
  let symbol: String
  let color: Color
  var body: some View {
    HStack(alignment: .top, spacing: 14) {
      Image(systemName: symbol).font(.system(size: 19, weight: .medium)).foregroundStyle(color)
        .frame(width: 42, height: 42).background(
          color.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
      VStack(alignment: .leading, spacing: 6) {
        Text(label).font(.caption).foregroundStyle(.secondary)
        Text(value).font(.system(size: 24, weight: .semibold, design: .rounded)).monospacedDigit()
        Text(detail).font(.caption).foregroundStyle(.secondary).fixedSize(
          horizontal: false, vertical: true)
      }
      Spacer(minLength: 0)
    }.padding(20).frame(maxWidth: .infinity, alignment: .leading).lifeCard()
  }
}

struct NavigationPressStyle: ButtonStyle {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  func makeBody(configuration: Configuration) -> some View {
    configuration.label.opacity(configuration.isPressed ? 0.82 : 1)
      .scaleEffect(reduceMotion || !configuration.isPressed ? 1 : 0.985)
      .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: configuration.isPressed)
  }
}
