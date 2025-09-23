import SwiftUI
import WorkoutBuilder

struct WorkoutDuplicationSheet: View {
    @Binding var isPresented: Bool
    let originalWorkout: WorkoutModel
    let onConfirm: (String) -> Void

    @State private var newWorkoutName: String = ""
    @State private var isNameValid: Bool = false

    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Spacer()

                // Icon and Title
                VStack(spacing: 16) {
                    Image(systemName: "doc.on.doc.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.accentColor)

                    VStack(spacing: 8) {
                        Text("Duplicate Workout")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("Create a copy of \"\(originalWorkout.displayName)\"")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }

                // Text Input
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Enter new workout name", text: $newWorkoutName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .focused($isTextFieldFocused)
                        .onChange(of: newWorkoutName) { _, newValue in
                            validateName()
                        }
                        .onSubmit {
                            if isNameValid {
                                confirmDuplication()
                            }
                        }

                    if !newWorkoutName.isEmpty && !isNameValid {
                        Text("Workout name must be at least 2 characters")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
                .padding(.horizontal)

                // Quick Suggestions
                VStack(alignment: .leading, spacing: 12) {
                    Text("Quick suggestions:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)

                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 8) {
                        ForEach(nameSuggestions, id: \.self) { suggestion in
                            Button(suggestion) {
                                newWorkoutName = suggestion
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
                    Button("Duplicate Workout") {
                        confirmDuplication()
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

            // Pre-populate with a suggested name
            newWorkoutName = generateDefaultName()
            validateName()
        }
    }

    private var nameSuggestions: [String] {
        let baseName = originalWorkout.displayName
        return [
            "\(baseName) Copy",
            "\(baseName) v2",
            "\(baseName) Modified",
            "My \(baseName)"
        ]
    }

    private func validateName() {
        isNameValid = newWorkoutName.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2
    }

    private func confirmDuplication() {
        guard isNameValid else { return }

        let trimmedName = newWorkoutName.trimmingCharacters(in: .whitespacesAndNewlines)
        onConfirm(trimmedName)
        isPresented = false
    }

    private func generateDefaultName() -> String {
        let baseName = originalWorkout.displayName
        return "\(baseName) Copy"
    }
}

#Preview {
    WorkoutDuplicationSheet(
        isPresented: .constant(true),
        originalWorkout: WorkoutModel(
            name: "Push Day",
            createdAt: Date(),
            updatedAt: Date()
        )
    ) { name in
        print("Duplicated workout named: \(name)")
    }
}