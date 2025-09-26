import Foundation

// MARK: - WorkoutExercise Business Model

/// Business model wrapper for WorkoutExercise Core Data entity
/// Represents an exercise within a specific workout with configuration
public struct WorkoutExerciseModel: Identifiable, Hashable {
    public let id: UUID
    public var workoutId: UUID
    public let exerciseId: UUID
    public var targetSets: Int
    public var targetReps: Int
    public var restSeconds: Int
    public var orderIndex: Int
    public var notes: String?

    // Warm-up configuration
    public var enableWarmups: Bool
    public var warmupCount: Int
    public var workingWeight: Double
    public var weightUnit: WarmupCalculator.WeightUnit
    public var useFineIncrements: Bool
    public var estimatedOneRM: Double?

    // Exercise notes
    public var privateNotes: String?

    public init(
        id: UUID = UUID(),
        workoutId: UUID,
        exerciseId: UUID,
        targetSets: Int,
        targetReps: Int,
        restSeconds: Int,
        orderIndex: Int,
        notes: String? = nil,
        enableWarmups: Bool = false,
        warmupCount: Int = 3,
        workingWeight: Double = 0,
        weightUnit: WarmupCalculator.WeightUnit = .pounds,
        useFineIncrements: Bool = false,
        estimatedOneRM: Double? = nil,
        privateNotes: String? = nil
    ) {
        self.id = id
        self.workoutId = workoutId
        self.exerciseId = exerciseId
        self.targetSets = targetSets
        self.targetReps = targetReps
        self.restSeconds = restSeconds
        self.orderIndex = orderIndex
        self.notes = notes
        self.enableWarmups = enableWarmups
        self.warmupCount = warmupCount
        self.workingWeight = workingWeight
        self.weightUnit = weightUnit
        self.useFineIncrements = useFineIncrements
        self.estimatedOneRM = estimatedOneRM
        self.privateNotes = privateNotes
    }
}

// MARK: - Core Data Conversion Extensions

extension WorkoutExerciseModel {
    /// Initialize from Core Data WorkoutExercise entity
    public init(from entity: WorkoutExercise) {
        self.id = entity.id ?? UUID()
        self.workoutId = entity.workout?.id ?? UUID()
        self.exerciseId = entity.exercise?.id ?? UUID()
        self.targetSets = Int(entity.targetSets)
        self.targetReps = Int(entity.targetReps)
        self.restSeconds = Int(entity.restSeconds)
        self.orderIndex = Int(entity.orderIndex)
        self.notes = entity.notes

        // Warm-up configuration
        self.enableWarmups = entity.enableWarmups
        self.warmupCount = Int(entity.warmupCount)
        self.workingWeight = entity.workingWeight
        self.weightUnit = WarmupCalculator.WeightUnit(rawValue: entity.weightUnit ?? "lbs") ?? .pounds
        self.useFineIncrements = entity.useFineIncrements
        self.estimatedOneRM = entity.estimatedOneRM > 0 ? entity.estimatedOneRM : nil

        // Exercise notes
        self.privateNotes = entity.privateNotes
    }

    /// Update Core Data WorkoutExercise entity from business model
    public func update(_ entity: WorkoutExercise) {
        entity.id = self.id
        entity.targetSets = Int16(self.targetSets)
        entity.targetReps = Int16(self.targetReps)
        entity.restSeconds = Int32(self.restSeconds)
        entity.orderIndex = Int16(self.orderIndex)
        entity.notes = self.notes

        // Warm-up configuration
        entity.enableWarmups = self.enableWarmups
        entity.warmupCount = Int16(self.warmupCount)
        entity.workingWeight = self.workingWeight
        entity.weightUnit = self.weightUnit.rawValue
        entity.useFineIncrements = self.useFineIncrements
        entity.estimatedOneRM = self.estimatedOneRM ?? 0

        // Exercise notes
        entity.privateNotes = self.privateNotes
        // Note: workout and exercise relationships are set by the data service
    }
}

// MARK: - Computed Properties

extension WorkoutExerciseModel {
    /// Formatted rest time for display
    public var formattedRestTime: String {
        if restSeconds < 60 {
            return "\(restSeconds)s"
        } else {
            let minutes = restSeconds / 60
            let seconds = restSeconds % 60
            if seconds == 0 {
                return "\(minutes)m"
            } else {
                return "\(minutes)m \(seconds)s"
            }
        }
    }

    /// Short rest time description
    public var restTimeDescription: String {
        switch restSeconds {
        case 0..<30:
            return "Very Short Rest"
        case 30..<60:
            return "Short Rest"
        case 60..<120:
            return "Moderate Rest"
        case 120..<180:
            return "Long Rest"
        default:
            return "Extended Rest"
        }
    }

    /// Sets and reps formatted for display
    public var setsRepsDisplay: String {
        return "\(targetSets) × \(targetReps)"
    }

    /// Volume calculation (sets × reps)
    public var volume: Int {
        return targetSets * targetReps
    }

    /// Estimated time for this exercise (including rest)
    public var estimatedTime: TimeInterval {
        // Estimate 30 seconds per set + rest time between sets (not after last set)
        let setTime = 30.0 * Double(targetSets)
        let restTime = Double(restSeconds) * Double(max(0, targetSets - 1))
        return setTime + restTime
    }

    /// Formatted estimated time
    public var formattedEstimatedTime: String {
        let minutes = Int(estimatedTime) / 60
        let seconds = Int(estimatedTime) % 60

        if minutes > 0 {
            return seconds > 0 ? "\(minutes)m \(seconds)s" : "\(minutes)m"
        } else {
            return "\(seconds)s"
        }
    }

    /// Intensity level based on sets and reps
    public var intensityLevel: ExerciseIntensity {
        switch (targetSets, targetReps) {
        case (1...2, 1...5):
            return .veryHigh // Low reps, heavy weight
        case (3...4, 1...6):
            return .high // Strength range
        case (3...4, 6...12):
            return .moderate // Hypertrophy range
        case (_, 12...):
            return .low // Endurance range
        default:
            return .moderate
        }
    }

    /// Exercise difficulty based on volume and intensity
    public var difficulty: ExerciseDifficulty {
        let totalVolume = volume

        switch intensityLevel {
        case .veryHigh:
            return totalVolume > 20 ? .expert : .advanced
        case .high:
            return totalVolume > 40 ? .advanced : .intermediate
        case .moderate:
            return totalVolume > 60 ? .intermediate : .beginner
        case .low:
            return totalVolume > 80 ? .intermediate : .beginner
        }
    }

    /// Check if configuration is suitable for beginners
    public var isBeginnerFriendly: Bool {
        return difficulty == .beginner && restSeconds >= 60
    }

    // MARK: - Warm-up Support

    /// Get warm-up settings for this exercise
    public var warmupSettings: WarmupCalculator.WarmupSettings {
        return WarmupCalculator.WarmupSettings(
            numberOfWarmups: warmupCount,
            weightUnit: weightUnit,
            useFineIncrements: useFineIncrements,
            estimatedOneRM: estimatedOneRM
        )
    }

    /// Generate warm-up sets for current working weight
    public func generateWarmupSets() -> [WarmupCalculator.WarmupSet] {
        guard enableWarmups && workingWeight > 0 else { return [] }

        return WarmupCalculator.generateWarmupSets(
            workingWeight: workingWeight,
            settings: warmupSettings
        )
    }

    /// Formatted working weight for display
    public var formattedWorkingWeight: String {
        guard workingWeight > 0 else { return "—" }
        return String(format: "%.1f %@", workingWeight, weightUnit.rawValue)
    }

    /// Check if exercise has any notes
    public var hasNotes: Bool {
        return !(notes?.isEmpty ?? true) || !(privateNotes?.isEmpty ?? true)
    }

    /// Combined notes for display (public notes only)
    public var displayNotes: String? {
        return notes?.isEmpty == false ? notes : nil
    }
}

// MARK: - Validation

extension WorkoutExerciseModel {
    /// Validate workout exercise configuration
    /// - Returns: Array of validation errors (empty if valid)
    public func validate() -> [WorkoutExerciseValidationError] {
        var errors: [WorkoutExerciseValidationError] = []

        // Check sets
        if targetSets < 1 {
            errors.append(.invalidSets)
        } else if targetSets > 10 {
            errors.append(.tooManySets)
        }

        // Check reps
        if targetReps < 1 {
            errors.append(.invalidReps)
        } else if targetReps > 100 {
            errors.append(.tooManyReps)
        }

        // Check rest time
        if restSeconds < 0 {
            errors.append(.invalidRestTime)
        } else if restSeconds > 600 { // 10 minutes
            errors.append(.restTimeTooLong)
        }

        // Check order index
        if orderIndex < 1 {
            errors.append(.invalidOrder)
        }

        // Check notes length
        if let notes = notes, notes.count > 200 {
            errors.append(.notesTooLong)
        }

        return errors
    }

    /// Check if workout exercise is valid
    public var isValid: Bool {
        return validate().isEmpty
    }
}

// MARK: - Codable Support for Templates

extension WorkoutExerciseModel: Codable {
    enum CodingKeys: String, CodingKey {
        case id, workoutId, exerciseId, targetSets, targetReps, restSeconds, orderIndex, notes
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // Handle UUID decoding
        if let idString = try? container.decode(String.self, forKey: .id) {
            self.id = UUID(uuidString: idString) ?? UUID()
        } else {
            self.id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        }

        if let workoutIdString = try? container.decode(String.self, forKey: .workoutId) {
            self.workoutId = UUID(uuidString: workoutIdString) ?? UUID()
        } else {
            self.workoutId = try container.decode(UUID.self, forKey: .workoutId)
        }

        if let exerciseIdString = try? container.decode(String.self, forKey: .exerciseId) {
            self.exerciseId = UUID(uuidString: exerciseIdString) ?? UUID()
        } else {
            self.exerciseId = try container.decode(UUID.self, forKey: .exerciseId)
        }

        self.targetSets = try container.decode(Int.self, forKey: .targetSets)
        self.targetReps = try container.decode(Int.self, forKey: .targetReps)
        self.restSeconds = try container.decode(Int.self, forKey: .restSeconds)
        self.orderIndex = try container.decode(Int.self, forKey: .orderIndex)
        self.notes = try container.decodeIfPresent(String.self, forKey: .notes)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(id.uuidString, forKey: .id)
        try container.encode(workoutId.uuidString, forKey: .workoutId)
        try container.encode(exerciseId.uuidString, forKey: .exerciseId)
        try container.encode(targetSets, forKey: .targetSets)
        try container.encode(targetReps, forKey: .targetReps)
        try container.encode(restSeconds, forKey: .restSeconds)
        try container.encode(orderIndex, forKey: .orderIndex)
        try container.encodeIfPresent(notes, forKey: .notes)
    }
}

// MARK: - Supporting Types

public enum ExerciseIntensity: String, CaseIterable {
    case low = "Low"
    case moderate = "Moderate"
    case high = "High"
    case veryHigh = "Very High"

    public var description: String { rawValue }

    public var color: String {
        switch self {
        case .low: return "green"
        case .moderate: return "blue"
        case .high: return "orange"
        case .veryHigh: return "red"
        }
    }
}

public enum ExerciseDifficulty: String, CaseIterable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"
    case expert = "Expert"

    public var description: String { rawValue }
}

public enum WorkoutExerciseValidationError: LocalizedError {
    case invalidSets
    case tooManySets
    case invalidReps
    case tooManyReps
    case invalidRestTime
    case restTimeTooLong
    case invalidOrder
    case notesTooLong

    public var errorDescription: String? {
        switch self {
        case .invalidSets:
            return "Must have at least 1 set"
        case .tooManySets:
            return "Cannot have more than 10 sets"
        case .invalidReps:
            return "Must have at least 1 rep"
        case .tooManyReps:
            return "Cannot have more than 100 reps"
        case .invalidRestTime:
            return "Rest time cannot be negative"
        case .restTimeTooLong:
            return "Rest time cannot exceed 10 minutes"
        case .invalidOrder:
            return "Order index must be at least 1"
        case .notesTooLong:
            return "Notes cannot exceed 200 characters"
        }
    }
}

// MARK: - Sample Data

extension WorkoutExerciseModel {
    /// Sample workout exercises for testing and previews
    public static let sampleWorkoutExercises: [WorkoutExerciseModel] = [
        WorkoutExerciseModel(
            workoutId: UUID(),
            exerciseId: UUID(),
            targetSets: 3,
            targetReps: 10,
            restSeconds: 120,
            orderIndex: 1,
            notes: "Focus on form over weight"
        ),
        WorkoutExerciseModel(
            workoutId: UUID(),
            exerciseId: UUID(),
            targetSets: 4,
            targetReps: 8,
            restSeconds: 180,
            orderIndex: 2,
            notes: "Progressive overload - increase weight from last week"
        ),
        WorkoutExerciseModel(
            workoutId: UUID(),
            exerciseId: UUID(),
            targetSets: 2,
            targetReps: 15,
            restSeconds: 60,
            orderIndex: 3
        )
    ]
}