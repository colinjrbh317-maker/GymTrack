import Foundation
import CoreData

@objc(Exercise)
public class Exercise: NSManagedObject {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Exercise> {
        return NSFetchRequest<Exercise>(entityName: "Exercise")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var instructions: String?
    @NSManaged public var imageName: String?
    @NSManaged public var equipment: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var primaryMuscleGroups: [String]?
    @NSManaged public var secondaryMuscleGroups: [String]?
    @NSManaged public var workoutExercises: NSSet?

}

// MARK: Generated accessors for workoutExercises
extension Exercise {

    @objc(addWorkoutExercisesObject:)
    @NSManaged public func addToWorkoutExercises(_ value: WorkoutExercise)

    @objc(removeWorkoutExercisesObject:)
    @NSManaged public func removeFromWorkoutExercises(_ value: WorkoutExercise)

    @objc(addWorkoutExercises:)
    @NSManaged public func addToWorkoutExercises(_ values: NSSet)

    @objc(removeWorkoutExercises:)
    @NSManaged public func removeFromWorkoutExercises(_ values: NSSet)

}

extension Exercise : Identifiable {

}