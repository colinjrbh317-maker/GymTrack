import Foundation
import CoreData

@objc(WorkoutExercise)
public class WorkoutExercise: NSManagedObject {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<WorkoutExercise> {
        return NSFetchRequest<WorkoutExercise>(entityName: "WorkoutExercise")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var orderIndex: Int16
    @NSManaged public var targetSets: Int16
    @NSManaged public var targetReps: Int16
    @NSManaged public var restSeconds: Int32
    @NSManaged public var supersetGroup: String?
    @NSManaged public var workout: Workout?
    @NSManaged public var exercise: Exercise?

    // Warm-up configuration
    @NSManaged public var enableWarmups: Bool
    @NSManaged public var warmupCount: Int16
    @NSManaged public var workingWeight: Double
    @NSManaged public var weightUnit: String?
    @NSManaged public var useFineIncrements: Bool
    @NSManaged public var estimatedOneRM: Double

    // Exercise notes
    @NSManaged public var notes: String?
    @NSManaged public var privateNotes: String?

}

extension WorkoutExercise : Identifiable {

}

// MARK: - Warm-up Support

extension WorkoutExercise {

    /// Get warm-up settings for this exercise
    public var warmupSettings: WarmupCalculator.WarmupSettings {
        let unit = WarmupCalculator.WeightUnit(rawValue: weightUnit ?? "lbs") ?? .pounds
        return WarmupCalculator.WarmupSettings(
            numberOfWarmups: Int(warmupCount),
            weightUnit: unit,
            useFineIncrements: useFineIncrements,
            estimatedOneRM: estimatedOneRM > 0 ? estimatedOneRM : nil
        )
    }

    /// Update warm-up settings for this exercise
    public func updateWarmupSettings(_ settings: WarmupCalculator.WarmupSettings) {
        enableWarmups = true
        warmupCount = Int16(settings.numberOfWarmups)
        weightUnit = settings.weightUnit.rawValue
        useFineIncrements = settings.useFineIncrements
        if let oneRM = settings.estimatedOneRM {
            estimatedOneRM = oneRM
        }
    }

    /// Generate warm-up sets for current working weight
    public func generateWarmupSets() -> [WarmupCalculator.WarmupSet] {
        guard enableWarmups && workingWeight > 0 else { return [] }

        return WarmupCalculator.generateWarmupSets(
            workingWeight: workingWeight,
            settings: warmupSettings
        )
    }

    /// Check if this exercise should have warm-ups enabled by default
    public var shouldEnableWarmupsByDefault: Bool {
        guard let exerciseName = exercise?.name else { return false }
        return WarmupCalculator.isCompoundLift(exerciseName)
    }

    /// Formatted working weight for display
    public var formattedWorkingWeight: String {
        guard workingWeight > 0 else { return "—" }
        let unit = WarmupCalculator.WeightUnit(rawValue: weightUnit ?? "lbs") ?? .pounds
        return String(format: "%.1f %@", workingWeight, unit.rawValue)
    }
}

// MARK: - Notes Support

extension WorkoutExercise {

    /// Check if exercise has any notes
    public var hasNotes: Bool {
        return !(notes?.isEmpty ?? true) || !(privateNotes?.isEmpty ?? true)
    }

    /// Combined notes for display (public notes only)
    public var displayNotes: String? {
        return notes?.isEmpty == false ? notes : nil
    }

    /// Set public notes
    public func setNotes(_ text: String?) {
        notes = text?.isEmpty == true ? nil : text
    }

    /// Set private notes
    public func setPrivateNotes(_ text: String?) {
        privateNotes = text?.isEmpty == true ? nil : text
    }
}