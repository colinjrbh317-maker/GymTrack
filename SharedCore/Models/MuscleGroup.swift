import Foundation

public enum MuscleGroup: String, CaseIterable, Codable {
    case chest = "Chest"
    case back = "Back"
    case shoulders = "Shoulders"
    case biceps = "Biceps"
    case triceps = "Triceps"
    case forearms = "Forearms"
    case abs = "Abs"
    case quadriceps = "Quadriceps"
    case hamstrings = "Hamstrings"
    case glutes = "Glutes"
    case calves = "Calves"
    case traps = "Traps"
    case lats = "Lats"
    case delts = "Delts"

    public var displayName: String {
        return rawValue
    }

    public var iconName: String {
        switch self {
        case .chest:
            return "figure.strengthtraining.traditional"
        case .back:
            return "figure.rowing"
        case .shoulders:
            return "figure.martial.arts"
        case .biceps, .triceps:
            return "figure.strengthtraining.functional"
        case .forearms:
            return "hand.raised"
        case .abs:
            return "figure.core.training"
        case .quadriceps, .hamstrings:
            return "figure.walk"
        case .glutes:
            return "figure.squat"
        case .calves:
            return "figure.run"
        case .traps, .lats, .delts:
            return "figure.strengthtraining.traditional"
        }
    }
}