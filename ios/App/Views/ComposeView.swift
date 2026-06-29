import AVFoundation
import Speech
import SwiftUI
import UIKit

struct ComposeView: View {
    @Binding var text: String
    let onGenerate: () -> Void
    let onAddFlight: () -> Void
    var flightChipTitle = "未添加航班 · 稍后补"
    var syncStatusTitle = "草稿已保存"
    var isOffline = false
    var onModeSelected: (String) -> Void = { _ in }
    var onTemplateSelected: (String) -> Void = { _ in }
    var onVoiceTranscribed: (Int) -> Void = { _ in }

    @State private var mode: DraftInputMode = .text
    @State private var selectedTemplate: WritingTemplate?
    @State private var voiceResult = ""
    @StateObject private var speechController = SpeechTranscriptionController()
    @FocusState private var isTextEditorFocused: Bool

    private let templates: [WritingTemplate] = [
        .init(text: "飞往 ___，因为 ___，起飞时我 ___"),
        .init(text: "如果能带一样东西上飞机，是 ___"),
        .init(text: "落地以后，我希望 ___")
    ]

    var body: some View {
        ZStack {
            NightBackground()

            VStack(spacing: 0) {
                header
                    .padding(.top, 48)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
                    .cloudReveal(delay: 0.02, offset: 10)

                flightChip
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 14)
                    .cloudReveal(delay: 0.08, offset: 10)

                VStack(alignment: .leading, spacing: 8) {
                    Text("这次飞行，我只想说：")
                        .font(.system(size: 23, weight: .medium, design: .serif))
                        .foregroundStyle(HICTheme.cream)
                    Rectangle()
                        .fill(LinearGradient(colors: [HICTheme.gold.opacity(0.62), .clear], startPoint: .leading, endPoint: .trailing))
                        .frame(width: 34, height: 1.5)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.bottom, 18)
                .cloudReveal(delay: 0.14, offset: 12)

                modeTabs
                    .padding(.horizontal, 24)
                    .padding(.bottom, 16)
                    .cloudReveal(delay: 0.19, offset: 10)

                ScrollView {
                    Group {
                        switch mode {
                        case .text:
                            textEntry
                        case .template:
                            templateEntry
                        case .voice:
                            voiceEntry
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 18)
                    .cloudReveal(delay: 0.24, offset: 16)
                }
                .scrollDismissesKeyboard(.interactively)

                VStack(spacing: 12) {
                    Group {
                        if text.isEmpty {
                            Text("一句话就够了")
                                .font(.system(size: 11, weight: .regular, design: .monospaced))
                                .tracking(0.6)
                                .foregroundStyle(HICTheme.mist.opacity(0.42))
                        } else {
                            Text("\(text.count) 字 · 草稿已保存")
                                .font(.system(size: 11, weight: .regular, design: .monospaced))
                                .tracking(0.6)
                                .foregroundStyle(Color(red: 0.47, green: 0.70, blue: 0.57).opacity(0.76))
                        }
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                    .animation(.easeInOut(duration: 0.20), value: text.isEmpty)

                    PrimaryCloudButton(title: "生成私人明信片", systemImage: "chevron.right") {
                        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            text = "这次飞行，我只想说一句。"
                        }
                        onGenerate()
                    }

                    Button {
                        HICFeedback.impact(.light)
                        onAddFlight()
                    } label: {
                        Text("添加航班，解锁同班机")
                            .font(.system(size: 12))
                            .foregroundStyle(HICTheme.mist.opacity(0.48))
                            .padding(.top, 2)
                    }
                    .buttonStyle(CloudPressButtonStyle(kind: .secondary))
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
                .background(
                    LinearGradient(colors: [.clear, HICTheme.nightBottom.opacity(0.92)], startPoint: .top, endPoint: .bottom)
                        .frame(height: 120)
                        .offset(y: -70),
                    alignment: .top
                )
                .cloudReveal(delay: 0.30, offset: 16)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            isTextEditorFocused = false
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完成") {
                    isTextEditorFocused = false
                    HICKeyboard.dismiss()
                }
                .font(.system(size: 15, weight: .semibold))
                .accessibilityIdentifier("compose.keyboard.dismiss")
            }
        }
        .onChange(of: speechController.transcript) { newValue in
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            voiceResult = trimmed
            text = trimmed
            onVoiceTranscribed(trimmed.count)
        }
    }

    private var header: some View {
        HStack {
            BackCircleButton()

            Spacer()

            HStack(spacing: 6) {
                Image(systemName: isOffline ? "wifi.slash" : "cloud")
                    .font(.system(size: 10, weight: .medium))
                Text(syncStatusTitle)
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .tracking(0.5)
            }
            .foregroundStyle(isOffline ? HICTheme.gold.opacity(0.74) : Color(red: 0.47, green: 0.70, blue: 0.57).opacity(0.74))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.white.opacity(0.04))
            .overlay {
                Capsule()
                    .stroke(Color(red: 0.47, green: 0.70, blue: 0.57).opacity(0.22), lineWidth: 1)
            }
            .clipShape(Capsule())

            Spacer()
            Color.clear.frame(width: 34, height: 34)
        }
    }

    private var flightChip: some View {
        Button {
            HICFeedback.impact(.light)
            onAddFlight()
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "airplane.departure")
                    .font(.system(size: 11, weight: .medium))
                Text(flightChipTitle)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .tracking(0.6)
            }
            .foregroundStyle(HICTheme.mist.opacity(0.56))
            .padding(.horizontal, 11)
            .padding(.vertical, 6)
            .background(.white.opacity(0.04))
            .overlay {
                Capsule()
                    .stroke(.white.opacity(0.08), lineWidth: 1)
            }
            .clipShape(Capsule())
        }
        .buttonStyle(CloudPressButtonStyle(kind: .secondary))
    }

    private var modeTabs: some View {
        HStack(spacing: 8) {
            ForEach(DraftInputMode.allCases) { item in
                Button {
                    isTextEditorFocused = false
                    HICKeyboard.dismiss()
                    HICFeedback.impact(.light)
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        mode = item
                    }
                    onModeSelected(item.rawValue)
                } label: {
                    Text(item.title)
                        .font(.system(size: 12, weight: .medium))
                        .tracking(0.5)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(mode == item ? HICTheme.gold.opacity(0.12) : .white.opacity(0.03))
                        .foregroundStyle(mode == item ? HICTheme.gold : HICTheme.mist.opacity(0.46))
                        .overlay {
                            Capsule()
                                .stroke(mode == item ? HICTheme.gold.opacity(0.50) : .white.opacity(0.06), lineWidth: 1)
                        }
                        .clipShape(Capsule())
                }
                .buttonStyle(CloudPressButtonStyle(kind: .secondary))
                .accessibilityIdentifier("compose.mode.\(item.rawValue)")
            }
        }
    }

    private var textEntry: some View {
        VStack(alignment: .trailing, spacing: 8) {
            PaperTextEditor(text: $text, isFocused: $isTextEditorFocused)
                .frame(minHeight: 218)

            Text(text.isEmpty ? "一句话就够了" : "\(text.count) 字")
                .font(.system(size: 11, weight: .regular, design: .monospaced))
                .tracking(0.6)
                .foregroundStyle(HICTheme.mist.opacity(0.36))
        }
    }

    private var templateEntry: some View {
        VStack(alignment: .leading, spacing: 11) {
            ForEach(Array(templates.enumerated()), id: \.element.id) { index, item in
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        selectedTemplate = selectedTemplate == item ? nil : item
                    }
                    onTemplateSelected(item.text)
                    if selectedTemplate == item && text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        text = item.text
                    }
                } label: {
                    HStack {
                        Text(item.text)
                            .font(.system(size: 15, weight: .regular, design: .serif))
                            .lineSpacing(5)
                            .tracking(0.4)
                            .foregroundStyle(selectedTemplate == item ? HICTheme.cream : HICTheme.mist.opacity(0.66))
                            .frame(maxWidth: .infinity, alignment: .leading)
                        if selectedTemplate == item {
                            Circle()
                                .fill(HICTheme.gold)
                                .frame(width: 7, height: 7)
                        }
                    }
                    .padding(16)
                    .background(selectedTemplate == item ? HICTheme.gold.opacity(0.08) : .white.opacity(0.025))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(selectedTemplate == item ? HICTheme.gold.opacity(0.5) : .white.opacity(0.07), lineWidth: 1)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(CloudPressButtonStyle(kind: .secondary))
                .accessibilityIdentifier("compose.template.\(index)")
            }

            Text("填写你的版本")
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .tracking(1)
                .foregroundStyle(HICTheme.mist.opacity(0.45))
                .padding(.top, 8)

            ZStack(alignment: .topLeading) {
                TextEditor(text: $text)
                    .font(.system(size: 15, weight: .regular, design: .serif))
                    .foregroundStyle(HICTheme.cream)
                    .lineSpacing(6)
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 110)
                    .padding(8)

                if text.isEmpty {
                    Text(selectedTemplate?.text ?? "把空格换成你的答案")
                        .font(.system(size: 14, weight: .regular, design: .serif))
                        .foregroundStyle(HICTheme.mist.opacity(0.38))
                        .padding(16)
                        .allowsHitTesting(false)
                }
            }
            .background(.white.opacity(0.035))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(HICTheme.gold.opacity(0.20), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }

    private var voiceEntry: some View {
        VStack(spacing: 18) {
            Button {
                Task {
                    HICFeedback.impact(.medium)
                    await speechController.toggleRecording()
                }
            } label: {
                Image(systemName: speechController.isRecording ? "stop.fill" : "mic")
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(speechController.isRecording || !voiceResult.isEmpty ? HICTheme.gold : HICTheme.mist.opacity(0.50))
                    .frame(width: 92, height: 92)
                    .background(speechController.isRecording || !voiceResult.isEmpty ? HICTheme.gold.opacity(0.16) : .white.opacity(0.05))
                    .overlay {
                        Circle()
                            .stroke(speechController.isRecording || !voiceResult.isEmpty ? HICTheme.gold.opacity(0.46) : .white.opacity(0.10), lineWidth: 2)
                    }
                    .clipShape(Circle())
            }
            .buttonStyle(CloudPressButtonStyle(kind: .icon))
            .disabled(speechController.isBusy)

            Text(speechController.statusTitle)
                .font(.system(size: 12, weight: .regular, design: .monospaced))
                .tracking(1)
                .foregroundStyle(speechController.isRecording || !voiceResult.isEmpty ? HICTheme.gold.opacity(0.72) : HICTheme.mist.opacity(0.42))

            if let message = speechController.message {
                Text(message)
                    .font(.system(size: 13))
                    .lineSpacing(5)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(HICTheme.mist.opacity(0.52))
                    .padding(.horizontal, 8)
            }

            if !voiceResult.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text(voiceResult)
                        .font(.system(size: 16, weight: .regular, design: .serif))
                        .lineSpacing(7)
                        .foregroundStyle(HICTheme.cream)

                    HStack(spacing: 8) {
                        Button("重新录") {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                voiceResult = ""
                                text = ""
                            }
                            speechController.resetTranscript()
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(.white.opacity(0.04))
                        .foregroundStyle(HICTheme.mist.opacity(0.50))
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

                        Button("使用这段话") {
                            text = voiceResult
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                mode = .text
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(HICTheme.gold.opacity(0.12))
                        .foregroundStyle(HICTheme.gold.opacity(0.86))
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    }
                    .font(.system(size: 12, weight: .medium))
                }
                .padding(18)
                .background(.white.opacity(0.04))
                .overlay {
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(HICTheme.gold.opacity(0.20), lineWidth: 1)
                }
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 22)
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: voiceResult.isEmpty)
        .animation(.spring(response: 0.32, dampingFraction: 0.82), value: speechController.isRecording)
    }
}

@MainActor
private final class SpeechTranscriptionController: ObservableObject {
    @Published private(set) var transcript = ""
    @Published private(set) var statusTitle = "点按开始录音转文字"
    @Published private(set) var message: String?
    @Published private(set) var isRecording = false
    @Published private(set) var isBusy = false

    private let audioEngine = AVAudioEngine()
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "zh_CN"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    func toggleRecording() async {
        if isRecording {
            stopRecording()
            return
        }

        await startRecording()
    }

    func resetTranscript() {
        transcript = ""
        message = nil
        statusTitle = "点按开始录音转文字"
    }

    private func startRecording() async {
        guard !isBusy else { return }
        isBusy = true
        statusTitle = "正在准备麦克风"
        message = nil

        guard recognizer?.isAvailable == true else {
            fail("当前系统暂时不可用语音识别，请改用一句话或模板。")
            return
        }

        let speechStatus = await requestSpeechAuthorization()
        guard speechStatus == .authorized else {
            fail("没有语音识别权限；你仍然可以直接写一句话。")
            return
        }

        let microphoneGranted = await requestMicrophonePermission()
        guard microphoneGranted else {
            fail("没有麦克风权限；你仍然可以直接写一句话。")
            return
        }

        do {
            try configureAudioSession()
            try startAudioEngine()
            transcript = ""
            isRecording = true
            isBusy = false
            statusTitle = "正在听，点按结束"
            message = "原始音频只用于本机转文字，不上传。"
        } catch {
            fail("录音没有启动成功，请改用一句话或模板。")
        }
    }

    private func stopRecording() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        isRecording = false
        isBusy = false
        statusTitle = transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "没有识别到内容" : "识别结果"
        message = transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "可以再试一次，或直接切回一句话输入。" : "确认后可以继续编辑这句话。"
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: .duckOthers)
        try session.setActive(true, options: .notifyOthersOnDeactivation)
    }

    private func startAudioEngine() throws {
        recognitionTask?.cancel()
        recognitionTask = nil

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        inputNode.removeTap(onBus: 0)

        recognitionTask = recognizer?.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                if let result {
                    self.transcript = result.bestTranscription.formattedString
                    if result.isFinal {
                        self.stopRecording()
                    }
                }
                if error != nil, self.isRecording {
                    self.fail("语音识别中断了，请再试一次或直接写一句话。")
                }
            }
        }

        let format = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1_024, format: format) { [weak request] buffer, _ in
            request?.append(buffer)
        }

        audioEngine.prepare()
        try audioEngine.start()
    }

    private func fail(_ text: String) {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        isRecording = false
        isBusy = false
        statusTitle = "语音暂时不可用"
        message = text
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func requestSpeechAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    private func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}

struct CardStudioView: View {
    @Binding var text: String
    let onPublish: () -> Void
    var onOpenPaywall: () -> Void = {}
    var onQuoteEdited: (String) -> Void = { _ in }

    @State private var template: CardTemplateKind = .boardingPostcard
    @State private var draftSaveMessage: String?
    @FocusState private var isQuoteEditorFocused: Bool

    var body: some View {
        ZStack {
            NightBackground()

            VStack(spacing: 0) {
	                HStack(spacing: 12) {
	                    BackCircleButton()
	                    Text(template == .flightLog ? "普通文字兜底" : "云上明信片")
	                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .tracking(1.6)
                        .foregroundStyle(HICTheme.gold.opacity(0.56))
                    if template == .flightLog {
                        Text("普通文本兜底")
                            .font(.system(size: 9, weight: .regular, design: .monospaced))
                            .foregroundStyle(HICTheme.gold.opacity(0.46))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(HICTheme.gold.opacity(0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    }
                    Spacer()
                }
                .padding(.top, 52)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

                CloudCardPreview(template: template, quote: shareSafeQuote)
                    .frame(width: 260, height: 347)
                    .padding(.top, 6)
                    .padding(.bottom, 18)
                    .id(template)
                    .transition(.opacity.combined(with: .scale(scale: 0.97)))
                    .animation(.spring(response: 0.34, dampingFraction: 0.82), value: template)
                    .cloudReveal(delay: 0.06, offset: 16)

                VStack(alignment: .leading, spacing: 11) {
                    HStack(spacing: 8) {
                        Image(systemName: "pencil")
                        Text("下方文字可直接编辑")
                        Spacer()
                    }
                    .font(.system(size: 13))
                    .foregroundStyle(HICTheme.mist.opacity(0.54))
                    .padding(11)
                    .background(.white.opacity(0.03))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(.white.opacity(0.06), lineWidth: 1)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $text)
                            .focused($isQuoteEditorFocused)
                            .accessibilityIdentifier("card_studio.quote_editor")
                            .font(.system(size: 14, weight: .regular, design: .serif))
                            .foregroundStyle(HICTheme.cream)
                            .lineSpacing(5)
                            .scrollContentBackground(.hidden)
                            .frame(height: 72)
                            .padding(8)
                            .onChange(of: text) { newValue in
                                onQuoteEdited(newValue)
                            }
                    }
                    .background(.white.opacity(0.035))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(HICTheme.gold.opacity(0.22), lineWidth: 1)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                    Text("卡片风格")
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(HICTheme.mist.opacity(0.42))
                        .padding(.top, 2)

                    HStack(spacing: 8) {
                        ForEach(CardTemplateKind.allCases) { item in
                            TemplateButton(item: item, selected: template == item) {
                                withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                                    template = item
                                }
                            }
                        }
                    }

                    Text(template.hint)
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .tracking(0.5)
                        .foregroundStyle(template == .flightLog ? HICTheme.mist.opacity(0.44) : HICTheme.gold.opacity(0.46))
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button(action: onOpenPaywall) {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 12, weight: .semibold))
                            Text("高级模板包")
                            Spacer()
                            Text("内测")
                                .font(.system(size: 9, weight: .regular, design: .monospaced))
                                .tracking(0.8)
                                .foregroundStyle(HICTheme.mist.opacity(0.40))
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(HICTheme.gold.opacity(0.82))
                        .padding(11)
                        .background(HICTheme.gold.opacity(0.07))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(HICTheme.gold.opacity(0.18), lineWidth: 1)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    }
                    .buttonStyle(CloudPressButtonStyle(kind: .secondary))
                    .accessibilityLabel("高级模板包")
                    .accessibilityHint("打开高级模板包说明")
                }
                .padding(.horizontal, 24)
                .cloudReveal(delay: 0.16, offset: 18)

                Spacer()

                VStack(spacing: 10) {
                    PrimaryCloudButton(title: "继续发布", systemImage: "chevron.right", action: onPublish)
                    SecondaryCloudButton(title: "保存为草稿") {
                        withAnimation(.spring(response: 0.30, dampingFraction: 0.84)) {
                            draftSaveMessage = "草稿已保存在本机，可返回后继续编辑。"
                        }
                        HICFeedback.success()
                    }
                    if let draftSaveMessage {
                        Text(draftSaveMessage)
                            .font(.system(size: 11))
                            .foregroundStyle(HICTheme.gold.opacity(0.66))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 2)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
                .cloudReveal(delay: 0.24, offset: 16)
            }
        }
        .onAppear {
            if text.shouldUseFlightLogFallback {
                template = .flightLog
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完成") {
                    isQuoteEditorFocused = false
                    HICKeyboard.dismiss()
                }
                .font(.system(size: 15, weight: .semibold))
                .accessibilityIdentifier("keyboard.dismiss")
            }
        }
        .animation(.spring(response: 0.30, dampingFraction: 0.84), value: draftSaveMessage)
    }

    private var shareSafeQuote: String {
        PublicTextSanitizer.sanitize(text.cloudFallback)
    }
}

struct PublishView: View {
    let text: String
    var shareURL: URL?
    var shareContext = "未添加航班 · 稍后补"
    var feedback: String?
    let onShare: (ShareChannel) -> Void
    let onSaveImage: (UIImage?) -> Void
    let onOpenFlight: () -> Void
    let onVerifyFlight: () -> Void
    let onOpenSharedLanding: () -> Void

    @State private var sharePayload: CloudCardSharePayload?
    @State private var didCelebrate = false

    var body: some View {
        ZStack {
            HICTheme.nightBottom.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    HStack {
                        BackCircleButton()
                        Spacer()
                        Text("发布")
                            .font(.system(size: 10, weight: .regular, design: .monospaced))
                            .tracking(1.4)
                            .foregroundStyle(HICTheme.gold.opacity(0.56))
                        Spacer()
                        Color.clear.frame(width: 34, height: 34)
                    }
                    .padding(.top, 52)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 18)

                    successHeader
                        .padding(.horizontal, 24)
                        .padding(.bottom, 22)
                        .cloudReveal(delay: 0.02, offset: 12)

                    CloudCardPreview(
                        template: text.shouldUseFlightLogFallback ? .flightLog : .boardingPostcard,
                        quote: shareSafeQuote
                    )
                    .frame(width: 260, height: 347)
                    .padding(.bottom, 28)
                    .scaleEffect(didCelebrate ? 1 : 0.96)
                    .opacity(didCelebrate ? 1 : 0)
                    .animation(.spring(response: 0.62, dampingFraction: 0.82).delay(0.18), value: didCelebrate)

                    VStack(spacing: 12) {
                        Text("分享到")
                            .font(.system(size: 11, weight: .regular, design: .monospaced))
                            .tracking(1.2)
                            .foregroundStyle(HICTheme.mist.opacity(0.50))

                        HStack(spacing: 12) {
                            ForEach(ShareChannel.allCases.filter { $0 != .copyLink }) { channel in
                                Button {
                                    handleShare(channel)
                                } label: {
                                    VStack(spacing: 7) {
                                        Image(systemName: channel.icon)
                                            .font(.system(size: 20, weight: .regular))
                                        Text(channel.title)
                                            .font(.system(size: 11))
                                    }
                                    .foregroundStyle(HICTheme.mist.opacity(0.70))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(.white.opacity(0.05))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(.white.opacity(0.08), lineWidth: 1)
                                    }
                                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                }
                                .buttonStyle(CloudPressButtonStyle(kind: .secondary))
                            }
                        }

                        if let feedback {
                            Text(feedback)
                                .font(.system(size: 12))
                                .foregroundStyle(HICTheme.gold.opacity(0.68))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(HICTheme.gold.opacity(0.07))
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }

                        SecondaryCloudButton(title: "复制链接并预览落地页", systemImage: "link") {
                            handleShare(.copyLink)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
                    .cloudReveal(delay: 0.34, offset: 18)

                    VStack(spacing: 10) {
                        PrimaryCloudButton(title: "查看我的飞行册", action: onOpenFlight)
                        SecondaryCloudButton(title: "验证航班并发布到同班机", systemImage: "lock", action: onVerifyFlight)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 36)
                    .cloudReveal(delay: 0.42, offset: 18)
                }
            }
        }
        .onAppear {
            didCelebrate = false
            withAnimation(.spring(response: 0.56, dampingFraction: 0.78).delay(0.05)) {
                didCelebrate = true
            }
            HICFeedback.success()
        }
        .sheet(item: $sharePayload) { payload in
            CloudCardShareSheet(activityItems: payload.activityItems)
        }
        .animation(.spring(response: 0.30, dampingFraction: 0.84), value: feedback)
    }

    private func handleShare(_ channel: ShareChannel) {
        onShare(channel)

        switch channel {
        case .saveImage:
            onSaveImage(shareCardImage)
            return
        case .copyLink:
            UIPasteboard.general.string = shareURL?.absoluteString ?? shareCaption
            onOpenSharedLanding()
        case .wechat:
            shareToWeChat(scene: .session)
        case .moments:
            shareToWeChat(scene: .timeline)
        case .rednote:
            sharePayload = CloudCardSharePayload(activityItems: activityItems)
        }
    }

    private func shareToWeChat(scene: WeChatShareScene) {
        guard let shareURL else {
            sharePayload = CloudCardSharePayload(activityItems: activityItems)
            return
        }

        WeChatSharing.shareWebpage(
            title: "云上心事",
            description: shareCaption,
            webpageURL: shareURL,
            thumbnail: shareCardImage,
            scene: scene
        ) { success in
            if !success {
                sharePayload = CloudCardSharePayload(activityItems: activityItems)
            }
        }
    }

    private var activityItems: [Any] {
        var items: [Any] = []
        if let image = shareCardImage {
            items.append(image)
        }
        items.append(shareCaption)
        if let shareURL {
            items.append(shareURL)
        }
        return items
    }

    private var shareCardImage: UIImage? {
        ShareableCloudCardImage.render(
            template: text.shouldUseFlightLogFallback ? .flightLog : .boardingPostcard,
            quote: shareSafeQuote
        )
    }

    private var shareCaption: String {
        "我在 \(shareContext) 留下了一张 Cloud Card：\(shareSafeQuote)"
    }

    private var shareSafeQuote: String {
        PublicTextSanitizer.sanitize(text.cloudFallback)
    }

    private var successHeader: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(HICTheme.gold.opacity(didCelebrate ? 0 : 0.40), lineWidth: 1.5)
                    .frame(width: 92, height: 92)
                    .scaleEffect(didCelebrate ? 1.42 : 0.62)
                    .animation(.easeOut(duration: 0.86).delay(0.10), value: didCelebrate)

                Circle()
                    .fill(Color(red: 0.40, green: 0.80, blue: 0.40).opacity(0.14))
                    .frame(width: 64, height: 64)
                    .overlay {
                        Circle()
                            .stroke(Color(red: 0.40, green: 0.80, blue: 0.40).opacity(0.34), lineWidth: 1.5)
                    }

                Image(systemName: "checkmark")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Color(red: 0.50, green: 0.86, blue: 0.50))
                    .scaleEffect(didCelebrate ? 1 : 0.30)
                    .rotationEffect(.degrees(didCelebrate ? 0 : -18))
                    .animation(.spring(response: 0.42, dampingFraction: 0.62).delay(0.16), value: didCelebrate)
            }
            .frame(width: 94, height: 94)

            Text("私人明信片已保存")
                .font(.system(size: 19, weight: .medium, design: .serif))
                .foregroundStyle(HICTheme.cream)
                .opacity(didCelebrate ? 1 : 0)
                .offset(y: didCelebrate ? 0 : 6)
                .animation(.easeOut(duration: 0.28).delay(0.26), value: didCelebrate)

            Text("私人卡不会进入同班机")
                .font(.system(size: 13))
                .tracking(0.8)
                .foregroundStyle(HICTheme.gold.opacity(0.70))
                .opacity(didCelebrate ? 1 : 0)
                .animation(.easeOut(duration: 0.28).delay(0.34), value: didCelebrate)
        }
    }
}

struct CloudCardSharePayload: Identifiable {
    let id = UUID()
    let activityItems: [Any]
}

struct CloudCardShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

enum ShareableCloudCardImage {
    @MainActor
    static func render(template: CardTemplateKind, quote: String) -> UIImage? {
        let renderer = ImageRenderer(
            content: CloudCardPreview(template: template, quote: quote)
                .frame(width: 260, height: 347)
                .padding(24)
                .background(HICTheme.nightBottom)
        )
        renderer.scale = UIScreen.main.scale
        return renderer.uiImage
    }
}

struct MyFlightsView: View {
    let records: [FlightRecordViewModel]
    let onNewFlight: () -> Void
    let onSettings: () -> Void

    var body: some View {
        ZStack {
            NightBackground()

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    BackCircleButton()
                    VStack(alignment: .leading, spacing: 4) {
                        Text("我的飞行册")
                            .font(.system(size: 21, weight: .medium, design: .serif))
                            .foregroundStyle(HICTheme.cream)
                        Text("\(records.count) 趟飞行 · \(records.count) 句留下来了")
                            .font(.system(size: 11, weight: .regular, design: .monospaced))
                            .tracking(0.6)
                            .foregroundStyle(HICTheme.gold.opacity(0.55))
                    }
                    Spacer()
                    Button {
                        HICFeedback.impact(.light)
                        onSettings()
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 15))
                            .foregroundStyle(HICTheme.mist.opacity(0.50))
                            .frame(width: 32, height: 32)
                            .background(.white.opacity(0.05))
                            .clipShape(Circle())
                    }
                    .buttonStyle(CloudPressButtonStyle(kind: .icon))
                }
                .padding(.top, 52)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)

                Rectangle()
                    .fill(LinearGradient(colors: [HICTheme.gold.opacity(0.32), .clear], startPoint: .leading, endPoint: .trailing))
                    .frame(height: 1)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)

	                ScrollView {
	                    VStack(spacing: 12) {
	                        if records.isEmpty {
	                            VStack(alignment: .leading, spacing: 10) {
	                                Image(systemName: "book.closed")
	                                    .font(.system(size: 21, weight: .medium))
	                                    .foregroundStyle(HICTheme.gold.opacity(0.64))
	                                Text("还没有飞行记录")
	                                    .font(.system(size: 17, weight: .medium, design: .serif))
	                                    .foregroundStyle(HICTheme.cream)
	                                Text("写下一句话并保存明信片后，这里会显示你真实留下的飞行。")
	                                    .font(.system(size: 12))
	                                    .lineSpacing(5)
	                                    .foregroundStyle(HICTheme.mist.opacity(0.56))
	                            }
	                            .padding(16)
	                            .frame(maxWidth: .infinity, alignment: .leading)
	                            .background(.white.opacity(0.04))
	                            .overlay {
	                                RoundedRectangle(cornerRadius: 16, style: .continuous)
	                                    .stroke(.white.opacity(0.08), lineWidth: 1)
	                            }
	                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
	                        } else {
	                            ForEach(records) { record in
	                                FlightRecordCard(record: record)
	                            }
	                        }
	                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 114)
                }

                PrimaryCloudButton(title: "写下一趟飞行", systemImage: "airplane.departure", action: onNewFlight)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                    .background(
                        LinearGradient(colors: [.clear, HICTheme.nightBottom.opacity(0.96)], startPoint: .top, endPoint: .bottom)
                            .frame(height: 112)
                            .offset(y: -72),
                        alignment: .top
                    )
            }
        }
    }
}

private struct PaperTextEditor: View {
    @Binding var text: String
    let isFocused: FocusState<Bool>.Binding

    private let prompts = [
        "飞这趟是为了什么？",
        "现在坐在哪个座位？",
        "如果只能带一样东西上飞机..."
    ]

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [HICTheme.cream, HICTheme.paper],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(PaperLines().opacity(0.6))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(HICTheme.gold.opacity(0.20), lineWidth: 1)
                }

            if text.isEmpty {
                VStack(alignment: .leading, spacing: 19) {
                    ForEach(Array(prompts.enumerated()), id: \.offset) { index, prompt in
                        Text(prompt)
                            .font(.system(size: 16, weight: .regular, design: .serif))
                            .italic()
                            .foregroundStyle(HICTheme.ink.opacity(0.20 - Double(index) * 0.045))
                            .tracking(0.3)
                    }
                }
                .padding(.top, 18)
                .padding(.leading, 18)
                .allowsHitTesting(false)
            }

            TextEditor(text: $text)
                .font(.system(size: 17, weight: .regular, design: .serif))
                .foregroundStyle(HICTheme.ink)
                .lineSpacing(9)
                .tracking(0.5)
                .scrollContentBackground(.hidden)
                .padding(12)
                .focused(isFocused)
                .accessibilityIdentifier("compose.text")
        }
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.20), radius: 18, y: 8)
    }
}

private struct TemplateButton: View {
    let item: CardTemplateKind
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Text(item.title)
                    .font(.system(size: 12, weight: .medium))
                Text(item.subtitle)
                    .font(.system(size: 8, weight: .regular, design: .serif))
                    .italic()
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(selected ? HICTheme.gold.opacity(0.10) : .white.opacity(0.03))
            .foregroundStyle(selected ? HICTheme.gold : HICTheme.mist.opacity(0.46))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selected ? HICTheme.gold.opacity(0.45) : .white.opacity(0.06), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(CloudPressButtonStyle(kind: .secondary))
    }
}

struct CloudCardPreview: View {
    let template: CardTemplateKind
    let quote: String

    var body: some View {
        Group {
            switch template {
            case .boardingPostcard:
                PostcardCard(quote: quote)
            case .routePoem:
                RoutePoemCard(quote: quote)
            case .cloudWindow:
                CloudWindowCard(quote: quote)
            case .flightLog:
                FlightLogCard(quote: quote)
            }
        }
        .shadow(color: .black.opacity(0.62), radius: 30, y: 18)
    }
}

private struct PostcardCard: View {
    let quote: String

    var body: some View {
        PostcardAnchorView(quote: quote)
            .frame(width: 260, height: 347)
    }
}

private struct RoutePoemCard: View {
    let quote: String

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.05, green: 0.12, blue: 0.23), Color(red: 0.03, green: 0.07, blue: 0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(HICTheme.gold.opacity(0.12), lineWidth: 1)
                }

            VStack(alignment: .leading, spacing: 14) {
                RouteArcView()
                    .frame(width: 228, height: 56)
                    .padding(.top, 10)

                Text("航线待补 · 坐标待补")
                    .font(.system(size: 8, weight: .regular, design: .monospaced))
                    .tracking(0.5)
                    .foregroundStyle(HICTheme.gold.opacity(0.42))

                Text(quote)
                    .font(.system(size: quote.count > 20 ? 16 : 19, weight: .regular, design: .serif))
                    .italic()
                    .lineSpacing(11)
                    .tracking(0.7)
                    .foregroundStyle(HICTheme.cream)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()

                Rectangle()
                    .fill(LinearGradient(colors: [.clear, HICTheme.gold.opacity(0.25), .clear], startPoint: .leading, endPoint: .trailing))
                    .frame(height: 1)

                Text("航班待确认 · 云上明信片")
                    .font(.system(size: 8, weight: .regular, design: .monospaced))
                    .tracking(0.8)
                    .foregroundStyle(HICTheme.gold.opacity(0.48))

                Text("Head in the Clouds")
                    .font(.system(size: 7, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(HICTheme.gold.opacity(0.24))
            }
            .padding(20)
        }
        .frame(width: 260, height: 347)
    }
}

private struct CloudWindowCard: View {
    let quote: String

    var body: some View {
        ZStack(alignment: .top) {
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.10, green: 0.18, blue: 0.29), Color(red: 0.04, green: 0.07, blue: 0.12)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

            VStack(spacing: 18) {
                ZStack {
                    Circle()
                        .stroke(Color(red: 0.55, green: 0.68, blue: 0.86).opacity(0.20), lineWidth: 3)
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.03, green: 0.07, blue: 0.16),
                                    Color(red: 0.10, green: 0.27, blue: 0.54),
                                    Color(red: 0.55, green: 0.74, blue: 0.88),
                                    Color(red: 0.88, green: 0.94, blue: 0.98)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(red: 0.20, green: 0.20, blue: 0.28).opacity(0.86))
                        .frame(width: 74, height: 12)
                        .offset(x: 24, y: 38)
                }
                .frame(width: 150, height: 150)
                .padding(.top, 22)

                Text(quote)
                    .font(.system(size: quote.count > 20 ? 15 : 18, weight: .regular, design: .serif))
                    .italic()
                    .lineSpacing(11)
                    .tracking(0.6)
                    .foregroundStyle(HICTheme.cream)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()

                Text("航线待补 · 坐标待补\n航班待确认 · 云上明信片")
                    .font(.system(size: 8, weight: .regular, design: .monospaced))
                    .lineSpacing(7)
                    .tracking(0.6)
                    .foregroundStyle(Color(red: 0.55, green: 0.68, blue: 0.86).opacity(0.36))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(20)
        }
        .frame(width: 260, height: 347)
    }
}

private struct FlightLogCard: View {
    let quote: String

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Circle().fill(.white.opacity(0.12)).frame(width: 4, height: 4)
                Text("航班待确认 · 云上明信片")
                    .font(.system(size: 8, weight: .regular, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(HICTheme.mist.opacity(0.36))
                Spacer()
                Circle().fill(.white.opacity(0.12)).frame(width: 4, height: 4)
            }
            .padding(.horizontal, 16)
            .frame(height: 32)
            .background(.white.opacity(0.03))
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(.white.opacity(0.10))
                    .frame(height: 1)
            }

            VStack(alignment: .leading, spacing: 16) {
                Text(quote)
                    .font(.system(size: quote.count <= 10 ? 26 : quote.count <= 20 ? 20 : 16, weight: .regular, design: .serif))
                    .lineSpacing(10)
                    .tracking(0.5)
                    .foregroundStyle(HICTheme.mist.opacity(0.90))
                    .frame(maxWidth: .infinity, alignment: .leading)

                PaperLines()
                    .opacity(0.7)
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            HStack {
                HStack(spacing: 5) {
                    RoundedRectangle(cornerRadius: 2)
                        .stroke(.white.opacity(0.10), lineWidth: 1)
                        .frame(width: 12, height: 12)
                        .overlay {
                            Image(systemName: "cloud")
                                .font(.system(size: 6))
                                .foregroundStyle(.white.opacity(0.30))
                        }
                    Text("Head in the Clouds")
                        .font(.system(size: 7, weight: .regular, design: .serif))
                        .italic()
                        .foregroundStyle(.white.opacity(0.18))
                }

                Spacer()

                Text("奔赴")
                    .font(.system(size: 9))
                    .foregroundStyle(HICTheme.gold.opacity(0.36))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .overlay {
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(HICTheme.gold.opacity(0.15), lineWidth: 1)
                    }
            }
            .padding(.horizontal, 16)
            .frame(height: 44)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(.white.opacity(0.08))
                    .frame(height: 1)
            }
        }
        .background(
            LinearGradient(
                colors: [Color(red: 0.07, green: 0.10, blue: 0.13), Color(red: 0.04, green: 0.06, blue: 0.09)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay {
            RoundedRectangle(cornerRadius: 10)
                .stroke(.white.opacity(0.07), lineWidth: 1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .frame(width: 260, height: 347)
    }
}

struct FlightRecordCard: View {
    let record: FlightRecordViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                HStack(spacing: 6) {
                    Text(record.flightNumber)
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .tracking(1)
                    Text("·")
                        .foregroundStyle(HICTheme.ink.opacity(0.30))
                    Text(record.route)
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .tracking(0.5)
                }
                .foregroundStyle(HICTheme.ink.opacity(0.80))

                Spacer()

                Text(record.mood)
                    .font(.system(size: 10))
                    .tracking(0.4)
                    .foregroundStyle(HICTheme.gold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(HICTheme.gold.opacity(0.12))
                    .clipShape(Capsule())
            }
            .padding(.bottom, 11)

            Text(record.quote)
                .font(.system(size: record.quote.count <= 10 ? 22 : 17, weight: .semibold, design: .serif))
                .lineSpacing(8)
                .tracking(0.7)
                .foregroundStyle(HICTheme.ink)
                .padding(.bottom, 12)

            HStack {
                Text(record.cityRoute)
                Spacer()
                Text(record.date)
            }
            .font(.system(size: 9, weight: .regular, design: .monospaced))
            .tracking(0.5)
            .foregroundStyle(HICTheme.ink.opacity(0.44))
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [HICTheme.cream, HICTheme.paper],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(PaperLines().opacity(0.45))
        }
        .padding(10)
        .background(HICTheme.ink)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.34), radius: 16, y: 8)
    }
}

private enum DraftInputMode: String, CaseIterable, Identifiable {
    case text
    case template
    case voice

    var id: String { rawValue }

    var title: String {
        switch self {
        case .text: return "一句话"
        case .template: return "模板"
        case .voice: return "语音"
        }
    }
}

enum CardTemplateKind: String, CaseIterable, Identifiable {
    case boardingPostcard
    case routePoem
    case cloudWindow
    case flightLog

    var id: String { rawValue }

    var title: String {
        switch self {
        case .boardingPostcard: return "明信片"
        case .routePoem: return "航线诗"
        case .cloudWindow: return "云窗"
        case .flightLog: return "飞行日志"
        }
    }

    var subtitle: String {
        switch self {
        case .boardingPostcard: return "Postcard"
        case .routePoem: return "Route Poem"
        case .cloudWindow: return "Cloud Window"
        case .flightLog: return "Flight Log"
        }
    }

    var hint: String {
        switch self {
        case .boardingPostcard: return "默认分享卡，适合朋友圈第一眼停留"
        case .routePoem: return "推荐用于诗意文字，适合情绪浓度高的内容"
        case .cloudWindow: return "推荐用于云层/舷窗相关内容"
        case .flightLog: return "任何真实文字都能承接，不强行诗意化"
        }
    }
}

private struct WritingTemplate: Identifiable, Hashable {
    let id = UUID()
    let text: String
}
