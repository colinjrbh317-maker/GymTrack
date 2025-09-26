import Foundation
import CoreData
import Combine

/// Service responsible for workout data persistence and retrieval
/// Handles Core Data operations for workouts, workout exercises, and templates
public class WorkoutDataService: ObservableObject {

    // MARK: - Dependencies

    private let persistenceController: PersistenceController
    private let context: NSManagedObjectContext

    // MARK: - Published Properties

    @Published public private(set) var workouts: [WorkoutModel] = []
    @Published public private(set) var templates: [WorkoutTemplateModel] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var error: WorkoutDataError?

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    public init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
        self.context = persistenceController.container.viewContext

        Task {
            await loadWorkouts()
            await loadTemplates()
        }
    }

    // MARK: - Workout Operations

    /// Load all workouts from Core Data
    @MainActor
    public func loadWorkouts() async {
        isLoading = true
        error = nil

        do {
            let fetchRequest: NSFetchRequest<Workout> = Workout.fetchRequest()
            fetchRequest.sortDescriptors = [
                NSSortDescriptor(key: "updatedAt", ascending: false)
            ]

            let entities = try context.fetch(fetchRequest)
            workouts = entities.map { WorkoutModel(from: $0) }
        } catch {
            self.error = .coreDataError(error)
        }

        isLoading = false
    }

    /// Create new workout
    /// - Parameter workout: Workout model to create
    /// - Returns: Created workout with updated timestamps
    /// - Throws: WorkoutDataError if creation fails
    @MainActor
    public func createWorkout(_ workout: WorkoutModel) async throws -> WorkoutModel {
        let entity = Workout(context: context)
        var updatedWorkout = workout
        updatedWorkout.createdAt = Date()
        updatedWorkout.updatedAt = Date()
        updatedWorkout.update(entity)

        do {
            try context.save()
            workouts.append(updatedWorkout)
            workouts.sort { $0.updatedAt > $1.updatedAt }
            return updatedWorkout
        } catch {
            context.rollback()
            throw WorkoutDataError.coreDataError(error)
        }
    }

    /// Update existing workout
    /// - Parameter workout: Workout model to update
    /// - Returns: Updated workout
    /// - Throws: WorkoutDataError if update fails
    @MainActor
    public func updateWorkout(_ workout: WorkoutModel) async throws -> WorkoutModel {
        let fetchRequest: NSFetchRequest<Workout> = Workout.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", workout.id as CVarArg)

        do {
            let entities = try context.fetch(fetchRequest)
            guard let entity = entities.first else {
                throw WorkoutDataError.workoutNotFound(workout.id)
            }

            var updatedWorkout = workout
            updatedWorkout.updatedAt = Date()
            updatedWorkout.update(entity)

            try context.save()

            // Update local array
            if let index = workouts.firstIndex(where: { $0.id == workout.id }) {
                workouts[index] = updatedWorkout
                workouts.sort { $0.updatedAt > $1.updatedAt }
            }

            return updatedWorkout
        } catch let error as WorkoutDataError {
            throw error
        } catch {
            context.rollback()
            throw WorkoutDataError.coreDataError(error)
        }
    }

    /// Delete workout
    /// - Parameter id: Workout ID to delete
    /// - Throws: WorkoutDataError if deletion fails
    @MainActor
    public func deleteWorkout(id: UUID) async throws {
        let fetchRequest: NSFetchRequest<Workout> = Workout.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)

        do {
            let entities = try context.fetch(fetchRequest)
            guard let entity = entities.first else {
                throw WorkoutDataError.workoutNotFound(id)
            }

            context.delete(entity)
            try context.save()

            // Update local array
            workouts.removeAll { $0.id == id }
        } catch let error as WorkoutDataError {
            throw error
        } catch {
            context.rollback()
            throw WorkoutDataError.coreDataError(error)
        }
    }

    /// Check if workout exists
    /// - Parameter id: Workout ID
    /// - Returns: True if workout exists
    public func workoutExists(id: UUID) async -> Bool {
        let fetchRequest: NSFetchRequest<Workout> = Workout.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        fetchRequest.fetchLimit = 1

        do {
            let count = try context.count(for: fetchRequest)
            return count > 0
        } catch {
            return false
        }
    }

    /// Get workout by ID
    /// - Parameter id: Workout ID
    /// - Returns: Workout model if found
    public func getWorkout(by id: UUID) -> WorkoutModel? {
        return workouts.first { $0.id == id }
    }

    // MARK: - Workout Exercise Operations

    /// Get workout exercises for specific workout
    /// - Parameter workoutId: Workout ID
    /// - Returns: Array of workout exercises
    /// - Throws: WorkoutDataError if fetch fails
    public func getWorkoutExercises(for workoutId: UUID) async throws -> [WorkoutExerciseModel] {
        let fetchRequest: NSFetchRequest<WorkoutExercise> = WorkoutExercise.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "workout.id == %@", workoutId as CVarArg)
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(key: "orderIndex", ascending: true)
        ]

        do {
            let entities = try context.fetch(fetchRequest)
            return entities.map { WorkoutExerciseModel(from: $0) }
        } catch {
            throw WorkoutDataError.coreDataError(error)
        }
    }

    /// Create workout exercise
    /// - Parameter workoutExercise: Workout exercise to create
    /// - Returns: Created workout exercise
    /// - Throws: WorkoutDataError if creation fails
    @MainActor
    public func createWorkoutExercise(_ workoutExercise: WorkoutExerciseModel) async throws -> WorkoutExerciseModel {
        // Find workout entity
        let workoutFetch: NSFetchRequest<Workout> = Workout.fetchRequest()
        workoutFetch.predicate = NSPredicate(format: "id == %@", workoutExercise.workoutId as CVarArg)

        // Find exercise entity
        let exerciseFetch: NSFetchRequest<Exercise> = Exercise.fetchRequest()
        exerciseFetch.predicate = NSPredicate(format: "id == %@", workoutExercise.exerciseId as CVarArg)

        do {
            let workoutEntities = try context.fetch(workoutFetch)
            let exerciseEntities = try context.fetch(exerciseFetch)

            guard let workoutEntity = workoutEntities.first else {
                throw WorkoutDataError.workoutNotFound(workoutExercise.workoutId)
            }

            guard let exerciseEntity = exerciseEntities.first else {
                throw WorkoutDataError.exerciseNotFound(workoutExercise.exerciseId)
            }

            let entity = WorkoutExercise(context: context)
            workoutExercise.update(entity)
            entity.workout = workoutEntity
            entity.exercise = exerciseEntity

            try context.save()
            return workoutExercise
        } catch let error as WorkoutDataError {
            throw error
        } catch {
            context.rollback()
            throw WorkoutDataError.coreDataError(error)
        }
    }

    /// Update workout exercise
    /// - Parameter workoutExercise: Workout exercise to update
    /// - Returns: Updated workout exercise
    /// - Throws: WorkoutDataError if update fails
    @MainActor
    public func updateWorkoutExercise(_ workoutExercise: WorkoutExerciseModel) async throws -> WorkoutExerciseModel {
        let fetchRequest: NSFetchRequest<WorkoutExercise> = WorkoutExercise.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", workoutExercise.id as CVarArg)

        do {
            let entities = try context.fetch(fetchRequest)
            guard let entity = entities.first else {
                throw WorkoutDataError.workoutExerciseNotFound(workoutExercise.id)
            }

            workoutExercise.update(entity)
            try context.save()
            return workoutExercise
        } catch let error as WorkoutDataError {
            throw error
        } catch {
            context.rollback()
            throw WorkoutDataError.coreDataError(error)
        }
    }

    /// Delete workout exercise
    /// - Parameter id: Workout exercise ID
    /// - Throws: WorkoutDataError if deletion fails
    @MainActor
    public func deleteWorkoutExercise(id: UUID) async throws {
        let fetchRequest: NSFetchRequest<WorkoutExercise> = WorkoutExercise.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)

        do {
            let entities = try context.fetch(fetchRequest)
            guard let entity = entities.first else {
                throw WorkoutDataError.workoutExerciseNotFound(id)
            }

            context.delete(entity)
            try context.save()
        } catch let error as WorkoutDataError {
            throw error
        } catch {
            context.rollback()
            throw WorkoutDataError.coreDataError(error)
        }
    }

    /// Check if workout exercise exists
    /// - Parameter id: Workout exercise ID
    /// - Returns: True if workout exercise exists
    public func workoutExerciseExists(id: UUID) async -> Bool {
        let fetchRequest: NSFetchRequest<WorkoutExercise> = WorkoutExercise.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        fetchRequest.fetchLimit = 1

        do {
            let count = try context.count(for: fetchRequest)
            return count > 0
        } catch {
            return false
        }
    }

    // MARK: - Template Operations

    /// Load all workout templates
    @MainActor
    public func loadTemplates() async {
        do {
            let fetchRequest: NSFetchRequest<WorkoutTemplate> = WorkoutTemplate.fetchRequest()
            fetchRequest.sortDescriptors = [
                NSSortDescriptor(key: "createdAt", ascending: false)
            ]

            let entities = try context.fetch(fetchRequest)
            templates = entities.compactMap { entity in
                do {
                    return try WorkoutTemplateModel(from: entity)
                } catch {
                    print("❌ Failed to decode template: \(error)")
                    return nil
                }
            }
        } catch {
            self.error = .coreDataError(error)
        }
    }

    /// Create workout template
    /// - Parameter template: Template to create
    /// - Returns: Created template
    /// - Throws: WorkoutDataError if creation fails
    @MainActor
    public func createWorkoutTemplate(_ template: WorkoutTemplateModel) async throws -> WorkoutTemplateModel {
        let entity = WorkoutTemplate(context: context)
        var updatedTemplate = template
        updatedTemplate.createdAt = Date()

        do {
            try updatedTemplate.update(entity)
            try context.save()
            templates.append(updatedTemplate)
            templates.sort { $0.createdAt > $1.createdAt }
            return updatedTemplate
        } catch {
            context.rollback()
            throw WorkoutDataError.coreDataError(error)
        }
    }

    /// Delete workout template
    /// - Parameter id: Template ID
    /// - Throws: WorkoutDataError if deletion fails
    @MainActor
    public func deleteTemplate(id: UUID) async throws {
        let fetchRequest: NSFetchRequest<WorkoutTemplate> = WorkoutTemplate.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)

        do {
            let entities = try context.fetch(fetchRequest)
            guard let entity = entities.first else {
                throw WorkoutDataError.templateNotFound(id)
            }

            context.delete(entity)
            try context.save()

            // Update local array
            templates.removeAll { $0.id == id }
        } catch let error as WorkoutDataError {
            throw error
        } catch {
            context.rollback()
            throw WorkoutDataError.coreDataError(error)
        }
    }

    // MARK: - Statistics and Analytics

    /// Get workout count
    /// - Returns: Total number of workouts
    public var workoutCount: Int {
        return workouts.count
    }

    /// Get template count
    /// - Returns: Total number of templates
    public var templateCount: Int {
        return templates.count
    }

    /// Get recent workouts
    /// - Parameter limit: Maximum number of workouts (default: 5)
    /// - Returns: Recent workouts
    public func getRecentWorkouts(limit: Int = 5) -> [WorkoutModel] {
        return Array(workouts.prefix(limit))
    }

    /// Get workouts by date range
    /// - Parameters:
    ///   - startDate: Start date
    ///   - endDate: End date
    /// - Returns: Workouts in date range
    public func getWorkouts(from startDate: Date, to endDate: Date) -> [WorkoutModel] {
        return workouts.filter { workout in
            workout.createdAt >= startDate && workout.createdAt <= endDate
        }
    }

    /// Refresh all data from Core Data
    @MainActor
    public func refresh() async {
        await loadWorkouts()
        await loadTemplates()
    }
}

// MARK: - Error Types

public enum WorkoutDataError: LocalizedError, Equatable {
    case coreDataError(Error)
    case workoutNotFound(UUID)
    case exerciseNotFound(UUID)
    case workoutExerciseNotFound(UUID)
    case templateNotFound(UUID)
    case invalidTemplateData

    public var errorDescription: String? {
        switch self {
        case .coreDataError(let error):
            return "Core Data error: \(error.localizedDescription)"
        case .workoutNotFound(let id):
            return "Workout not found: \(id)"
        case .exerciseNotFound(let id):
            return "Exercise not found: \(id)"
        case .workoutExerciseNotFound(let id):
            return "Workout exercise not found: \(id)"
        case .templateNotFound(let id):
            return "Template not found: \(id)"
        case .invalidTemplateData:
            return "Invalid template data"
        }
    }

    public static func == (lhs: WorkoutDataError, rhs: WorkoutDataError) -> Bool {
        switch (lhs, rhs) {
        case (.workoutNotFound(let lhsId), .workoutNotFound(let rhsId)):
            return lhsId == rhsId
        case (.exerciseNotFound(let lhsId), .exerciseNotFound(let rhsId)):
            return lhsId == rhsId
        case (.workoutExerciseNotFound(let lhsId), .workoutExerciseNotFound(let rhsId)):
            return lhsId == rhsId
        case (.templateNotFound(let lhsId), .templateNotFound(let rhsId)):
            return lhsId == rhsId
        case (.invalidTemplateData, .invalidTemplateData):
            return true
        case (.coreDataError(let lhsError), .coreDataError(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}

// MARK: - Background Operations

extension WorkoutDataService {
    /// Perform data operations on background context
    public func performBackgroundOperation<T>(
        _ operation: @escaping (NSManagedObjectContext) throws -> T
    ) async throws -> T {
        return try await withCheckedThrowingContinuation { continuation in
            persistenceController.performBackgroundTask { backgroundContext in
                do {
                    let result = try operation(backgroundContext)
                    try backgroundContext.save()
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Bulk delete workouts
    /// - Parameter ids: Workout IDs to delete
    /// - Throws: WorkoutDataError if bulk delete fails
    @MainActor
    public func bulkDeleteWorkouts(_ ids: [UUID]) async throws {
        for id in ids {
            try await deleteWorkout(id: id)
        }
    }
}