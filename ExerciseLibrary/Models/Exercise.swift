import Foundation

// MARK: - Exercise Business Model

/// Business model wrapper for Exercise Core Data entity
/// Provides clean interface for ExerciseLibrary functionality
public struct ExerciseModel: Identifiable, Hashable {
    public let id: UUID
    public let name: String
    public let instructions: String
    public let imageName: String?
    public let equipment: String
    public let primaryMuscleGroups: [MuscleGroup]
    public let secondaryMuscleGroups: [MuscleGroup]
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        instructions: String,
        imageName: String? = nil,
        equipment: String,
        primaryMuscleGroups: [MuscleGroup],
        secondaryMuscleGroups: [MuscleGroup] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.instructions = instructions
        self.imageName = imageName
        self.equipment = equipment
        self.primaryMuscleGroups = primaryMuscleGroups
        self.secondaryMuscleGroups = secondaryMuscleGroups
        self.createdAt = createdAt
    }
}

// MARK: - Core Data Conversion Extensions

extension ExerciseModel {
    /// Initialize from Core Data Exercise entity
    public init(from entity: Exercise) {
        self.id = entity.id ?? UUID()
        self.name = entity.name ?? ""
        self.instructions = entity.instructions ?? ""
        self.imageName = entity.imageName
        self.equipment = entity.equipment ?? ""

        // Convert string arrays to MuscleGroup enums
        self.primaryMuscleGroups = (entity.primaryMuscleGroups ?? [])
            .compactMap { MuscleGroup(rawValue: $0) }
        self.secondaryMuscleGroups = (entity.secondaryMuscleGroups ?? [])
            .compactMap { MuscleGroup(rawValue: $0) }

        self.createdAt = entity.createdAt ?? Date()
    }

    /// Update Core Data Exercise entity from business model
    public func update(_ entity: Exercise) {
        entity.id = self.id
        entity.name = self.name
        entity.instructions = self.instructions
        entity.imageName = self.imageName
        entity.equipment = self.equipment
        entity.primaryMuscleGroups = self.primaryMuscleGroups.map { $0.rawValue }
        entity.secondaryMuscleGroups = self.secondaryMuscleGroups.map { $0.rawValue }
        entity.createdAt = self.createdAt
    }
}

// MARK: - Computed Properties

extension ExerciseModel {
    /// All muscle groups (primary + secondary) for filtering
    public var allMuscleGroups: [MuscleGroup] {
        return primaryMuscleGroups + secondaryMuscleGroups
    }

    /// Primary muscle group for display (first in array)
    public var primaryMuscleGroup: MuscleGroup? {
        return primaryMuscleGroups.first
    }

    /// Display name with equipment context
    public var displayName: String {
        if equipment.lowercased() == "bodyweight" {
            return name
        } else {
            return "\(name) (\(equipment))"
        }
    }

    /// Icon name for UI display
    public var iconName: String {
        return primaryMuscleGroup?.iconName ?? "dumbbell"
    }

    /// Short instructions for preview (first sentence)
    public var shortInstructions: String {
        let sentences = instructions.components(separatedBy: ". ")
        return sentences.first ?? instructions
    }
}

// MARK: - Search and Filter Support

extension ExerciseModel {
    /// Check if exercise matches search query
    public func matches(searchQuery: String) -> Bool {
        let query = searchQuery.lowercased().trimmingCharacters(in: .whitespaces)

        guard !query.isEmpty else { return true }

        // Search in name
        if name.lowercased().contains(query) {
            return true
        }

        // Search in equipment
        if equipment.lowercased().contains(query) {
            return true
        }

        // Search in muscle groups
        let muscleGroupNames = allMuscleGroups.map { $0.rawValue.lowercased() }
        if muscleGroupNames.contains(where: { $0.contains(query) }) {
            return true
        }

        // Search in instructions (for advanced search)
        if instructions.lowercased().contains(query) {
            return true
        }

        return false
    }

    /// Check if exercise targets specific muscle group
    public func targets(muscleGroup: MuscleGroup) -> Bool {
        return allMuscleGroups.contains(muscleGroup)
    }

    /// Check if exercise uses specific equipment
    public func uses(equipment: String) -> Bool {
        return self.equipment.lowercased() == equipment.lowercased()
    }
}

// MARK: - Codable Support for JSON Data

extension ExerciseModel: Codable {
    enum CodingKeys: String, CodingKey {
        case id, name, instructions, imageName, equipment, createdAt
        case primaryMuscleGroups = "primary_muscle_groups"
        case secondaryMuscleGroups = "secondary_muscle_groups"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Handle both UUID string and UUID types
        if let uuidString = try? container.decode(String.self, forKey: .id) {
            self.id = UUID(uuidString: uuidString) ?? UUID()
        } else {
            self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        }

        self.name = try container.decode(String.self, forKey: .name)
        self.instructions = try container.decode(String.self, forKey: .instructions)
        self.imageName = try container.decodeIfPresent(String.self, forKey: .imageName)
        self.equipment = try container.decode(String.self, forKey: .equipment)

        // Decode muscle groups from strings
        let primaryStrings = try container.decode([String].self, forKey: .primaryMuscleGroups)
        self.primaryMuscleGroups = primaryStrings.compactMap { MuscleGroup(rawValue: $0) }

        let secondaryStrings = try container.decodeIfPresent([String].self, forKey: .secondaryMuscleGroups) ?? []
        self.secondaryMuscleGroups = secondaryStrings.compactMap { MuscleGroup(rawValue: $0) }

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
        try container.encode(instructions, forKey: .instructions)
        try container.encodeIfPresent(imageName, forKey: .imageName)
        try container.encode(equipment, forKey: .equipment)

        // Encode muscle groups as strings
        try container.encode(primaryMuscleGroups.map { $0.rawValue }, forKey: .primaryMuscleGroups)
        try container.encode(secondaryMuscleGroups.map { $0.rawValue }, forKey: .secondaryMuscleGroups)

        // Encode date as ISO8601 string
        let formatter = ISO8601DateFormatter()
        try container.encode(formatter.string(from: createdAt), forKey: .createdAt)
    }
}

// MARK: - Sample Data

extension ExerciseModel {
    /// Sample exercises for testing and previews
    public static let sampleExercises: [ExerciseModel] = [
        ExerciseModel(
            name: "Bench Press",
            instructions: "Lie on bench, grip bar slightly wider than shoulders. Lower to chest, press up explosively.",
            imageName: "bench_press",
            equipment: "Barbell",
            primaryMuscleGroups: [.chest],
            secondaryMuscleGroups: [.triceps, .shoulders]
        ),
        ExerciseModel(
            name: "Squat",
            instructions: "Stand with feet shoulder-width apart. Lower down as if sitting back into chair. Drive through heels to stand.",
            imageName: "squat",
            equipment: "Barbell",
            primaryMuscleGroups: [.quadriceps],
            secondaryMuscleGroups: [.glutes, .hamstrings]
        ),
        ExerciseModel(
            name: "Pull-up",
            instructions: "Hang from bar with arms fully extended. Pull body up until chin clears bar.",
            imageName: "pullup",
            equipment: "Bodyweight",
            primaryMuscleGroups: [.lats],
            secondaryMuscleGroups: [.biceps, .back]
        ),
        ExerciseModel(
            name: "Push-up",
            instructions: "Start in plank position. Lower chest to floor, push back up to starting position.",
            imageName: "pushup",
            equipment: "Bodyweight",
            primaryMuscleGroups: [.chest],
            secondaryMuscleGroups: [.triceps, .shoulders]
        ),
        ExerciseModel(
            name: "Deadlift",
            instructions: "Stand with feet hip-width apart, bar over mid-foot. Hinge at hips and knees, grip bar, stand up tall.",
            imageName: "deadlift",
            equipment: "Barbell",
            primaryMuscleGroups: [.hamstrings],
            secondaryMuscleGroups: [.glutes, .back, .traps]
        )
    ]
}