import SwiftUI

struct WarmupSetView: View {
    let warmupSet: WarmupCalculator.WarmupSet
    let onEdit: (() -> Void)?
    let onDelete: (() -> Void)?

    @State private var isSelected = false

    init(
        warmupSet: WarmupCalculator.WarmupSet,
        onEdit: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil
    ) {
        self.warmupSet = warmupSet
        self.onEdit = onEdit
        self.onDelete = onDelete
    }

    var body: some View {
        HStack(spacing: 12) {
            // Warm-up indicator
            VStack(spacing: 2) {
                Image(systemName: "flame.fill")
                    .font(.caption2)
                    .foregroundColor(.orange)

                Text("WARM")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(.orange)
            }
            .frame(width: 30)

            // Set details
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("\(warmupSet.formattedWeight)")
                        .font(.headline)
                        .fontWeight(.semibold)

                    Text("×")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text("\(warmupSet.targetReps)")
                        .font(.headline)
                        .fontWeight(.semibold)

                    Spacer()

                    Text(warmupSet.formattedPercentage)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(4)
                }

                // Weight difference indicator (if applicable)
                if abs(warmupSet.weight - warmupSet.roundedWeight) > 0.1 {
                    Text("Rounded from \(String(format: "%.1f", warmupSet.weight))")
                        .font(.caption2)
                        .foregroundColor(.orange)
                        .italic()
                }
            }

            Spacer()

            // Action buttons (if provided)
            if onEdit != nil || onDelete != nil {
                HStack(spacing: 8) {
                    if let onEdit = onEdit {
                        Button(action: onEdit) {
                            Image(systemName: "pencil")
                                .font(.caption)
                                .foregroundColor(.blue)
                                .frame(width: 24, height: 24)
                                .background(Color.blue.opacity(0.1))
                                .clipShape(Circle())
                        }
                    }

                    if let onDelete = onDelete {
                        Button(action: onDelete) {
                            Image(systemName: "trash.fill")
                                .font(.caption)
                                .foregroundColor(.red)
                                .frame(width: 24, height: 24)
                                .background(Color.red.opacity(0.1))
                                .clipShape(Circle())
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.orange.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

// MARK: - Container View for Multiple Warm-ups

struct WarmupSetsView: View {
    let warmupSets: [WarmupCalculator.WarmupSet]
    let isEditable: Bool
    let onEditSet: ((Int) -> Void)?
    let onDeleteSet: ((Int) -> Void)?
    let onAddSet: (() -> Void)?

    init(
        warmupSets: [WarmupCalculator.WarmupSet],
        isEditable: Bool = false,
        onEditSet: ((Int) -> Void)? = nil,
        onDeleteSet: ((Int) -> Void)? = nil,
        onAddSet: (() -> Void)? = nil
    ) {
        self.warmupSets = warmupSets
        self.isEditable = isEditable
        self.onEditSet = onEditSet
        self.onDeleteSet = onDeleteSet
        self.onAddSet = onAddSet
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "flame.fill")
                        .font(.subheadline)
                        .foregroundColor(.orange)

                    Text("Warm-up Sets")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }

                Spacer()

                if isEditable, let onAddSet = onAddSet {
                    Button(action: onAddSet) {
                        Image(systemName: "plus.circle.fill")
                            .font(.subheadline)
                            .foregroundColor(.orange)
                    }
                }
            }

            // Warm-up sets
            if warmupSets.isEmpty {
                Text("No warm-up sets configured")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
                    .padding(.vertical, 8)
            } else {
                VStack(spacing: 6) {
                    ForEach(Array(warmupSets.enumerated()), id: \.offset) { index, warmupSet in
                        WarmupSetView(
                            warmupSet: warmupSet,
                            onEdit: isEditable ? { onEditSet?(index) } : nil,
                            onDelete: isEditable ? { onDeleteSet?(index) } : nil
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Warm-up Configuration View

struct WarmupConfigurationView: View {
    @Binding var workoutExercise: WorkoutExerciseModel
    @State private var showingWeightInput = false
    @State private var tempWorkingWeight: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Enable/Disable Toggle
            HStack {
                Toggle("Enable Warm-ups", isOn: $workoutExercise.enableWarmups)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            if workoutExercise.enableWarmups {
                VStack(alignment: .leading, spacing: 12) {
                    // Working Weight Input
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Working Weight")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)

                        HStack {
                            Button(action: { showingWeightInput.toggle() }) {
                                HStack {
                                    Text(workoutExercise.formattedWorkingWeight)
                                        .font(.subheadline)
                                        .foregroundColor(workoutExercise.workingWeight > 0 ? .primary : .secondary)

                                    Image(systemName: "pencil")
                                        .font(.caption2)
                                        .foregroundColor(.blue)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color(.systemGray6))
                                .cornerRadius(6)
                            }

                            Spacer()
                        }
                    }

                    // Number of Warm-ups
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Number of Warm-ups")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)

                        HStack {
                            ForEach(1...5, id: \.self) { count in
                                Button("\(count)") {
                                    workoutExercise.warmupCount = count
                                }
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(workoutExercise.warmupCount == count ? .white : .accentColor)
                                .frame(width: 32, height: 32)
                                .background(
                                    Circle().fill(
                                        workoutExercise.warmupCount == count ?
                                        Color.accentColor : Color.accentColor.opacity(0.1)
                                    )
                                )
                            }

                            Spacer()
                        }
                    }

                    // Weight Unit
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Weight Unit")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)

                        Picker("Weight Unit", selection: $workoutExercise.weightUnit) {
                            Text("lbs").tag(WarmupCalculator.WeightUnit.pounds)
                            Text("kg").tag(WarmupCalculator.WeightUnit.kilograms)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }

                    // Fine Increments Toggle
                    Toggle("Use Fine Increments (\(workoutExercise.weightUnit.fineIncrement, specifier: "%.1f") \(workoutExercise.weightUnit.rawValue))", isOn: $workoutExercise.useFineIncrements)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // Generated Warm-ups Preview
                    if workoutExercise.workingWeight > 0 {
                        WarmupSetsView(warmupSets: workoutExercise.generateWarmupSets())
                    }
                }
                .padding(.leading, 16)
            }
        }
        .alert("Enter Working Weight", isPresented: $showingWeightInput) {
            TextField("Weight", text: $tempWorkingWeight)
                .keyboardType(.decimalPad)

            Button("Save") {
                if let weight = Double(tempWorkingWeight), weight > 0 {
                    workoutExercise.workingWeight = weight
                }
                tempWorkingWeight = ""
            }

            Button("Cancel", role: .cancel) {
                tempWorkingWeight = ""
            }
        } message: {
            Text("Enter the weight you plan to use for your working sets")
        }
        .onAppear {
            // Auto-enable warm-ups for compound lifts
            if !workoutExercise.enableWarmups {
                // Note: This would need exercise name from the exercise library
                // For now, we'll leave it to manual enablement
            }
        }
    }
}

// MARK: - Previews

#Preview("Single Warm-up Set") {
    WarmupSetView(
        warmupSet: WarmupCalculator.WarmupSet(
            percentage: 0.60,
            targetReps: 5,
            weight: 121.0,
            roundedWeight: 120.0
        ),
        onEdit: { print("Edit") },
        onDelete: { print("Delete") }
    )
    .padding()
}

#Preview("Warm-up Sets View") {
    let sampleSets = WarmupCalculator.generateWarmupSets(
        workingWeight: 200,
        settings: WarmupCalculator.WarmupSettings(
            numberOfWarmups: 3,
            weightUnit: .pounds
        )
    )

    WarmupSetsView(
        warmupSets: sampleSets,
        isEditable: true,
        onEditSet: { index in print("Edit set \(index)") },
        onDeleteSet: { index in print("Delete set \(index)") },
        onAddSet: { print("Add set") }
    )
    .padding()
}

#Preview("Warm-up Configuration") {
    @State var sampleExercise = WorkoutExerciseModel(
        workoutId: UUID(),
        exerciseId: UUID(),
        targetSets: 3,
        targetReps: 10,
        restSeconds: 120,
        orderIndex: 1,
        enableWarmups: true,
        workingWeight: 185
    )

    WarmupConfigurationView(workoutExercise: $sampleExercise)
        .padding()
}