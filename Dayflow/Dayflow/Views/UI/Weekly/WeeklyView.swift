import AppKit
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

struct WeeklyView: View {
  @EnvironmentObject private var categoryStore: CategoryStore
  @Environment(\.scenePhase) private var scenePhase

  @AppStorage("weeklyAccessManuallyLocked") private var isManuallyLocked = false

  @State private var weekRange: WeeklyDateRange
  @State private var dashboardSnapshot: WeeklyDashboardSnapshot
  @State private var isLoading = true
  @State private var weeklyAccessProgress: WeeklyAccessProgressSnapshot
  @State private var notificationState: WeeklyAccessNotificationState = .idle

  init() {
    let initialWeekRange = WeeklyDateRange.containing(Date())
    let initialAccessProgress = WeeklyAccessProgressSnapshot(
      completedBatchCount: StorageManager.shared.countCompletedAnalysisBatchesForWeeklyAccess()
    )

    _weekRange = State(initialValue: initialWeekRange)
    _dashboardSnapshot = State(
      initialValue: WeeklyDashboardBuilder.build(
        cards: [],
        previousWeekCards: [],
        categories: [],
        weekRange: initialWeekRange
      )
    )
    _weeklyAccessProgress = State(initialValue: initialAccessProgress)
  }

  var body: some View {
    Group {
      if isWeeklyAccessUnlocked {
        weeklyDashboard
          .transition(.opacity)
          .task(id: weekRange) {
            await loadWeeklyData(for: weekRange, categories: categoryStore.categories)
          }
          .onChange(of: categoryStore.categories) { _, categories in
            Task {
              await loadWeeklyData(for: weekRange, categories: categories)
            }
          }
          .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task {
              await loadWeeklyData(for: weekRange, categories: categoryStore.categories)
            }
          }
      } else {
        WeeklyAccessLockedView(
          accessProgress: weeklyAccessProgress,
          notificationState: notificationState,
          onNotify: handleWeeklyNotifyAction
        )
        .transition(.opacity)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .background(Color(hex: "FBF6EF"))
    .environment(\.colorScheme, .light)
    .animation(.easeInOut(duration: 0.22), value: isWeeklyAccessUnlocked)
    .onAppear {
      refreshWeeklyAccessState()
    }
    .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { _ in
      refreshWeeklyAccessState()
    }
    .onChange(of: scenePhase) { _, phase in
      guard phase == .active else { return }
      refreshWeeklyAccessState()
    }
  }

  private var weeklyDashboard: some View {
    GeometryReader { geometry in
      let layout = WeeklyAdaptiveLayout(panelWidth: geometry.size.width)

      ScrollView(.vertical, showsIndicators: false) {
        VStack(spacing: 0) {
          WeeklyHeader(
            title: weekRange.title,
            canNavigateForward: weekRange.canNavigateForward,
            onPrevious: showPreviousWeek,
            onNext: showNextWeek
          )
          .overlay(alignment: .trailing) {
            WeeklyAccessLockButton(action: lockWeeklyAccess)
              .frame(width: layout.contentWidth, alignment: .trailing)
              .frame(maxWidth: .infinity, alignment: .center)
          }
          .padding(.bottom, layout.headerBottomPadding)

          VStack(spacing: layout.sectionSpacing) {
            topSummarySection(layout: layout)

            WeeklyExportableGraphic(
              layout: layout,
              title: "Time distribution",
              fileName: exportFileName("time-distribution"),
              designHeight: 339,
              watermarkPlacement: .bottomTrailing
            ) {
              WeeklyOverviewSection(snapshot: dashboardSnapshot.overview)
            }

            WeeklyExportableGraphic(
              layout: layout,
              title: "Suggestions",
              fileName: exportFileName("suggestions"),
              designHeight: 328,
              watermarkPlacement: .topTrailing
            ) {
              WeeklySuggestionsSection(snapshot: dashboardSnapshot.suggestions)
            }

            WeeklyExportableGraphic(
              layout: layout,
              title: "Focus breakdown",
              fileName: exportFileName("focus-breakdown"),
              designHeight: 549,
              watermarkPlacement: .bottomTrailing
            ) {
              WeeklyTreemapSection(snapshot: dashboardSnapshot.treemap)
            }

            WeeklyExportableGraphic(
              layout: layout,
              title: "Application flow",
              fileName: exportFileName("application-flow"),
              designHeight: WeeklyAdaptiveLayout.sankeyHeight,
              watermarkPlacement: .bottomLeading
            ) {
              WeeklySankeySection(
                snapshot: dashboardSnapshot.sankey,
                showsControls: false
              )
            }

            WeeklyExportableGraphic(
              layout: layout,
              title: "Focus heatmap",
              fileName: exportFileName("focus-heatmap"),
              designHeight: 238,
              watermarkPlacement: .bottomTrailing
            ) {
              WeeklyFocusHeatmapSection(snapshot: dashboardSnapshot.heatmap)
            }

            WeeklyExportableGraphic(
              layout: layout,
              title: "Context charts",
              fileName: exportFileName("context-charts"),
              designHeight: 427,
              watermarkPlacement: .bottomTrailing
            ) {
              WeeklyContextChartsSection(snapshot: dashboardSnapshot.contextCharts)
            }
          }
          .frame(width: layout.contentWidth, alignment: .top)
        }
        .padding(.top, layout.topPadding)
        .padding(.bottom, layout.bottomPadding)
        .padding(.horizontal, layout.horizontalPadding)
        .frame(maxWidth: .infinity, alignment: .top)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
  }

  @ViewBuilder
  private func topSummarySection(layout: WeeklyAdaptiveLayout) -> some View {
    if layout.usesTopRowColumns {
      HStack(alignment: .top, spacing: WeeklyAdaptiveLayout.topRowSpacing) {
        WeeklyExportableFixedGraphic(
          availableWidth: WeeklyAdaptiveLayout.donutCardWidth,
          title: "Weekly distribution",
          fileName: exportFileName("weekly-distribution"),
          designWidth: WeeklyAdaptiveLayout.donutCardWidth,
          designHeight: WeeklyAdaptiveLayout.topRowHeight,
          watermarkPlacement: .bottomTrailing
        ) {
          WeeklyDonutSection(snapshot: dashboardSnapshot.donut, isLoading: isLoading)
        }

        WeeklyExportableFixedGraphic(
          availableWidth: WeeklyAdaptiveLayout.highlightsCardWidth,
          title: "Top highlights",
          fileName: exportFileName("top-highlights"),
          designWidth: WeeklyAdaptiveLayout.highlightsCardWidth,
          designHeight: WeeklyAdaptiveLayout.highlightsCardHeight,
          watermarkPlacement: .bottomTrailing
        ) {
          WeeklyHighlightsSection(snapshot: dashboardSnapshot.highlights)
        }
      }
      .frame(
        width: WeeklyAdaptiveLayout.designContentWidth,
        height: WeeklyAdaptiveLayout.topRowHeight,
        alignment: .topLeading
      )
    } else {
      VStack(spacing: layout.compactTopRowSpacing) {
        WeeklyExportableFixedGraphic(
          availableWidth: layout.contentWidth,
          title: "Weekly distribution",
          fileName: exportFileName("weekly-distribution"),
          designWidth: WeeklyAdaptiveLayout.donutCardWidth,
          designHeight: WeeklyAdaptiveLayout.topRowHeight,
          watermarkPlacement: .bottomTrailing
        ) {
          WeeklyDonutSection(snapshot: dashboardSnapshot.donut, isLoading: isLoading)
        }
        .frame(width: layout.contentWidth, alignment: .center)

        WeeklyExportableFixedGraphic(
          availableWidth: layout.contentWidth,
          title: "Top highlights",
          fileName: exportFileName("top-highlights"),
          designWidth: WeeklyAdaptiveLayout.highlightsCardWidth,
          designHeight: WeeklyAdaptiveLayout.highlightsCardHeight,
          watermarkPlacement: .bottomTrailing
        ) {
          WeeklyHighlightsSection(snapshot: dashboardSnapshot.highlights)
        }
        .frame(width: layout.contentWidth, alignment: .center)
      }
      .frame(width: layout.contentWidth, alignment: .top)
    }
  }

  private var isWeeklyAccessUnlocked: Bool {
    weeklyAccessProgress.isComplete && !isManuallyLocked
  }

  private func refreshWeeklyAccessState() {
    weeklyAccessProgress = WeeklyAccessProgressSnapshot(
      completedBatchCount: StorageManager.shared.countCompletedAnalysisBatchesForWeeklyAccess()
    )

    guard weeklyAccessProgress.isComplete, !isManuallyLocked else { return }

    NotificationService.shared.cancelWeeklyUnlockNotification()
  }

  private func handleWeeklyNotifyAction() {
    if weeklyAccessProgress.isComplete {
      NotificationService.shared.cancelWeeklyUnlockNotification()
      notificationState = .idle
      withAnimation(.easeInOut(duration: 0.22)) {
        isManuallyLocked = false
      }
      return
    }

    if notificationState == .denied {
      openNotificationSettings()
      return
    }

    guard notificationState != .requesting else { return }

    notificationState = .requesting

    Task {
      let result = await NotificationService.shared.scheduleWeeklyUnlockNotification(
        at: weeklyAccessProgress.estimatedUnlockDate(from: Date())
      )

      await MainActor.run {
        switch result {
        case .scheduled:
          notificationState = .scheduled
        case .denied:
          notificationState = .denied
        case .failed:
          notificationState = .failed
        }
      }
    }
  }

  private func openNotificationSettings() {
    let bundleID = Bundle.main.bundleIdentifier ?? "ai.dayflow.Dayflow"
    let settingsURLString =
      "x-apple.systempreferences:com.apple.preference.notifications?id=\(bundleID)"

    if let settingsURL = URL(string: settingsURLString) {
      _ = NSWorkspace.shared.open(settingsURL)
      return
    }

    if let fallbackURL = URL(string: "x-apple.systempreferences:com.apple.preference.notifications")
    {
      _ = NSWorkspace.shared.open(fallbackURL)
    }
  }

  private func lockWeeklyAccess() {
    NotificationService.shared.cancelWeeklyUnlockNotification()
    notificationState = .idle
    weeklyAccessProgress = WeeklyAccessProgressSnapshot(
      completedBatchCount: StorageManager.shared.countCompletedAnalysisBatchesForWeeklyAccess()
    )

    withAnimation(.easeInOut(duration: 0.22)) {
      isManuallyLocked = true
    }
  }

  private func exportFileName(_ graphicSlug: String) -> String {
    let weekSlug = weekRange.title
      .lowercased()
      .components(separatedBy: CharacterSet.alphanumerics.inverted)
      .filter { !$0.isEmpty }
      .joined(separator: "-")

    return "dayflow-weekly-\(weekSlug)-\(graphicSlug).png"
  }

  private func showPreviousWeek() {
    weekRange = weekRange.shifted(byWeeks: -1)
  }

  private func showNextWeek() {
    guard weekRange.canNavigateForward else { return }
    weekRange = weekRange.shifted(byWeeks: 1)
  }

  @MainActor
  private func loadWeeklyData(
    for range: WeeklyDateRange,
    categories: [TimelineCategory]
  ) async {
    isLoading = true

    let previousRange = range.shifted(byWeeks: -1)
    let cards = StorageManager.shared.fetchTimelineCardsByTimeRange(
      from: range.weekStart,
      to: range.weekEnd
    )
    let previousCards = StorageManager.shared.fetchTimelineCardsByTimeRange(
      from: previousRange.weekStart,
      to: previousRange.weekEnd
    )
    let snapshot = WeeklyDashboardBuilder.build(
      cards: cards,
      previousWeekCards: previousCards,
      categories: categories,
      weekRange: range
    )

    guard range == weekRange else { return }
    dashboardSnapshot = snapshot
    isLoading = false
  }
}

private struct WeeklyAccessLockButton: View {
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: "lock.fill")
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(Color(hex: "B46531"))
        .frame(width: 32, height: 32)
        .background(
          Circle()
            .fill(Color.white.opacity(0.92))
        )
        .overlay(
          Circle()
            .stroke(Color(hex: "EBD8C8"), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 5, y: 2)
    }
    .buttonStyle(.plain)
    .help("Lock Weekly")
    .accessibilityLabel("Lock Weekly")
    .hoverScaleEffect(scale: 1.03)
    .pointingHandCursorOnHover(reassertOnPressEnd: true)
  }
}

private struct WeeklyAdaptiveLayout {
  static let designContentWidth: CGFloat = 958
  static let donutCardWidth: CGFloat = 461
  static let highlightsCardWidth: CGFloat = 470
  static let highlightsCardHeight: CGFloat = 298
  static let topRowHeight: CGFloat = 300
  static let topRowSpacing: CGFloat = 27
  static let sankeyHeight: CGFloat = designContentWidth * 933 / 1748

  let panelWidth: CGFloat

  var horizontalPadding: CGFloat {
    min(80, max(24, panelWidth * 0.05))
  }

  private var rawContentWidth: CGFloat {
    max(1, panelWidth - horizontalPadding * 2)
  }

  var contentWidth: CGFloat {
    min(Self.designContentWidth, rawContentWidth)
  }

  var shrinkScale: CGFloat {
    min(1, contentWidth / Self.designContentWidth)
  }

  var sectionSpacing: CGFloat {
    24
  }

  var compactTopRowSpacing: CGFloat {
    18
  }

  var headerBottomPadding: CGFloat {
    16
  }

  var topPadding: CGFloat {
    28
  }

  var bottomPadding: CGFloat {
    48
  }

  var usesTopRowColumns: Bool {
    rawContentWidth >= Self.designContentWidth
  }
}

private struct WeeklyExportableGraphic<Content: View>: View {
  let layout: WeeklyAdaptiveLayout
  let title: String
  let fileName: String
  let designHeight: CGFloat
  let watermarkPlacement: WeeklyExportWatermarkPlacement
  let content: () -> Content

  init(
    layout: WeeklyAdaptiveLayout,
    title: String,
    fileName: String,
    designHeight: CGFloat,
    watermarkPlacement: WeeklyExportWatermarkPlacement,
    @ViewBuilder content: @escaping () -> Content
  ) {
    self.layout = layout
    self.title = title
    self.fileName = fileName
    self.designHeight = designHeight
    self.watermarkPlacement = watermarkPlacement
    self.content = content
  }

  var body: some View {
    let scale = layout.shrinkScale

    ZStack(alignment: .topTrailing) {
      content()
        .frame(
          width: WeeklyAdaptiveLayout.designContentWidth,
          height: designHeight,
          alignment: .topLeading
        )
        .scaleEffect(scale, anchor: .topLeading)
        .frame(
          width: WeeklyAdaptiveLayout.designContentWidth * scale,
          height: designHeight * scale,
          alignment: .topLeading
        )

      WeeklyGraphicDownloadButton(title: title) {
        WeeklyGraphicExporter.savePNG(
          fileName: fileName,
          size: CGSize(width: WeeklyAdaptiveLayout.designContentWidth, height: designHeight),
          watermarkPlacement: watermarkPlacement
        ) {
          content()
        }
      }
      .padding(.top, 10)
      .padding(.trailing, 10)
    }
    .frame(
      width: layout.contentWidth,
      height: designHeight * scale,
      alignment: .topLeading
    )
  }
}

private struct WeeklyExportableFixedGraphic<Content: View>: View {
  let availableWidth: CGFloat
  let title: String
  let fileName: String
  let designWidth: CGFloat
  let designHeight: CGFloat
  let watermarkPlacement: WeeklyExportWatermarkPlacement
  let content: () -> Content

  init(
    availableWidth: CGFloat,
    title: String,
    fileName: String,
    designWidth: CGFloat,
    designHeight: CGFloat,
    watermarkPlacement: WeeklyExportWatermarkPlacement,
    @ViewBuilder content: @escaping () -> Content
  ) {
    self.availableWidth = availableWidth
    self.title = title
    self.fileName = fileName
    self.designWidth = designWidth
    self.designHeight = designHeight
    self.watermarkPlacement = watermarkPlacement
    self.content = content
  }

  private var scale: CGFloat {
    min(1, max(1, availableWidth) / designWidth)
  }

  var body: some View {
    ZStack(alignment: .topTrailing) {
      content()
        .frame(width: designWidth, height: designHeight, alignment: .topLeading)
        .scaleEffect(scale, anchor: .topLeading)
        .frame(
          width: designWidth * scale,
          height: designHeight * scale,
          alignment: .topLeading
        )

      WeeklyGraphicDownloadButton(title: title) {
        WeeklyGraphicExporter.savePNG(
          fileName: fileName,
          size: CGSize(width: designWidth, height: designHeight),
          watermarkPlacement: watermarkPlacement
        ) {
          content()
        }
      }
      .padding(.top, 10)
      .padding(.trailing, 10)
    }
    .frame(
      width: designWidth * scale,
      height: designHeight * scale,
      alignment: .topLeading
    )
  }
}

private struct WeeklyGraphicDownloadButton: View {
  let title: String
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      Image(systemName: "arrow.down.to.line")
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(Color(hex: "B46531"))
        .frame(width: 28, height: 28)
        .background(
          Circle()
            .fill(Color.white.opacity(0.92))
        )
        .overlay(
          Circle()
            .stroke(Color(hex: "EBE6E3"), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.06), radius: 5, y: 2)
    }
    .buttonStyle(.plain)
    .help("Download \(title) as a full-resolution PNG")
    .hoverScaleEffect(scale: 1.03)
    .pointingHandCursorOnHover(reassertOnPressEnd: true)
  }
}

@MainActor
private enum WeeklyGraphicExporter {
  private static let targetPixelWidth: CGFloat = 1080

  static func savePNG<Content: View>(
    fileName: String,
    size: CGSize,
    watermarkPlacement: WeeklyExportWatermarkPlacement,
    @ViewBuilder content: () -> Content
  ) {
    let exportView = content()
      .frame(width: size.width, height: size.height, alignment: .topLeading)
      .background(Color(hex: "FBF6EF"))
      .overlay(alignment: watermarkPlacement.alignment) {
        WeeklyExportWatermark()
          .padding(watermarkPlacement.padding)
      }
      .environment(\.colorScheme, .light)

    let renderer = ImageRenderer(content: exportView)
    renderer.proposedSize = ProposedViewSize(width: size.width, height: size.height)
    renderer.scale = targetPixelWidth / size.width

    guard let image = renderer.cgImage else {
      NSSound.beep()
      return
    }

    let savePanel = NSSavePanel()
    savePanel.title = "Download graphic"
    savePanel.prompt = "Download"
    savePanel.nameFieldStringValue = fileName
    savePanel.allowedContentTypes = [.png]
    savePanel.canCreateDirectories = true

    guard savePanel.runModal() == .OK, let url = savePanel.url else { return }

    guard
      let destination = CGImageDestinationCreateWithURL(
        url as CFURL,
        UTType.png.identifier as CFString,
        1,
        nil
      )
    else {
      NSSound.beep()
      return
    }

    CGImageDestinationAddImage(destination, image, nil)

    if !CGImageDestinationFinalize(destination) {
      NSSound.beep()
    }
  }
}

private enum WeeklyExportWatermarkPlacement {
  case topLeading
  case topTrailing
  case bottomLeading
  case bottomTrailing

  var alignment: Alignment {
    switch self {
    case .topLeading:
      return .topLeading
    case .topTrailing:
      return .topTrailing
    case .bottomLeading:
      return .bottomLeading
    case .bottomTrailing:
      return .bottomTrailing
    }
  }

  var padding: EdgeInsets {
    switch self {
    case .topLeading:
      return EdgeInsets(top: 14, leading: 14, bottom: 0, trailing: 0)
    case .topTrailing:
      return EdgeInsets(top: 14, leading: 0, bottom: 0, trailing: 14)
    case .bottomLeading:
      return EdgeInsets(top: 0, leading: 14, bottom: 14, trailing: 0)
    case .bottomTrailing:
      return EdgeInsets(top: 0, leading: 0, bottom: 14, trailing: 14)
    }
  }
}

private struct WeeklyExportWatermark: View {
  var body: some View {
    HStack(spacing: 6) {
      Image("DayflowLogo")
        .resizable()
        .scaledToFit()
        .frame(width: 16, height: 16)

      WeeklyGeneratedWithDayflowText()
    }
    .padding(.leading, 7)
    .padding(.trailing, 9)
    .frame(height: 26)
    .background(
      Capsule(style: .continuous)
        .fill(Color.white.opacity(0.94))
    )
    .overlay(
      Capsule(style: .continuous)
        .stroke(Color(hex: "EBE6E3"), lineWidth: 1)
    )
    .shadow(color: Color.black.opacity(0.05), radius: 6, y: 2)
  }
}

private struct WeeklyGeneratedWithDayflowText: View {
  var body: some View {
    HStack(spacing: 3) {
      Text("Generated with")
        .font(.custom("Figtree-SemiBold", size: 10))
        .foregroundStyle(Color(hex: "786A61"))

      Text("Dayflow")
        .font(.custom("Figtree-Bold", size: 10))
        .foregroundStyle(Color(hex: "B46531"))
    }
  }
}

#Preview("Weekly View", traits: .fixedLayout(width: 1119, height: 920)) {
  WeeklyView()
    .environmentObject(CategoryStore.shared)
}
