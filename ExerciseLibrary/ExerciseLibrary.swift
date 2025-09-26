import Foundation
import SwiftUI
import Combine

// MARK: - ExerciseLibrary Public API

/// Main entry point for the ExerciseLibrary module
/// Provides a clean interface for workout building and exercise management
@MainActor
public final class ExerciseLibrary: ObservableObject {

    // MARK: - Public Services

    /// Service for exercise data operations (CRUD, persistence)
    public let dataService: ExerciseDataService

    /// Service for exercise search and filtering
    public let searchService: ExerciseSearchService

    // MARK: - Published State

    /// Current loading state of the library
    @Published public private(set) var isLoading: Bool = false

    /// Any errors from library operations
    @Published public private(set) var error: ExerciseDataError?

    /// Total number of exercises available
    @Published public private(set) var exerciseCount: Int = 0

    // MARK: - Private Properties

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    /// Initialize ExerciseLibrary with optional persistence controller
    /// - Parameter persistenceController: Core Data controller (defaults to shared)
    public init(persistenceController: PersistenceController = .shared) {
        self.dataService = ExerciseDataService(persistenceController: persistenceController)
        self.searchService = ExerciseSearchService(dataService: dataService)

        setupBindings()
    }

    /// Initialize ExerciseLibrary with custom data service (for testing)
    /// - Parameter dataService: Custom exercise data service
    public init(dataService: ExerciseDataService) {
        self.dataService = dataService
        self.searchService = ExerciseSearchService(dataService: dataService)

        setupBindings()
    }

    // MARK: - Public Interface

    /// Load the exercise library
    public func loadLibrary() async {
        await dataService.loadExercises()
    }

    /// Refresh the exercise library from Core Data
    public func refresh() async {
        await dataService.refresh()
    }

    /// Get all available exercises
    public var allExercises: [ExerciseModel] {
        return dataService.exercises
    }

    /// Get filtered and searched exercises
    public var searchResults: [ExerciseModel] {
        return searchService.searchResults
    }

    /// Get available equipment types
    public var equipmentTypes: [String] {
        return dataService.getEquipmentTypes()
    }

    /// Check if any filters are active
    public var hasActiveFilters: Bool {
        return searchService.hasActiveFilters
    }

    /// Get search statistics
    public var searchStatistics: SearchStatistics {
        return searchService.getSearchStatistics()
    }

    // MARK: - Exercise Management

    /// Get exercise by ID
    /// - Parameter id: Exercise UUID
    /// - Returns: ExerciseModel if found
    public func getExercise(by id: UUID) -> ExerciseModel? {
        return dataService.getExercise(by: id)
    }

    /// Get exercises targeting specific muscle group
    /// - Parameter muscleGroup: Target muscle group
    /// - Returns: Array of matching exercises
    public func getExercises(for muscleGroup: MuscleGroup) -> [ExerciseModel] {
        return dataService.getExercises(for: muscleGroup)
    }

    /// Get exercises using specific equipment
    /// - Parameter equipment: Equipment type
    /// - Returns: Array of matching exercises
    public func getExercises(for equipment: String) -> [ExerciseModel] {
        return dataService.getExercises(for: equipment)
    }

    /// Add new exercise to library
    /// - Parameter exercise: Exercise model to add
    /// - Throws: ExerciseDataError if operation fails
    public func addExercise(_ exercise: ExerciseModel) async throws {
        try await dataService.addExercise(exercise)
    }

    /// Update existing exercise
    /// - Parameter exercise: Updated exercise model
    /// - Throws: ExerciseDataError if operation fails
    public func updateExercise(_ exercise: ExerciseModel) async throws {
        try await dataService.updateExercise(exercise)
    }

    /// Delete exercise from library
    /// - Parameter id: Exercise UUID to delete
    /// - Throws: ExerciseDataError if operation fails
    public func deleteExercise(id: UUID) async throws {
        try await dataService.deleteExercise(id: id)
    }

    /// Get exercise count for specific muscle group
    /// - Parameter muscleGroup: Target muscle group
    /// - Returns: Number of exercises targeting that muscle group
    public func getExerciseCount(for muscleGroup: MuscleGroup) -> Int {
        return dataService.getExerciseCount(for: muscleGroup)
    }

    // MARK: - Search Interface

    /// Current search query
    public var searchQuery: String {
        get { searchService.searchQuery }
        set { searchService.searchQuery = newValue }
    }

    /// Selected muscle group filters
    public var selectedMuscleGroups: Set<MuscleGroup> {
        get { searchService.selectedMuscleGroups }
        set { searchService.selectedMuscleGroups = newValue }
    }

    /// Selected equipment filters
    public var selectedEquipment: Set<String> {
        get { searchService.selectedEquipment }
        set { searchService.selectedEquipment = newValue }
    }

    /// Clear all search filters and query
    public func clearSearch() {
        searchService.clearSearch()
    }

    /// Add muscle group filter
    /// - Parameter muscleGroup: Muscle group to filter by
    public func addMuscleGroupFilter(_ muscleGroup: MuscleGroup) {
        searchService.addMuscleGroupFilter(muscleGroup)
    }

    /// Remove muscle group filter
    /// - Parameter muscleGroup: Muscle group to remove from filters
    public func removeMuscleGroupFilter(_ muscleGroup: MuscleGroup) {
        searchService.removeMuscleGroupFilter(muscleGroup)
    }

    /// Toggle muscle group filter
    /// - Parameter muscleGroup: Muscle group to toggle
    public func toggleMuscleGroupFilter(_ muscleGroup: MuscleGroup) {
        searchService.toggleMuscleGroupFilter(muscleGroup)
    }

    /// Add equipment filter
    /// - Parameter equipment: Equipment type to filter by
    public func addEquipmentFilter(_ equipment: String) {
        searchService.addEquipmentFilter(equipment)
    }

    /// Remove equipment filter
    /// - Parameter equipment: Equipment type to remove from filters
    public func removeEquipmentFilter(_ equipment: String) {
        searchService.removeEquipmentFilter(equipment)
    }

    /// Toggle equipment filter
    /// - Parameter equipment: Equipment type to toggle
    public func toggleEquipmentFilter(_ equipment: String) {
        searchService.toggleEquipmentFilter(equipment)
    }

    // MARK: - Recommendations

    /// Get popular exercises for new users
    /// - Returns: Array of popular exercises
    public func getPopularExercises() -> [ExerciseModel] {
        return searchService.getPopularExercises()
    }

    /// Get suggested exercises based on current workout selection
    /// - Parameter exerciseIds: Currently selected exercise IDs
    /// - Returns: Array of complementary exercise suggestions
    public func getSuggestedExercises(for exerciseIds: [UUID]) -> [ExerciseModel] {
        return searchService.getSuggestedExercises(for: exerciseIds)
    }

    // MARK: - Filter Presets

    /// Apply predefined filter preset
    /// - Parameter preset: Filter preset to apply
    public func applyFilterPreset(_ preset: ExerciseSearchService.FilterPreset) {
        searchService.applyFilterPreset(preset)
    }

    /// Get all available filter presets
    public var filterPresets: [ExerciseSearchService.FilterPreset] {
        return ExerciseSearchService.FilterPreset.allCases
    }

    // MARK: - Bulk Operations

    /// Import multiple exercises from external source
    /// - Parameter exercises: Array of exercise models to import
    /// - Throws: ExerciseDataError if bulk import fails
    public func bulkImportExercises(_ exercises: [ExerciseModel]) async throws {
        try await dataService.bulkImportExercises(exercises)
    }

    // MARK: - Private Methods

    private func setupBindings() {
        // Bind data service loading state
        dataService.$isLoading
            .receive(on: DispatchQueue.main)
            .assign(to: &$isLoading)

        // Bind data service errors
        dataService.$error
            .receive(on: DispatchQueue.main)
            .assign(to: &$error)

        // Bind exercise count
        dataService.$exercises
            .map { $0.count }
            .receive(on: DispatchQueue.main)
            .assign(to: &$exerciseCount)
    }
}

// MARK: - SwiftUI Integration

extension ExerciseLibrary {
    /// Create a properly configured ExerciseLibrary for SwiftUI previews
    public static var preview: ExerciseLibrary {
        let library = ExerciseLibrary(persistenceController: .preview)
        return library
    }
}

// MARK: - Public Type Aliases

/// Re-export commonly used types for convenience
public typealias Exercise = ExerciseModel
public typealias MuscleGroup = SharedCore.MuscleGroup
public typealias FilterPreset = ExerciseSearchService.FilterPreset
public typealias SearchStats = SearchStatistics

// MARK: - Convenience Extensions

extension ExerciseLibrary {
    /// Check if library is empty
    public var isEmpty: Bool {
        return exerciseCount == 0
    }

    /// Check if library has exercises
    public var hasExercises: Bool {
        return exerciseCount > 0
    }

    /// Get search result count
    public var searchResultCount: Int {
        return searchResults.count
    }

    /// Check if currently searching
    public var isSearching: Bool {
        return searchService.isSearching
    }

    /// Get unique muscle groups from available exercises
    public var availableMuscleGroups: [MuscleGroup] {
        let allGroups = Set(dataService.exercises.flatMap { $0.allMuscleGroups })
        return Array(allGroups).sorted { $0.rawValue < $1.rawValue }
    }
}

// MARK: - Debug Support

#if DEBUG
extension ExerciseLibrary {
    /// Generate sample exercises for testing (Debug builds only)
    public func populateWithSampleData() async {
        let sampleExercises = ExerciseModel.sampleExercises
        do {
            try await bulkImportExercises(sampleExercises)
            print("✅ Populated ExerciseLibrary with \(sampleExercises.count) sample exercises")
        } catch {
            print("❌ Failed to populate sample data: \(error)")
        }
    }

    /// Clear all exercises (Debug builds only)
    public func clearAllExercises() async {
        for exercise in dataService.exercises {
            do {
                try await deleteExercise(id: exercise.id)
            } catch {
                print("❌ Failed to delete exercise \(exercise.name): \(error)")
            }
        }
    }
}
#endif