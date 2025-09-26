import Foundation
import CoreData

@objc(LoggedSet)
public class LoggedSet: NSManagedObject {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<LoggedSet> {
        return NSFetchRequest<LoggedSet>(entityName: "LoggedSet")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var weight: Double
    @NSManaged public var reps: Int16
    @NSManaged public var rpe: Int16
    @NSManaged public var toFailure: Bool
    @NSManaged public var loggedAt: Date?
    @NSManaged public var exerciseId: UUID?
    @NSManaged public var session: WorkoutSession?

}

extension LoggedSet : Identifiable {

}