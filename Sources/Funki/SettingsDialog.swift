import AppKit

/// The settings, edited in a single alert-style dialog.
@MainActor
final class SettingsDialog: NSObject {
    private let server = NSTextField()
    private let checkInterval = NSTextField()
    private let retryInterval = NSTextField()

    /// Runs the dialog until the user saves valid settings or cancels.
    /// Returns `nil` when cancelled.
    func run(editing settings: Settings) -> Settings? {
        show(settings)

        let alert = NSAlert()
        alert.messageText = "Funki Settings"
        alert.informativeText = "Funki requests the server to find out whether you are online. Leave it empty to use Apple's."
        alert.accessoryView = makeForm()
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")
        alert.window.initialFirstResponder = server

        NSApp.activate()
        while alert.runModal() == .alertFirstButtonReturn {
            switch read() {
            case .success(let settings): return settings
            case .failure(let problem): alert.informativeText = problem.message
            }
        }
        return nil
    }

    private func makeForm() -> NSView {
        server.placeholderString = Endpoint.apple.url.absoluteString
        server.widthAnchor.constraint(equalToConstant: 280).isActive = true

        let reset = NSButton(title: "Reset to Defaults", target: self, action: #selector(resetToDefaults))
        let form = NSGridView(views: [
            [label("Server:"), server],
            [label("Check every"), seconds(checkInterval, suffix: "seconds while online")],
            [label("Retry every"), seconds(retryInterval, suffix: "seconds while offline")],
            [NSGridCell.emptyContentView, reset],
        ])
        form.column(at: 0).xPlacement = .trailing
        form.rowAlignment = .firstBaseline
        form.row(at: 3).topPadding = 6
        form.setFrameSize(form.fittingSize)
        return form
    }

    private func label(_ text: String) -> NSTextField {
        NSTextField(labelWithString: text)
    }

    private func seconds(_ field: NSTextField, suffix: String) -> NSView {
        field.alignment = .right
        field.widthAnchor.constraint(equalToConstant: 52).isActive = true
        let row = NSStackView(views: [field, label(suffix)])
        row.alignment = .firstBaseline
        return row
    }

    /// Fills in the defaults without closing the dialog. Nothing changes until
    /// the user saves.
    @objc private func resetToDefaults() {
        show(Settings())
    }

    private func show(_ settings: Settings) {
        server.stringValue = settings.customURL?.absoluteString ?? ""
        checkInterval.integerValue = settings.checkInterval
        retryInterval.integerValue = settings.retryInterval
    }

    private enum Problem: Error {
        case server, intervals

        var message: String {
            switch self {
            case .server:
                "Please enter a valid http or https address."
            case .intervals:
                "Intervals are whole seconds: at least \(Settings.minimumCheckInterval) while online "
                    + "and at least \(Settings.minimumRetryInterval) while offline."
            }
        }
    }

    private func read() -> Result<Settings, Problem> {
        var settings = Settings()

        let address = server.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if !address.isEmpty {
            guard let url = Settings.parseURL(address) else { return .failure(.server) }
            settings.customURL = url
        }

        guard
            let check = Int(checkInterval.stringValue.trimmingCharacters(in: .whitespaces)),
            let retry = Int(retryInterval.stringValue.trimmingCharacters(in: .whitespaces)),
            check >= Settings.minimumCheckInterval, retry >= Settings.minimumRetryInterval
        else { return .failure(.intervals) }
        settings.checkInterval = check
        settings.retryInterval = retry

        return .success(settings)
    }
}
