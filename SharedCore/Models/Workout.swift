import Foundation
import CoreData

@objc(Workout)
public class Workout: NSManagedObject {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Workout> {
        return NSFetchRequest<Workout>(entityName: "Workout")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var exercises: NSSet?
    @NSManaged public var sessions: NSSet?

}

// MARK: Generated accessors for exercises
extension Workout {

    @objc(addExercisesObject:)
    @NSManaged public func addToExercises(_ value: WorkoutExercise)

    @objc(removeExercisesObject:)
    @NSManaged public func removeFromExercises(_ value: WorkoutExercise)

    @objc(addExercises:)
    @NSManaged public func addToExercises(_ values: NSSet)

    @objc(removeExercises:)
    @NSManaged public func removeFromExercises(_ values: NSSet)

}

// MARK: Generated accessors for sessions
extension Workout {

    @objc(addSessionsObject:)
    @NSManaged public func addToSessions(_ value: WorkoutSession)

    @objc(removeSessionsObject:)
    @NSManaged public func removeFromSessions(_ value: WorkoutSession)

    @objc(addSessions:)
    @NSManaged public func addToSessions(_ values: NSSet)

    @objc(removeSessions:)
    @NSManaged public func removeFromSessions(_ values: NSSet)

}

extension Workout : Identifiable {

}