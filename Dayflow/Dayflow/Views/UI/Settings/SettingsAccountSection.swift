import AppKit
import SwiftUI

struct SettingsAccountSection: View {
  @ObservedObject private var authManager = DayflowAuthManager.shared
  @State private var isAuthSheetPresented = false
  @State private var selectedBillingInterval: DayflowBillingInterval = .yearly

  var body: some View {
    VStack(alignment: .leading, spacing: SettingsStyle.sectionSpacing) {
      if authManager.entitlements.status == "active" {
        currentPlanSection
      } else {
        accountSection
        upgradeSection
      }

      if let errorText = authManager.errorText {
        Text(errorText)
          .font(.custom("Figtree", size: 11))
          .foregroundColor(SettingsStyle.destructive)
          .textSelection(.enabled)
      }
    }
    .sheet(isPresented: $isAuthSheetPresented) {
      DayflowSignInSheet {
        isAuthSheetPresented = false
      }
      .frame(width: 430)
    }
    .task {
      authManager.loadStoredSessionIfNeeded()
    }
  }

  private var accountSection: some View {
    SettingsSection(
      title: "Account",
      subtitle: "Sign in once to keep Dayflow Pro and cloud features attached to this Mac."
    ) {
      VStack(alignment: .leading, spacing: 0) {
        SettingsRow(
          label: "Dayflow account",
          subtitle: authManager.isSignedIn
            ? authManager.displayIdentity
            : nil,
          showsDivider: authManager.isSignedIn
        ) {
          HStack(spacing: 8) {
            SettingsStatusDot(
              state: authManager.isSignedIn ? .good : .warn,
              label: authManager.isSignedIn ? "Signed in" : "Signed out"
            )

            if authManager.isSignedIn {
              SettingsSecondaryButton(
                title: "Sign out",
                systemImage: "rectangle.portrait.and.arrow.right",
                isDisabled: authManager.isBusy,
                action: { Task { await authManager.signOut() } }
              )
            } else {
              SettingsPrimaryButton(
                title: "Sign in",
                systemImage: "person.crop.circle",
                isLoading: authManager.isBusy && authManager.hasLoadedStoredSession == false,
                action: { isAuthSheetPresented = true }
              )
            }
          }
        }
      }
    }
  }

  private var currentPlanSection: some View {
    SettingsSection(
      title: "Account",
      subtitle: "Manage your Dayflow account and subscription."
    ) {
      ActiveProCard(
        entitlement: authManager.entitlements,
        email: authManager.displayIdentity,
        isBusy: authManager.isBusy,
        signOutAction: { Task { await authManager.signOut() } },
        manageBillingAction: { Task { await authManager.openBillingPortal() } }
      )
    }
  }

  private var upgradeSection: some View {
    SettingsSection(
      title: "Upgrade to Dayflow Pro",
      subtitle: "Pick a plan, then finish securely in Stripe Checkout."
    ) {
      VStack(alignment: .leading, spacing: 16) {
        HStack(alignment: .top, spacing: 12) {
          BillingPlanCard(
            title: "Monthly",
            price: "$18",
            cadence: "/mo",
            note: "Flexible monthly billing.",
            badge: nil,
            isSelected: selectedBillingInterval == .monthly
          ) {
            withAnimation(.easeOut(duration: 0.16)) {
              selectedBillingInterval = .monthly
            }
          }

          BillingPlanCard(
            title: "Yearly",
            price: "$15",
            cadence: "/mo",
            note: "Billed yearly.",
            badge: "2 months free",
            isSelected: selectedBillingInterval == .yearly
          ) {
            withAnimation(.easeOut(duration: 0.16)) {
              selectedBillingInterval = .yearly
            }
          }
        }
        .padding(.leading, 2)

        ProFeatureList()

        HStack(alignment: .center, spacing: 12) {
          SettingsPrimaryButton(
            title: authManager.isSignedIn ? "Start 14-day trial" : "Sign in to upgrade",
            systemImage: authManager.isSignedIn ? "creditcard" : "person.crop.circle",
            isLoading: authManager.isBusy,
            action: upgradeAction
          )

          VStack(alignment: .leading, spacing: 4) {
            Text("Cancel any time. No-questions-asked refunds.")
              .font(.custom("Figtree", size: 12))
              .foregroundColor(SettingsStyle.secondary)
              .fixedSize(horizontal: false, vertical: true)

            SettingsLinkButton(title: "Privacy policy", systemImage: "lock") {
              openPrivacyPolicy()
            }
          }
        }
      }
    }
  }

  private func upgradeAction() {
    guard authManager.isSignedIn else {
      isAuthSheetPresented = true
      return
    }

    Task {
      await authManager.openBillingCheckout(interval: selectedBillingInterval)
    }
  }

  private func openPrivacyPolicy() {
    guard let url = URL(string: "https://dayflow.so/privacy") else { return }
    NSWorkspace.shared.open(url)
  }
}

private func formattedEntitlementDate(_ value: String?) -> String? {
  guard let value, !value.isEmpty else { return nil }

  if value.count >= 10 {
    let datePrefix = String(value.prefix(10))
    let dateOnlyFormatter = DateFormatter()
    dateOnlyFormatter.locale = Locale(identifier: "en_US_POSIX")
    dateOnlyFormatter.timeZone = TimeZone(secondsFromGMT: 0)
    dateOnlyFormatter.dateFormat = "yyyy-MM-dd"

    if let date = dateOnlyFormatter.date(from: datePrefix) {
      let displayFormatter = DateFormatter()
      displayFormatter.locale = Locale.current
      displayFormatter.timeZone = TimeZone(secondsFromGMT: 0)
      displayFormatter.dateStyle = .medium
      displayFormatter.timeStyle = .none
      return displayFormatter.string(from: date)
    }
  }

  let formatters: [ISO8601DateFormatter] = [
    {
      let formatter = ISO8601DateFormatter()
      formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
      return formatter
    }(),
    {
      let formatter = ISO8601DateFormatter()
      formatter.formatOptions = [.withInternetDateTime]
      return formatter
    }(),
  ]

  let date = formatters.compactMap { $0.date(from: value) }.first
  guard let date else { return nil }

  let displayFormatter = DateFormatter()
  displayFormatter.locale = Locale.current
  displayFormatter.dateStyle = .medium
  displayFormatter.timeStyle = .none
  return displayFormatter.string(from: date)
}

private struct ActiveProCard: View {
  let entitlement: DayflowEntitlement
  let email: String
  let isBusy: Bool
  let signOutAction: () -> Void
  let manageBillingAction: () -> Void

  private var isGifted: Bool {
    entitlement.source == "manual"
  }

  private var title: String {
    isGifted ? "Gifted Pro" : "Dayflow Pro"
  }

  private var badge: String {
    isGifted ? "Gifted" : "Active"
  }

  private var description: String {
    if isGifted {
      return
        "You have complimentary Dayflow Pro access. There is no billing to manage for this account."
    }

    return "Your Pro access is active on this Mac and attached to your Dayflow account."
  }

  private var dateLabel: String {
    if formattedEntitlementDate(entitlement.currentPeriodEnd) == nil {
      return "Status"
    }

    return isGifted ? "Access through" : "Renews"
  }

  private var dateValue: String {
    formattedEntitlementDate(entitlement.currentPeriodEnd) ?? "Active"
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 18) {
      HStack(alignment: .top, spacing: 16) {
        ZStack {
          RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(SettingsStyle.ink.opacity(0.1))
          Image(systemName: isGifted ? "gift.fill" : "star.fill")
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(SettingsStyle.ink)
        }
        .frame(width: 34, height: 34)

        VStack(alignment: .leading, spacing: 5) {
          HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(title)
              .font(.custom("Figtree", size: 22))
              .fontWeight(.bold)
              .foregroundColor(SettingsStyle.text)

            SettingsBadge(text: badge.uppercased(), isAccent: true)
          }

          Text(description)
            .font(.custom("Figtree", size: 13))
            .foregroundColor(SettingsStyle.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }

        Spacer(minLength: 16)

        SettingsStatusDot(state: .good, label: "Active")
          .padding(.top, 4)
      }

      HStack(alignment: .top, spacing: 12) {
        ActiveProInfoTile(label: "Signed in as", value: email)
        ActiveProInfoTile(label: dateLabel, value: dateValue)
      }

      Rectangle()
        .fill(SettingsStyle.divider)
        .frame(height: 1)

      HStack(alignment: .center, spacing: 16) {
        ProFeatureList()

        Spacer(minLength: 16)

        HStack(spacing: 8) {
          SettingsSecondaryButton(
            title: "Sign out",
            systemImage: "rectangle.portrait.and.arrow.right",
            isDisabled: isBusy,
            action: signOutAction
          )

          if !isGifted {
            SettingsPrimaryButton(
              title: "Manage billing",
              systemImage: "creditcard",
              isLoading: isBusy,
              action: manageBillingAction
            )
          }
        }
      }
    }
    .padding(18)
    .background(
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .fill(Color.white.opacity(0.42))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 10, style: .continuous)
        .stroke(SettingsStyle.divider, lineWidth: 1)
    )
  }
}

private struct ActiveProInfoTile: View {
  let label: String
  let value: String

  var body: some View {
    VStack(alignment: .leading, spacing: 5) {
      Text(label.uppercased())
        .font(.custom("Figtree", size: 10))
        .fontWeight(.bold)
        .kerning(0.5)
        .foregroundColor(SettingsStyle.meta)

      Text(value)
        .font(.custom("Figtree", size: 14))
        .fontWeight(.semibold)
        .foregroundColor(SettingsStyle.text)
        .lineLimit(1)
        .truncationMode(.middle)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(12)
    .background(
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .fill(Color.white.opacity(0.45))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .stroke(SettingsStyle.divider, lineWidth: 1)
    )
  }
}

private struct BillingPlanCard: View {
  let title: String
  let price: String
  let cadence: String
  let note: String
  let badge: String?
  let isSelected: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      VStack(alignment: .leading, spacing: 12) {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
          Text(title)
            .font(.custom("Figtree", size: 13))
            .fontWeight(.bold)
            .foregroundColor(SettingsStyle.text)

          Spacer(minLength: 8)

          if let badge {
            SettingsBadge(text: badge.uppercased(), isAccent: true)
          }
        }

        HStack(alignment: .firstTextBaseline, spacing: 4) {
          Text(price)
            .font(.custom("InstrumentSerif-Regular", size: 38))
            .foregroundColor(SettingsStyle.text)
          Text(cadence)
            .font(.custom("Figtree", size: 13))
            .fontWeight(.semibold)
            .foregroundColor(SettingsStyle.secondary)
        }

        Text(note)
          .font(.custom("Figtree", size: 12))
          .foregroundColor(SettingsStyle.secondary)
          .fixedSize(horizontal: false, vertical: true)
      }
      .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
      .padding(14)
      .background(
        RoundedRectangle(cornerRadius: 8, style: .continuous)
          .fill(isSelected ? SettingsStyle.ink.opacity(0.06) : Color.white.opacity(0.55))
      )
      .overlay(
        RoundedRectangle(cornerRadius: 8, style: .continuous)
          .stroke(isSelected ? SettingsStyle.ink.opacity(0.8) : SettingsStyle.divider, lineWidth: 1)
      )
    }
    .buttonStyle(.plain)
    .pointingHandCursor()
  }
}

private struct ProFeatureList: View {
  private let features = [
    "Zero setup cloud AI for timeline generation",
    "Daily and weekly reports without provider setup",
    "Priority support",
    "Processed securely and never used to train AI models",
  ]

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      ForEach(features, id: \.self) { feature in
        HStack(alignment: .top, spacing: 8) {
          Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(SettingsStyle.statusGood)
            .padding(.top, 1)

          Text(feature)
            .font(.custom("Figtree", size: 12))
            .foregroundColor(SettingsStyle.text)
            .fixedSize(horizontal: false, vertical: true)
        }
      }
    }
    .padding(.top, 2)
  }
}

private struct DayflowSignInSheet: View {
  private enum Step {
    case email
    case code
  }

  private enum Field {
    case email
    case code
  }

  @ObservedObject private var authManager = DayflowAuthManager.shared
  @FocusState private var focusedField: Field?

  let onDismiss: () -> Void

  @State private var step: Step = .email
  @State private var emailAddress = ""
  @State private var verificationEmail: String?
  @State private var verificationCode = ""
  @State private var didAutoSubmitCode = false

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      header

      switch step {
      case .email:
        emailForm
      case .code:
        codeForm
      }

      if let errorText = authManager.errorText {
        Text(errorText)
          .font(.custom("Figtree", size: 12))
          .foregroundColor(SettingsStyle.destructive)
          .textSelection(.enabled)
      }
    }
    .padding(26)
    .background(Color.white)
    .onAppear {
      emailAddress = authManager.signedInEmail ?? emailAddress
      focusedField = step == .email ? .email : .code
    }
    .onChange(of: authManager.isSignedIn) { _, isSignedIn in
      guard isSignedIn else { return }
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
        onDismiss()
      }
    }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 5) {
      Text(step == .email ? "Sign in to Dayflow" : "Check your email")
        .font(.custom("InstrumentSerif-Regular", size: 30))
        .foregroundColor(SettingsStyle.text)

      Text(
        step == .email
          ? "Enter your email and Dayflow will send a 6 digit code."
          : "Enter the code sent to \(verificationEmail ?? authManager.pendingEmail ?? emailAddressTrimmed)."
      )
      .font(.custom("Figtree", size: 13))
      .foregroundColor(SettingsStyle.secondary)
      .fixedSize(horizontal: false, vertical: true)
    }
  }

  private var emailForm: some View {
    VStack(alignment: .leading, spacing: 14) {
      TextField("you@example.com", text: $emailAddress)
        .textFieldStyle(.roundedBorder)
        .font(.custom("Figtree", size: 14))
        .focused($focusedField, equals: .email)
        .disabled(authManager.isBusy)
        .onSubmit { sendCode() }

      HStack(spacing: 10) {
        SettingsPrimaryButton(
          title: "Continue",
          systemImage: "arrow.right",
          isLoading: authManager.isBusy,
          isDisabled: emailAddressTrimmed.isEmpty,
          action: sendCode
        )

        SettingsSecondaryButton(
          title: "Cancel",
          isDisabled: authManager.isBusy,
          action: onDismiss
        )
      }
    }
  }

  private var codeForm: some View {
    VStack(alignment: .leading, spacing: 14) {
      TextField("000000", text: $verificationCode)
        .textFieldStyle(.plain)
        .font(.system(size: 30, weight: .semibold, design: .monospaced))
        .multilineTextAlignment(.center)
        .tracking(8)
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
          RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(Color.black.opacity(0.04))
        )
        .overlay(
          RoundedRectangle(cornerRadius: 8, style: .continuous)
            .stroke(SettingsStyle.divider, lineWidth: 1)
        )
        .focused($focusedField, equals: .code)
        .disabled(authManager.isBusy)
        .onChange(of: verificationCode) { _, newValue in
          let digits = String(newValue.filter(\.isNumber).prefix(6))
          if digits != newValue {
            verificationCode = digits
          }
          guard digits.count == 6, !didAutoSubmitCode, !authManager.isBusy else { return }
          didAutoSubmitCode = true
          verifyCode()
        }
        .onSubmit { verifyCode() }

      HStack(spacing: 10) {
        SettingsPrimaryButton(
          title: "Verify",
          systemImage: "checkmark",
          isLoading: authManager.isBusy,
          isDisabled: verificationCodeTrimmed.count != 6,
          action: verifyCode
        )

        SettingsSecondaryButton(
          title: "Resend",
          isDisabled: authManager.isBusy,
          action: {
            Task {
              didAutoSubmitCode = false
              verificationCode = ""
              await authManager.sendCode(to: verificationEmail ?? emailAddressTrimmed)
              verificationEmail = authManager.pendingEmail ?? verificationEmail
              focusedField = .code
            }
          }
        )

        SettingsSecondaryButton(
          title: "Change email",
          isDisabled: authManager.isBusy,
          action: {
            authManager.useDifferentEmail()
            verificationEmail = nil
            verificationCode = ""
            didAutoSubmitCode = false
            step = .email
            focusedField = .email
          }
        )
      }
    }
  }

  private func sendCode() {
    guard !emailAddressTrimmed.isEmpty else { return }
    Task {
      await authManager.sendCode(to: emailAddressTrimmed)
      if authManager.canVerifyCode, authManager.errorText == nil {
        verificationEmail = authManager.pendingEmail ?? emailAddressTrimmed
        verificationCode = ""
        didAutoSubmitCode = false
        step = .code
        focusedField = .code
      }
    }
  }

  private func verifyCode() {
    guard verificationCodeTrimmed.count == 6 else { return }
    guard let email = verificationEmail ?? authManager.pendingEmail else {
      step = .email
      focusedField = .email
      return
    }
    Task {
      await authManager.verifyCode(verificationCodeTrimmed, for: email)
      if authManager.errorText != nil {
        didAutoSubmitCode = false
      }
    }
  }

  private var emailAddressTrimmed: String {
    emailAddress.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var verificationCodeTrimmed: String {
    String(verificationCode.filter(\.isNumber).prefix(6))
  }
}
