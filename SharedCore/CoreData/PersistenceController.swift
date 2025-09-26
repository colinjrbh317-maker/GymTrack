import CoreData
import Foundation

public class PersistenceController: ObservableObject {
    public static let shared = PersistenceController()

    public static var preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)

        // Add sample data for previews
        let context = result.container.viewContext

        // Sample Exercise
        let sampleExercise = Exercise(context: context)
        sampleExercise.id = UUID()
        sampleExercise.name = "Bench Press"
        sampleExercise.instructions = "Lie on bench, press weight up"
        sampleExercise.equipment = "Barbell"
        sampleExercise.primaryMuscleGroups = ["Chest", "Triceps"]
        sampleExercise.createdAt = Date()

        // Sample Workout
        let sampleWorkout = Workout(context: context)
        sampleWorkout.id = UUID()
        sampleWorkout.name = "Push Day A"
        sampleWorkout.createdAt = Date()
        sampleWorkout.updatedAt = Date()

        // Sample WorkoutExercise
        let sampleWorkoutExercise = WorkoutExercise(context: context)
        sampleWorkoutExercise.id = UUID()
        sampleWorkoutExercise.workout = sampleWorkout
        sampleWorkoutExercise.exercise = sampleExercise
        sampleWorkoutExercise.targetSets = 3
        sampleWorkoutExercise.targetReps = 10
        sampleWorkoutExercise.restSeconds = 120
        sampleWorkoutExercise.orderIndex = 1

        do {
            try context.save()
        } catch {
            print("Preview data creation failed: \(error)")
        }

        return result
    }()

    public let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        // Find the bundle containing the Core Data model
        let bundle = Bundle.module
        guard let modelURL = bundle.url(forResource: "GymTrack", withExtension: "momd") else {
            // Fallback for development/testing
            container = NSPersistentContainer(name: "GymTrack")
            if inMemory {
                container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
            }
            loadStores()
            return
        }

        guard let model = NSManagedObjectModel(contentsOf: modelURL) else {
            fatalError("Failed to load Core Data model from \(modelURL)")
        }

        container = NSPersistentContainer(name: "GymTrack", managedObjectModel: model)

        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }

        loadStores()
    }

    private func loadStores() {
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Core Data error: \(error), \(error.userInfo)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true

        // Configure context for better performance
        container.viewContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        container.viewContext.undoManager = nil
    }

    public func save() {
        let context = container.viewContext

        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nsError = error as NSError
                print("Core Data save error: \(nsError), \(nsError.userInfo)")
                // In production, you might want to handle this more gracefully
                // For now, we'll just print the error instead of crashing
            }
        }
    }

    public func saveContext() {
        save()
    }

    // MARK: - Background Context Operations

    public func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) -> Void) {
        container.performBackgroundTask(block)
    }

    public func newBackgroundContext() -> NSManagedObjectContext {
        return container.newBackgroundContext()
    }
}

// MARK: - Bundle Extension for Package Resources
extension Bundle {
    static var module: Bundle {
        Bundle(for: PersistenceController.self)
    }
}