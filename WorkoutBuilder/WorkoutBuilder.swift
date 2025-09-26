import Foundation
import SwiftUI
import Combine

// MARK: - WorkoutBuilder Public API

/// Main entry point for the WorkoutBuilder module
/// Provides unified interface for workout creation, management, and templates
@MainActor
public final class WorkoutBuilder: ObservableObject {

    // MARK: - Public Services

    /// Service for workout building operations
    public let builderService: WorkoutBuilderService

    /// Service for workout data persistence
    public let dataService: WorkoutDataService

    /// Exercise library for workout building
    public let exerciseLibrary: ExerciseLibrary

    // MARK: - Published State

    /// Current workout being built/edited
    @Published public var currentWorkout: WorkoutModel? {
        get { builderService.currentWorkout }
        set { /* Read-only from outside - use methods to modify */ }
    }

    /// Exercises in current workout
    @Published public var workoutExercises: [WorkoutExerciseModel] {
        get { builderService.workoutExercises }
        set { /* Read-only from outside - use methods to modify */ }
    }

    /// All saved workouts
    @Published public var savedWorkouts: [WorkoutModel] {
        get { dataService.workouts }
        set { /* Read-only from outside */ }
    }

    /// Available workout templates
    @Published public var templates: [WorkoutTemplateModel] {
        get { dataService.templates }
        set { /* Read-only from outside */ }
    }

    /// Builder state flags
    @Published public var isDirty: Bool {
        get { builderService.isDirty }
        set { /* Read-only from outside */ }
    }

    @Published public var isValid: Bool {
        get { builderService.isValid }
        set { /* Read-only from outside */ }
    }

    @Published public var isLoading: Bool = false

    @Published public var error: Error?

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    /// Initialize WorkoutBuilder with optional persistence controller
    /// - Parameter persistenceController: Core Data controller (defaults to shared)
    public init(persistenceController: PersistenceController = .shared) {
        self.exerciseLibrary = ExerciseLibrary(persistenceController: persistenceController)
        self.dataService = WorkoutDataService(persistenceController: persistenceController)
        self.builderService = WorkoutBuilderService(
            dataService: dataService,
            exerciseLibrary: exerciseLibrary
        )

        setupBindings()

        // Load initial data
        Task {
            await loadData()
        }
    }

    /// Initialize WorkoutBuilder with custom services (for testing)
    public init(
        dataService: WorkoutDataService,
        exerciseLibrary: ExerciseLibrary
    ) {
        self.dataService = dataService
        self.exerciseLibrary = exerciseLibrary
        self.builderService = WorkoutBuilderService(
            dataService: dataService,
            exerciseLibrary: exerciseLibrary
        )

        setupBindings()
    }

    // MARK: - Workout Building Interface

    /// Start building a new workout
    /// - Parameter name: Initial workout name
    public func startNewWorkout(name: String = "New Workout") {
        builderService.startNewWorkout(name: name)
    }

    /// Load existing workout for editing
    /// - Parameter workout: Workout to edit
    public func editWorkout(_ workout: WorkoutModel) async {
        await builderService.editWorkout(workout)
    }

    /// Update workout name
    /// - Parameter name: New workout name
    public func updateWorkoutName(_ name: String) {
        builderService.updateWorkoutName(name)
    }

    /// Update workout notes
    /// - Parameter notes: Workout notes
    public func updateWorkoutNotes(_ notes: String?) {
        builderService.updateWorkoutNotes(notes)
    }

    /// Save current workout
    /// - Throws: Error if save fails
    public func saveWorkout() async throws {
        isLoading = true
        defer { isLoading = false }

        do {
            try await builderService.saveWorkout()
            await refreshWorkouts()
        } catch {
            self.error = error
            throw error
        }
    }

    /// Cancel editing and discard changes
    public func cancelEditing() {
        builderService.cancelEditing()
    }

    // MARK: - Exercise Management

    /// Add exercise to current workout
    /// - Parameters:
    ///   - exercise: Exercise to add
    ///   - sets: Target sets (default: 3)
    ///   - reps: Target reps (default: 10)
    ///   - restSeconds: Rest time (default: 60)
    public func addExercise(
        _ exercise: ExerciseModel,
        sets: Int = 3,
        reps: Int = 10,
        restSeconds: Int = 60
    ) {
        builderService.addExercise(exercise, sets: sets, reps: reps, restSeconds: restSeconds)
    }

    /// Remove exercise from current workout
    /// - Parameter exerciseId: Exercise ID to remove
    public func removeExercise(id: UUID) {
        builderService.removeExercise(id: id)
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
        builderService.updateExercise(id: id, sets: sets, reps: reps, restSeconds: restSeconds)
    }

    /// Reorder exercises in workout
    /// - Parameters:
    ///   - from: Source indices
    ///   - to: Destination index
    public func moveExercise(from source: IndexSet, to destination: Int) {
        builderService.moveExercise(from: source, to: destination)
    }

    /// Get exercise model for workout exercise
    /// - Parameter workoutExercise: Workout exercise
    /// - Returns: Exercise model if found
    public func getExercise(for workoutExercise: WorkoutExerciseModel) -> ExerciseModel? {
        return builderService.getExercise(for: workoutExercise)
    }

    // MARK: - Workout Analysis

    /// Get estimated workout duration
    /// - Returns: Estimated duration in seconds
    public func getEstimatedDuration() -> TimeInterval {
        return builderService.getEstimatedDuration()
    }

    /// Get targeted muscle groups
    /// - Returns: Set of muscle groups targeted by current workout
    public func getTargetedMuscleGroups() -> Set<MuscleGroup> {
        return builderService.getTargetedMuscleGroups()
    }

    /// Get workout difficulty estimate
    /// - Returns: Difficulty level
    public func getDifficultyLevel() -> WorkoutDifficulty {
        return builderService.getDifficultyLevel()
    }

    /// Get equipment needed for workout
    /// - Returns: Set of equipment types required
    public func getRequiredEquipment() -> Set<String> {
        return builderService.getRequiredEquipment()
    }

    /// Get workout statistics
    /// - Returns: Comprehensive workout statistics
    public func getWorkoutStatistics() -> WorkoutStatistics {
        return builderService.getWorkoutStatistics()
    }

    // MARK: - Template Management

    /// Save current workout as template
    /// - Parameter name: Template name
    /// - Returns: Saved template
    /// - Throws: Error if save fails
    public func saveAsTemplate(name: String) async throws -> WorkoutTemplateModel {
        isLoading = true
        defer { isLoading = false }

        do {
            let template = try await builderService.saveAsTemplate(name: name)
            await refreshTemplates()
            return template
        } catch {
            self.error = error
            throw error
        }
    }

    /// Load workout from template
    /// - Parameter template: Template to load
    public func loadFromTemplate(_ template: WorkoutTemplateModel) {
        builderService.loadFromTemplate(template)
    }

    /// Duplicate an existing workout
    /// - Parameters:
    ///   - workout: Workout to duplicate
    ///   - newName: Name for the duplicated workout
    /// - Returns: Duplicated workout
    /// - Throws: Error if duplication fails
    public func duplicateWorkout(_ workout: WorkoutModel, newName: String) async throws -> WorkoutModel {
        isLoading = true
        defer { isLoading = false }

        do {
            let duplicatedWorkout = try await builderService.duplicateWorkout(workout, newName: newName)
            await refreshWorkouts()
            return duplicatedWorkout
        } catch {
            self.error = error
            throw error
        }
    }

    /// Clone a workout for editing (starts editing session with workout copy)
    /// - Parameters:
    ///   - workout: Workout to clone
    ///   - newName: Name for the cloned workout
    public func cloneWorkoutForEditing(_ workout: WorkoutModel, newName: String) {
        builderService.cloneWorkoutForEditing(workout, newName: newName)
    }

    /// Delete workout template
    /// - Parameter templateId: Template ID to delete
    /// - Throws: Error if deletion fails
    public func deleteTemplate(id: UUID) async throws {
        isLoading = true
        defer { isLoading = false }

        do {
            try await dataService.deleteTemplate(id: id)
            await refreshTemplates()
        } catch {
            self.error = error
            throw error
        }
    }

    // MARK: - Workout Management

    /// Delete saved workout
    /// - Parameter workoutId: Workout ID to delete
    /// - Throws: Error if deletion fails
    public func deleteWorkout(id: UUID) async throws {
        isLoading = true
        defer { isLoading = false }

        do {
            try await dataService.deleteWorkout(id: id)
            await refreshWorkouts()
        } catch {
            self.error = error
            throw error
        }
    }

    /// Get recent workouts
    /// - Parameter limit: Maximum number of workouts
    /// - Returns: Recent workouts
    public func getRecentWorkouts(limit: Int = 5) -> [WorkoutModel] {
        return dataService.getRecentWorkouts(limit: limit)
    }

    /// Get workouts in date range
    /// - Parameters:
    ///   - startDate: Start date
    ///   - endDate: End date
    /// - Returns: Workouts in range
    public func getWorkouts(from startDate: Date, to endDate: Date) -> [WorkoutModel] {
        return dataService.getWorkouts(from: startDate, to: endDate)
    }

    // MARK: - Data Management

    /// Refresh all data from persistence
    public func refresh() async {
        await loadData()
    }

    /// Clear any errors
    public func clearError() {
        error = nil
    }

    // MARK: - Convenience Properties

    /// Check if currently building a workout
    public var isBuildingWorkout: Bool {
        return currentWorkout != nil
    }

    /// Check if current workout has exercises
    public var hasExercises: Bool {
        return !workoutExercises.isEmpty
    }

    /// Current workout exercise count
    public var exerciseCount: Int {
        return workoutExercises.count
    }

    /// Total saved workout count
    public var savedWorkoutCount: Int {
        return savedWorkouts.count
    }

    /// Available template count
    public var templateCount: Int {
        return templates.count
    }

    /// Validation errors for current workout
    public var validationErrors: [WorkoutValidationError] {
        return builderService.validationErrors
    }

    // MARK: - Private Methods

    private func setupBindings() {
        // Bind builder service state
        builderService.$currentWorkout
            .receive(on: DispatchQueue.main)
            .assign(to: &$currentWorkout)

        builderService.$workoutExercises
            .receive(on: DispatchQueue.main)
            .assign(to: &$workoutExercises)

        builderService.$isDirty
            .receive(on: DispatchQueue.main)
            .assign(to: &$isDirty)

        builderService.$isValid
            .receive(on: DispatchQueue.main)
            .assign(to: &$isValid)

        // Bind data service state
        dataService.$workouts
            .receive(on: DispatchQueue.main)
            .assign(to: &$savedWorkouts)

        dataService.$templates
            .receive(on: DispatchQueue.main)
            .assign(to: &$templates)

        // Bind loading states
        Publishers.CombineLatest3(
            dataService.$isLoading,
            exerciseLibrary.$isLoading,
            $isLoading
        )
        .map { $0 || $1 || $2 }
        .receive(on: DispatchQueue.main)
        .assign(to: &$isLoading)

        // Bind errors
        Publishers.Merge3(
            dataService.$error.compactMap { $0 },
            exerciseLibrary.$error.compactMap { $0 },
            $error.compactMap { $0 }
        )
        .receive(on: DispatchQueue.main)
        .assign(to: &$error)
    }

    private func loadData() async {
        await exerciseLibrary.loadLibrary()
        await refreshWorkouts()
        await refreshTemplates()
    }

    private func refreshWorkouts() async {
        await dataService.loadWorkouts()
    }

    private func refreshTemplates() async {
        await dataService.loadTemplates()
    }
}

// MARK: - SwiftUI Integration

extension WorkoutBuilder {
    /// Create a properly configured WorkoutBuilder for SwiftUI previews
    public static var preview: WorkoutBuilder {
        let builder = WorkoutBuilder(persistenceController: .preview)
        return builder
    }
}

// MARK: - Public Type Aliases

/// Re-export commonly used types for convenience
public typealias Workout = WorkoutModel
public typealias WorkoutExercise = WorkoutExerciseModel
public typealias WorkoutTemplate = WorkoutTemplateModel
public typealias Exercise = ExerciseLibrary.Exercise
public typealias MuscleGroup = SharedCore.MuscleGroup

// MARK: - Debug Support

#if DEBUG
extension WorkoutBuilder {
    /// Populate with sample data for testing (Debug builds only)
    public func populateWithSampleData() async {
        await exerciseLibrary.populateWithSampleData()

        // Create sample workout
        startNewWorkout(name: "Sample Push Day")

        if let exercises = exerciseLibrary.allExercises.prefix(3).map({ $0 }) as [ExerciseModel]? {
            for exercise in exercises {
                addExercise(exercise)
            }
        }

        do {
            try await saveWorkout()
            print("✅ Created sample workout")
        } catch {
            print("❌ Failed to create sample workout: \(error)")
        }
    }
}
#endif