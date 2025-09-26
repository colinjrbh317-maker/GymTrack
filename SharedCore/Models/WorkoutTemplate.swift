import Foundation
import CoreData

// MARK: - WorkoutTemplate Core Data Entity

@objc(WorkoutTemplate)
public class WorkoutTemplate: NSManagedObject {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<WorkoutTemplate> {
        return NSFetchRequest<WorkoutTemplate>(entityName: "WorkoutTemplate")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var exercisesData: Data?
    @NSManaged public var estimatedDuration: TimeInterval
    @NSManaged public var difficulty: String?
    @NSManaged public var muscleGroups: [String]?
    @NSManaged public var equipment: [String]?
    @NSManaged public var createdAt: Date?
}

extension WorkoutTemplate {
    /// Initialize with default values
    public override func awakeFromInsert() {
        super.awakeFromInsert()
        id = UUID()
        createdAt = Date()
        estimatedDuration = 0
    }
}