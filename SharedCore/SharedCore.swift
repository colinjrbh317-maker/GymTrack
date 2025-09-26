import Foundation
import CoreData

public struct SharedCore {
    public static let persistence = PersistenceController.shared

    public static func initialize() {
        // Initialize Core Data stack
        _ = persistence
        print("SharedCore initialized with Core Data stack")
    }
}