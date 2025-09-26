import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            WorkoutBuilderView()
                .tabItem {
                    Image(systemName: "plus.circle")
                    Text("Build")
                }

            WorkoutLibraryView()
                .tabItem {
                    Image(systemName: "list.bullet")
                    Text("Workouts")
                }

            ExerciseLibraryView(exerciseLibrary: ExerciseLibrary()) { _ in
                // Handle exercise selection in main library view
            }
            .tabItem {
                Image(systemName: "dumbbell")
                Text("Exercises")
            }

            ProgressView()
                .tabItem {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                    Text("Progress")
                }
        }
        .accentColor(.primary)
    }
}

// MARK: - Workout Library View

struct WorkoutLibraryView: View {
    @StateObject private var workoutBuilder = WorkoutBuilder()
    @State private var workoutToDuplicate: WorkoutModel?
    @State private var showingDuplicationSheet = false

    var body: some View {
        NavigationView {
            VStack {
                if workoutBuilder.savedWorkouts.isEmpty {
                    emptyStateView
                } else {
                    workoutListView
                }
            }
            .navigationTitle("My Workouts")
            .navigationBarTitleDisplayMode(.large)
        }
        .onAppear {
            Task {
                await workoutBuilder.refresh()
            }
        }
        .sheet(isPresented: $showingDuplicationSheet) {
            if let workout = workoutToDuplicate {
                WorkoutDuplicationSheet(
                    isPresented: $showingDuplicationSheet,
                    originalWorkout: workout
                ) { newName in
                    duplicateWorkout(workout, newName: newName)
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 60))
                .foregroundColor(.secondary)

            VStack(spacing: 8) {
                Text("No Workouts Yet")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Create your first workout using the Build tab")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()
        }
        .padding()
    }

    private var workoutListView: some View {
        List {
            ForEach(workoutBuilder.savedWorkouts) { workout in
                WorkoutLibraryRow(workout: workout)
                    .contextMenu {
                        Button(action: {
                            showDuplicationSheet(for: workout)
                        }) {
                            Label("Duplicate", systemImage: "doc.on.doc")
                        }

                        Button(action: {
                            deleteWorkout(workout)
                        }) {
                            Label("Delete", systemImage: "trash")
                        }
                        .foregroundColor(.red)
                    }
            }
            .onDelete(perform: deleteWorkouts)
        }
        .listStyle(PlainListStyle())
    }

    private func deleteWorkouts(offsets: IndexSet) {
        for index in offsets {
            let workout = workoutBuilder.savedWorkouts[index]
            Task {
                try? await workoutBuilder.deleteWorkout(id: workout.id)
            }
        }
    }

    private func deleteWorkout(_ workout: WorkoutModel) {
        Task {
            try? await workoutBuilder.deleteWorkout(id: workout.id)
        }
    }

    private func showDuplicationSheet(for workout: WorkoutModel) {
        workoutToDuplicate = workout
        showingDuplicationSheet = true
    }

    private func duplicateWorkout(_ workout: WorkoutModel, newName: String) {
        Task {
            do {
                let _ = try await workoutBuilder.duplicateWorkout(workout, newName: newName)
                // Success - the workout builder will automatically refresh the list
            } catch {
                print("❌ Failed to duplicate workout: \(error)")
                // TODO: Show error alert to user
            }
        }
    }
}

struct WorkoutLibraryRow: View {
    let workout: WorkoutModel

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(workout.displayName)
                    .font(.headline)

                Spacer()

                if workout.isRecentlyUpdated {
                    Image(systemName: "circle.fill")
                        .foregroundColor(.green)
                        .font(.caption2)
                }
            }

            Text(workout.shortDescription)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .lineLimit(2)

            HStack {
                Label(workout.formattedUpdatedDate, systemImage: "clock")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Progress View Placeholder

struct ProgressView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.system(size: 60))
                    .foregroundColor(.secondary)

                VStack(spacing: 8) {
                    Text("Progress Tracking")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Track your fitness journey with detailed analytics")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                Text("Coming Soon")
                    .font(.caption)
                    .foregroundColor(.orange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)

                Spacer()
            }
            .padding()
            .navigationTitle("Progress")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    ContentView()
}