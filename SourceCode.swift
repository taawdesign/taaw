import SwiftUI
import WebKit

// MARK: - Main App Entry Point
@main
struct AIChatApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

// MARK: - Main View
struct ContentView: View {
    // State for the window size and position
    @State private var windowSize: CGSize = CGSize(width: 400, height: 600)
    @State private var windowPosition: CGPoint = CGPoint(x: 50, y: 100)
    
    // State for the content sync
    @State private var extractedText = "Waiting for AI code..."
    @State private var selectedTab = 0
    
    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Background (dimmed to focus on the floating window)
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()
                    .overlay(
                        Text("Drag and resize the floating window")
                            .foregroundColor(.secondary)
                    )
                
                // Floating Window
                FloatingWindowView(
                    size: $windowSize,
                    position: $windowPosition,
                    extractedText: $extractedText,
                    selectedTab: $selectedTab
                )
            }
        }
    }
}

// MARK: - Floating Window Component
struct FloatingWindowView: View {
    @Binding var size: CGSize
    @Binding var position: CGPoint
    @Binding var extractedText: String
    @Binding var selectedTab: Int
    
    // Drag Gestures
    @State private var dragOffset: CGSize = .zero
    @State private var isDraggingWindow = false
    
    // Resize Gestures
    @State private var isResizing = false
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Main Window Content
            VStack(spacing: 0) {
                // Header Bar (For dragging)
                HStack {
                    Text("AI Assistant")
                        .font(.headline)
                        .foregroundColor(.white)
                    Spacer()
                    Circle()
                        .fill(Color.red)
                        .frame(width: 12, height: 12)
                    Circle()
                        .fill(Color.yellow)
                        .frame(width: 12, height: 12)
                    Circle()
                        .fill(Color.green)
                        .frame(width: 12, height: 12)
                }
                .padding()
                .background(Color.gray.opacity(0.8))
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            self.isDraggingWindow = true
                            self.position.x += value.translation.width
                            self.position.y += value.translation.height
                        }
                        .onEnded { _ in
                            self.isDraggingWindow = false
                        }
                )
                
                // Tab View (Chat vs Code)
                TabView(selection: $selectedTab) {
                    // Tab 1: Chat Webview
                    ChatWebView(extractedText: $extractedText)
                        .tag(0)
                        .tabItem {
                            Label("Chat", systemImage: "message.fill")
                        }
                    
                    // Tab 2: Code View
                    CodeView(content: $extractedText)
                        .tag(1)
                        .tabItem {
                            Label("Code", systemImage: "chevron.left.forwardslash.chevron.right")
                        }
                }
            }
            .frame(width: size.width, height: size.height)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
            .shadow(radius: 20, x: 5, y: 5)
            .position(x: position.x + size.width / 2, y: position.y + size.height / 2)
            
            // Resize Handle (Bottom Right Corner)
            ResizeHandle()
                .frame(width: 30, height: 30)
                .offset(x: -10, y: -10)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            self.isResizing = true
                            let newWidth = max(300, self.size.width + value.translation.width)
                            let newHeight = max(400, self.size.height + value.translation.height)
                            self.size = CGSize(width: newWidth, height: newHeight)
                        }
                        .onEnded { _ in
                            self.isResizing = false
                        }
                )
        }
    }
}

// MARK: - Resize Handle View
struct ResizeHandle: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 5)
                .fill(Color.gray.opacity(0.5))
            Image(systemName: "chevron.right.down")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.white)
        }
    }
}

// MARK: - Code View
struct CodeView: View {
    @Binding var content: String
    
    var body: some View {
        ScrollView {
            Text(content)
                .font(.system(.body, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .textSelection(.enabled) // Allows copying
        }
    }
}

// MARK: - Web View with JS Injection
struct ChatWebView: UIViewRepresentable {
    @Binding var extractedText: String
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> WKWebView {
        let webConfiguration = WKWebViewConfiguration()
        let contentController = WKUserContentController()
        
        // 1. Add the script message handler
        contentController.add(context.coordinator, name: "iosObserver")
        
        // 2. Inject JavaScript to listen for changes
        // NOTE: This is a generic script. For chat.z.ai, you might need to change 
        // "document.body.innerText" to target the specific class of the code block.
        let script = """
        var lastContent = "";
        
        function checkForChanges() {
            // CURRENT STRATEGY: Grab all text from the body
            // TODO: Replace 'document.body.innerText' with the specific CSS selector 
            // of the code block on chat.z.ai for better accuracy.
            // Example: document.querySelector('.code-block').innerText;
            
            var currentContent = document.body.innerText;
            
            // Heuristic: Try to find the largest block of text that looks like code
            // (This is a fallback if we don't know the exact class)
            if(currentContent !== lastContent) {
                lastContent = currentContent;
                // Send message to Swift
                webkit.messageHandlers.iosObserver.postMessage(currentContent);
            }
        }
        
        // Check every 1 second
        setInterval(checkForChanges, 1000);
        """
        
        let userScript = WKUserScript(source: script, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
        contentController.addUserScript(userScript)
        
        webConfiguration.userContentController = contentController
        
        let webView = WKWebView(frame: .zero, configuration: webConfiguration)
        
        // Load the URL
        if let url = URL(string: "https://chat.z.ai/") {
            webView.load(URLRequest(url: url))
        }
        
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        // No updates needed dynamically
    }
    
    // MARK: - Coordinator to handle messages from JS
    class Coordinator: NSObject, WKScriptMessageHandler {
        var parent: ChatWebView
        
        init(_ parent: ChatWebView) {
            self.parent = parent
        }
        
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            // This is called when the JavaScript sends a message
            if let messageBody = message.body as? String {
                DispatchQueue.main.async {
                    // Update the @State in the parent view
                    self.parent.extractedText = messageBody
                }
            }
        }
    }
}