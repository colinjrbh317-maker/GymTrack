import Foundation

// MARK: - Workout Business Model

/// Business model wrapper for Workout Core Data entity
/// Provides clean interface for workout management functionality
public struct WorkoutModel: Identifiable, Hashable {
    public let id: UUID
    public var name: String
    public var notes: String?
    public let createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        notes: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Core Data Conversion Extensions

extension WorkoutModel {
    /// Initialize from Core Data Workout entity
    public init(from entity: Workout) {
        self.id = entity.id ?? UUID()
        self.name = entity.name ?? ""
        self.notes = entity.notes
        self.createdAt = entity.createdAt ?? Date()
        self.updatedAt = entity.updatedAt ?? Date()
    }

    /// Update Core Data Workout entity from business model
    public func update(_ entity: Workout) {
        entity.id = self.id
        entity.name = self.name
        entity.notes = self.notes
        entity.createdAt = self.createdAt
        entity.updatedAt = self.updatedAt
    }
}

// MARK: - Computed Properties

extension WorkoutModel {
    /// Display name with fallback
    public var displayName: String {
        return name.trimmingCharacters(in: .whitespaces).isEmpty ? "Untitled Workout" : name
    }

    /// Short description for list displays
    public var shortDescription: String {
        if let notes = notes, !notes.trimmingCharacters(in: .whitespaces).isEmpty {
            let trimmed = notes.trimmingCharacters(in: .whitespaces)
            return String(trimmed.prefix(50)) + (trimmed.count > 50 ? "..." : "")
        }
        return "No description"
    }

    /// Formatted creation date
    public var formattedCreatedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: createdAt)
    }

    /// Formatted last updated date
    public var formattedUpdatedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: updatedAt)
    }

    /// Relative time since last update
    public var lastUpdatedRelative: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: updatedAt, relativeTo: Date())
    }

    /// Check if workout was recently created (within last 24 hours)
    public var isNew: Bool {
        return createdAt.timeIntervalSinceNow > -86400 // 24 hours
    }

    /// Check if workout was recently updated (within last hour)
    public var isRecentlyUpdated: Bool {
        return updatedAt.timeIntervalSinceNow > -3600 // 1 hour
    }
}

// MARK: - Validation

extension WorkoutModel {
    /// Validate workout data
    /// - Returns: Array of validation errors (empty if valid)
    public func validate() -> [WorkoutValidationError] {
        var errors: [WorkoutValidationError] = []

        // Check name
        if name.trimmingCharacters(in: .whitespaces).isEmpty {
            errors.append(.emptyName)
        }

        // Check name length
        if name.count > 100 {
            errors.append(.nameTooLong)
        }

        // Check notes length
        if let notes = notes, notes.count > 500 {
            errors.append(.notesTooLong)
        }

        return errors
    }

    /// Check if workout is valid
    public var isValid: Bool {
        return validate().isEmpty
    }
}

// MARK: - Sample Data

extension WorkoutModel {
    /// Sample workouts for testing and previews
    public static let sampleWorkouts: [WorkoutModel] = [
        WorkoutModel(
            name: "Push Day A",
            notes: "Focus on chest, shoulders, and triceps. Progressive overload on bench press.",
            createdAt: Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date(),
            updatedAt: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
        ),
        WorkoutModel(
            name: "Pull Day A",
            notes: "Back and biceps focus. Start with deadlifts for compound movement.",
            createdAt: Calendar.current.date(byAdding: .day, value: -5, to: Date()) ?? Date(),
            updatedAt: Calendar.current.date(byAdding: .day, value: -2, to: Date()) ?? Date()
        ),
        WorkoutModel(
            name: "Leg Day",
            notes: "Squat focused session with accessory work for glutes and hamstrings.",
            createdAt: Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date(),
            updatedAt: Date()
        )
    ]
}

// MARK: - Validation Error Types

public enum WorkoutValidationError: LocalizedError {
    case emptyName
    case nameTooLong
    case notesTooLong

    public var errorDescription: String? {
        switch self {
        case .emptyName:
            return "Workout name cannot be empty"
        case .nameTooLong:
            return "Workout name cannot exceed 100 characters"
        case .notesTooLong:
            return "Workout notes cannot exceed 500 characters"
        }
    }
}

// MARK: - Sorting and Filtering

extension WorkoutModel {
    /// Sort workouts by update date (most recent first)
    public static func sortByUpdateDate(_ workouts: [WorkoutModel]) -> [WorkoutModel] {
        return workouts.sorted { $0.updatedAt > $1.updatedAt }
    }

    /// Sort workouts by creation date (newest first)
    public static func sortByCreationDate(_ workouts: [WorkoutModel]) -> [WorkoutModel] {
        return workouts.sorted { $0.createdAt > $1.createdAt }
    }

    /// Sort workouts alphabetically by name
    public static func sortByName(_ workouts: [WorkoutModel]) -> [WorkoutModel] {
        return workouts.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Filter workouts by search query
    /// - Parameter query: Search query
    /// - Returns: Filtered workouts
    public static func filter(_ workouts: [WorkoutModel], by query: String) -> [WorkoutModel] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return workouts }

        let lowercaseQuery = query.lowercased()
        return workouts.filter { workout in
            workout.name.lowercased().contains(lowercaseQuery) ||
            (workout.notes?.lowercased().contains(lowercaseQuery) ?? false)
        }
    }

    /// Get workouts created in date range
    /// - Parameters:
    ///   - workouts: Workouts to filter
    ///   - startDate: Start date
    ///   - endDate: End date
    /// - Returns: Filtered workouts
    public static func filter(
        _ workouts: [WorkoutModel],
        from startDate: Date,
        to endDate: Date
    ) -> [WorkoutModel] {
        return workouts.filter { workout in
            workout.createdAt >= startDate && workout.createdAt <= endDate
        }
    }
}