import SwiftUI

struct WeeklyContextChartsSection: View {
  let snapshot: WeeklyContextChartsSnapshot

  var body: some View {
    HStack(alignment: .top, spacing: 40) {
      WeeklyContextDistributionCard(snapshot: snapshot.distribution)
      WeeklyContextComparisonBarCard(snapshot: snapshot.comparison)
    }
    .frame(width: 958, height: 427, alignment: .topLeading)
  }
}

private struct WeeklyContextDistributionCard: View {
  let snapshot: WeeklyContextDistributionSnapshot

  private enum Design {
    static let width: CGFloat = 340
    static let height: CGFloat = 427
    static let plotWidth: CGFloat = 216
    static let plotHeight: CGFloat = 283
    static let contextColor = Color(hex: "B097FF")
    static let distractionColor = Color(hex: "FF7C5A")
    static let axisColor = Color(hex: "C9C2BC")
  }

  private var hourTicks: [String] {
    ["6pm", "5pm", "4pm", "3pm", "2pm", "1pm", "12pm", "11am", "10am"]
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text("Context shift and distractions distribution")
        .font(.custom("InstrumentSerif-Regular", size: 18))
        .foregroundStyle(Color(hex: "B46531"))
        .padding(.leading, 25)
        .padding(.top, 18)

      HStack(spacing: 24) {
        legendItem("Context shift", color: Design.contextColor)
        legendItem("Distraction", color: Design.distractionColor)
      }
      .frame(maxWidth: .infinity)
      .padding(.top, 23)

      HStack(alignment: .top, spacing: 3) {
        VStack {
          ForEach(hourTicks, id: \.self) { tick in
            Text(tick)
              .font(.custom("Figtree-Regular", size: 8))
              .foregroundStyle(Color.black)

            if tick != hourTicks.last {
              Spacer(minLength: 0)
            }
          }
        }
        .frame(width: 21, height: 261)

        scatterPlot
      }
      .padding(.top, 24)
      .padding(.leading, 46)

      HStack(spacing: 8) {
        ForEach(snapshot.days, id: \.self) { day in
          Text(day)
            .font(.custom("Figtree-Regular", size: 10))
            .foregroundStyle(Color.black)
            .frame(maxWidth: .infinity)
        }
      }
      .frame(width: Design.plotWidth)
      .padding(.top, 7)
      .padding(.leading, 70)
    }
    .frame(width: Design.width, height: Design.height, alignment: .topLeading)
    .background(Color.white.opacity(0.75))
    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
  }

  private var scatterPlot: some View {
    ZStack(alignment: .topLeading) {
      HStack(spacing: 8) {
        ForEach(snapshot.days, id: \.self) { _ in
          Rectangle()
            .fill(Design.axisColor.opacity(0.13))
        }
      }

      VStack(spacing: 27) {
        ForEach(0..<10, id: \.self) { _ in
          Rectangle()
            .fill(Design.axisColor.opacity(0.16))
            .frame(height: 1)
        }
      }

      Rectangle()
        .fill(Design.axisColor)
        .frame(width: 1)

      Rectangle()
        .fill(Design.axisColor)
        .frame(height: 1)
        .frame(maxHeight: .infinity, alignment: .bottom)

      ForEach(snapshot.events) { event in
        RoundedRectangle(cornerRadius: 2, style: .continuous)
          .fill(event.kind == .context ? Design.contextColor : Design.distractionColor)
          .frame(width: 28, height: 1.5)
          .position(point(for: event))
      }
    }
    .frame(width: Design.plotWidth, height: Design.plotHeight)
  }

  private func point(for event: WeeklyContextDistributionEvent) -> CGPoint {
    let dayIndex = snapshot.days.firstIndex(of: event.day) ?? 0
    let x = ((CGFloat(dayIndex) + 0.5) / CGFloat(max(snapshot.days.count, 1))) * Design.plotWidth
    let start = minutes(snapshot.start)
    let end = minutes(snapshot.end)
    let y =
      ((CGFloat(end - minutes(event.time))) / CGFloat(max(end - start, 1))) * Design.plotHeight
    return CGPoint(x: x, y: min(max(y, 0), Design.plotHeight))
  }

  private func legendItem(_ title: String, color: Color) -> some View {
    HStack(spacing: 6) {
      Circle()
        .fill(color)
        .frame(width: 9, height: 9)

      Text(title)
        .font(.custom("Figtree-Regular", size: 10))
        .foregroundStyle(Color.black)
    }
  }
}

private struct WeeklyContextComparisonBarCard: View {
  let snapshot: WeeklyContextComparisonSnapshot

  private enum Design {
    static let width: CGFloat = 574
    static let height: CGFloat = 427
    static let mainHeight: CGFloat = 369
    static let barAreaHeight: CGFloat = 204
    static let maxBarHeight: CGFloat = 180
    static let axisColor = Color(hex: "C9C2BC")
  }

  private var maxValue: Int {
    snapshot.days.flatMap { [$0.distracted, $0.shifts, $0.meetings] }.max() ?? 1
  }

  var body: some View {
    VStack(spacing: 0) {
      VStack(alignment: .leading, spacing: 0) {
        Text("Context shift and distractions comparison")
          .font(.custom("InstrumentSerif-Regular", size: 18))
          .foregroundStyle(Color(hex: "B46531"))
          .padding(.top, 22)
          .padding(.leading, 25)

        bars
          .padding(.top, 45)
          .padding(.horizontal, 52)

        legend
          .padding(.top, 40)
          .frame(maxWidth: .infinity)
      }
      .frame(width: Design.width, height: Design.mainHeight, alignment: .topLeading)
      .background(Color.white.opacity(0.75))
      .overlay(alignment: .bottom) {
        Rectangle()
          .fill(Color(hex: "EBE6E3"))
          .frame(height: 1)
      }

      footer
    }
    .frame(width: Design.width, height: Design.height, alignment: .topLeading)
    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
  }

  private var bars: some View {
    HStack(alignment: .bottom, spacing: 24) {
      ForEach(snapshot.days) { day in
        VStack(spacing: 0) {
          HStack(alignment: .bottom, spacing: 2) {
            metricBar(
              value: day.distracted, color: Color(hex: "FF653B"), softColor: Color(hex: "FF9999"))
            metricBar(
              value: day.shifts, color: Color(hex: "A88CFF"), softColor: Color(hex: "A1B7FF"))
            metricBar(
              value: day.meetings, color: Color(hex: "A29993"), softColor: Color(hex: "D1C7C0"))
          }
          .frame(height: 192, alignment: .bottom)

          Text(day.day)
            .font(.custom("Figtree-Regular", size: 12))
            .foregroundStyle(Color.black)
            .padding(.top, 10)
        }
      }
    }
    .padding(.leading, 10)
    .frame(height: Design.barAreaHeight, alignment: .bottomLeading)
    .overlay(alignment: .leading) {
      Rectangle()
        .fill(Design.axisColor)
        .frame(width: 1)
    }
    .overlay(alignment: .bottom) {
      Rectangle()
        .fill(Design.axisColor)
        .frame(height: 1)
    }
  }

  private func metricBar(value: Int, color: Color, softColor: Color) -> some View {
    let height = max(CGFloat(2), CGFloat(value) / CGFloat(max(maxValue, 1)) * Design.maxBarHeight)

    return VStack(spacing: 4) {
      Text("\(value)")
        .font(.custom("Figtree-Regular", size: 10))
        .foregroundStyle(color)

      RoundedRectangle(cornerRadius: 3, style: .continuous)
        .fill(
          LinearGradient(
            colors: [color.opacity(0.9), softColor.opacity(0.8)],
            startPoint: .top,
            endPoint: .bottom
          )
        )
        .frame(width: 18, height: height)
        .overlay(
          RoundedRectangle(cornerRadius: 3, style: .continuous)
            .stroke(color.opacity(0.72), lineWidth: 0.75)
        )
    }
  }

  private var legend: some View {
    HStack(spacing: 24) {
      legendItem("Number of times distracted", color: Color(hex: "FF653B"))
      legendItem("Number of context shifts", color: Color(hex: "A88CFF"))
      legendItem("Number of meetings", color: Color(hex: "A29993"))
    }
  }

  private func legendItem(_ title: String, color: Color) -> some View {
    HStack(spacing: 4) {
      RoundedRectangle(cornerRadius: 3, style: .continuous)
        .fill(color.opacity(0.65))
        .frame(width: 10, height: 10)

      Text(title)
        .font(.custom("Figtree-Regular", size: 10))
        .foregroundStyle(Color.black)
    }
  }

  private var footer: some View {
    HStack(spacing: 14) {
      HStack(alignment: .top, spacing: 4) {
        Circle()
          .fill(Color(hex: "F5AD41"))
          .frame(width: 7, height: 7)
          .padding(.top, 3)

        Text(snapshot.insight)
          .font(.custom("Figtree-Regular", size: 12))
          .foregroundStyle(Color.black)
          .lineSpacing(1)
          .frame(width: 389, alignment: .leading)
      }

      Spacer(minLength: 0)

      Button("Highlight pattern") {}
        .font(.custom("Figtree-Regular", size: 12))
        .foregroundStyle(Color.black)
        .buttonStyle(.plain)
        .padding(.horizontal, 12)
        .frame(height: 28)
        .background(Color.white)
        .clipShape(Capsule(style: .continuous))
        .overlay(
          Capsule(style: .continuous)
            .stroke(Color(hex: "EBE6E3"), lineWidth: 1)
        )
    }
    .padding(.horizontal, 18)
    .frame(width: Design.width, height: 58, alignment: .center)
    .background(Color(hex: "FAF7F5"))
  }
}

struct WeeklyContextChartsSnapshot {
  let distribution: WeeklyContextDistributionSnapshot
  let comparison: WeeklyContextComparisonSnapshot

  static let figmaPreview = WeeklyContextChartsSnapshot(
    distribution: .figmaPreview,
    comparison: .figmaPreview
  )
}

struct WeeklyContextDistributionSnapshot {
  let days: [String]
  let start: String
  let end: String
  let events: [WeeklyContextDistributionEvent]

  static let figmaPreview = WeeklyContextDistributionSnapshot(
    days: ["Mon", "Tue", "Wed", "Thur", "Fri"],
    start: "10:00",
    end: "18:00",
    events: [
      .init(day: "Mon", kind: .context, time: "10:45"),
      .init(day: "Mon", kind: .distraction, time: "11:55"),
      .init(day: "Mon", kind: .context, time: "13:55"),
      .init(day: "Mon", kind: .distraction, time: "15:08"),
      .init(day: "Mon", kind: .context, time: "16:40"),
      .init(day: "Tue", kind: .context, time: "12:55"),
      .init(day: "Tue", kind: .distraction, time: "14:45"),
      .init(day: "Tue", kind: .context, time: "15:50"),
      .init(day: "Wed", kind: .distraction, time: "10:55"),
      .init(day: "Wed", kind: .context, time: "11:45"),
      .init(day: "Wed", kind: .distraction, time: "13:20"),
      .init(day: "Wed", kind: .context, time: "14:55"),
      .init(day: "Wed", kind: .distraction, time: "15:55"),
      .init(day: "Thu", kind: .distraction, time: "11:20"),
      .init(day: "Thu", kind: .context, time: "14:15"),
      .init(day: "Thu", kind: .distraction, time: "16:18"),
      .init(day: "Fri", kind: .context, time: "10:28"),
      .init(day: "Fri", kind: .distraction, time: "11:55"),
      .init(day: "Fri", kind: .distraction, time: "14:20"),
      .init(day: "Fri", kind: .context, time: "16:58"),
    ]
  )
}

struct WeeklyContextDistributionEvent: Identifiable {
  let id = UUID()
  let day: String
  let kind: WeeklyContextEventKind
  let time: String
}

enum WeeklyContextEventKind {
  case context
  case distraction
}

struct WeeklyContextComparisonSnapshot {
  let days: [WeeklyContextComparisonDay]
  let insight: String

  static let figmaPreview = WeeklyContextComparisonSnapshot(
    days: [
      .init(day: "Mon", distracted: 12, shifts: 15, meetings: 3),
      .init(day: "Tue", distracted: 8, shifts: 10, meetings: 5),
      .init(day: "Wed", distracted: 16, shifts: 28, meetings: 0),
      .init(day: "Thur", distracted: 12, shifts: 5, meetings: 2),
      .init(day: "Fri", distracted: 3, shifts: 10, meetings: 2),
      .init(day: "Sat", distracted: 12, shifts: 12, meetings: 0),
    ],
    insight:
      "You tend to be more distracted and have more context shifts on days with lighter meetings."
  )
}

struct WeeklyContextComparisonDay: Identifiable {
  let id = UUID()
  let day: String
  let distracted: Int
  let shifts: Int
  let meetings: Int
}

private func minutes(_ time: String) -> Int {
  let parts = time.split(separator: ":").compactMap { Int($0) }
  guard parts.count == 2 else { return 0 }
  return parts[0] * 60 + parts[1]
}

#Preview("Context Charts", traits: .fixedLayout(width: 958, height: 427)) {
  WeeklyContextChartsSection(snapshot: .figmaPreview)
    .padding(24)
    .background(Color(hex: "FBF6EF"))
}
