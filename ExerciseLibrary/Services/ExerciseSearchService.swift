import Foundation
import Combine

/// Service responsible for fast exercise search and filtering
/// Optimized for real-time search with debouncing and intelligent ranking
public class ExerciseSearchService: ObservableObject {

    // MARK: - Dependencies

    private let dataService: ExerciseDataService

    // MARK: - Published Properties

    @Published public var searchQuery: String = "" {
        didSet {
            searchSubject.send(searchQuery)
        }
    }

    @Published public var selectedMuscleGroups: Set<MuscleGroup> = [] {
        didSet {
            performSearch()
        }
    }

    @Published public var selectedEquipment: Set<String> = [] {
        didSet {
            performSearch()
        }
    }

    @Published public private(set) var searchResults: [ExerciseModel] = []
    @Published public private(set) var isSearching = false
    @Published public private(set) var hasActiveFilters = false

    // MARK: - Private Properties

    private let searchSubject = PassthroughSubject<String, Never>()
    private var cancellables = Set<AnyCancellable>()

    // Search optimization
    private var lastSearchQuery = ""
    private var searchResultsCache: [String: [ExerciseModel]] = [:]

    // MARK: - Initialization

    public init(dataService: ExerciseDataService) {
        self.dataService = dataService

        setupSearchDebouncing()
        setupDataServiceBinding()
        updateActiveFiltersState()
    }

    // MARK: - Public Methods

    /// Clear all search filters and query
    public func clearSearch() {
        searchQuery = ""
        selectedMuscleGroups.removeAll()
        selectedEquipment.removeAll()
        searchResults = dataService.exercises
    }

    /// Add muscle group filter
    public func addMuscleGroupFilter(_ muscleGroup: MuscleGroup) {
        selectedMuscleGroups.insert(muscleGroup)
    }

    /// Remove muscle group filter
    public func removeMuscleGroupFilter(_ muscleGroup: MuscleGroup) {
        selectedMuscleGroups.remove(muscleGroup)
    }

    /// Toggle muscle group filter
    public func toggleMuscleGroupFilter(_ muscleGroup: MuscleGroup) {
        if selectedMuscleGroups.contains(muscleGroup) {
            selectedMuscleGroups.remove(muscleGroup)
        } else {
            selectedMuscleGroups.insert(muscleGroup)
        }
    }

    /// Add equipment filter
    public func addEquipmentFilter(_ equipment: String) {
        selectedEquipment.insert(equipment)
    }

    /// Remove equipment filter
    public func removeEquipmentFilter(_ equipment: String) {
        selectedEquipment.remove(equipment)
    }

    /// Toggle equipment filter
    public func toggleEquipmentFilter(_ equipment: String) {
        if selectedEquipment.contains(equipment) {
            selectedEquipment.remove(equipment)
        } else {
            selectedEquipment.insert(equipment)
        }
    }

    /// Get popular exercises (most commonly used muscle groups)
    public func getPopularExercises() -> [ExerciseModel] {
        let popularMuscleGroups: [MuscleGroup] = [.chest, .back, .quadriceps, .shoulders]
        return dataService.exercises.filter { exercise in
            exercise.primaryMuscleGroups.contains { popularMuscleGroups.contains($0) }
        }.prefix(10).map { $0 }
    }

    /// Get suggested exercises based on current selection
    public func getSuggestedExercises(for exerciseIds: [UUID]) -> [ExerciseModel] {
        guard !exerciseIds.isEmpty else { return getPopularExercises() }

        let selectedExercises = exerciseIds.compactMap { id in
            dataService.exercises.first { $0.id == id }
        }

        // Get muscle groups from selected exercises
        let targetedMuscleGroups = Set(selectedExercises.flatMap { $0.primaryMuscleGroups })

        // Find complementary exercises
        let suggestions = dataService.exercises.filter { exercise in
            // Not already selected
            !exerciseIds.contains(exercise.id) &&
            // Targets same or complementary muscle groups
            !Set(exercise.primaryMuscleGroups).isDisjoint(with: targetedMuscleGroups)
        }

        return Array(suggestions.prefix(5))
    }

    // MARK: - Private Methods

    private func setupSearchDebouncing() {
        searchSubject
            .debounce(for: .milliseconds(300), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] query in
                self?.performSearch()
            }
            .store(in: &cancellables)
    }

    private func setupDataServiceBinding() {
        dataService.$exercises
            .sink { [weak self] exercises in
                self?.performSearch()
            }
            .store(in: &cancellables)
    }

    private func performSearch() {
        isSearching = true

        let query = searchQuery.trimmingCharacters(in: .whitespaces)
        let cacheKey = "\(query)_\(selectedMuscleGroups.hashValue)_\(selectedEquipment.hashValue)"

        // Check cache first
        if let cachedResults = searchResultsCache[cacheKey] {
            searchResults = cachedResults
            isSearching = false
            return
        }

        var results = dataService.exercises

        // Apply text search
        if !query.isEmpty {
            results = results.filter { $0.matches(searchQuery: query) }
        }

        // Apply muscle group filters
        if !selectedMuscleGroups.isEmpty {
            results = results.filter { exercise in
                !Set(exercise.allMuscleGroups).isDisjoint(with: selectedMuscleGroups)
            }
        }

        // Apply equipment filters
        if !selectedEquipment.isEmpty {
            results = results.filter { exercise in
                selectedEquipment.contains(exercise.equipment)
            }
        }

        // Rank results by relevance
        results = rankSearchResults(results, query: query)

        // Cache results
        searchResultsCache[cacheKey] = results

        // Limit cache size
        if searchResultsCache.count > 50 {
            searchResultsCache.removeAll()
        }

        searchResults = results
        isSearching = false
        updateActiveFiltersState()
    }

    private func rankSearchResults(_ exercises: [ExerciseModel], query: String) -> [ExerciseModel] {
        if query.isEmpty {
            return exercises.sorted { $0.name < $1.name }
        }

        let lowercaseQuery = query.lowercased()

        return exercises.sorted { exercise1, exercise2 in
            let score1 = calculateRelevanceScore(exercise1, query: lowercaseQuery)
            let score2 = calculateRelevanceScore(exercise2, query: lowercaseQuery)

            if score1 != score2 {
                return score1 > score2
            }

            // Secondary sort by name
            return exercise1.name < exercise2.name
        }
    }

    private func calculateRelevanceScore(_ exercise: ExerciseModel, query: String) -> Int {
        var score = 0

        let exerciseName = exercise.name.lowercased()
        let equipment = exercise.equipment.lowercased()

        // Exact name match gets highest score
        if exerciseName == query {
            score += 100
        }
        // Name starts with query
        else if exerciseName.hasPrefix(query) {
            score += 50
        }
        // Name contains query
        else if exerciseName.contains(query) {
            score += 25
        }

        // Equipment match
        if equipment.contains(query) {
            score += 15
        }

        // Muscle group match
        let muscleGroupNames = exercise.allMuscleGroups.map { $0.rawValue.lowercased() }
        if muscleGroupNames.contains(where: { $0.contains(query) }) {
            score += 10
        }

        // Popular exercises get small boost
        let popularNames = ["bench", "squat", "deadlift", "press", "pull"]
        if popularNames.contains(where: { exerciseName.contains($0) }) {
            score += 5
        }

        return score
    }

    private func updateActiveFiltersState() {
        hasActiveFilters = !selectedMuscleGroups.isEmpty ||
                          !selectedEquipment.isEmpty ||
                          !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty
    }
}

// MARK: - Search Statistics

extension ExerciseSearchService {
    /// Get search statistics for analytics
    public func getSearchStatistics() -> SearchStatistics {
        return SearchStatistics(
            totalExercises: dataService.exercises.count,
            currentResults: searchResults.count,
            muscleGroupsFiltered: selectedMuscleGroups.count,
            equipmentFiltered: selectedEquipment.count,
            hasTextQuery: !searchQuery.trimmingCharacters(in: .whitespaces).isEmpty
        )
    }
}

// MARK: - Supporting Types

public struct SearchStatistics {
    public let totalExercises: Int
    public let currentResults: Int
    public let muscleGroupsFiltered: Int
    public let equipmentFiltered: Int
    public let hasTextQuery: Bool

    public var filterEfficiency: Double {
        guard totalExercises > 0 else { return 0 }
        return Double(currentResults) / Double(totalExercises)
    }
}

// MARK: - Predefined Filters

extension ExerciseSearchService {
    /// Common filter presets for quick access
    public enum FilterPreset: CaseIterable {
        case chest
        case back
        case legs
        case shoulders
        case arms
        case bodyweight
        case barbell
        case dumbbell

        public var name: String {
            switch self {
            case .chest: return "Chest"
            case .back: return "Back"
            case .legs: return "Legs"
            case .shoulders: return "Shoulders"
            case .arms: return "Arms"
            case .bodyweight: return "Bodyweight"
            case .barbell: return "Barbell"
            case .dumbbell: return "Dumbbell"
            }
        }

        public var muscleGroups: [MuscleGroup] {
            switch self {
            case .chest: return [.chest]
            case .back: return [.back, .lats]
            case .legs: return [.quadriceps, .hamstrings, .glutes, .calves]
            case .shoulders: return [.shoulders, .delts]
            case .arms: return [.biceps, .triceps, .forearms]
            case .bodyweight, .barbell, .dumbbell: return []
            }
        }

        public var equipment: [String] {
            switch self {
            case .bodyweight: return ["Bodyweight"]
            case .barbell: return ["Barbell"]
            case .dumbbell: return ["Dumbbell"]
            case .chest, .back, .legs, .shoulders, .arms: return []
            }
        }
    }

    /// Apply predefined filter preset
    public func applyFilterPreset(_ preset: FilterPreset) {
        clearSearch()

        for muscleGroup in preset.muscleGroups {
            selectedMuscleGroups.insert(muscleGroup)
        }

        for equipment in preset.equipment {
            selectedEquipment.insert(equipment)
        }
    }
}