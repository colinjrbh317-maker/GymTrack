import Foundation

/// Calculator for generating warm-up sets based on working weight and user preferences
public class WarmupCalculator {

    // MARK: - Public Types

    public enum WeightUnit: String, CaseIterable, Codable {
        case pounds = "lbs"
        case kilograms = "kg"

        public var plateIncrements: [Double] {
            switch self {
            case .pounds:
                return [45, 35, 25, 10, 5, 2.5]
            case .kilograms:
                return [25, 20, 15, 10, 5, 2.5, 1.25]
            }
        }

        public var defaultIncrement: Double {
            switch self {
            case .pounds:
                return 5.0
            case .kilograms:
                return 2.5
            }
        }

        public var fineIncrement: Double {
            switch self {
            case .pounds:
                return 2.5
            case .kilograms:
                return 1.25
            }
        }

        public var standardBarWeight: Double {
            switch self {
            case .pounds:
                return 45.0 // Standard Olympic barbell
            case .kilograms:
                return 20.0 // Standard Olympic barbell
            }
        }
    }

    public struct WarmupSet {
        public let percentage: Double
        public let targetReps: Int
        public let weight: Double
        public let roundedWeight: Double

        public init(percentage: Double, targetReps: Int, weight: Double, roundedWeight: Double) {
            self.percentage = percentage
            self.targetReps = targetReps
            self.weight = weight
            self.roundedWeight = roundedWeight
        }

        public var formattedWeight: String {
            return String(format: "%.1f", roundedWeight)
        }

        public var formattedPercentage: String {
            return String(format: "%.0f%%", percentage * 100)
        }
    }

    public struct WarmupSettings {
        public let numberOfWarmups: Int
        public let weightUnit: WeightUnit
        public let useFineIncrements: Bool
        public let barWeight: Double?
        public let estimatedOneRM: Double?

        public init(
            numberOfWarmups: Int = 3,
            weightUnit: WeightUnit = .pounds,
            useFineIncrements: Bool = false,
            barWeight: Double? = nil,
            estimatedOneRM: Double? = nil
        ) {
            self.numberOfWarmups = numberOfWarmups
            self.weightUnit = weightUnit
            self.useFineIncrements = useFineIncrements
            self.barWeight = barWeight
            self.estimatedOneRM = estimatedOneRM
        }
    }

    // MARK: - Private Properties

    private static let warmupFormulas: [Int: [(percentage: Double, reps: Int)]] = [
        1: [(0.60, 5)],
        2: [(0.50, 5), (0.70, 3)],
        3: [(0.40, 5), (0.60, 3), (0.75, 2)],
        4: [(0.35, 6), (0.50, 5), (0.65, 3), (0.75, 2)],
        5: [(0.25, 8), (0.40, 6), (0.55, 4), (0.70, 2), (0.80, 1)]
    ]

    // MARK: - Public Methods

    /// Generate warm-up sets for a given working weight
    /// - Parameters:
    ///   - workingWeight: Target working set weight
    ///   - settings: Warm-up configuration settings
    /// - Returns: Array of warm-up sets ordered from lightest to heaviest
    public static func generateWarmupSets(
        workingWeight: Double,
        settings: WarmupSettings
    ) -> [WarmupSet] {

        guard workingWeight > 0,
              let formula = warmupFormulas[settings.numberOfWarmups] else {
            return []
        }

        var warmupSets: [WarmupSet] = []

        for (percentage, reps) in formula {
            let targetWeight = workingWeight * percentage
            let adjustedWeight = applyWeightConstraints(
                targetWeight: targetWeight,
                workingWeight: workingWeight,
                settings: settings
            )
            let roundedWeight = roundToIncrement(
                weight: adjustedWeight,
                settings: settings
            )

            let warmupSet = WarmupSet(
                percentage: percentage,
                targetReps: reps,
                weight: targetWeight,
                roundedWeight: roundedWeight
            )

            warmupSets.append(warmupSet)
        }

        return warmupSets
    }

    /// Calculate plate loading for a given weight
    /// - Parameters:
    ///   - targetWeight: Weight to load
    ///   - barWeight: Barbell weight (defaults to standard for unit)
    ///   - availablePlates: Available plate denominations
    ///   - unit: Weight unit
    /// - Returns: Tuple of (plates per side, total achievable weight)
    public static func calculatePlateLoading(
        targetWeight: Double,
        barWeight: Double? = nil,
        availablePlates: [Double]? = nil,
        unit: WeightUnit
    ) -> (platesPerSide: [Double: Int], achievableWeight: Double) {

        let barWeight = barWeight ?? unit.standardBarWeight
        let plates = availablePlates ?? unit.plateIncrements
        let weightToLoad = max(0, targetWeight - barWeight)
        let weightPerSide = weightToLoad / 2.0

        var platesPerSide: [Double: Int] = [:]
        var remainingWeight = weightPerSide

        // Start with heaviest plates first
        for plateWeight in plates.sorted(by: >) {
            let plateCount = Int(remainingWeight / plateWeight)
            if plateCount > 0 {
                platesPerSide[plateWeight] = plateCount
                remainingWeight -= Double(plateCount) * plateWeight
            }
        }

        let achievableWeightPerSide = platesPerSide.reduce(0.0) { total, pair in
            total + (Double(pair.value) * pair.key)
        }
        let totalAchievableWeight = barWeight + (achievableWeightPerSide * 2.0)

        return (platesPerSide, totalAchievableWeight)
    }

    /// Check if an exercise is a compound lift that should have warm-ups by default
    /// - Parameter exerciseName: Name of the exercise
    /// - Returns: True if the exercise is a major compound lift
    public static func isCompoundLift(_ exerciseName: String) -> Bool {
        let compoundLifts = [
            "squat", "bench", "deadlift", "overhead press", "ohp",
            "military press", "front squat", "back squat",
            "incline bench", "decline bench", "sumo deadlift",
            "romanian deadlift", "rdl", "clean", "snatch",
            "clean and jerk", "push press", "thruster"
        ]

        let lowercaseName = exerciseName.lowercased()
        return compoundLifts.contains { lowercaseName.contains($0) }
    }

    /// Estimate 1RM using Epley formula
    /// - Parameters:
    ///   - weight: Weight lifted
    ///   - reps: Number of repetitions
    /// - Returns: Estimated 1RM
    public static func estimateOneRM(weight: Double, reps: Int) -> Double {
        guard reps > 0 && weight > 0 else { return 0 }
        if reps == 1 { return weight }

        // Epley formula: 1RM = weight × (1 + reps/30)
        return weight * (1 + Double(reps) / 30.0)
    }

    // MARK: - Private Methods

    private static func applyWeightConstraints(
        targetWeight: Double,
        workingWeight: Double,
        settings: WarmupSettings
    ) -> Double {
        var adjustedWeight = targetWeight

        // Apply 1RM constraints if available
        if let oneRM = settings.estimatedOneRM {
            let maxWarmupPercentage = 0.85
            let maxWarmupWeight = oneRM * maxWarmupPercentage
            adjustedWeight = min(adjustedWeight, maxWarmupWeight)
        }

        // Ensure minimum weight (bar weight)
        let barWeight = settings.barWeight ?? settings.weightUnit.standardBarWeight
        adjustedWeight = max(adjustedWeight, barWeight)

        return adjustedWeight
    }

    private static func roundToIncrement(
        weight: Double,
        settings: WarmupSettings
    ) -> Double {
        let increment = settings.useFineIncrements ?
            settings.weightUnit.fineIncrement :
            settings.weightUnit.defaultIncrement

        return round(weight / increment) * increment
    }
}

// MARK: - Extensions

extension WarmupCalculator.WarmupSet: Equatable {
    public static func == (lhs: WarmupCalculator.WarmupSet, rhs: WarmupCalculator.WarmupSet) -> Bool {
        return lhs.percentage == rhs.percentage &&
               lhs.targetReps == rhs.targetReps &&
               lhs.weight == rhs.weight &&
               lhs.roundedWeight == rhs.roundedWeight
    }
}

extension WarmupCalculator.WarmupSettings: Equatable {
    public static func == (lhs: WarmupCalculator.WarmupSettings, rhs: WarmupCalculator.WarmupSettings) -> Bool {
        return lhs.numberOfWarmups == rhs.numberOfWarmups &&
               lhs.weightUnit == rhs.weightUnit &&
               lhs.useFineIncrements == rhs.useFineIncrements &&
               lhs.barWeight == rhs.barWeight &&
               lhs.estimatedOneRM == rhs.estimatedOneRM
    }
}