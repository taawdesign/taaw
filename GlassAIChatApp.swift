import SwiftUI

// MARK: - App Entry Point
@main
struct GlassAIChatApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// MARK: - Models

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let content: String
    let isUser: Bool
    let timestamp: Date
    var attachments: [Attachment]
    
    init(content: String, isUser: Bool, attachments: [Attachment] = []) {
        self.content = content
        self.isUser = isUser
        self.timestamp = Date()
        self.attachments = attachments
    }
}

struct Attachment: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let type: AttachmentType
    let data: Data?
    
    enum AttachmentType: String, CaseIterable {
        case image = "photo"
        case document = "doc.text"
        case pdf = "doc.richtext"
        case code = "chevron.left.forwardslash.chevron.right"
        case audio = "waveform"
        case video = "video"
        case other = "paperclip"
    }
}

struct AIProvider: Identifiable, Equatable, Hashable {
    let id = UUID()
    var name: String
    var apiKey: String
    var baseURL: String
    var model: String
    var isActive: Bool
    var availableModels: [String]
    
    static let presets: [AIProvider] = [
        AIProvider(name: "OpenAI", apiKey: "", baseURL: "https://api.openai.com/v1/chat/completions", model: "", isActive: false, availableModels: []),
        AIProvider(name: "Anthropic", apiKey: "", baseURL: "https://api.anthropic.com/v1/messages", model: "", isActive: false, availableModels: []),
        AIProvider(name: "Google AI", apiKey: "", baseURL: "https://generativelanguage.googleapis.com/v1beta/models", model: "", isActive: false, availableModels: []),
        AIProvider(name: "Mistral", apiKey: "", baseURL: "https://api.mistral.ai/v1/chat/completions", model: "", isActive: false, availableModels: []),
        AIProvider(name: "Groq", apiKey: "", baseURL: "https://api.groq.com/openai/v1/chat/completions", model: "", isActive: false, availableModels: []),
        AIProvider(name: "Together AI", apiKey: "", baseURL: "https://api.together.xyz/v1/chat/completions", model: "", isActive: false, availableModels: []),
        AIProvider(name: "Custom", apiKey: "", baseURL: "", model: "", isActive: false, availableModels: [])
    ]
}

// MARK: - Model Fetching Service

@MainActor
class ModelFetchingService {
    static let shared = ModelFetchingService()
    
    private init() {}
    
    func fetchModels(for provider: AIProvider) async throws -> [String] {
        guard !provider.apiKey.isEmpty else {
            return []
        }
        
        switch provider.name {
        case "OpenAI":
            return try await fetchOpenAIModels(apiKey: provider.apiKey)
        case "Anthropic":
            return try await fetchAnthropicModels(apiKey: provider.apiKey)
        case "Google AI":
            return try await fetchGoogleModels(apiKey: provider.apiKey)
        case "Mistral":
            return try await fetchMistralModels(apiKey: provider.apiKey)
        case "Groq":
            return try await fetchGroqModels(apiKey: provider.apiKey)
        case "Together AI":
            return try await fetchTogetherModels(apiKey: provider.apiKey)
        case "Custom":
            return try await fetchCustomModels(provider: provider)
        default:
            return []
        }
    }
    
    private func fetchOpenAIModels(apiKey: String) async throws -> [String] {
        let url = URL(string: "https://api.openai.com/v1/models")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let modelsData = json?["data"] as? [[String: Any]] else {
            return []
        }
        
        let chatModels = modelsData
            .compactMap { $0["id"] as? String }
            .filter { model in
                model.contains("gpt") || model.contains("o1") || model.contains("o3")
            }
            .sorted()
        
        return chatModels
    }
    
    private func fetchAnthropicModels(apiKey: String) async throws -> [String] {
        let url = URL(string: "https://api.anthropic.com/v1/models")!
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let modelsData = json?["data"] as? [[String: Any]] else {
            return []
        }
        
        let models = modelsData
            .compactMap { $0["id"] as? String }
            .sorted()
        
        return models
    }
    
    private func fetchGoogleModels(apiKey: String) async throws -> [String] {
        let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models?key=\(apiKey)")!
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let modelsData = json?["models"] as? [[String: Any]] else {
            return []
        }
        
        let models = modelsData
            .compactMap { modelData -> String? in
                guard let name = modelData["name"] as? String else { return nil }
                // Extract model name from "models/gemini-pro" format
                return name.replacingOccurrences(of: "models/", with: "")
            }
            .filter { model in
                model.contains("gemini")
            }
            .sorted()
        
        return models
    }
    
    private func fetchMistralModels(apiKey: String) async throws -> [String] {
        let url = URL(string: "https://api.mistral.ai/v1/models")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let modelsData = json?["data"] as? [[String: Any]] else {
            return []
        }
        
        let models = modelsData
            .compactMap { $0["id"] as? String }
            .sorted()
        
        return models
    }
    
    private func fetchGroqModels(apiKey: String) async throws -> [String] {
        let url = URL(string: "https://api.groq.com/openai/v1/models")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let modelsData = json?["data"] as? [[String: Any]] else {
            return []
        }
        
        let models = modelsData
            .compactMap { $0["id"] as? String }
            .sorted()
        
        return models
    }
    
    private func fetchTogetherModels(apiKey: String) async throws -> [String] {
        let url = URL(string: "https://api.together.xyz/v1/models")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        
        let models: [String]
        if let jsonArray = json {
            // Together AI returns an array directly
            models = jsonArray
                .compactMap { $0["id"] as? String }
                .filter { model in
                    model.lowercased().contains("chat") || 
                    model.lowercased().contains("instruct") ||
                    model.lowercased().contains("llama") ||
                    model.lowercased().contains("mixtral") ||
                    model.lowercased().contains("qwen")
                }
                .sorted()
        } else if let jsonDict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let modelsData = jsonDict["data"] as? [[String: Any]] {
            // Or it might return { "data": [...] }
            models = modelsData
                .compactMap { $0["id"] as? String }
                .sorted()
        } else {
            models = []
        }
        
        return models
    }
    
    private func fetchCustomModels(provider: AIProvider) async throws -> [String] {
        // For custom providers, try OpenAI-compatible /models endpoint
        guard !provider.baseURL.isEmpty else { return [] }
        
        // Extract base URL (remove /chat/completions if present)
        var baseURLString = provider.baseURL
        if baseURLString.hasSuffix("/chat/completions") {
            baseURLString = String(baseURLString.dropLast("/chat/completions".count))
        }
        
        guard let url = URL(string: "\(baseURLString)/models") else { return [] }
        
        var request = URLRequest(url: url)
        request.setValue("Bearer \(provider.apiKey)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            return []
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let modelsData = json?["data"] as? [[String: Any]] else {
            return []
        }
        
        let models = modelsData
            .compactMap { $0["id"] as? String }
            .sorted()
        
        return models
    }
}

// MARK: - Glass Style Modifier (Compatible Fallback)

struct GlassModifier: ViewModifier {
    var cornerRadius: CGFloat = 20
    var tintColor: Color? = nil
    
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                    
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.25),
                                    Color.white.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    if let tint = tintColor {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(tint.opacity(0.15))
                    }
                    
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.5),
                                    Color.white.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                }
            )
    }
}

struct GlassCircleModifier: ViewModifier {
    var tintColor: Color? = nil
    
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                    
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.25),
                                    Color.white.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    if let tint = tintColor {
                        Circle()
                            .fill(tint.opacity(0.2))
                    }
                    
                    Circle()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.5),
                                    Color.white.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                }
            )
    }
}

struct GlassCapsuleModifier: ViewModifier {
    var tintColor: Color? = nil
    
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    Capsule()
                        .fill(.ultraThinMaterial)
                    
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.25),
                                    Color.white.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    if let tint = tintColor {
                        Capsule()
                            .fill(tint.opacity(0.15))
                    }
                    
                    Capsule()
                        .strokeBorder(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.5),
                                    Color.white.opacity(0.1)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 0.5
                        )
                }
            )
    }
}

extension View {
    func glassStyle(cornerRadius: CGFloat = 20, tint: Color? = nil) -> some View {
        self.modifier(GlassModifier(cornerRadius: cornerRadius, tintColor: tint))
    }
    
    func glassCircle(tint: Color? = nil) -> some View {
        self.modifier(GlassCircleModifier(tintColor: tint))
    }
    
    func glassCapsule(tint: Color? = nil) -> some View {
        self.modifier(GlassCapsuleModifier(tintColor: tint))
    }
}

// MARK: - View Model

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var inputText: String = ""
    @Published var pendingAttachments: [Attachment] = []
    @Published var providers: [AIProvider] = AIProvider.presets
    @Published var isLoading: Bool = false
    @Published var showSettings: Bool = false
    @Published var showAttachmentPicker: Bool = false
    @Published var errorMessage: String?
    
    var activeProvider: AIProvider? {
        providers.first { $0.isActive }
    }
    
    func sendMessage() async {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard let provider = activeProvider, !provider.apiKey.isEmpty else {
            errorMessage = "Please configure an API key in settings"
            return
        }
        guard !provider.model.isEmpty else {
            errorMessage = "Please select a model in settings"
            return
        }
        
        let userMessage = ChatMessage(
            content: inputText,
            isUser: true,
            attachments: pendingAttachments
        )
        
        messages.append(userMessage)
        let messageContent = inputText
        inputText = ""
        pendingAttachments = []
        isLoading = true
        errorMessage = nil
        
        do {
            let response = try await callAPI(provider: provider, message: messageContent)
            let aiMessage = ChatMessage(content: response, isUser: false)
            messages.append(aiMessage)
        } catch {
            errorMessage = "Error: \(error.localizedDescription)"
            let errorMsg = ChatMessage(content: "Sorry, I encountered an error. Please check your API configuration.", isUser: false)
            messages.append(errorMsg)
        }
        
        isLoading = false
    }
    
    private func callAPI(provider: AIProvider, message: String) async throws -> String {
        guard let url = URL(string: provider.baseURL) else {
            throw URLError(.badURL)
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any]
        
        switch provider.name {
        case "Anthropic":
            request.setValue(provider.apiKey, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
            body = [
                "model": provider.model,
                "max_tokens": 4096,
                "messages": [["role": "user", "content": message]]
            ]
        case "Google AI":
            let googleURL = URL(string: "\(provider.baseURL)/\(provider.model):generateContent?key=\(provider.apiKey)")!
            request.url = googleURL
            body = [
                "contents": [["parts": [["text": message]]]]
            ]
        default:
            request.setValue("Bearer \(provider.apiKey)", forHTTPHeaderField: "Authorization")
            body = [
                "model": provider.model,
                "messages": [["role": "user", "content": message]],
                "max_tokens": 4096
            ]
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        guard httpResponse.statusCode == 200 else {
            if let errorJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let error = errorJson["error"] as? [String: Any],
               let errorMessage = error["message"] as? String {
                throw NSError(domain: "", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: errorMessage])
            }
            throw URLError(.badServerResponse)
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        
        switch provider.name {
        case "Anthropic":
            if let content = json?["content"] as? [[String: Any]],
               let text = content.first?["text"] as? String {
                return text
            }
        case "Google AI":
            if let candidates = json?["candidates"] as? [[String: Any]],
               let content = candidates.first?["content"] as? [String: Any],
               let parts = content["parts"] as? [[String: Any]],
               let text = parts.first?["text"] as? String {
                return text
            }
        default:
            if let choices = json?["choices"] as? [[String: Any]],
               let messageDict = choices.first?["message"] as? [String: Any],
               let content = messageDict["content"] as? String {
                return content
            }
        }
        
        throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse response"])
    }
    
    func addAttachment(name: String, type: Attachment.AttachmentType) {
        let attachment = Attachment(name: name, type: type, data: nil)
        pendingAttachments.append(attachment)
    }
    
    func removeAttachment(_ attachment: Attachment) {
        pendingAttachments.removeAll { $0.id == attachment.id }
    }
    
    func clearChat() {
        messages = []
    }
    
    func setActiveProvider(_ provider: AIProvider) {
        for i in providers.indices {
            providers[i].isActive = providers[i].id == provider.id
        }
    }
    
    func updateProvider(_ provider: AIProvider) {
        if let index = providers.firstIndex(where: { $0.id == provider.id }) {
            providers[index] = provider
        }
    }
}

// MARK: - Main Content View

struct ContentView: View {
    @StateObject private var viewModel = ChatViewModel()
    @State private var showingFilePicker = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Animated gradient background
                AnimatedGradientBackground()
                    .ignoresSafeArea()
                
                // Main chat interface
                VStack(spacing: 0) {
                    // Header
                    HeaderView(viewModel: viewModel)
                    
                    // Messages
                    MessagesScrollView(viewModel: viewModel)
                    
                    // Input area
                    InputAreaView(
                        viewModel: viewModel,
                        showingFilePicker: $showingFilePicker
                    )
                }
            }
        }
        .sheet(isPresented: $viewModel.showSettings) {
            SettingsSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $showingFilePicker) {
            AttachmentPickerSheet(viewModel: viewModel)
        }
        .alert("Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }
}

// MARK: - Header View

struct HeaderView: View {
    @ObservedObject var viewModel: ChatViewModel
    
    var body: some View {
        HStack(spacing: 16) {
            // App title
            HStack(spacing: 10) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
                
                Text("Glass AI")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .glassCapsule()
            
            Spacer()
            
            // Active model indicator
            if let provider = viewModel.activeProvider {
                HStack(spacing: 8) {
                    Circle()
                        .fill(provider.model.isEmpty ? .orange : .green)
                        .frame(width: 8, height: 8)
                    Text(provider.name)
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                    if !provider.model.isEmpty {
                        Text("•")
                            .foregroundStyle(.white.opacity(0.6))
                        Text(provider.model)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    } else {
                        Text("• No model selected")
                            .font(.caption)
                            .foregroundStyle(.orange.opacity(0.9))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .glassCapsule(tint: provider.model.isEmpty ? .orange : .green)
            }
            
            Spacer()
            
            // Action buttons
            HStack(spacing: 12) {
                Button {
                    viewModel.clearChat()
                } label: {
                    Image(systemName: "trash")
                        .font(.body.bold())
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                }
                .glassCircle()
                .opacity(viewModel.messages.isEmpty ? 0.5 : 1)
                .disabled(viewModel.messages.isEmpty)
                
                Button {
                    viewModel.showSettings = true
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.body.bold())
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                }
                .glassCircle(tint: .blue)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
    }
}

// MARK: - Messages Scroll View

struct MessagesScrollView: View {
    @ObservedObject var viewModel: ChatViewModel
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 16) {
                    if viewModel.messages.isEmpty {
                        EmptyStateView()
                            .padding(.top, 100)
                    } else {
                        ForEach(viewModel.messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                        
                        if viewModel.isLoading {
                            LoadingIndicator()
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
            .onChange(of: viewModel.messages.count) {
                if let lastMessage = viewModel.messages.last {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }
}

// MARK: - Empty State View

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "sparkles")
                .font(.system(size: 64))
                .foregroundStyle(.white.opacity(0.6))
            
            VStack(spacing: 8) {
                Text("Start a Conversation")
                    .font(.title2.bold())
                    .foregroundStyle(.white)
                
                Text("Configure your AI provider in settings,\nthen send a message to begin.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(40)
        .glassStyle(cornerRadius: 24)
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            if message.isUser { Spacer(minLength: 60) }
            
            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 8) {
                // Attachments
                if !message.attachments.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(message.attachments) { attachment in
                            AttachmentChip(attachment: attachment, removable: false, onRemove: {})
                        }
                    }
                }
                
                // Message content
                Text(message.content)
                    .font(.body)
                    .foregroundStyle(.white)
                    .textSelection(.enabled)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .background(
                        Group {
                            if message.isUser {
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.blue, Color.blue.opacity(0.8)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                            } else {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .fill(.ultraThinMaterial)
                                    
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .fill(
                                            LinearGradient(
                                                colors: [
                                                    Color.white.opacity(0.2),
                                                    Color.white.opacity(0.05)
                                                ],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                    
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .strokeBorder(Color.white.opacity(0.3), lineWidth: 0.5)
                                }
                            }
                        }
                    )
                
                // Timestamp
                Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
            }
            .frame(maxWidth: 600, alignment: message.isUser ? .trailing : .leading)
            
            if !message.isUser { Spacer(minLength: 60) }
        }
    }
}

// MARK: - Loading Indicator

struct LoadingIndicator: View {
    @State private var animating = false
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(.white.opacity(0.8))
                        .frame(width: 8, height: 8)
                        .scaleEffect(animating ? 1 : 0.5)
                        .animation(
                            .easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                            value: animating
                        )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .glassCapsule()
            
            Spacer(minLength: 60)
        }
        .onAppear { animating = true }
    }
}

// MARK: - Input Area View

struct InputAreaView: View {
    @ObservedObject var viewModel: ChatViewModel
    @Binding var showingFilePicker: Bool
    @FocusState private var isInputFocused: Bool
    
    var body: some View {
        VStack(spacing: 12) {
            // Pending attachments
            if !viewModel.pendingAttachments.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(viewModel.pendingAttachments) { attachment in
                            AttachmentChip(
                                attachment: attachment,
                                removable: true,
                                onRemove: { viewModel.removeAttachment(attachment) }
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                }
            }
            
            // Input row
            HStack(spacing: 12) {
                // Attachment button
                Button {
                    showingFilePicker = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                }
                .glassCircle()
                
                // Settings quick access
                Button {
                    viewModel.showSettings = true
                } label: {
                    Image(systemName: "key.fill")
                        .font(.title3)
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                }
                .glassCircle(tint: viewModel.activeProvider == nil ? .orange : nil)
                
                // Text input
                HStack(spacing: 12) {
                    TextField("Message...", text: $viewModel.inputText, axis: .vertical)
                        .font(.body)
                        .foregroundStyle(.white)
                        .lineLimit(1...6)
                        .focused($isInputFocused)
                        .submitLabel(.send)
                        .onSubmit {
                            if !viewModel.inputText.isEmpty {
                                Task { await viewModel.sendMessage() }
                            }
                        }
                    
                    // Send button
                    Button {
                        Task { await viewModel.sendMessage() }
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title)
                            .foregroundStyle(
                                viewModel.inputText.isEmpty || viewModel.isLoading ?
                                    .white.opacity(0.4) : .blue
                            )
                    }
                    .disabled(viewModel.inputText.isEmpty || viewModel.isLoading)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .glassCapsule()
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .padding(.top, 12)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
        )
    }
}

// MARK: - Attachment Chip

struct AttachmentChip: View {
    let attachment: Attachment
    let removable: Bool
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: attachment.type.rawValue)
                .font(.caption.bold())
                .foregroundStyle(.white)
            
            Text(attachment.name)
                .font(.caption)
                .foregroundStyle(.white)
                .lineLimit(1)
            
            if removable {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassCapsule(tint: .purple)
    }
}

// MARK: - Attachment Picker Sheet

struct AttachmentPickerSheet: View {
    @ObservedObject var viewModel: ChatViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var customFileName = ""
    @State private var selectedType: Attachment.AttachmentType = .document
    
    var body: some View {
        NavigationStack {
            Form {
                Section("File Type") {
                    Picker("Type", selection: $selectedType) {
                        ForEach(Attachment.AttachmentType.allCases, id: \.self) { type in
                            Label(typeName(type), systemImage: type.rawValue)
                                .tag(type)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                Section("File Name") {
                    TextField("Enter file name", text: $customFileName)
                }
                
                Section {
                    Button("Add Attachment") {
                        let name = customFileName.isEmpty ? "Untitled" : customFileName
                        viewModel.addAttachment(name: name, type: selectedType)
                        dismiss()
                    }
                    .disabled(customFileName.isEmpty)
                }
                
                Section("Quick Add") {
                    ForEach(Attachment.AttachmentType.allCases, id: \.self) { type in
                        Button {
                            viewModel.addAttachment(name: "Sample \(typeName(type))", type: type)
                            dismiss()
                        } label: {
                            Label("Add \(typeName(type))", systemImage: type.rawValue)
                        }
                    }
                }
            }
            .navigationTitle("Add Attachment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    func typeName(_ type: Attachment.AttachmentType) -> String {
        switch type {
        case .image: return "Image"
        case .document: return "Document"
        case .pdf: return "PDF"
        case .code: return "Code"
        case .audio: return "Audio"
        case .video: return "Video"
        case .other: return "File"
        }
    }
}

// MARK: - Settings Sheet

struct SettingsSheet: View {
    @ObservedObject var viewModel: ChatViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var editingProvider: AIProvider?
    
    var body: some View {
        NavigationStack {
            List {
                Section("AI Providers") {
                    ForEach(viewModel.providers) { provider in
                        ProviderRow(
                            provider: provider,
                            isActive: provider.isActive,
                            onSelect: { viewModel.setActiveProvider(provider) },
                            onEdit: { editingProvider = provider }
                        )
                    }
                }
                
                Section {
                    Text("Configure your API key for each provider. Only one provider can be active at a time. Models will be fetched automatically when you enter an API key.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(item: $editingProvider) { provider in
                ProviderEditSheet(
                    provider: provider,
                    onSave: { updated in
                        viewModel.updateProvider(updated)
                        editingProvider = nil
                    }
                )
            }
        }
    }
}

// MARK: - Provider Row

struct ProviderRow: View {
    let provider: AIProvider
    let isActive: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(provider.name)
                        .font(.headline)
                    
                    if isActive {
                        Text("Active")
                            .font(.caption2.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(.green.opacity(0.2))
                            .foregroundStyle(.green)
                            .clipShape(Capsule())
                    }
                }
                
                if !provider.model.isEmpty {
                    Text(provider.model)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if !provider.apiKey.isEmpty {
                    Text("No model selected")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                
                HStack(spacing: 4) {
                    Text(provider.apiKey.isEmpty ? "No API key configured" : "API key configured")
                        .font(.caption2)
                        .foregroundStyle(provider.apiKey.isEmpty ? .orange : .green)
                    
                    if !provider.apiKey.isEmpty && !provider.availableModels.isEmpty {
                        Text("• \(provider.availableModels.count) models")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Button {
                    onEdit()
                } label: {
                    Image(systemName: "pencil.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
                
                Button {
                    onSelect()
                } label: {
                    Image(systemName: isActive ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundStyle(isActive ? .green : .secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onSelect() }
    }
}

// MARK: - Provider Edit Sheet

struct ProviderEditSheet: View {
    @State private var provider: AIProvider
    @State private var isFetchingModels: Bool = false
    @State private var fetchError: String?
    @State private var previousApiKey: String = ""
    let onSave: (AIProvider) -> Void
    @Environment(\.dismiss) private var dismiss
    
    init(provider: AIProvider, onSave: @escaping (AIProvider) -> Void) {
        _provider = State(initialValue: provider)
        _previousApiKey = State(initialValue: provider.apiKey)
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Provider Details") {
                    if provider.name == "Custom" {
                        TextField("Name", text: $provider.name)
                    } else {
                        LabeledContent("Name", value: provider.name)
                    }
                }
                
                Section("API Configuration") {
                    SecureField("API Key", text: $provider.apiKey)
                        .textContentType(.password)
                        .onChange(of: provider.apiKey) { oldValue, newValue in
                            // Clear models and selected model when API key changes
                            if newValue != previousApiKey {
                                provider.availableModels = []
                                provider.model = ""
                                fetchError = nil
                            }
                        }
                    
                    if provider.name == "Custom" {
                        TextField("Base URL", text: $provider.baseURL)
                            .textContentType(.URL)
                            .keyboardType(.URL)
                            .autocapitalization(.none)
                    }
                }
                
                Section("Model Selection") {
                    if provider.apiKey.isEmpty {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundStyle(.secondary)
                            Text("Enter an API key to fetch available models")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } else if isFetchingModels {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Fetching models...")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } else if let error = fetchError {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundStyle(.orange)
                                Text("Failed to fetch models")
                                    .font(.subheadline)
                                    .foregroundStyle(.orange)
                            }
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Button("Retry") {
                                Task { await fetchModels() }
                            }
                            .font(.subheadline)
                            
                            // Allow manual entry as fallback
                            TextField("Or enter model manually", text: $provider.model)
                                .autocapitalization(.none)
                        }
                    } else if provider.availableModels.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Button {
                                Task { await fetchModels() }
                            } label: {
                                HStack {
                                    Image(systemName: "arrow.clockwise")
                                    Text("Fetch Available Models")
                                }
                            }
                            
                            // Allow manual entry as fallback
                            TextField("Or enter model manually", text: $provider.model)
                                .autocapitalization(.none)
                        }
                    } else {
                        Picker("Model", selection: $provider.model) {
                            Text("Select a model")
                                .tag("")
                            ForEach(provider.availableModels, id: \.self) { model in
                                Text(model)
                                    .tag(model)
                            }
                        }
                        .pickerStyle(.menu)
                        
                        HStack {
                            Text("\(provider.availableModels.count) models available")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            
                            Spacer()
                            
                            Button {
                                Task { await fetchModels() }
                            } label: {
                                Image(systemName: "arrow.clockwise")
                                    .font(.caption)
                            }
                        }
                    }
                }
                
                Section {
                    if provider.name != "Custom" {
                        Text("Get your API key from the \(provider.name) developer portal.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Edit \(provider.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(provider)
                        dismiss()
                    }
                }
            }
            .onAppear {
                // Auto-fetch models if API key is set but no models loaded
                if !provider.apiKey.isEmpty && provider.availableModels.isEmpty {
                    Task { await fetchModels() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
    
    private func fetchModels() async {
        guard !provider.apiKey.isEmpty else { return }
        
        isFetchingModels = true
        fetchError = nil
        
        do {
            let models = try await ModelFetchingService.shared.fetchModels(for: provider)
            provider.availableModels = models
            previousApiKey = provider.apiKey
            
            // Auto-select first model if none selected
            if provider.model.isEmpty && !models.isEmpty {
                provider.model = models.first ?? ""
            }
        } catch {
            fetchError = error.localizedDescription
        }
        
        isFetchingModels = false
    }
}

// MARK: - Animated Gradient Background

struct AnimatedGradientBackground: View {
    @State private var animateGradient = false
    
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.08, green: 0.08, blue: 0.18),
                Color(red: 0.12, green: 0.08, blue: 0.22),
                Color(red: 0.08, green: 0.12, blue: 0.26),
                Color(red: 0.1, green: 0.1, blue: 0.2)
            ],
            startPoint: animateGradient ? .topLeading : .bottomLeading,
            endPoint: animateGradient ? .bottomTrailing : .topTrailing
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 8).repeatForever(autoreverses: true)) {
                animateGradient.toggle()
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
}
