import SwiftUI

actor BaseManager<T> {
    private var continuation: AsyncStream<Result<T, Error>>.Continuation
    let stream: AsyncStream<Result<T, Error>>
    
    init() {
        var cont: AsyncStream<Result<T, Error>>.Continuation!
        self.stream = AsyncStream { continuation in
            cont = continuation
        }
        self.continuation = cont
    }
    
    func send(_ value: T) {
        continuation.yield(.success(value))
    }
    
    func sendError(_ error: Error) {
        continuation.yield(.failure(error))
    }
    
    func finish() {
        continuation.finish()
    }
}

@MainActor
final class BaseViewModel<T>: ObservableObject {
    @Published var latestValue: T?
    @Published var lastError: String?
    
    private let manager: BaseManager<T>
    private var task: Task<Void, Never>?
    
    init(manager: BaseManager<T>) {
        self.manager = manager
        startObserving()
    }
    
    private func startObserving() {
        task = Task {
            for await result in await manager.stream {
                switch result {
                case .success(let value):
                    latestValue = value
                case .failure(let error):
                    lastError = error.localizedDescription
                }
            }
        }
    }
    
    func stopObserving() {
        task?.cancel()
        task = nil
    }
}

struct BaseView<T: CustomStringConvertible>: View {
    @StateObject private var viewModel: BaseViewModel<T>
    
    init(manager: BaseManager<T>) {
        _viewModel = StateObject(wrappedValue: BaseViewModel(manager: manager))
    }
    
    var body: some View {
        VStack(spacing: 20) {
            if let value = viewModel.latestValue {
                Text("最近の値: \(value.description)")
                    .font(.headline)
            } else {
                Text("値はまだありません")
                    .foregroundStyle(.secondary)
            }
            
            if let error = viewModel.lastError {
                Text("エラー: \(error)")
                    .foregroundStyle(.red)
            }
            
            Button("購読停止") {
                viewModel.stopObserving()
            }
            .padding()
            .background(Color.red.opacity(0.2))
            .cornerRadius(8)
        }
        .padding()
    }
}

struct ContentView: View {
    var body: some View {
        VStack {
            Image(systemName: "globe")
                .imageScale(.large)
                .foregroundStyle(.tint)
            Text("Hello, world!")
        }
        .padding()
    }
}

#Preview {
    ContentView()
}

import SwiftUI

@main
struct TESTActorStreamMVVMApp: App {
    private static let manager = BaseManager<String>()
    
    var body: some Scene {
        WindowGroup {
            BaseView(manager: Self.manager)
                .task {
                    for i in 1...10 {
                        if i % 3 == 0 {
                            await Self.manager.sendError(NSError(domain: "TestError", code: i, userInfo: [NSLocalizedDescriptionKey: "Error \(i) occurred"]))
                        } else {
                            await Self.manager.send("Value \(i)")
                        }
                        try? await Task.sleep(nanoseconds: 1_000_000_000)
                    }
                    await Self.manager.finish()
                }
        }
    }
}
