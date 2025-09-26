import Foundation
import CoreData

@objc(WorkoutSession)
public class WorkoutSession: NSManagedObject {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<WorkoutSession> {
        return NSFetchRequest<WorkoutSession>(entityName: "WorkoutSession")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var startedAt: Date?
    @NSManaged public var completedAt: Date?
    @NSManaged public var status: String?
    @NSManaged public var workout: Workout?
    @NSManaged public var loggedSets: NSSet?

}

// MARK: Generated accessors for loggedSets
extension WorkoutSession {

    @objc(addLoggedSetsObject:)
    @NSManaged public func addToLoggedSets(_ value: LoggedSet)

    @objc(removeLoggedSetsObject:)
    @NSManaged public func removeFromLoggedSets(_ value: LoggedSet)

    @objc(addLoggedSets:)
    @NSManaged public func addToLoggedSets(_ values: NSSet)

    @objc(removeLoggedSets:)
    @NSManaged public func removeFromLoggedSets(_ values: NSSet)

}

extension WorkoutSession : Identifiable {

}