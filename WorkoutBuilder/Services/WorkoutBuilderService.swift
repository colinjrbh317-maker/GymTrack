import Foundation
import Combine

/// Service responsible for building and managing workout routines
/// Provides functionality for creating, editing, and organizing workouts with exercises
public class WorkoutBuilderService: ObservableObject {

    // MARK: - Dependencies

    private let dataService: WorkoutDataService
    private let exerciseLibrary: ExerciseLibrary

    // MARK: - Published Properties

    @Published public private(set) var currentWorkout: WorkoutModel?
    @Published public private(set) var workoutExercises: [WorkoutExerciseModel] = []
    @Published public private(set) var isDirty = false
    @Published public private(set) var isValid = false
    @Published public private(set) var validationErrors: [WorkoutValidationError] = []

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private var nextOrderIndex = 1

    // MARK: - Initialization

    public init(
        dataService: WorkoutDataService,
        exerciseLibrary: ExerciseLibrary
    ) {
        self.dataService = dataService
        self.exerciseLibrary = exerciseLibrary

        setupBindings()
    }

    // MARK: - Workout Management

    /// Start building a new workout
    /// - Parameter name: Workout name (optional, can be set later)
    public func startNewWorkout(name: String = "New Workout") {
        currentWorkout = WorkoutModel(
            name: name,
            createdAt: Date(),
            updatedAt: Date()
        )
        workoutExercises = []
        nextOrderIndex = 1
        isDirty = false
        validateWorkout()
    }

    /// Load existing workout for editing
    /// - Parameter workout: Workout to edit
    public func editWorkout(_ workout: WorkoutModel) async {
        currentWorkout = workout

        // Load associated workout exercises
        do {
            workoutExercises = try await dataService.getWorkoutExercises(for: workout.id)
                .sorted { $0.orderIndex < $1.orderIndex }
            nextOrderIndex = (workoutExercises.map { $0.orderIndex }.max() ?? 0) + 1
            isDirty = false
            validateWorkout()
        } catch {
            print("❌ Failed to load workout exercises: \(error)")
            workoutExercises = []
        }
    }

    /// Update workout name
    /// - Parameter name: New workout name
    public func updateWorkoutName(_ name: String) {
        guard var workout = currentWorkout else { return }
        workout.name = name
        workout.updatedAt = Date()
        currentWorkout = workout
        markDirty()
    }

    /// Update workout notes
    /// - Parameter notes: Workout notes
    public func updateWorkoutNotes(_ notes: String?) {
        guard var workout = currentWorkout else { return }
        workout.notes = notes
        workout.updatedAt = Date()
        currentWorkout = workout
        markDirty()
    }

    /// Save current workout
    /// - Throws: WorkoutDataError if save fails
    public func saveWorkout() async throws {
        guard let workout = currentWorkout else {
            throw WorkoutBuilderError.noActiveWorkout
        }

        guard isValid else {
            throw WorkoutBuilderError.invalidWorkout(validationErrors)
        }

        // Save or update workout
        let savedWorkout: WorkoutModel
        if await dataService.workoutExists(id: workout.id) {
            savedWorkout = try await dataService.updateWorkout(workout)
        } else {
            savedWorkout = try await dataService.createWorkout(workout)
        }

        // Save workout exercises
        for workoutExercise in workoutExercises {
            var updatedExercise = workoutExercise
            updatedExercise.workoutId = savedWorkout.id

            if await dataService.workoutExerciseExists(id: workoutExercise.id) {
                try await dataService.updateWorkoutExercise(updatedExercise)
            } else {
                try await dataService.createWorkoutExercise(updatedExercise)
            }
        }

        currentWorkout = savedWorkout
        isDirty = false
    }

    /// Cancel editing and discard changes
    public func cancelEditing() {
        currentWorkout = nil
        workoutExercises = []
        nextOrderIndex = 1
        isDirty = false
        validationErrors = []
    }

    // MARK: - Exercise Management

    /// Add exercise to current workout
    /// - Parameters:
    ///   - exercise: Exercise to add
    ///   - sets: Target number of sets (default: 3)
    ///   - reps: Target number of reps (default: 10)
    ///   - restSeconds: Rest time in seconds (default: 60)
    public func addExercise(
        _ exercise: ExerciseModel,
        sets: Int = 3,
        reps: Int = 10,
        restSeconds: Int = 60
    ) {
        guard currentWorkout != nil else { return }

        // Check if exercise already exists
        if workoutExercises.contains(where: { $0.exerciseId == exercise.id }) {
            return // Don't add duplicates
        }

        let workoutExercise = WorkoutExerciseModel(
            workoutId: currentWorkout!.id,
            exerciseId: exercise.id,
            targetSets: sets,
            targetReps: reps,
            restSeconds: restSeconds,
            orderIndex: nextOrderIndex
        )

        workoutExercises.append(workoutExercise)
        nextOrderIndex += 1
        markDirty()
    }

    /// Remove exercise from current workout
    /// - Parameter exerciseId: ID of exercise to remove
    public func removeExercise(id: UUID) {
        workoutExercises.removeAll { $0.id == id }
        reorderExercises()
        markDirty()
    }

    /// Update exercise configuration
    /// - Parameters:
    ///   - exerciseId: Exercise ID to update
    ///   - sets: New target sets
    ///   - reps: New target reps
    ///   - restSeconds: New rest time
    public func updateExercise(
        id: UUID,
        sets: Int? = nil,
        reps: Int? = nil,
        restSeconds: Int? = nil
    ) {
        guard let index = workoutExercises.firstIndex(where: { $0.id == id }) else { return }

        var exercise = workoutExercises[index]

        if let sets = sets {
            exercise.targetSets = sets
        }
        if let reps = reps {
            exercise.targetReps = reps
        }
        if let restSeconds = restSeconds {
            exercise.restSeconds = restSeconds
        }

        workoutExercises[index] = exercise
        markDirty()
    }

    /// Reorder exercises in workout
    /// - Parameters:
    ///   - from: Source indices
    ///   - to: Destination index
    public func moveExercise(from source: IndexSet, to destination: Int) {
        workoutExercises.move(fromOffsets: source, toOffset: destination)
        reorderExercises()
        markDirty()
    }

    /// Get exercise model for workout exercise
    /// - Parameter workoutExercise: Workout exercise
    /// - Returns: Exercise model if found
    public func getExercise(for workoutExercise: WorkoutExerciseModel) -> ExerciseModel? {
        return exerciseLibrary.getExercise(by: workoutExercise.exerciseId)
    }

    // MARK: - Workout Analysis

    /// Get estimated workout duration
    /// - Returns: Estimated duration in seconds
    public func getEstimatedDuration() -> TimeInterval {
        let exerciseTime = workoutExercises.reduce(0.0) { total, exercise in
            // Estimate 30 seconds per set + rest time between sets
            let setTime = 30.0 * Double(exercise.targetSets)
            let restTime = Double(exercise.restSeconds) * Double(exercise.targetSets - 1)
            return total + setTime + restTime
        }

        // Add 2 minutes transition between exercises
        let transitionTime = Double(max(0, workoutExercises.count - 1)) * 120.0

        return exerciseTime + transitionTime
    }

    /// Get targeted muscle groups
    /// - Returns: Set of muscle groups targeted by workout
    public func getTargetedMuscleGroups() -> Set<MuscleGroup> {
        var muscleGroups = Set<MuscleGroup>()

        for workoutExercise in workoutExercises {
            if let exercise = getExercise(for: workoutExercise) {
                muscleGroups.formUnion(exercise.allMuscleGroups)
            }
        }

        return muscleGroups
    }

    /// Get workout difficulty estimate
    /// - Returns: Difficulty level based on volume and complexity
    public func getDifficultyLevel() -> WorkoutDifficulty {
        let totalSets = workoutExercises.reduce(0) { $0 + $1.targetSets }
        let exerciseCount = workoutExercises.count

        if totalSets <= 10 && exerciseCount <= 4 {
            return .beginner
        } else if totalSets <= 20 && exerciseCount <= 7 {
            return .intermediate
        } else {
            return .advanced
        }
    }

    /// Get equipment needed for workout
    /// - Returns: Set of equipment types required
    public func getRequiredEquipment() -> Set<String> {
        var equipment = Set<String>()

        for workoutExercise in workoutExercises {
            if let exercise = getExercise(for: workoutExercise) {
                equipment.insert(exercise.equipment)
            }
        }

        return equipment
    }

    // MARK: - Template Management

    /// Save current workout as template
    /// - Parameter name: Template name
    /// - Returns: Saved template
    /// - Throws: WorkoutDataError if save fails
    public func saveAsTemplate(name: String) async throws -> WorkoutTemplateModel {
        guard let workout = currentWorkout, isValid else {
            throw WorkoutBuilderError.invalidWorkout(validationErrors)
        }

        let template = WorkoutTemplateModel(
            name: name,
            exercises: workoutExercises,
            estimatedDuration: getEstimatedDuration(),
            difficulty: getDifficultyLevel(),
            muscleGroups: Array(getTargetedMuscleGroups()),
            equipment: Array(getRequiredEquipment()),
            createdAt: Date()
        )

        return try await dataService.createWorkoutTemplate(template)
    }

    /// Load workout from template
    /// - Parameter template: Template to load
    public func loadFromTemplate(_ template: WorkoutTemplateModel) {
        startNewWorkout(name: template.name)
        workoutExercises = template.exercises.map { exercise in
            var newExercise = exercise
            newExercise.id = UUID() // Generate new IDs
            newExercise.workoutId = currentWorkout!.id
            return newExercise
        }
        reorderExercises()
        markDirty()
    }

    // MARK: - Workout Duplication

    /// Duplicate an existing workout
    /// - Parameters:
    ///   - workout: Workout to duplicate
    ///   - newName: Name for the duplicated workout
    /// - Returns: Duplicated workout
    /// - Throws: WorkoutDataError if duplication fails
    public func duplicateWorkout(_ workout: WorkoutModel, newName: String) async throws -> WorkoutModel {
        // Create new workout with same properties but new ID and name
        var duplicatedWorkout = workout
        duplicatedWorkout.id = UUID()
        duplicatedWorkout.name = newName
        duplicatedWorkout.createdAt = Date()
        duplicatedWorkout.updatedAt = Date()

        // Save the duplicated workout
        let savedWorkout = try await dataService.createWorkout(duplicatedWorkout)

        // Load and duplicate exercises
        let originalExercises = try await dataService.getWorkoutExercises(for: workout.id)

        for originalExercise in originalExercises {
            var duplicatedExercise = originalExercise
            duplicatedExercise.id = UUID()
            duplicatedExercise.workoutId = savedWorkout.id
            try await dataService.createWorkoutExercise(duplicatedExercise)
        }

        return savedWorkout
    }

    /// Clone a workout for editing (starts editing session with workout copy)
    /// - Parameters:
    ///   - workout: Workout to clone
    ///   - newName: Name for the cloned workout
    public func cloneWorkoutForEditing(_ workout: WorkoutModel, newName: String) {
        // Create new workout for editing
        var clonedWorkout = workout
        clonedWorkout.id = UUID()
        clonedWorkout.name = newName
        clonedWorkout.createdAt = Date()
        clonedWorkout.updatedAt = Date()

        currentWorkout = clonedWorkout

        // Load and clone exercises asynchronously
        Task {
            do {
                let originalExercises = try await dataService.getWorkoutExercises(for: workout.id)

                await MainActor.run {
                    workoutExercises = originalExercises.map { exercise in
                        var clonedExercise = exercise
                        clonedExercise.id = UUID()
                        clonedExercise.workoutId = clonedWorkout.id
                        return clonedExercise
                    }.sorted { $0.orderIndex < $1.orderIndex }

                    nextOrderIndex = (workoutExercises.map { $0.orderIndex }.max() ?? 0) + 1
                    isDirty = true
                    validateWorkout()
                }
            } catch {
                print("❌ Failed to clone workout exercises: \(error)")
                await MainActor.run {
                    workoutExercises = []
                    isDirty = true
                    validateWorkout()
                }
            }
        }
    }

    // MARK: - Private Methods

    private func setupBindings() {
        // Validate workout whenever exercises change
        $workoutExercises
            .sink { [weak self] _ in
                self?.validateWorkout()
            }
            .store(in: &cancellables)
    }

    private func markDirty() {
        isDirty = true
        validateWorkout()
    }

    private func reorderExercises() {
        for (index, _) in workoutExercises.enumerated() {
            workoutExercises[index].orderIndex = index + 1
        }
        nextOrderIndex = workoutExercises.count + 1
    }

    private func validateWorkout() {
        validationErrors = []

        // Check workout name
        if let workout = currentWorkout, workout.name.trimmingCharacters(in: .whitespaces).isEmpty {
            validationErrors.append(.emptyWorkoutName)
        }

        // Check exercises
        if workoutExercises.isEmpty {
            validationErrors.append(.noExercises)
        }

        // Validate each exercise
        for workoutExercise in workoutExercises {
            if workoutExercise.targetSets < 1 {
                validationErrors.append(.invalidSets(workoutExercise.id))
            }
            if workoutExercise.targetReps < 1 {
                validationErrors.append(.invalidReps(workoutExercise.id))
            }
            if workoutExercise.restSeconds < 0 {
                validationErrors.append(.invalidRest(workoutExercise.id))
            }
        }

        isValid = validationErrors.isEmpty
    }
}

// MARK: - Supporting Types

public enum WorkoutDifficulty: String, CaseIterable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"

    public var description: String { rawValue }
}

public enum WorkoutBuilderError: LocalizedError {
    case noActiveWorkout
    case invalidWorkout([WorkoutValidationError])

    public var errorDescription: String? {
        switch self {
        case .noActiveWorkout:
            return "No active workout to save"
        case .invalidWorkout(let errors):
            return "Workout validation failed: \(errors.map { $0.localizedDescription }.joined(separator: ", "))"
        }
    }
}

public enum WorkoutValidationError: LocalizedError {
    case emptyWorkoutName
    case noExercises
    case invalidSets(UUID)
    case invalidReps(UUID)
    case invalidRest(UUID)

    public var errorDescription: String? {
        switch self {
        case .emptyWorkoutName:
            return "Workout name cannot be empty"
        case .noExercises:
            return "Workout must contain at least one exercise"
        case .invalidSets(let id):
            return "Exercise \(id) must have at least 1 set"
        case .invalidReps(let id):
            return "Exercise \(id) must have at least 1 rep"
        case .invalidRest(let id):
            return "Exercise \(id) rest time cannot be negative"
        }
    }
}

// MARK: - Workout Statistics

extension WorkoutBuilderService {
    /// Get workout statistics for current workout
    /// - Returns: Workout statistics
    public func getWorkoutStatistics() -> WorkoutStatistics {
        let totalSets = workoutExercises.reduce(0) { $0 + $1.targetSets }
        let totalReps = workoutExercises.reduce(0) { $0 + ($1.targetSets * $1.targetReps) }
        let avgRestTime = workoutExercises.isEmpty ? 0 :
            workoutExercises.reduce(0) { $0 + $1.restSeconds } / workoutExercises.count

        return WorkoutStatistics(
            exerciseCount: workoutExercises.count,
            totalSets: totalSets,
            totalReps: totalReps,
            averageRestTime: avgRestTime,
            estimatedDuration: getEstimatedDuration(),
            muscleGroups: Array(getTargetedMuscleGroups()),
            equipment: Array(getRequiredEquipment()),
            difficulty: getDifficultyLevel()
        )
    }
}

public struct WorkoutStatistics {
    public let exerciseCount: Int
    public let totalSets: Int
    public let totalReps: Int
    public let averageRestTime: Int
    public let estimatedDuration: TimeInterval
    public let muscleGroups: [MuscleGroup]
    public let equipment: [String]
    public let difficulty: WorkoutDifficulty

    public var formattedDuration: String {
        let minutes = Int(estimatedDuration) / 60
        return "\(minutes) minutes"
    }
}