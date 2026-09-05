import AppKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var model: ClipboardModel
    let sendReply: (String, Bool) -> Void
    let startOver: () -> Void
    @State private var showHelp = false
    private let purple = Color(red: 0.43, green: 0.29, blue: 0.88)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            scenePicker

            VStack(alignment: .leading, spacing: 5) {
                Text(model.selectedScene.name + model.selectedScene.firstLineTail)
                Text(model.selectedScene.secondLine)
            }
            .font(.system(size: 19, weight: .semibold))
            .lineSpacing(2)

            Text("把原话丢进来。先弄明白他到底要什么，再回一句他听得进去的。")
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)

            editor

            action("让 \(model.selectedProvider.name) 说人话") {
                model.understand()
            }
            .disabled(!model.hasUsableMessage || model.isWorking)

            if !model.clipboardHint.isEmpty {
                Text(model.clipboardHint)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()
            bottomBar
        }
        .padding(18)
        .frame(width: 420, height: 400)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack(spacing: 11) {
            if let url = Bundle.main.url(forResource: "LydiaLogo", withExtension: "png"),
               let logo = NSImage(contentsOf: url) {
                Image(nsImage: logo)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 34, height: 34)
                    .accessibilityHidden(true)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("LYDIA 脑洞小工具")
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .tracking(0.7)
                Text("说人话")
                    .font(.system(size: 21, weight: .bold))
            }
            Spacer()
            Button {
                if let url = URL(string: "https://afdian.com/a/lydiahub2026") {
                    NSWorkspace.shared.open(url)
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Color(red: 0.95, green: 0.34, blue: 0.52))
                    Text("投喂脑洞")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Color(red: 0.95, green: 0.34, blue: 0.52))
                        .fixedSize()
                }
                .padding(.horizontal, 8)
                .frame(height: 25)
                .background(Color(red: 0.95, green: 0.34, blue: 0.52).opacity(0.10), in: Capsule())
            }
            .buttonStyle(.plain)
            .focusable(false)
            .accessibilityLabel("投喂 Lydia 的脑洞")
            .help("投喂一下，继续脑洞大开")
            Button {
                showHelp.toggle()
            } label: {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 14))
            }
            .buttonStyle(.plain)
            .focusable(false)
            .foregroundStyle(.secondary)
            .accessibilityLabel("使用说明")
            .help("使用说明 · ⌃⌥R 打开工具")
            .popover(isPresented: $showHelp, arrowEdge: .bottom) { helpContent }
        }
    }

    private var editor: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $model.sourceText)
                .font(.system(size: 14))
                .scrollContentBackground(.hidden)
                .padding(7)
                .accessibilityLabel("对方的原话")
                .disabled(model.isWorking)
            if model.sourceText.isEmpty {
                Text("把那句每个字都认识、连起来却听不懂的话放这里。")
                    .font(.system(size: 13))
                    .foregroundStyle(.tertiary)
                    .padding(12)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .frame(height: 96)
        .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.14)))
    }

    private var scenePicker: some View {
        HStack(spacing: 6) {
            ForEach(WorkplaceScene.all) { scene in
                Button {
                    model.selectedSceneID = scene.id
                } label: {
                    Text(scene.name)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(scene.id == model.selectedSceneID ? Color.white : Color.secondary)
                        .padding(.horizontal, 11)
                        .frame(height: 26)
                        .background(
                            scene.id == model.selectedSceneID ? purple : Color.secondary.opacity(0.08),
                            in: Capsule()
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(scene.name)场景")
            }
            Spacer()
        }
        .help("切换后，AI 听懂这句话的重点也会跟着变")
    }

    private var bottomBar: some View {
        HStack(spacing: 9) {
            Menu {
                ForEach(AIProvider.all) { provider in
                    Button {
                        model.selectedProviderID = provider.id
                    } label: {
                        if provider.id == model.selectedProviderID {
                            Label(provider.name, systemImage: "checkmark")
                        } else {
                            Text(provider.name)
                        }
                    }
                }
            } label: {
                Label(model.selectedProvider.name, systemImage: "sparkles")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("选择你本来就在用的 AI")

            Spacer(minLength: 4)

            Button("好的，收到") { sendReply("好的，收到", true) }
                .buttonStyle(.bordered)
                .help("不调用 AI；能确认原输入框时直接发送，否则只复制")

            Menu {
                Button("收到，我先看一下") { sendReply("收到，我先看一下", true) }
                Button("我确认下再回你") { sendReply("我确认下再回你", true) }
            } label: {
                Image(systemName: "ellipsis")
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .accessibilityLabel("更多快捷回复")
            .help("更多不用 AI 的快捷回复")
        }
        .font(.system(size: 11.5))
        .foregroundStyle(.secondary)
        .disabled(model.isWorking)
    }

    private var helpContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("不是教你写提示词，是少折腾两步。")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.primary)
            Text("复制整段消息，按 ⌃⌥R；支持标准文本选择的软件，也可以右键“服务 → 说人话”。")
            Text("选一次你常用的 AI。以后工具会把原话和“先讲明白、再帮我回”的规则一起复制，并直接打开它。")
            Text("豆包、钉钉 AI、WorkBuddy 和 ChatGPT 都可以用；是否免费、能用多少，以各平台和所在企业的权益为准。")
            Text("“好的，收到”等固定回复不调用 AI；无法确认原聊天框时只复制，不会乱发。")
            Divider()
            Text("工具本身不保存聊天，也不需要模型 API Key。")
        }
        .font(.system(size: 12))
        .foregroundStyle(.secondary)
        .fixedSize(horizontal: false, vertical: true)
        .padding(18)
        .frame(width: 310)
    }

    private func action(_ title: String, run: @escaping () -> Void) -> some View {
        Button(action: run) {
            HStack(spacing: 7) {
                Image(systemName: "arrow.up.forward.app.fill")
                Text(title).font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 42)
            .background(purple, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
