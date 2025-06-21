//
//  ContentView.swift
//  
//
//  Created by Cameron Brooks on 6/21/25.
//

import SwiftUI

struct ContentView: View {
    @State private var prompt: String = ""
    @StateObject private var viewModel = LLM_EnterApp()
    @State private var selectedTab = 0
    @Namespace private var glassEffectNamespace
    
    var body: some View {
        GlassEffectContainer {
            TabView(selection: $selectedTab) {
                // Current Chat Tab
                ChatView(prompt: $prompt, viewModel: viewModel, namespace: glassEffectNamespace)
                    .tabItem {
                        Image(systemName: "message.fill")
                        Text("Chat")
                    }
                    .tag(0)
                
                // History Tab
                HistoryView(viewModel: viewModel, prompt: $prompt, selectedTab: $selectedTab, namespace: glassEffectNamespace)
                    .tabItem {
                        Image(systemName: "clock.fill")
                        Text("History")
                    }
                    .tag(1)
            }
#if os(iOS)
            .tabBarMinimizeBehavior(.onScrollDown)
#endif
            .glassEffect()
            .tint(.blue)
        }
    }
}

struct ChatView: View {
    @Binding var prompt: String
    @ObservedObject var viewModel: LLM_EnterApp
    let namespace: Namespace.ID
    @State private var editingResponse = false
    @State private var editedResponse = ""
    
    var body: some View {
        ZStack {
            // Main chat interface
            VStack(spacing: 16) {
                // Glass toolbar
                HStack {
                    Button(action: {
                        viewModel.showSidebar.toggle()
                    }) {
                        Image(systemName: "sidebar.left")
                            .font(.title2)
                    }
                    .buttonStyle(.bordered)
                    .glassEffect()
                    
                    VStack(spacing: 12) {
                        TextField("Enter your prompt", text: $prompt, axis: .vertical)
                            .textFieldStyle(.plain)
                            .padding(12)
                            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                            .glassEffect()
                            .glassEffectID("promptField", in: namespace)
                        
                        HStack(spacing: 12) {
                            Button(action: {
                                Task {
                                    await viewModel.runLLM(prompt: prompt)
                                }
                            }) {
                                HStack {
                                    if viewModel.isGenerating {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "paperplane.fill")
                                    }
                                    Text(viewModel.isGenerating ? "Generating..." : "Send")
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                            }
                            .disabled(viewModel.isGenerating || prompt.isEmpty)
                            .buttonStyle(.borderedProminent)
                            .glassEffect()
                            
                            if viewModel.isGenerating {
                                Button(action: {
                                    viewModel.stopGeneration()
                                }) {
                                    Image(systemName: "stop.fill")
                                        .foregroundColor(.red)
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 12)
                                }
                                .buttonStyle(.bordered)
                                .glassEffect()
                                .tint(.red)
                            }
                        }
                    }
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .glassEffect()
                .glassEffectID("toolbar", in: namespace)
            
                // Response area with glass effect
                ScrollView {
                    if !viewModel.output.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "brain.head.profile")
                                    .foregroundColor(.blue)
                                Text("Response")
                                    .font(.headline)
                                    .foregroundColor(.blue)
                                Spacer()
                                
                                Menu {
                                    Button("Edit Response") {
                                        editedResponse = viewModel.output
                                        editingResponse = true
                                    }
                                    Button("Copy Response") {
                                        #if os(macOS)
                                        NSPasteboard.general.clearContents()
                                        NSPasteboard.general.setString(viewModel.output, forType: .string)
                                        #else
                                        UIPasteboard.general.string = viewModel.output
                                        #endif
                                    }
                                } label: {
                                    Image(systemName: "ellipsis.circle.fill")
                                        .foregroundStyle(.secondary)
                                }
                                .glassEffect()
                            }
                            
                            Text(viewModel.output)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                        }
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                        .glassEffect()
                        .glassEffectID("response", in: namespace)
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 48))
                                .foregroundStyle(.secondary)
                            Text("Ready to chat")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                            Text("Enter a prompt above to get started")
                                .foregroundStyle(.tertiary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding()
            .background(.clear)
            
            // Sliding Sidebar
            SidebarView(viewModel: viewModel, namespace: namespace)
        }
        .sheet(isPresented: $editingResponse) {
            EditResponseSheet(
                originalResponse: viewModel.output,
                editedResponse: $editedResponse,
                onSubmit: { newResponse in
                    viewModel.output = newResponse
                    editingResponse = false
                },
                namespace: namespace
            )
        }
    }
}

struct HistoryView: View {
    @ObservedObject var viewModel: LLM_EnterApp
    @Binding var prompt: String
    @Binding var selectedTab: Int
    @State private var editingItem: PromptHistoryItem?
    @State private var editedPrompt: String = ""
    let namespace: Namespace.ID
    
    var body: some View {
        NavigationSplitView {
            VStack {
                if viewModel.promptHistory.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "clock.badge.questionmark")
                            .font(.system(size: 48))
                            .foregroundStyle(.secondary)
                        Text("No History Yet")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("Start a conversation to see your chat history")
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            ForEach(viewModel.promptHistory.reversed()) { item in
                                HistoryItemView(
                                    item: item,
                                    onEdit: {
                                        editingItem = item
                                        editedPrompt = item.prompt
                                    },
                                    namespace: namespace
                                )
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Chat History")
            .searchable(text: .constant(""))
        } detail: {
            VStack(spacing: 16) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("Select a conversation")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .glassEffect()
        .sheet(item: $editingItem) { item in
            EditPromptSheet(
                originalPrompt: item.prompt,
                editedPrompt: $editedPrompt,
                onSubmit: { newPrompt in
                    prompt = newPrompt
                    selectedTab = 0
                    viewModel.editAndResubmit(historyItem: item, newPrompt: newPrompt)
                    editingItem = nil
                },
                namespace: namespace
            )
        }
    }
}

struct HistoryItemView: View {
    let item: PromptHistoryItem
    let onEdit: () -> Void
    let namespace: Namespace.ID
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with timestamp and menu
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(item.timestamp, style: .time)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Menu {
                    Button(action: onEdit) {
                        Label("Edit & Resubmit", systemImage: "pencil")
                    }
                    Button {
                        #if os(macOS)
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(item.prompt, forType: .string)
                        #else
                        UIPasteboard.general.string = item.prompt
                        #endif
                    } label: {
                        Label("Copy Prompt", systemImage: "doc.on.doc")
                    }
                    Button {
                        #if os(macOS)
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(item.output, forType: .string)
                        #else
                        UIPasteboard.general.string = item.output
                        #endif
                    } label: {
                        Label("Copy Response", systemImage: "doc.on.doc.fill")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .glassEffect()
            }
            
            // Prompt section
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "person.fill")
                        .foregroundColor(.green)
                    Text("You")
                        .font(.headline)
                        .foregroundColor(.green)
                }
                
                Text(item.prompt)
                    .textSelection(.enabled)
                    .padding(12)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .glassEffect()
                    .glassEffectID("prompt-\(item.id)", in: namespace)
            }
            
            // Response section
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: "brain.head.profile")
                        .foregroundColor(.blue)
                    Text("Assistant")
                        .font(.headline)
                        .foregroundColor(.blue)
                }
                
                Text(item.output)
                    .textSelection(.enabled)
                    .padding(12)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                    .glassEffect()
                    .glassEffectID("response-\(item.id)", in: namespace)
            }
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        .glassEffect()
        .glassEffectID("historyItem-\(item.id)", in: namespace)
    }
}

struct EditPromptSheet: View {
    let originalPrompt: String
    @Binding var editedPrompt: String
    let onSubmit: (String) -> Void
    let namespace: Namespace.ID
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.blue)
                    Text("Edit Prompt")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Modify your prompt and resubmit")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .glassEffect()
                .glassEffectID("editHeader", in: namespace)
                
                // Text editor with glass effect
                VStack(alignment: .leading, spacing: 8) {
                    Text("Prompt:")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    TextEditor(text: $editedPrompt)
                        .padding(12)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                        .glassEffect()
                        .glassEffectID("editTextEditor", in: namespace)
                        .frame(minHeight: 200)
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .glassEffect()
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 12) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .glassEffect()
                    .frame(maxWidth: .infinity)
                    
                    Button("Submit") {
                        onSubmit(editedPrompt)
                        dismiss()
                    }
                    .disabled(editedPrompt.isEmpty)
                    .buttonStyle(.borderedProminent)
                    .glassEffect()
                    .frame(maxWidth: .infinity)
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .glassEffect()
                .glassEffectID("editActions", in: namespace)
            }
            .padding()
            .background(.clear)
#if os(iOS)
            .navigationTitle("")
            .navigationBarHidden(true)
#else
            .navigationTitle("")
#endif
        }
        .glassEffect()
    }
}

struct SidebarView: View {
    @ObservedObject var viewModel: LLM_EnterApp
    let namespace: Namespace.ID
    @State private var selectedSidebarTab = 0
    
    var body: some View {
        HStack {
            if viewModel.showSidebar {
                VStack {
                    // Sidebar content
                    TabView(selection: $selectedSidebarTab) {
                        TodoListView(viewModel: viewModel, namespace: namespace)
                            .tabItem {
                                Image(systemName: "checklist")
                                Text("Todos")
                            }
                            .tag(0)
                        
                        FileBucketView(viewModel: viewModel, namespace: namespace)
                            .tabItem {
                                Image(systemName: "folder")
                                Text("Files")
                            }
                            .tag(1)
                    }
                }
                .frame(width: 320)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .glassEffect()
                .glassEffectID("sidebar", in: namespace)
                .transition(.move(edge: .leading).combined(with: .opacity))
            }
            
            Spacer()
        }
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: viewModel.showSidebar)
    }
}

struct TodoListView: View {
    @ObservedObject var viewModel: LLM_EnterApp
    let namespace: Namespace.ID
    @State private var newTodoText = ""
    @State private var editingTodo: TodoItem?
    @State private var editTodoText = ""
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "checklist")
                    .foregroundColor(.green)
                Text("Todo List")
                    .font(.headline)
                    .foregroundColor(.green)
                Spacer()
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .glassEffect()
            
            // Add new todo
            HStack {
                TextField("Add new todo...", text: $newTodoText)
                    .textFieldStyle(.plain)
                
                Button(action: {
                    if !newTodoText.isEmpty {
                        viewModel.addTodo(newTodoText)
                        newTodoText = ""
                    }
                }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.green)
                }
                .disabled(newTodoText.isEmpty)
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .glassEffect()
            
            // Todo list
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(viewModel.todos) { todo in
                        TodoItemView(
                            todo: todo,
                            onToggle: { viewModel.toggleTodo(todo) },
                            onDelete: { viewModel.deleteTodo(todo) },
                            onEdit: {
                                editingTodo = todo
                                editTodoText = todo.title
                            },
                            namespace: namespace
                        )
                    }
                }
                .padding()
            }
            
            if viewModel.todos.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "checklist")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text("No todos yet")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(item: $editingTodo) { todo in
            EditTodoSheet(
                todo: todo,
                editText: $editTodoText,
                onSave: { newText in
                    viewModel.updateTodo(todo, newTitle: newText)
                    editingTodo = nil
                },
                namespace: namespace
            )
        }
    }
}

struct TodoItemView: View {
    let todo: TodoItem
    let onToggle: () -> Void
    let onDelete: () -> Void
    let onEdit: () -> Void
    let namespace: Namespace.ID
    
    var body: some View {
        HStack {
            Button(action: onToggle) {
                Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(todo.isCompleted ? .green : .secondary)
            }
            
            Text(todo.title)
                .strikethrough(todo.isCompleted)
                .foregroundColor(todo.isCompleted ? .secondary : .primary)
            
            Spacer()
            
            Menu {
                Button("Edit", action: onEdit)
                Button("Delete", role: .destructive, action: onDelete)
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .glassEffect()
        .glassEffectID("todo-\(todo.id)", in: namespace)
    }
}

struct FileBucketView: View {
    @ObservedObject var viewModel: LLM_EnterApp
    let namespace: Namespace.ID
    @State private var showingAddFile = false
    @State private var selectedFile: FileItem?
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "folder")
                    .foregroundColor(.blue)
                Text("File Bucket")
                    .font(.headline)
                    .foregroundColor(.blue)
                Spacer()
                
                Button(action: {
                    showingAddFile = true
                }) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundColor(.blue)
                }
            }
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .glassEffect()
            
            // File list
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(viewModel.files) { file in
                        FileItemView(
                            file: file,
                            onSelect: { selectedFile = file },
                            onDelete: { viewModel.deleteFile(file) },
                            namespace: namespace
                        )
                    }
                }
                .padding()
            }
            
            if viewModel.files.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 32))
                        .foregroundStyle(.secondary)
                    Text("No files yet")
                        .foregroundStyle(.secondary)
                    Text("Add HTML, CSS, or JS files")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $showingAddFile) {
            AddFileSheet(viewModel: viewModel, namespace: namespace)
        }
        .sheet(item: $selectedFile) { file in
            FileDetailSheet(file: file, viewModel: viewModel, namespace: namespace)
        }
    }
}

struct FileItemView: View {
    let file: FileItem
    let onSelect: () -> Void
    let onDelete: () -> Void
    let namespace: Namespace.ID
    
    var body: some View {
        HStack {
            Image(systemName: file.type.icon)
                .foregroundColor(.blue)
            
            VStack(alignment: .leading) {
                Text(file.name)
                    .font(.headline)
                Text(file.type.rawValue.uppercased())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            Menu {
                Button("View", action: onSelect)
                Button("Delete", role: .destructive, action: onDelete)
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .glassEffect()
        .glassEffectID("file-\(file.id)", in: namespace)
        .onTapGesture {
            onSelect()
        }
    }
}

struct EditResponseSheet: View {
    let originalResponse: String
    @Binding var editedResponse: String
    let onSubmit: (String) -> Void
    let namespace: Namespace.ID
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "pencil.and.outline")
                        .font(.system(size: 32))
                        .foregroundColor(.blue)
                    Text("Edit AI Response")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text("Modify the AI response and save changes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .glassEffect()
                .glassEffectID("editResponseHeader", in: namespace)
                
                // Text editor
                VStack(alignment: .leading, spacing: 8) {
                    Text("Response:")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    TextEditor(text: $editedResponse)
                        .padding(12)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                        .glassEffect()
                        .glassEffectID("editResponseEditor", in: namespace)
                        .frame(minHeight: 300)
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .glassEffect()
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 12) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .glassEffect()
                    .frame(maxWidth: .infinity)
                    
                    Button("Save Changes") {
                        onSubmit(editedResponse)
                    }
                    .disabled(editedResponse.isEmpty)
                    .buttonStyle(.borderedProminent)
                    .glassEffect()
                    .frame(maxWidth: .infinity)
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .glassEffect()
                .glassEffectID("editResponseActions", in: namespace)
            }
            .padding()
            .background(.clear)
#if os(iOS)
            .navigationTitle("")
            .navigationBarHidden(true)
#else
            .navigationTitle("")
#endif
        }
        .glassEffect()
    }
}

struct EditTodoSheet: View {
    let todo: TodoItem
    @Binding var editText: String
    let onSave: (String) -> Void
    let namespace: Namespace.ID
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Image(systemName: "pencil.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.green)
                    Text("Edit Todo")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .glassEffect()
                
                TextField("Todo title", text: $editText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .padding(12)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .glassEffect()
                    .padding()
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .glassEffect()
                    .frame(maxWidth: .infinity)
                    
                    Button("Save") {
                        onSave(editText)
                    }
                    .disabled(editText.isEmpty)
                    .buttonStyle(.borderedProminent)
                    .glassEffect()
                    .frame(maxWidth: .infinity)
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .glassEffect()
            }
            .padding()
        }
        .glassEffect()
    }
}

struct AddFileSheet: View {
    @ObservedObject var viewModel: LLM_EnterApp
    let namespace: Namespace.ID
    @State private var fileName = ""
    @State private var fileContent = ""
    @State private var selectedType: FileItem.FileType = .html
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Image(systemName: "doc.badge.plus")
                        .font(.system(size: 32))
                        .foregroundColor(.blue)
                    Text("Add File")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .glassEffect()
                
                VStack(spacing: 12) {
                    TextField("File name", text: $fileName)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                        .glassEffect()
                    
                    Picker("File Type", selection: $selectedType) {
                        ForEach(FileItem.FileType.allCases, id: \.self) { type in
                            Text(type.rawValue.uppercased()).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)
                    .glassEffect()
                    
                    TextEditor(text: $fileContent)
                        .padding(12)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                        .glassEffect()
                        .frame(minHeight: 200)
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .glassEffect()
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .glassEffect()
                    .frame(maxWidth: .infinity)
                    
                    Button("Add File") {
                        viewModel.addFile(name: fileName, content: fileContent, type: selectedType)
                        dismiss()
                    }
                    .disabled(fileName.isEmpty || fileContent.isEmpty)
                    .buttonStyle(.borderedProminent)
                    .glassEffect()
                    .frame(maxWidth: .infinity)
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .glassEffect()
            }
            .padding()
        }
        .glassEffect()
    }
}

struct FileDetailSheet: View {
    let file: FileItem
    @ObservedObject var viewModel: LLM_EnterApp
    let namespace: Namespace.ID
    @State private var editingFile = false
    @State private var editedName = ""
    @State private var editedContent = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Image(systemName: file.type.icon)
                        .font(.system(size: 32))
                        .foregroundColor(.blue)
                    Text(file.name)
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text(file.type.rawValue.uppercased())
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .glassEffect()
                
                ScrollView {
                    Text(file.content)
                        .textSelection(.enabled)
                        .font(.system(.body, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                        .glassEffect()
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .glassEffect()
                
                HStack(spacing: 12) {
                    Button("Edit") {
                        editedName = file.name
                        editedContent = file.content
                        editingFile = true
                    }
                    .buttonStyle(.bordered)
                    .glassEffect()
                    .frame(maxWidth: .infinity)
                    
                    Button("Close") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .glassEffect()
                    .frame(maxWidth: .infinity)
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .glassEffect()
            }
            .padding()
        }
        .glassEffect()
        .sheet(isPresented: $editingFile) {
            EditFileSheet(
                file: file,
                editedName: $editedName,
                editedContent: $editedContent,
                onSave: {
                    viewModel.updateFile(file, name: editedName, content: editedContent)
                    editingFile = false
                },
                namespace: namespace
            )
        }
    }
}

struct EditFileSheet: View {
    let file: FileItem
    @Binding var editedName: String
    @Binding var editedContent: String
    let onSave: () -> Void
    let namespace: Namespace.ID
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(spacing: 8) {
                    Image(systemName: "pencil.and.outline")
                        .font(.system(size: 32))
                        .foregroundColor(.blue)
                    Text("Edit File")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .glassEffect()
                
                VStack(spacing: 12) {
                    TextField("File name", text: $editedName)
                        .textFieldStyle(.plain)
                        .padding(12)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                        .glassEffect()
                    
                    TextEditor(text: $editedContent)
                        .font(.system(.body, design: .monospaced))
                        .padding(12)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                        .glassEffect()
                        .frame(minHeight: 300)
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .glassEffect()
                
                Spacer()
                
                HStack(spacing: 12) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .glassEffect()
                    .frame(maxWidth: .infinity)
                    
                    Button("Save Changes") {
                        onSave()
                        dismiss()
                    }
                    .disabled(editedName.isEmpty || editedContent.isEmpty)
                    .buttonStyle(.borderedProminent)
                    .glassEffect()
                    .frame(maxWidth: .infinity)
                }
                .padding()
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                .glassEffect()
            }
            .padding()
        }
        .glassEffect()
    }
}

#Preview {
    ContentView()
}

