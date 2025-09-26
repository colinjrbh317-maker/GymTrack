import Foundation
import CoreData
import Combine

/// Service responsible for managing exercise data operations
/// Handles Core Data persistence, bundled data loading, and CRUD operations
public class ExerciseDataService: ObservableObject {

    // MARK: - Dependencies

    private let persistenceController: PersistenceController
    private let context: NSManagedObjectContext

    // MARK: - Published Properties

    @Published public private(set) var exercises: [ExerciseModel] = []
    @Published public private(set) var isLoading = false
    @Published public private(set) var error: ExerciseDataError?

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()
    private let exerciseCache = NSCache<NSString, NSArray>()

    // MARK: - Initialization

    public init(persistenceController: PersistenceController = .shared) {
        self.persistenceController = persistenceController
        self.context = persistenceController.container.viewContext

        // Configure cache
        exerciseCache.countLimit = 100
        exerciseCache.totalCostLimit = 1024 * 1024 // 1MB

        // Load exercises on initialization
        Task {
            await loadExercises()
        }
    }

    // MARK: - Public Methods

    /// Load all exercises from Core Data
    @MainActor
    public func loadExercises() async {
        isLoading = true
        error = nil

        do {
            let fetchRequest: NSFetchRequest<Exercise> = Exercise.fetchRequest()
            fetchRequest.sortDescriptors = [
                NSSortDescriptor(key: "name", ascending: true)
            ]

            let entities = try context.fetch(fetchRequest)

            if entities.isEmpty {
                // First launch - populate from bundled data
                await populateFromBundledData()
            } else {
                exercises = entities.map { ExerciseModel(from: $0) }
            }
        } catch {
            self.error = .coreDataError(error)
        }

        isLoading = false
    }

    /// Get exercise by ID
    public func getExercise(by id: UUID) -> ExerciseModel? {
        return exercises.first { $0.id == id }
    }

    /// Get exercises by muscle group
    public func getExercises(for muscleGroup: MuscleGroup) -> [ExerciseModel] {
        return exercises.filter { $0.targets(muscleGroup: muscleGroup) }
    }

    /// Get exercises by equipment type
    public func getExercises(for equipment: String) -> [ExerciseModel] {
        return exercises.filter { $0.uses(equipment: equipment) }
    }

    /// Add new exercise
    @MainActor
    public func addExercise(_ exerciseModel: ExerciseModel) async throws {
        let entity = Exercise(context: context)
        exerciseModel.update(entity)

        do {
            try context.save()
            exercises.append(exerciseModel)
            exercises.sort { $0.name < $1.name }
        } catch {
            context.rollback()
            throw ExerciseDataError.coreDataError(error)
        }
    }

    /// Update existing exercise
    @MainActor
    public func updateExercise(_ exerciseModel: ExerciseModel) async throws {
        let fetchRequest: NSFetchRequest<Exercise> = Exercise.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", exerciseModel.id as CVarArg)

        do {
            let entities = try context.fetch(fetchRequest)
            guard let entity = entities.first else {
                throw ExerciseDataError.exerciseNotFound(exerciseModel.id)
            }

            exerciseModel.update(entity)
            try context.save()

            // Update local array
            if let index = exercises.firstIndex(where: { $0.id == exerciseModel.id }) {
                exercises[index] = exerciseModel
                exercises.sort { $0.name < $1.name }
            }
        } catch let error as ExerciseDataError {
            throw error
        } catch {
            context.rollback()
            throw ExerciseDataError.coreDataError(error)
        }
    }

    /// Delete exercise
    @MainActor
    public func deleteExercise(id: UUID) async throws {
        let fetchRequest: NSFetchRequest<Exercise> = Exercise.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", id as CVarArg)

        do {
            let entities = try context.fetch(fetchRequest)
            guard let entity = entities.first else {
                throw ExerciseDataError.exerciseNotFound(id)
            }

            context.delete(entity)
            try context.save()

            // Update local array
            exercises.removeAll { $0.id == id }
        } catch let error as ExerciseDataError {
            throw error
        } catch {
            context.rollback()
            throw ExerciseDataError.coreDataError(error)
        }
    }

    /// Get unique equipment types
    public func getEquipmentTypes() -> [String] {
        let uniqueEquipment = Set(exercises.map { $0.equipment })
        return Array(uniqueEquipment).sorted()
    }

    /// Get exercise count by muscle group
    public func getExerciseCount(for muscleGroup: MuscleGroup) -> Int {
        return exercises.filter { $0.targets(muscleGroup: muscleGroup) }.count
    }

    /// Refresh exercises from Core Data
    @MainActor
    public func refresh() async {
        await loadExercises()
    }

    // MARK: - Private Methods

    /// Populate Core Data from bundled JSON data
    @MainActor
    private func populateFromBundledData() async {
        do {
            let bundledExercises = try loadBundledExercises()

            // Save to Core Data
            for exerciseModel in bundledExercises {
                let entity = Exercise(context: context)
                exerciseModel.update(entity)
            }

            try context.save()
            exercises = bundledExercises.sorted { $0.name < $1.name }

            print("✅ Populated \(bundledExercises.count) exercises from bundled data")
        } catch {
            self.error = .bundledDataError(error)
            print("❌ Failed to populate from bundled data: \(error)")

            // Fallback to sample data
            await populateWithSampleData()
        }
    }

    /// Load exercises from bundled JSON file
    private func loadBundledExercises() throws -> [ExerciseModel] {
        guard let url = Bundle.main.url(forResource: "exercises", withExtension: "json") else {
            throw ExerciseDataError.bundledDataNotFound
        }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        return try decoder.decode([ExerciseModel].self, from: data)
    }

    /// Fallback to sample data if bundled data fails
    @MainActor
    private func populateWithSampleData() async {
        let sampleExercises = ExerciseModel.sampleExercises

        do {
            for exerciseModel in sampleExercises {
                let entity = Exercise(context: context)
                exerciseModel.update(entity)
            }

            try context.save()
            exercises = sampleExercises.sorted { $0.name < $1.name }

            print("✅ Populated \(sampleExercises.count) sample exercises")
        } catch {
            self.error = .coreDataError(error)
            print("❌ Failed to populate sample data: \(error)")
        }
    }
}

// MARK: - Error Types

public enum ExerciseDataError: LocalizedError, Equatable {
    case coreDataError(Error)
    case bundledDataError(Error)
    case bundledDataNotFound
    case exerciseNotFound(UUID)
    case invalidExerciseData

    public var errorDescription: String? {
        switch self {
        case .coreDataError(let error):
            return "Core Data error: \(error.localizedDescription)"
        case .bundledDataError(let error):
            return "Bundled data error: \(error.localizedDescription)"
        case .bundledDataNotFound:
            return "Bundled exercise data not found"
        case .exerciseNotFound(let id):
            return "Exercise not found: \(id)"
        case .invalidExerciseData:
            return "Invalid exercise data provided"
        }
    }

    public static func == (lhs: ExerciseDataError, rhs: ExerciseDataError) -> Bool {
        switch (lhs, rhs) {
        case (.bundledDataNotFound, .bundledDataNotFound):
            return true
        case (.invalidExerciseData, .invalidExerciseData):
            return true
        case (.exerciseNotFound(let lhsId), .exerciseNotFound(let rhsId)):
            return lhsId == rhsId
        case (.coreDataError(let lhsError), .coreDataError(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        case (.bundledDataError(let lhsError), .bundledDataError(let rhsError)):
            return lhsError.localizedDescription == rhsError.localizedDescription
        default:
            return false
        }
    }
}

// MARK: - Background Operations Extension

extension ExerciseDataService {
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

    /// Bulk import exercises from external source
    @MainActor
    public func bulkImportExercises(_ exerciseModels: [ExerciseModel]) async throws {
        isLoading = true
        defer { isLoading = false }

        try await performBackgroundOperation { backgroundContext in
            for exerciseModel in exerciseModels {
                let entity = Exercise(context: backgroundContext)
                exerciseModel.update(entity)
            }
        }

        // Refresh UI
        await refresh()
    }
}