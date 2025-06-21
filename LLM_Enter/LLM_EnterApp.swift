import Foundation
import MLX
import MLXLMCommon
import MLXLLM
import SwiftUI
import Combine

struct PromptHistoryItem: Identifiable {
    let id = UUID()
    var prompt: String
    var output: String
    var timestamp: Date
}

struct TodoItem: Identifiable, Codable {
    let id = UUID()
    var title: String
    var isCompleted: Bool
    var timestamp: Date
    
    init(title: String) {
        self.title = title
        self.isCompleted = false
        self.timestamp = Date()
    }
}

struct FileItem: Identifiable, Codable {
    let id = UUID()
    var name: String
    var content: String
    var type: FileType
    var timestamp: Date
    
    enum FileType: String, CaseIterable, Codable {
        case html = "html"
        case css = "css"
        case javascript = "js"
        case markdown = "md"
        case text = "txt"
        
        var icon: String {
            switch self {
            case .html: return "globe"
            case .css: return "paintbrush"
            case .javascript: return "chevron.left.forwardslash.chevron.right"
            case .markdown: return "doc.text"
            case .text: return "doc"
            }
        }
    }
    
    init(name: String, content: String, type: FileType) {
        self.name = name
        self.content = content
        self.type = type
        self.timestamp = Date()
    }
}

class LLM_EnterApp: ObservableObject {
    @Published var output = ""
    @Published var promptHistory: [PromptHistoryItem] = []
    @Published var isGenerating = false
    @Published var todos: [TodoItem] = []
    @Published var files: [FileItem] = []
    @Published var showSidebar = false
    
    private var currentTask: Task<Void, Never>?
    
    func runLLM(prompt: String) async {
        DispatchQueue.main.async {
            self.isGenerating = true
            self.output = ""
        }
        
        currentTask = Task {
            do {
                let modelId = "mlx-community/AceReason-Nemotron-1.1-7B-8bit"
                let modelFactory = LLMModelFactory.shared
                let configuration = ModelConfiguration(id: modelId)
                
                // Start loading the model with progress logging
                print("Starting model download/loading...")
                let model = try await modelFactory.loadContainer(configuration: configuration) { progress in
                    // Progress handler for model download
                    print("Download progress: \(Int(progress.fractionCompleted * 100))%")
                }   

                try await model.perform { context in
                    let input = try await context.processor.prepare(input: UserInput(prompt: prompt))
                    let params = GenerateParameters(temperature: 0.6)
                    let tokenStream = try generate(input: input, parameters: params, context: context)
                    for try await part in tokenStream {
                        if Task.isCancelled { break }
                        DispatchQueue.main.async {
                            self.output += part.chunk ?? ""
                        }
                    }
                }
                
                // Save to history when complete
                DispatchQueue.main.async {
                    let historyItem = PromptHistoryItem(
                        prompt: prompt,
                        output: self.output,
                        timestamp: Date()
                    )
                    self.promptHistory.append(historyItem)
                    self.isGenerating = false
                }
                
            } catch {
                DispatchQueue.main.async {
                    self.output = "Error: \(error.localizedDescription)"
                    self.isGenerating = false
                }
            }
        }
        
        await currentTask?.value
    }
    
    func stopGeneration() {
        currentTask?.cancel()
        DispatchQueue.main.async {
            self.isGenerating = false
        }
    }
    
    func editAndResubmit(historyItem: PromptHistoryItem, newPrompt: String) {
        Task {
            await runLLM(prompt: newPrompt)
        }
    }
    
    // MARK: - Todo Management
    func addTodo(_ title: String) {
        let newTodo = TodoItem(title: title)
        DispatchQueue.main.async {
            self.todos.append(newTodo)
        }
    }
    
    func toggleTodo(_ todo: TodoItem) {
        DispatchQueue.main.async {
            if let index = self.todos.firstIndex(where: { $0.id == todo.id }) {
                self.todos[index].isCompleted.toggle()
            }
        }
    }
    
    func deleteTodo(_ todo: TodoItem) {
        DispatchQueue.main.async {
            self.todos.removeAll { $0.id == todo.id }
        }
    }
    
    func updateTodo(_ todo: TodoItem, newTitle: String) {
        DispatchQueue.main.async {
            if let index = self.todos.firstIndex(where: { $0.id == todo.id }) {
                self.todos[index].title = newTitle
            }
        }
    }
    
    // MARK: - File Management
    func addFile(name: String, content: String, type: FileItem.FileType) {
        let newFile = FileItem(name: name, content: content, type: type)
        DispatchQueue.main.async {
            self.files.append(newFile)
        }
    }
    
    func deleteFile(_ file: FileItem) {
        DispatchQueue.main.async {
            self.files.removeAll { $0.id == file.id }
        }
    }
    
    func updateFile(_ file: FileItem, name: String, content: String) {
        DispatchQueue.main.async {
            if let index = self.files.firstIndex(where: { $0.id == file.id }) {
                self.files[index].name = name
                self.files[index].content = content
            }
        }
    }
    
    // MARK: - AI Response Editing
    func editAndResubmitResponse(historyItem: PromptHistoryItem, editedResponse: String) {
        DispatchQueue.main.async {
            if let index = self.promptHistory.firstIndex(where: { $0.id == historyItem.id }) {
                self.promptHistory[index].output = editedResponse
            }
        }
    }
}
