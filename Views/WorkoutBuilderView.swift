import SwiftUI

struct WorkoutBuilderView: View {
    @StateObject private var workoutBuilder = WorkoutBuilder()
    @StateObject private var exerciseLibrary = ExerciseLibrary()

    @State private var showingExerciseLibrary = false
    @State private var showingWorkoutSave = false
    @State private var showingWorkoutNaming = false
    @State private var autoOpenExerciseLibrary = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if workoutBuilder.isBuildingWorkout {
                    buildingWorkoutView
                } else {
                    emptyStateView
                }
            }
            .navigationTitle("Workout Builder")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if workoutBuilder.isBuildingWorkout {
                        Button("Save") {
                            saveWorkout()
                        }
                        .disabled(!workoutBuilder.isValid)
                    } else {
                        Button("New Workout") {
                            showWorkoutNaming()
                        }
                    }
                }

                ToolbarItem(placement: .navigationBarLeading) {
                    if workoutBuilder.isBuildingWorkout {
                        Button("Cancel") {
                            cancelWorkout()
                        }
                    }
                }
            }
            .sheet(isPresented: $showingWorkoutNaming) {
                WorkoutNamingSheet(isPresented: $showingWorkoutNaming) { workoutName in
                    startNewWorkout(name: workoutName)
                    autoOpenExerciseLibrary = true
                }
            }
            .sheet(isPresented: $showingExerciseLibrary) {
                ExerciseLibraryView(exerciseLibrary: exerciseLibrary) { exercise in
                    addExercise(exercise)
                    showingExerciseLibrary = false
                }
            }
            .onChange(of: autoOpenExerciseLibrary) { _, shouldOpen in
                if shouldOpen && workoutBuilder.isBuildingWorkout {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showingExerciseLibrary = true
                        autoOpenExerciseLibrary = false
                    }
                }
            }
            .alert("Error", isPresented: .constant(errorMessage != nil)) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - Building Workout View

    private var buildingWorkoutView: some View {
        VStack(spacing: 16) {
            // Workout Header
            workoutHeaderView

            // Exercise List
            if workoutBuilder.hasExercises {
                exerciseListView
            } else {
                emptyExerciseListView
            }

            // Add Exercise Button
            addExerciseButton

            // Workout Stats
            workoutStatsView
        }
        .padding()
    }

    private var workoutHeaderView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text(workoutBuilder.currentWorkout?.displayName ?? "New Workout")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Building workout...")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if workoutBuilder.isDirty {
                    Image(systemName: "circle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                }
            }

            if !workoutBuilder.isValid {
                Label("Workout has validation errors", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private var exerciseListView: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(workoutBuilder.workoutExercises) { workoutExercise in
                    WorkoutExerciseRow(
                        workoutExercise: workoutExercise,
                        exercise: workoutBuilder.getExercise(for: workoutExercise),
                        onUpdate: { sets, reps, rest in
                            updateExercise(workoutExercise.id, sets: sets, reps: reps, restSeconds: rest)
                        },
                        onDelete: {
                            deleteExercise(workoutExercise.id)
                        }
                    )
                    .onTapGesture {
                        // Explicitly do nothing to prevent any accidental taps
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    private var emptyExerciseListView: some View {
        VStack(spacing: 16) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 50))
                .foregroundColor(.secondary)

            Text("No exercises added yet")
                .font(.headline)
                .foregroundColor(.secondary)

            Text("Add exercises to build your workout")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 40)
    }

    private var addExerciseButton: some View {
        Button(action: {
            showingExerciseLibrary = true
        }) {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("Add Exercise")
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color.accentColor)
            .cornerRadius(12)
        }
    }

    private var workoutStatsView: some View {
        let stats = workoutBuilder.getWorkoutStatistics()

        HStack(spacing: 20) {
            StatView(
                title: "Exercises",
                value: "\(stats.exerciseCount)",
                icon: "list.bullet"
            )

            StatView(
                title: "Duration",
                value: stats.formattedDuration,
                icon: "clock"
            )

            StatView(
                title: "Difficulty",
                value: stats.difficulty.description,
                icon: "chart.bar"
            )
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "dumbbell.fill")
                .font(.system(size: 80))
                .foregroundColor(.accentColor)

            VStack(spacing: 8) {
                Text("Ready to Build?")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Create a custom workout with exercises from our library")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button("Create New Workout") {
                showWorkoutNaming()
            }
            .font(.headline)
            .foregroundColor(.white)
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
            .background(Color.accentColor)
            .cornerRadius(25)

            if workoutBuilder.savedWorkoutCount > 0 {
                Text("\(workoutBuilder.savedWorkoutCount) saved workouts")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding()
    }

    // MARK: - Actions

    private func showWorkoutNaming() {
        showingWorkoutNaming = true
    }

    private func startNewWorkout(name: String) {
        workoutBuilder.startNewWorkout(name: name)
    }

    private func cancelWorkout() {
        workoutBuilder.cancelEditing()
    }

    private func saveWorkout() {
        Task {
            do {
                try await workoutBuilder.saveWorkout()
                showingWorkoutSave = true
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func addExercise(_ exercise: ExerciseModel) {
        workoutBuilder.addExercise(exercise)
    }

    private func updateExercise(_ id: UUID, sets: Int, reps: Int, restSeconds: Int) {
        workoutBuilder.updateExercise(id: id, sets: sets, reps: reps, restSeconds: restSeconds)
    }

    private func deleteExercise(_ id: UUID) {
        workoutBuilder.removeExercise(id: id)
    }
}

// MARK: - Supporting Views

struct WorkoutExerciseRow: View {
    let workoutExercise: WorkoutExerciseModel
    let exercise: ExerciseModel?
    let onUpdate: (Int, Int, Int) -> Void
    let onDelete: () -> Void

    @State private var sets: Int
    @State private var reps: Int
    @State private var restSeconds: Int
    @State private var showingDetails = false
    @State private var showingDeleteConfirmation = false

    init(
        workoutExercise: WorkoutExerciseModel,
        exercise: ExerciseModel?,
        onUpdate: @escaping (Int, Int, Int) -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.workoutExercise = workoutExercise
        self.exercise = exercise
        self.onUpdate = onUpdate
        self.onDelete = onDelete

        self._sets = State(initialValue: workoutExercise.targetSets)
        self._reps = State(initialValue: workoutExercise.targetReps)
        self._restSeconds = State(initialValue: workoutExercise.restSeconds)
    }

    var body: some View {
        VStack(spacing: 12) {
            // Exercise Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise?.name ?? "Unknown Exercise")
                        .font(.headline)

                    if let exercise = exercise {
                        Text(exercise.primaryMuscleGroup?.displayName ?? "")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                DeleteButton(
                    onDelete: {
                        showingDeleteConfirmation = true
                    }
                )
            }

            // Configuration Controls
            VStack(spacing: 12) {
                HStack(spacing: 20) {
                    // Sets Configuration
                    VStack(spacing: 6) {
                        Text("Sets")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)

                        HStack(spacing: 8) {
                            Button(action: { decrementSets() }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(sets > 1 ? .accentColor : .gray)
                            }
                            .disabled(sets <= 1)
                            .buttonStyle(PlainButtonStyle())

                            Text("\(sets)")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .frame(minWidth: 30)

                            Button(action: { incrementSets() }) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(sets < 10 ? .accentColor : .gray)
                            }
                            .disabled(sets >= 10)
                            .buttonStyle(PlainButtonStyle())
                        }
                    }

                    // Reps Configuration
                    VStack(spacing: 6) {
                        Text("Reps")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)

                        HStack(spacing: 8) {
                            Button(action: { decrementReps() }) {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(reps > 1 ? .accentColor : .gray)
                            }
                            .disabled(reps <= 1)
                            .buttonStyle(PlainButtonStyle())

                            Text("\(reps)")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .frame(minWidth: 30)

                            Button(action: { incrementReps() }) {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundColor(reps < 50 ? .accentColor : .gray)
                            }
                            .disabled(reps >= 50)
                            .buttonStyle(PlainButtonStyle())
                        }
                    }

                    // Rest Configuration
                    VStack(spacing: 6) {
                        Text("Rest")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)

                        Button(action: { showingDetails = true }) {
                            Text(workoutExercise.formattedRestTime)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.accentColor)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.accentColor.opacity(0.1))
                                .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.2), radius: 2, x: 0, y: 1)
        .allowsHitTesting(true) // Ensure hit testing works properly
        .alert("Delete Exercise", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                onDelete()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to remove \"\(exercise?.name ?? "this exercise")\" from your workout?")
        }
    }

    // MARK: - Helper Methods

    private func incrementSets() {
        if sets < 10 {
            sets += 1
            onUpdate(sets, reps, restSeconds)
        }
    }

    private func decrementSets() {
        if sets > 1 {
            sets -= 1
            onUpdate(sets, reps, restSeconds)
        }
    }

    private func incrementReps() {
        if reps < 50 {
            reps += 1
            onUpdate(sets, reps, restSeconds)
        }
    }

    private func decrementReps() {
        if reps > 1 {
            reps -= 1
            onUpdate(sets, reps, restSeconds)
        }
    }
}

struct StatView: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.accentColor)

            Text(value)
                .font(.headline)
                .fontWeight(.semibold)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Delete Button Component

struct DeleteButton: View {
    let onDelete: () -> Void
    @State private var isPressed = false
    
    var body: some View {
        Image(systemName: "trash.fill")
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.white)
            .frame(width: 28, height: 28)
            .background(Color.red)
            .clipShape(Circle())
            .scaleEffect(isPressed ? 0.9 : 1.0)
            .onTapGesture {
                // Do nothing on tap - require long press
            }
            .onLongPressGesture(minimumDuration: 0.5, maximumDistance: 50) {
                onDelete()
            } onPressingChanged: { pressing in
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = pressing
                }
            }
            .accessibilityLabel("Delete exercise")
            .accessibilityHint("Long press to confirm deletion")
    }
}

#Preview {
    WorkoutBuilderView()
}