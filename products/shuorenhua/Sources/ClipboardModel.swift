import AppKit
import Foundation

@MainActor
final class ClipboardModel: ObservableObject {
    @Published var sourceText = ""
    @Published var intention = ""
    @Published var reply = ""
    @Published private(set) var plain = ""
    @Published private(set) var unclear = ""
    @Published private(set) var isWorking = false
    @Published private(set) var clipboardHint = ""
    @Published private(set) var errorMessage: String?
    @Published private(set) var needsAccessibilityPermission = false
    @Published private(set) var installedProviderIDs: Set<String> = []
    @Published var selectedSceneID: String {
        didSet { UserDefaults.standard.set(selectedSceneID, forKey: "preferredWorkplaceScene") }
    }
    @Published var selectedProviderID: String {
        didSet { UserDefaults.standard.set(selectedProviderID, forKey: "preferredAIProviderV2") }
    }
    var onHandoff: (() -> Void)?
    var onResult: (() -> Void)?
    private var task: Task<Void, Never>?
    private var lastClipboardCount = -1
    private var lastCopiedText = ""

    init() {
        installedProviderIDs = Set(AIProvider.all.filter { $0.isInstalled() }.map(\.id))
        let savedScene = UserDefaults.standard.string(forKey: "preferredWorkplaceScene") ?? "leader"
        selectedSceneID = WorkplaceScene.all.contains { $0.id == savedScene } ? savedScene : "leader"
        // v0.8 deliberately starts from the built-in Feishu/Doubao route instead
        // of inheriting the old automatic WorkBuddy bridge preference.
        let saved = UserDefaults.standard.string(forKey: "preferredAIProviderV2") ?? "feishu"
        selectedProviderID = AIProvider.all.contains { $0.id == saved } ? saved : "feishu"
    }
    var selectedScene: WorkplaceScene { WorkplaceScene.all.first { $0.id == selectedSceneID } ?? WorkplaceScene.all[0] }
    var selectedProvider: AIProvider { AIProvider.all.first { $0.id == selectedProviderID } ?? AIProvider.all[0] }
    var hasUsableMessage: Bool { !PromptBuilder.normalize(sourceText).isEmpty && !PromptBuilder.isGeneratedTask(sourceText) }
    var automaticAvailable: Bool { false }
    var hasResult: Bool { !plain.isEmpty }

    @discardableResult
    func acceptSelectedText(_ raw: String) -> Bool {
        guard !isWorking else {
            clipboardHint = "上一句话还在处理中"
            return false
        }
        let text = PromptBuilder.normalize(raw)
        guard !text.isEmpty, !PromptBuilder.isGeneratedTask(text) else {
            clipboardHint = "没有读到可处理的文字"
            return false
        }
        sourceText = text
        clearResult()
        clipboardHint = "已接住选中的话"
        return true
    }

    func refreshClipboard(force: Bool = false) {
        guard !isWorking else { return }
        let board = NSPasteboard.general
        guard force || lastClipboardCount != board.changeCount else { return }
        lastClipboardCount = board.changeCount
        guard let raw = board.string(forType: .string) else { return }
        let text = PromptBuilder.normalize(raw)
        guard !text.isEmpty, !PromptBuilder.isGeneratedTask(text), text != lastCopiedText, text != sourceText else { return }
        sourceText = text
        clearResult()
        clipboardHint = ""
    }
    func clearResult() {
        plain = ""; unclear = ""; reply = ""; intention = ""
        errorMessage = nil; needsAccessibilityPermission = false
    }
    func reset() { cancel(); sourceText = ""; clearResult(); clipboardHint = "" }
    func understand() { manualHandoff() }
    func composeReply() {
        guard !intention.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        run(replying: true)
    }
    private func run(replying: Bool) {
        guard !isWorking, hasUsableMessage else { return }
        guard automaticAvailable else { manualHandoff(); return }
        errorMessage = nil; needsAccessibilityPermission = false; isWorking = true
        if !replying { plain = ""; unclear = ""; reply = "" }
        let token = UUID().uuidString
        let prompt = PromptBuilder.bridge(message: sourceText, intention: replying ? intention : nil, token: token)
        let provider = selectedProvider
        task = Task {
            do {
                onHandoff?()
                let result = try await DesktopAI.run(provider: provider, prompt: prompt, token: token) { [weak self] in self?.clipboardHint = $0 }
                try Task.checkCancellation()
                if replying {
                    guard !result.reply.isEmpty else { throw AIBridgeError.failed }
                    reply = result.reply
                    clipboardHint = ""
                } else {
                    guard !result.plain.isEmpty else { throw AIBridgeError.failed }
                    plain = result.plain; unclear = result.unclear
                    clipboardHint = ""
                }
            } catch {
                errorMessage = error is CancellationError ? AIBridgeError.cancelled.localizedDescription : error.localizedDescription
                if case AIBridgeError.permission = error { needsAccessibilityPermission = true }
                clipboardHint = "原话还在，不用重来"
            }
            isWorking = false; task = nil
            onResult?()
        }
    }
    func cancel() { task?.cancel() }
    func showStatus(_ text: String) { clipboardHint = text }
    func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }
    func copyQuickReply(_ text: String) { copy(text); clipboardHint = "已复制，回到聊天里粘贴" }
    func copy(_ text: String) {
        let board = NSPasteboard.general; board.clearContents()
        if board.setString(text, forType: .string) { lastCopiedText = text; lastClipboardCount = board.changeCount }
    }
    func manualHandoff() {
        guard hasUsableMessage else { return }
        copy(PromptBuilder.build(from: sourceText, scene: selectedScene))
        clipboardHint = "已复制好；到 \(selectedProvider.name) 粘贴发送就行"
        onHandoff?()
        if let app = selectedProvider.runningApplication() { app.activate(options: [.activateIgnoringOtherApps]) }
        else if let url = selectedProvider.installedApplicationURL() { NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration()) }
        else if let url = selectedProvider.webURL { NSWorkspace.shared.open(url) }
    }
}
