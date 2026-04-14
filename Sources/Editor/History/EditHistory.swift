import Foundation

/// Manages undo/redo history for the editor using the Command pattern.
public final class EditHistory: ObservableObject {
    @Published public private(set) var undoStack: [EditCommand] = []
    @Published public private(set) var redoStack: [EditCommand] = []

    /// Maximum number of undo steps to keep
    public let maxHistorySize: Int

    public init(maxHistorySize: Int = 100) {
        self.maxHistorySize = maxHistorySize
    }

    /// Record a command that was executed (clears redo stack)
    public func record(_ command: EditCommand) {
        undoStack.append(command)
        redoStack.removeAll()

        // Trim history if needed
        if undoStack.count > maxHistorySize {
            undoStack.removeFirst(undoStack.count - maxHistorySize)
        }
    }

    /// Whether undo is available
    public var canUndo: Bool {
        !undoStack.isEmpty
    }

    /// Whether redo is available
    public var canRedo: Bool {
        !redoStack.isEmpty
    }

    /// Pop the last command for undo, returning it and its inverse
    public func popUndo() -> EditCommand? {
        guard let command = undoStack.popLast() else { return nil }
        redoStack.append(command)
        return command.inverse
    }

    /// Pop the last undone command for redo
    public func popRedo() -> EditCommand? {
        guard let command = redoStack.popLast() else { return nil }
        undoStack.append(command)
        return command
    }

    /// Name of the command that would be undone
    public var undoActionName: String? {
        undoStack.last?.displayName
    }

    /// Name of the command that would be redone
    public var redoActionName: String? {
        redoStack.last?.displayName
    }

    /// Clear all history
    public func clear() {
        undoStack.removeAll()
        redoStack.removeAll()
    }
}
