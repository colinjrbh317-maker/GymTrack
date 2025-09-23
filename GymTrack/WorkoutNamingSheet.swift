import SwiftUI

struct WorkoutNamingSheet: View {
    @Binding var isPresented: Bool
    @State private var workoutName: String = ""
    @State private var isNameValid: Bool = false

    let onConfirm: (String) -> Void

    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Spacer()

                // Icon and Title
                VStack(spacing: 16) {
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.accentColor)

                    VStack(spacing: 8) {
                        Text("Name Your Workout")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("Give your workout a descriptive name")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }

                // Text Input
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Enter workout name", text: $workoutName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .focused($isTextFieldFocused)
                        .onChange(of: workoutName) { _, newValue in
                            validateName()
                        }
                        .onSubmit {
                            if isNameValid {
                                confirmWorkout()
                            }
                        }

                    if !workoutName.isEmpty && !isNameValid {
                        Text("Workout name must be at least 2 characters")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                .padding(.horizontal)

                // Suggestions
                VStack(alignment: .leading, spacing: 12) {
                    Text("Quick suggestions:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 8) {
                        ForEach(workoutSuggestions, id: \.self) { suggestion in
                            Button(suggestion) {
                                workoutName = suggestion
                                validateName()
                            }
                            .buttonStyle(SuggestionButtonStyle())
                        }
                    }
                }
                .padding(.horizontal)

                Spacer()

                // Action Buttons
                VStack(spacing: 12) {
                    Button("Create Workout") {
                        confirmWorkout()
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isNameValid ? Color.accentColor : Color.gray)
                    .cornerRadius(12)
                    .disabled(!isNameValid)

                    Button("Cancel") {
                        isPresented = false
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            // Auto-focus the text field and suggest a default name
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isTextFieldFocused = true
            }

            // Pre-populate with a default name based on current date
            if workoutName.isEmpty {
                workoutName = generateDefaultWorkoutName()
                validateName()
            }
        }
    }

    private var workoutSuggestions: [String] {
        [
            "Push Day",
            "Pull Day",
            "Leg Day",
            "Upper Body",
            "Full Body",
            "Core & Cardio"
        ]
    }

    private func validateName() {
        isNameValid = workoutName.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2
    }

    private func confirmWorkout() {
        guard isNameValid else { return }

        let trimmedName = workoutName.trimmingCharacters(in: .whitespacesAndNewlines)
        onConfirm(trimmedName)
        isPresented = false
    }

    private func generateDefaultWorkoutName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        let dayOfWeek = formatter.string(from: Date())
        return "\(dayOfWeek) Workout"
    }
}

// MARK: - Supporting Views

struct SuggestionButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline)
            .foregroundColor(configuration.isPressed ? .white : .accentColor)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(configuration.isPressed ? Color.accentColor : Color.accentColor.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.accentColor, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Preview

#Preview {
    WorkoutNamingSheet(isPresented: .constant(true)) { name in
        print("Workout named: \(name)")
    }
}