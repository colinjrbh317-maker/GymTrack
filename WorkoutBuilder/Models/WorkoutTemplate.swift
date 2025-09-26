import Foundation

// MARK: - WorkoutTemplate Business Model

/// Business model for workout templates
/// Represents a reusable workout configuration that can be applied to create new workouts
public struct WorkoutTemplateModel: Identifiable, Hashable {
    public let id: UUID
    public var name: String
    public var exercises: [WorkoutExerciseModel]
    public let estimatedDuration: TimeInterval
    public let difficulty: WorkoutDifficulty
    public let muscleGroups: [MuscleGroup]
    public let equipment: [String]
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        exercises: [WorkoutExerciseModel],
        estimatedDuration: TimeInterval,
        difficulty: WorkoutDifficulty,
        muscleGroups: [MuscleGroup],
        equipment: [String],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.exercises = exercises
        self.estimatedDuration = estimatedDuration
        self.difficulty = difficulty
        self.muscleGroups = muscleGroups
        self.equipment = equipment
        self.createdAt = createdAt
    }
}

// MARK: - Core Data Conversion Extensions

extension WorkoutTemplateModel {
    /// Initialize from Core Data WorkoutTemplate entity
    public init(from entity: WorkoutTemplate) throws {
        self.id = entity.id ?? UUID()
        self.name = entity.name ?? ""
        self.estimatedDuration = entity.estimatedDuration
        self.difficulty = WorkoutDifficulty(rawValue: entity.difficulty ?? "") ?? .intermediate
        self.createdAt = entity.createdAt ?? Date()

        // Decode exercises from JSON
        if let exercisesData = entity.exercisesData {
            let decoder = JSONDecoder()
            self.exercises = try decoder.decode([WorkoutExerciseModel].self, from: exercisesData)
        } else {
            self.exercises = []
        }

        // Decode muscle groups from strings
        if let muscleGroupStrings = entity.muscleGroups {
            self.muscleGroups = muscleGroupStrings.compactMap { MuscleGroup(rawValue: $0) }
        } else {
            self.muscleGroups = []
        }

        // Equipment array
        self.equipment = entity.equipment ?? []
    }

    /// Update Core Data WorkoutTemplate entity from business model
    public func update(_ entity: WorkoutTemplate) throws {
        entity.id = self.id
        entity.name = self.name
        entity.estimatedDuration = self.estimatedDuration
        entity.difficulty = self.difficulty.rawValue
        entity.createdAt = self.createdAt

        // Encode exercises to JSON
        let encoder = JSONEncoder()
        entity.exercisesData = try encoder.encode(self.exercises)

        // Convert muscle groups to strings
        entity.muscleGroups = self.muscleGroups.map { $0.rawValue }

        // Equipment array
        entity.equipment = self.equipment
    }
}

// MARK: - Computed Properties

extension WorkoutTemplateModel {
    /// Display name with fallback
    public var displayName: String {
        return name.trimmingCharacters(in: .whitespaces).isEmpty ? "Untitled Template" : name
    }

    /// Exercise count
    public var exerciseCount: Int {
        return exercises.count
    }

    /// Total sets across all exercises
    public var totalSets: Int {
        return exercises.reduce(0) { $0 + $1.targetSets }
    }

    /// Total reps across all exercises
    public var totalReps: Int {
        return exercises.reduce(0) { $0 + ($1.targetSets * $1.targetReps) }
    }

    /// Formatted duration for display
    public var formattedDuration: String {
        let minutes = Int(estimatedDuration) / 60
        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            if remainingMinutes == 0 {
                return "\(hours)h"
            } else {
                return "\(hours)h \(remainingMinutes)m"
            }
        }
    }

    /// Formatted creation date
    public var formattedCreatedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: createdAt)
    }

    /// Primary muscle groups (first 3)
    public var primaryMuscleGroups: [MuscleGroup] {
        return Array(muscleGroups.prefix(3))
    }

    /// Muscle groups display string
    public var muscleGroupsDisplay: String {
        if muscleGroups.isEmpty {
            return "Full Body"
        } else if muscleGroups.count <= 3 {
            return muscleGroups.map { $0.displayName }.joined(separator: ", ")
        } else {
            let first = muscleGroups.prefix(2).map { $0.displayName }.joined(separator: ", ")
            return "\(first) + \(muscleGroups.count - 2) more"
        }
    }

    /// Equipment display string
    public var equipmentDisplay: String {
        if equipment.isEmpty {
            return "No equipment"
        } else if equipment.count == 1 {
            return equipment.first!
        } else if equipment.count <= 3 {
            return equipment.joined(separator: ", ")
        } else {
            return "\(equipment.prefix(2).joined(separator: ", ")) + \(equipment.count - 2) more"
        }
    }

    /// Template summary for preview
    public var summary: String {
        return "\(exerciseCount) exercises • \(formattedDuration) • \(difficulty.description)"
    }

    /// Check if template targets specific muscle group
    public func targets(_ muscleGroup: MuscleGroup) -> Bool {
        return muscleGroups.contains(muscleGroup)
    }

    /// Check if template uses specific equipment
    public func uses(_ equipment: String) -> Bool {
        return self.equipment.contains { $0.lowercased() == equipment.lowercased() }
    }
}

// MARK: - Validation

extension WorkoutTemplateModel {
    /// Validate template data
    /// - Returns: Array of validation errors (empty if valid)
    public func validate() -> [TemplateValidationError] {
        var errors: [TemplateValidationError] = []

        // Check name
        if name.trimmingCharacters(in: .whitespaces).isEmpty {
            errors.append(.emptyName)
        }

        // Check name length
        if name.count > 100 {
            errors.append(.nameTooLong)
        }

        // Check exercises
        if exercises.isEmpty {
            errors.append(.noExercises)
        }

        // Check exercise count
        if exercises.count > 20 {
            errors.append(.tooManyExercises)
        }

        // Validate each exercise
        for exercise in exercises {
            if !exercise.isValid {
                errors.append(.invalidExercise(exercise.id))
            }
        }

        // Check duration
        if estimatedDuration <= 0 {
            errors.append(.invalidDuration)
        }

        return errors
    }

    /// Check if template is valid
    public var isValid: Bool {
        return validate().isEmpty
    }
}

// MARK: - Codable Support

extension WorkoutTemplateModel: Codable {
    enum CodingKeys: String, CodingKey {
        case id, name, exercises, estimatedDuration, difficulty, muscleGroups, equipment, createdAt
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Handle UUID decoding
        if let idString = try? container.decode(String.self, forKey: .id) {
            self.id = UUID(uuidString: idString) ?? UUID()
        } else {
            self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        }

        self.name = try container.decode(String.self, forKey: .name)
        self.exercises = try container.decode([WorkoutExerciseModel].self, forKey: .exercises)
        self.estimatedDuration = try container.decode(TimeInterval.self, forKey: .estimatedDuration)

        // Decode difficulty
        let difficultyString = try container.decode(String.self, forKey: .difficulty)
        self.difficulty = WorkoutDifficulty(rawValue: difficultyString) ?? .intermediate

        // Decode muscle groups
        let muscleGroupStrings = try container.decode([String].self, forKey: .muscleGroups)
        self.muscleGroups = muscleGroupStrings.compactMap { MuscleGroup(rawValue: $0) }

        self.equipment = try container.decode([String].self, forKey: .equipment)

        // Handle date decoding
        if let dateString = try? container.decode(String.self, forKey: .createdAt) {
            let formatter = ISO8601DateFormatter()
            self.createdAt = formatter.date(from: dateString) ?? Date()
        } else {
            self.createdAt = try container.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id.uuidString, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(exercises, forKey: .exercises)
        try container.encode(estimatedDuration, forKey: .estimatedDuration)
        try container.encode(difficulty.rawValue, forKey: .difficulty)
        try container.encode(muscleGroups.map { $0.rawValue }, forKey: .muscleGroups)
        try container.encode(equipment, forKey: .equipment)

        // Encode date as ISO8601 string
        let formatter = ISO8601DateFormatter()
        try container.encode(formatter.string(from: createdAt), forKey: .createdAt)
    }
}

// MARK: - Supporting Types

public enum WorkoutDifficulty: String, CaseIterable, Codable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"

    public var description: String { rawValue }

    public var color: String {
        switch self {
        case .beginner: return "green"
        case .intermediate: return "blue"
        case .advanced: return "red"
        }
    }
}

public enum TemplateValidationError: LocalizedError {
    case emptyName
    case nameTooLong
    case noExercises
    case tooManyExercises
    case invalidExercise(UUID)
    case invalidDuration

    public var errorDescription: String? {
        switch self {
        case .emptyName:
            return "Template name cannot be empty"
        case .nameTooLong:
            return "Template name cannot exceed 100 characters"
        case .noExercises:
            return "Template must contain at least one exercise"
        case .tooManyExercises:
            return "Template cannot have more than 20 exercises"
        case .invalidExercise(let id):
            return "Exercise \(id) has invalid configuration"
        case .invalidDuration:
            return "Template duration must be positive"
        }
    }
}

// MARK: - Sample Data

extension WorkoutTemplateModel {
    /// Sample workout templates for testing and previews
    public static let sampleTemplates: [WorkoutTemplateModel] = [
        WorkoutTemplateModel(
            name: "Upper Body Push",
            exercises: [
                WorkoutExerciseModel(
                    workoutId: UUID(),
                    exerciseId: UUID(),
                    targetSets: 3,
                    targetReps: 10,
                    restSeconds: 120,
                    orderIndex: 1
                ),
                WorkoutExerciseModel(
                    workoutId: UUID(),
                    exerciseId: UUID(),
                    targetSets: 3,
                    targetReps: 12,
                    restSeconds: 90,
                    orderIndex: 2
                ),
                WorkoutExerciseModel(
                    workoutId: UUID(),
                    exerciseId: UUID(),
                    targetSets: 2,
                    targetReps: 15,
                    restSeconds: 60,
                    orderIndex: 3
                )
            ],
            estimatedDuration: 2700, // 45 minutes
            difficulty: .intermediate,
            muscleGroups: [.chest, .shoulders, .triceps],
            equipment: ["Barbell", "Dumbbell"],
            createdAt: Calendar.current.date(byAdding: .day, value: -10, to: Date()) ?? Date()
        ),
        WorkoutTemplateModel(
            name: "Beginner Full Body",
            exercises: [
                WorkoutExerciseModel(
                    workoutId: UUID(),
                    exerciseId: UUID(),
                    targetSets: 2,
                    targetReps: 12,
                    restSeconds: 90,
                    orderIndex: 1
                ),
                WorkoutExerciseModel(
                    workoutId: UUID(),
                    exerciseId: UUID(),
                    targetSets: 2,
                    targetReps: 10,
                    restSeconds: 90,
                    orderIndex: 2
                )
            ],
            estimatedDuration: 1800, // 30 minutes
            difficulty: .beginner,
            muscleGroups: [.chest, .back, .quadriceps],
            equipment: ["Bodyweight", "Dumbbell"],
            createdAt: Calendar.current.date(byAdding: .day, value: -5, to: Date()) ?? Date()
        )
    ]
}