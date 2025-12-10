import AppKit
import Sparkle

// A no-UI user driver that silently installs updates immediately
final class SilentUserDriver: NSObject, SPUUserDriver {
    func show(_ request: SPUUpdatePermissionRequest, reply: @escaping (SUUpdatePermissionResponse) -> Void) {
        print("[Sparkle] Permission request; checking user preference for automatic updates")
        // Check user preference (default: false - automatic updates disabled)
        let savedPreference = UserDefaults.standard.object(forKey: "SUEnableAutomaticChecks") as? Bool
        let shouldAutoUpdate = savedPreference ?? false
        print("[Sparkle] Automatic checks preference: \(shouldAutoUpdate)")
        
        // Enable automatic checks & downloads only if user has enabled it
        let response = SUUpdatePermissionResponse(
            automaticUpdateChecks: shouldAutoUpdate,
            automaticUpdateDownloading: NSNumber(value: shouldAutoUpdate),
            sendSystemProfile: false
        )
        AnalyticsService.shared.capture("sparkle_permission_requested", [
            "automatic_checks": shouldAutoUpdate,
            "automatic_downloads": shouldAutoUpdate
        ])
        reply(response)
    }

    func showUserInitiatedUpdateCheck(cancellation: @escaping () -> Void) {
        // No UI; ignore
    }

    func showUpdateFound(with appcastItem: SUAppcastItem, state: SPUUserUpdateState, reply: @escaping (SPUUserUpdateChoice) -> Void) {
        print("[Sparkle] Update found: \(appcastItem.displayVersionString ?? appcastItem.versionString)")
        // Always proceed to install
        reply(.install)
    }

    func showUpdateReleaseNotes(with downloadData: SPUDownloadData) {
        // No-op
    }

    func showUpdateReleaseNotesFailedToDownloadWithError(_ error: Error) {
        // No-op
    }

    func showUpdateNotFoundWithError(_ error: Error, acknowledgement: @escaping () -> Void) {
        acknowledgement()
    }

    func showUpdaterError(_ error: Error, acknowledgement: @escaping () -> Void) {
        let nsError = error as NSError
        AnalyticsService.shared.capture("sparkle_user_driver_error", [
            "domain": nsError.domain,
            "code": nsError.code
        ])
        acknowledgement()
    }

    func showDownloadInitiated(cancellation: @escaping () -> Void) {
        // No UI
    }

    func showDownloadDidReceiveExpectedContentLength(_ expectedContentLength: UInt64) {
        // No UI
    }

    func showDownloadDidReceiveData(ofLength length: UInt64) {
        // No UI
    }

    func showDownloadDidStartExtractingUpdate() {
        // No UI
    }

    func showExtractionReceivedProgress(_ progress: Double) {
        // No UI
    }

    func showReady(toInstallAndRelaunch reply: @escaping (SPUUserUpdateChoice) -> Void) {
        print("[Sparkle] Ready to install; allowing termination")
        Task { @MainActor in
            AppDelegate.allowTermination = true
            AnalyticsService.shared.capture("sparkle_install_ready")
            reply(.install)
        }
    }

    func showInstallingUpdate(withApplicationTerminated applicationTerminated: Bool, retryTerminatingApplication: @escaping () -> Void) {
        // No UI; don't retry programmatically here
    }

    func showUpdateInstalledAndRelaunched(_ relaunched: Bool, acknowledgement: @escaping () -> Void) {
        print("[Sparkle] Update installed; relaunched=\(relaunched)")
        AnalyticsService.shared.capture("sparkle_install_completed", [
            "relaunched": relaunched
        ])
        acknowledgement()
    }

    func showUpdateInFocus() {
        // No UI
    }

    func dismissUpdateInstallation() {
        // No UI
    }
}
