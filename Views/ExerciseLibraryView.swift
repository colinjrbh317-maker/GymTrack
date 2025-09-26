import SwiftUI

struct ExerciseLibraryView: View {
    @ObservedObject var exerciseLibrary: ExerciseLibrary
    let onExerciseSelected: (ExerciseModel) -> Void

    @State private var searchText = ""
    @State private var selectedMuscleGroups: Set<MuscleGroup> = []
    @State private var selectedEquipment: Set<String> = []
    @State private var showingFilters = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                searchBar

                // Filter Tags
                if exerciseLibrary.hasActiveFilters {
                    activeFiltersView
                }

                // Exercise List
                if exerciseLibrary.isLoading {
                    loadingView
                } else if exerciseLibrary.searchResults.isEmpty {
                    emptyStateView
                } else {
                    exerciseListView
                }
            }
            .navigationTitle("Exercise Library")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Filters") {
                        showingFilters = true
                    }
                }

                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        // Dismiss sheet - parent will handle
                    }
                }
            }
            .sheet(isPresented: $showingFilters) {
                ExerciseFiltersView(
                    exerciseLibrary: exerciseLibrary,
                    selectedMuscleGroups: $selectedMuscleGroups,
                    selectedEquipment: $selectedEquipment
                )
            }
            .onAppear {
                Task {
                    await exerciseLibrary.loadLibrary()
                }
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("Search exercises...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())
                .onChange(of: searchText) { _, newValue in
                    exerciseLibrary.searchQuery = newValue
                }

            if !searchText.isEmpty {
                Button("Clear") {
                    searchText = ""
                    exerciseLibrary.searchQuery = ""
                }
                .font(.caption)
                .foregroundColor(.accentColor)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
        .padding(.top)
    }

    // MARK: - Active Filters

    private var activeFiltersView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Muscle Group Filters
                ForEach(Array(exerciseLibrary.selectedMuscleGroups), id: \.self) { muscleGroup in
                    FilterTag(
                        text: muscleGroup.displayName,
                        color: .blue,
                        onRemove: {
                            exerciseLibrary.removeMuscleGroupFilter(muscleGroup)
                        }
                    )
                }

                // Equipment Filters
                ForEach(Array(exerciseLibrary.selectedEquipment), id: \.self) { equipment in
                    FilterTag(
                        text: equipment,
                        color: .green,
                        onRemove: {
                            exerciseLibrary.removeEquipmentFilter(equipment)
                        }
                    )
                }

                // Clear All Button
                if exerciseLibrary.hasActiveFilters {
                    Button("Clear All") {
                        exerciseLibrary.clearSearch()
                        selectedMuscleGroups.removeAll()
                        selectedEquipment.removeAll()
                    }
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(15)
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }

    // MARK: - Exercise List

    private var exerciseListView: some View {
        List {
            ForEach(exerciseLibrary.searchResults) { exercise in
                ExerciseRow(exercise: exercise) {
                    onExerciseSelected(exercise)
                }
            }
        }
        .listStyle(PlainListStyle())
    }

    // MARK: - Loading State

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)

            Text("Loading exercises...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 50))
                .foregroundColor(.secondary)

            Text("No exercises found")
                .font(.headline)
                .foregroundColor(.secondary)

            if exerciseLibrary.hasActiveFilters {
                Text("Try adjusting your filters")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Button("Clear Filters") {
                    exerciseLibrary.clearSearch()
                    selectedMuscleGroups.removeAll()
                    selectedEquipment.removeAll()
                }
                .foregroundColor(.accentColor)
            } else {
                Text("Try a different search term")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Exercise Row

struct ExerciseRow: View {
    let exercise: ExerciseModel
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                // Exercise Icon
                Image(systemName: exercise.iconName)
                    .font(.title2)
                    .foregroundColor(.accentColor)
                    .frame(width: 40, height: 40)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(8)

                // Exercise Info
                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.name)
                        .font(.headline)
                        .foregroundColor(.primary)

                    HStack {
                        if let primaryMuscle = exercise.primaryMuscleGroup {
                            Text(primaryMuscle.displayName)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(10)
                        }

                        Text(exercise.equipment)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.1))
                            .foregroundColor(.green)
                            .cornerRadius(10)

                        Spacer()
                    }

                    Text(exercise.shortInstructions)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "plus.circle")
                    .font(.title2)
                    .foregroundColor(.accentColor)
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Filter Tag

struct FilterTag: View {
    let text: String
    let color: Color
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.caption)
                .foregroundColor(color)

            Button(action: onRemove) {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundColor(color)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Exercise Filters View

struct ExerciseFiltersView: View {
    @ObservedObject var exerciseLibrary: ExerciseLibrary
    @Binding var selectedMuscleGroups: Set<MuscleGroup>
    @Binding var selectedEquipment: Set<String>

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                Section("Muscle Groups") {
                    ForEach(exerciseLibrary.availableMuscleGroups, id: \.self) { muscleGroup in
                        Toggle(muscleGroup.displayName, isOn: Binding(
                            get: { exerciseLibrary.selectedMuscleGroups.contains(muscleGroup) },
                            set: { isSelected in
                                if isSelected {
                                    exerciseLibrary.addMuscleGroupFilter(muscleGroup)
                                    selectedMuscleGroups.insert(muscleGroup)
                                } else {
                                    exerciseLibrary.removeMuscleGroupFilter(muscleGroup)
                                    selectedMuscleGroups.remove(muscleGroup)
                                }
                            }
                        ))
                    }
                }

                Section("Equipment") {
                    ForEach(exerciseLibrary.equipmentTypes, id: \.self) { equipment in
                        Toggle(equipment, isOn: Binding(
                            get: { exerciseLibrary.selectedEquipment.contains(equipment) },
                            set: { isSelected in
                                if isSelected {
                                    exerciseLibrary.addEquipmentFilter(equipment)
                                    selectedEquipment.insert(equipment)
                                } else {
                                    exerciseLibrary.removeEquipmentFilter(equipment)
                                    selectedEquipment.remove(equipment)
                                }
                            }
                        ))
                    }
                }

                Section {
                    Button("Clear All Filters") {
                        exerciseLibrary.clearSearch()
                        selectedMuscleGroups.removeAll()
                        selectedEquipment.removeAll()
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ExerciseLibraryView(exerciseLibrary: ExerciseLibrary.preview) { exercise in
        print("Selected: \(exercise.name)")
    }
}