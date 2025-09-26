import SwiftUI
import Combine
import Speech
import AVFoundation

// MARK: - Enhanced Models
struct DetailedExercise: Identifiable {
    let id = UUID()
    let name: String
    let instructions: String
    let equipment: String
    let primaryMuscle: String
    let secondaryMuscles: [String]

    var muscleDisplay: String {
        if secondaryMuscles.isEmpty {
            return primaryMuscle
        }
        return "\(primaryMuscle) (+\(secondaryMuscles.count) more)"
    }
}

struct DetailedWorkout: Identifiable, Codable {
    let id = UUID()
    let name: String
    let exercises: [WorkoutExercise]
    let createdAt = Date()

    var totalSets: Int {
        exercises.reduce(0) { $0 + $1.sets }
    }

    var estimatedDuration: Int {
        // Rough estimate: 30 seconds per set + rest time
        let exerciseTime = exercises.reduce(0) { total, exercise in
            total + (exercise.sets * 30) + (exercise.sets * exercise.restSeconds)
        }
        return exerciseTime / 60 // Convert to minutes
    }

    var difficulty: String {
        let totalVolume = exercises.reduce(0) { $0 + ($1.sets * $1.reps) }
        if totalVolume < 50 { return "Beginner" }
        else if totalVolume < 100 { return "Intermediate" }
        else { return "Advanced" }
    }
}

struct WorkoutExercise: Identifiable, Codable {
    let id = UUID()
    let exerciseName: String
    var sets: Int
    var reps: Int
    var restSeconds: Int

    var restDisplay: String {
        if restSeconds < 60 {
            return "\(restSeconds)s"
        } else {
            let minutes = restSeconds / 60
            let seconds = restSeconds % 60
            return seconds == 0 ? "\(minutes)m" : "\(minutes)m \(seconds)s"
        }
    }
}

// MARK: - Workout Session Models
struct WorkoutSession: Identifiable {
    let id = UUID()
    let workout: DetailedWorkout
    let startTime = Date()
    var endTime: Date?
    var sessionExercises: [SessionExercise]

    var isCompleted: Bool {
        endTime != nil
    }

    var duration: TimeInterval {
        (endTime ?? Date()).timeIntervalSince(startTime)
    }

    init(workout: DetailedWorkout) {
        self.workout = workout
        self.sessionExercises = workout.exercises.map { workoutExercise in
            SessionExercise(workoutExercise: workoutExercise)
        }
    }
}

struct SessionExercise: Identifiable {
    let id = UUID()
    let exerciseName: String
    let targetSets: Int
    let targetReps: Int
    let restSeconds: Int
    var completedSets: [LoggedSet] = []

    init(workoutExercise: WorkoutExercise) {
        self.exerciseName = workoutExercise.exerciseName
        self.targetSets = workoutExercise.sets
        self.targetReps = workoutExercise.reps
        self.restSeconds = workoutExercise.restSeconds
    }

    var isCompleted: Bool {
        completedSets.count >= targetSets
    }

    var completionPercentage: Double {
        Double(completedSets.count) / Double(targetSets)
    }
}

struct LoggedSet: Identifiable {
    let id = UUID()
    var weight: Double
    var reps: Int
    let timestamp = Date()
    var isCompleted: Bool = false
}

// MARK: - Voice Input Manager
class VoiceInputManager: ObservableObject {
    @Published var isListening = false
    @Published var transcribedText = ""
    @Published var hasPermission = false

    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?

    init() {
        requestPermissions()
    }

    func requestPermissions() {
        SFSpeechRecognizer.requestAuthorization { [weak self] authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    self?.hasPermission = true
                case .denied, .restricted, .notDetermined:
                    self?.hasPermission = false
                @unknown default:
                    self?.hasPermission = false
                }
            }
        }
    }

    func startListening() {
        guard hasPermission, let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            return
        }

        // Cancel any previous task
        recognitionTask?.cancel()
        recognitionTask = nil

        // Setup audio session
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try? audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }
        recognitionRequest.shouldReportPartialResults = true

        // Setup audio input
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }

        audioEngine.prepare()
        try? audioEngine.start()

        isListening = true
        transcribedText = ""

        // Start recognition task
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            DispatchQueue.main.async {
                if let result = result {
                    self?.transcribedText = result.bestTranscription.formattedString
                }

                if error != nil || result?.isFinal == true {
                    self?.stopListening()
                }
            }
        }
    }

    func stopListening() {
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        isListening = false
    }

    private func convertWordNumbersToDigits(_ text: String) -> String {
        let wordToNumber: [String: String] = [
            "zero": "0", "one": "1", "two": "2", "three": "3", "four": "4", "five": "5",
            "six": "6", "seven": "7", "eight": "8", "nine": "9", "ten": "10",
            "eleven": "11", "twelve": "12", "thirteen": "13", "fourteen": "14", "fifteen": "15",
            "sixteen": "16", "seventeen": "17", "eighteen": "18", "nineteen": "19", "twenty": "20",
            "twenty-one": "21", "twenty-two": "22", "twenty-three": "23", "twenty-four": "24", "twenty-five": "25",
            "thirty": "30", "forty": "40", "fifty": "50", "sixty": "60", "seventy": "70", "eighty": "80", "ninety": "90",
            "hundred": "100", "one hundred": "100", "two hundred": "200", "three hundred": "300"
        ]

        var convertedText = text.lowercased()

        // Replace word numbers with digits
        for (word, digit) in wordToNumber {
            convertedText = convertedText.replacingOccurrences(of: " \(word) ", with: " \(digit) ")
            convertedText = convertedText.replacingOccurrences(of: " \(word)", with: " \(digit)")
            convertedText = convertedText.replacingOccurrences(of: "\(word) ", with: "\(digit) ")

            // Handle start/end of string
            if convertedText.hasPrefix("\(word) ") {
                convertedText = "\(digit)" + String(convertedText.dropFirst(word.count))
            }
            if convertedText.hasSuffix(" \(word)") {
                convertedText = String(convertedText.dropLast(word.count + 1)) + " \(digit)"
            }
            if convertedText == word {
                convertedText = digit
            }
        }

        return convertedText
    }

    func parseSetInput(_ text: String) -> (weight: Double?, reps: Int?) {
        // First convert word numbers to digits
        let convertedText = convertWordNumbersToDigits(text)
        let lowercased = convertedText.lowercased()
        print("🎤 Parsing: '\(text)' → '\(convertedText)'") // Debug output

        var weight: Double?
        var reps: Int?

        // Handle common gym terminology first
        if lowercased.contains("bodyweight") || lowercased.contains("body weight") {
            weight = 0
            print("📝 Found bodyweight")
        } else if lowercased.contains("plate") {
            if lowercased.contains("two plate") || lowercased.contains("2 plate") || lowercased.contains("two plates") {
                weight = 225
                print("📝 Found two plates = 225")
            } else if lowercased.contains("three plate") || lowercased.contains("3 plate") || lowercased.contains("three plates") {
                weight = 315
                print("📝 Found three plates = 315")
            } else if lowercased.contains("one plate") || lowercased.contains("1 plate") || lowercased.contains("plate") {
                weight = 135
                print("📝 Found one plate = 135")
            }
        }

        // If no plate terminology, extract all numbers first
        let numberPattern = #"\b(\d+(?:\.\d+)?)\b"#
        var allNumbers: [Double] = []

        if let regex = try? NSRegularExpression(pattern: numberPattern) {
            let matches = regex.matches(in: convertedText, range: NSRange(convertedText.startIndex..., in: convertedText))
            for match in matches {
                if let numberRange = Range(match.range(at: 1), in: convertedText),
                   let number = Double(String(convertedText[numberRange])) {
                    allNumbers.append(number)
                }
            }
        }

        print("📝 All numbers found: \(allNumbers)")

        // If we haven't found weight from plates, look for weight patterns
        if weight == nil && !allNumbers.isEmpty {
            // Look for weight with units first
            let weightWithUnitsPatterns = [
                #"(\d+(?:\.\d+)?)\s*(?:lbs?|pounds?|pound)"#,
                #"(\d+(?:\.\d+)?)\s*(?:kg|kilos?|kilo)"#
            ]

            for pattern in weightWithUnitsPatterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                   let match = regex.firstMatch(in: convertedText, options: [], range: NSRange(convertedText.startIndex..., in: convertedText)),
                   let weightRange = Range(match.range(at: 1), in: convertedText) {
                    weight = Double(String(convertedText[weightRange]))
                    print("📝 Found weight with units: \(weight!)")
                    break
                }
            }

            // If no units found, assume first larger number (>20) is weight
            if weight == nil {
                if let firstLargeNumber = allNumbers.first(where: { $0 > 20 }) {
                    weight = firstLargeNumber
                    print("📝 Assuming weight (>20): \(weight!)")
                }
            }
        }

        // Look for reps
        let repPatterns = [
            #"(\d+)\s*(?:reps?|repetitions?|rep)"#,
            #"(?:for|times?|time|x)\s*(\d+)"#,
            #"(\d+)\s*(?:times?|time)"#
        ]

        for pattern in repPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: convertedText, options: [], range: NSRange(convertedText.startIndex..., in: convertedText)),
               let repRange = Range(match.range(at: 1), in: convertedText) {
                reps = Int(String(convertedText[repRange]))
                print("📝 Found reps with pattern: \(reps!)")
                break
            }
        }

        // If no reps pattern found, look for smaller numbers (1-50 range)
        if reps == nil && !allNumbers.isEmpty {
            if let repNumber = allNumbers.first(where: { $0 >= 1 && $0 <= 50 && $0 != weight }) {
                reps = Int(repNumber)
                print("📝 Assuming reps (1-50): \(reps!)")
            }
        }

        // Common speech patterns
        if weight == nil || reps == nil {
            // "I did 135 for 12" pattern
            let didPattern = #"(?:i\s+did\s+|did\s+)?(\d+(?:\.\d+)?)\s+(?:for|times?)\s+(\d+)"#
            if let regex = try? NSRegularExpression(pattern: didPattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: convertedText, options: [], range: NSRange(convertedText.startIndex..., in: convertedText)) {
                if let weightRange = Range(match.range(at: 1), in: convertedText),
                   let repRange = Range(match.range(at: 2), in: convertedText) {
                    weight = Double(String(convertedText[weightRange]))
                    reps = Int(String(convertedText[repRange]))
                    print("📝 Found 'did X for Y' pattern: \(weight!) lbs, \(reps!) reps")
                }
            }
        }

        print("📝 Final result: weight=\(weight?.description ?? "nil"), reps=\(reps?.description ?? "nil")")
        return (weight, reps)
    }
}

// MARK: - Exercise Data
class ExerciseDatabase: ObservableObject {
    static let shared = ExerciseDatabase()

    @Published var exercises: [DetailedExercise] = [
        DetailedExercise(name: "Bench Press", instructions: "Lie on bench with eyes under the bar. Grip bar slightly wider than shoulders. Lower bar to chest with control. Press explosively back to starting position. Keep feet planted and core tight throughout movement.", equipment: "Barbell", primaryMuscle: "Chest", secondaryMuscles: ["Triceps", "Shoulders"]),
        DetailedExercise(name: "Squat", instructions: "Stand with feet shoulder-width apart. Rest bar on upper traps. Lower down by sitting back and bending knees. Keep chest up and knees in line with toes. Drive through heels to return to standing.", equipment: "Barbell", primaryMuscle: "Quadriceps", secondaryMuscles: ["Glutes", "Hamstrings"]),
        DetailedExercise(name: "Deadlift", instructions: "Stand with feet hip-width apart, bar over mid-foot. Hinge at hips and knees to grip bar. Keep back straight. Drive through heels and hips to stand tall. Lower with control by pushing hips back.", equipment: "Barbell", primaryMuscle: "Hamstrings", secondaryMuscles: ["Glutes", "Back", "Traps"]),
        DetailedExercise(name: "Pull-up", instructions: "Hang from pull-up bar with arms fully extended. Pull body up until chin clears bar. Lower with control back to starting position. Keep core engaged throughout movement.", equipment: "Bodyweight", primaryMuscle: "Lats", secondaryMuscles: ["Biceps", "Back"]),
        DetailedExercise(name: "Push-up", instructions: "Start in plank position with hands slightly wider than shoulders. Lower chest to floor while keeping straight line from head to heels. Push back up to starting position.", equipment: "Bodyweight", primaryMuscle: "Chest", secondaryMuscles: ["Triceps", "Shoulders"]),
        DetailedExercise(name: "Overhead Press", instructions: "Stand with feet hip-width apart. Press bar from shoulders directly overhead. Keep core tight and avoid arching back. Lower bar back to shoulders with control.", equipment: "Barbell", primaryMuscle: "Shoulders", secondaryMuscles: ["Triceps", "Chest"]),
        DetailedExercise(name: "Bent-over Row", instructions: "Hinge at hips with slight knee bend. Keep back straight and chest up. Pull bar to lower chest/upper abdomen. Squeeze shoulder blades together. Lower with control.", equipment: "Barbell", primaryMuscle: "Back", secondaryMuscles: ["Biceps", "Lats"]),
        DetailedExercise(name: "Dumbbell Chest Press", instructions: "Lie on bench holding dumbbells at chest level. Press dumbbells up and together. Lower with control allowing deeper stretch than barbell. Keep core engaged throughout.", equipment: "Dumbbell", primaryMuscle: "Chest", secondaryMuscles: ["Triceps", "Shoulders"]),
        DetailedExercise(name: "Goblet Squat", instructions: "Hold dumbbell at chest level with both hands. Stand with feet slightly wider than shoulders. Lower down keeping chest up and weight on heels. Drive through heels to stand.", equipment: "Dumbbell", primaryMuscle: "Quadriceps", secondaryMuscles: ["Glutes", "Hamstrings"]),
        DetailedExercise(name: "Dumbbell Row", instructions: "Place one knee and hand on bench. Hold dumbbell in opposite hand. Pull dumbbell to hip keeping elbow close to body. Squeeze back muscles at top. Lower with control.", equipment: "Dumbbell", primaryMuscle: "Back", secondaryMuscles: ["Biceps", "Lats"]),
        DetailedExercise(name: "Dip", instructions: "Support body on parallel bars with arms straight. Lower body by bending elbows until shoulders are below elbows. Push back up to starting position. Keep body upright.", equipment: "Bodyweight", primaryMuscle: "Triceps", secondaryMuscles: ["Chest", "Shoulders"]),
        DetailedExercise(name: "Plank", instructions: "Start in push-up position but on forearms. Keep straight line from head to heels. Engage core and glutes. Hold position breathing normally. Avoid sagging hips or raising butt.", equipment: "Bodyweight", primaryMuscle: "Abs", secondaryMuscles: ["Shoulders", "Back"]),
        DetailedExercise(name: "Lateral Raise", instructions: "Hold dumbbells at sides with slight bend in elbows. Raise weights out to sides until arms are parallel to floor. Lower with control. Keep slight forward lean.", equipment: "Dumbbell", primaryMuscle: "Shoulders", secondaryMuscles: ["Delts"]),
        DetailedExercise(name: "Romanian Deadlift", instructions: "Hold bar with overhand grip. Keep slight bend in knees. Hinge at hips pushing butt back. Lower bar along legs feeling stretch in hamstrings. Drive hips forward to return.", equipment: "Barbell", primaryMuscle: "Hamstrings", secondaryMuscles: ["Glutes", "Back"]),
        DetailedExercise(name: "Leg Press", instructions: "Sit in leg press machine with feet on platform shoulder-width apart. Lower weight by bending knees to 90 degrees. Press through heels to return to starting position.", equipment: "Machine", primaryMuscle: "Quadriceps", secondaryMuscles: ["Glutes", "Hamstrings"]),
        DetailedExercise(name: "Bicep Curl", instructions: "Hold dumbbells at sides with palms facing forward. Curl weights up by flexing biceps. Keep elbows stationary at sides. Lower with control back to starting position.", equipment: "Dumbbell", primaryMuscle: "Biceps", secondaryMuscles: ["Forearms"]),
        DetailedExercise(name: "Tricep Extension", instructions: "Lie on bench holding dumbbell with both hands overhead. Lower weight behind head by bending elbows. Keep upper arms stationary. Extend back to starting position.", equipment: "Dumbbell", primaryMuscle: "Triceps", secondaryMuscles: ["Shoulders"]),
        DetailedExercise(name: "Lunge", instructions: "Step forward into lunge position. Lower back knee toward ground keeping front knee over ankle. Push through front heel to return to starting position. Alternate legs.", equipment: "Bodyweight", primaryMuscle: "Quadriceps", secondaryMuscles: ["Glutes", "Hamstrings"]),
        DetailedExercise(name: "Calf Raise", instructions: "Stand with balls of feet on platform, heels hanging off. Raise up onto toes as high as possible. Hold briefly then lower heels below platform level for stretch.", equipment: "Bodyweight", primaryMuscle: "Calves", secondaryMuscles: []),
        DetailedExercise(name: "Incline Bench Press", instructions: "Set bench to 30-45 degree incline. Lie back and grip bar slightly wider than shoulders. Lower bar to upper chest. Press back to starting position focusing on upper chest activation.", equipment: "Barbell", primaryMuscle: "Chest", secondaryMuscles: ["Triceps", "Shoulders"])
    ]

    func searchExercises(query: String, equipment: String = "All") -> [DetailedExercise] {
        var filtered = exercises

        // Filter by equipment
        if equipment != "All" {
            filtered = filtered.filter { $0.equipment == equipment }
        }

        // Filter by search query
        if !query.isEmpty {
            filtered = filtered.filter { exercise in
                exercise.name.localizedCaseInsensitiveContains(query) ||
                exercise.primaryMuscle.localizedCaseInsensitiveContains(query) ||
                exercise.equipment.localizedCaseInsensitiveContains(query)
            }
        }

        return filtered
    }

    var equipmentTypes: [String] {
        ["All"] + Array(Set(exercises.map { $0.equipment })).sorted()
    }
}

// MARK: - Workout Store
class WorkoutStore: ObservableObject {
    static let shared = WorkoutStore()

    @Published var savedWorkouts: [DetailedWorkout] = []

    private let userDefaults = UserDefaults.standard
    private let key = "savedWorkouts"

    init() {
        loadWorkouts()
    }

    func saveWorkout(_ workout: DetailedWorkout) {
        savedWorkouts.append(workout)
        persistWorkouts()
    }

    func updateWorkout(_ updatedWorkout: DetailedWorkout) {
        if let index = savedWorkouts.firstIndex(where: { $0.id == updatedWorkout.id }) {
            savedWorkouts[index] = updatedWorkout
            persistWorkouts()
        }
    }

    func deleteWorkout(at offsets: IndexSet) {
        savedWorkouts.remove(atOffsets: offsets)
        persistWorkouts()
    }

    func deleteWorkout(id: UUID) {
        savedWorkouts.removeAll { $0.id == id }
        persistWorkouts()
    }

    private func persistWorkouts() {
        if let data = try? JSONEncoder().encode(savedWorkouts) {
            userDefaults.set(data, forKey: key)
        }
    }

    private func loadWorkouts() {
        if let data = userDefaults.data(forKey: key),
           let workouts = try? JSONDecoder().decode([DetailedWorkout].self, from: data) {
            savedWorkouts = workouts
        }
    }
}

// MARK: - Onboarding Models and Views
class OnboardingStore: ObservableObject {
    static let shared = OnboardingStore()

    @Published var hasCompletedOnboarding: Bool

    private let userDefaults = UserDefaults.standard
    private let onboardingKey = "hasCompletedOnboarding"

    private init() {
        self.hasCompletedOnboarding = userDefaults.bool(forKey: onboardingKey)
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        userDefaults.set(true, forKey: onboardingKey)
    }

    func resetOnboarding() {
        hasCompletedOnboarding = false
        userDefaults.set(false, forKey: onboardingKey)
    }
}

struct OnboardingView: View {
    @StateObject private var onboardingStore = OnboardingStore.shared
    @State private var currentPage = 0
    let totalPages = 4

    var body: some View {
        VStack(spacing: 0) {
            // Progress indicator
            HStack {
                ForEach(0..<totalPages, id: \.self) { index in
                    Circle()
                        .fill(index <= currentPage ? Color.blue : Color.gray.opacity(0.3))
                        .frame(width: 10, height: 10)
                }
            }
            .padding()

            TabView(selection: $currentPage) {
                OnboardingPage1()
                    .tag(0)
                OnboardingPage2()
                    .tag(1)
                OnboardingPage3()
                    .tag(2)
                OnboardingPage4()
                    .tag(3)
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))

            // Navigation buttons
            HStack {
                if currentPage > 0 {
                    Button("Back") {
                        withAnimation {
                            currentPage -= 1
                        }
                    }
                    .foregroundColor(.blue)
                }

                Spacer()

                if currentPage < totalPages - 1 {
                    Button("Next") {
                        withAnimation {
                            currentPage += 1
                        }
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.blue)
                    .cornerRadius(8)
                } else {
                    Button("Get Started") {
                        onboardingStore.completeOnboarding()
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.green)
                    .cornerRadius(8)
                }
            }
            .padding()
        }
        .preferredColorScheme(.dark)
    }
}

struct OnboardingPage1: View {
    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            Image(systemName: "dumbbell.fill")
                .font(.system(size: 80))
                .foregroundColor(.blue)

            VStack(spacing: 16) {
                Text("Welcome to GymTrack")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Your personal fitness companion for building custom workouts and tracking progress")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()
        }
    }
}

struct OnboardingPage2: View {
    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            Image(systemName: "plus.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.green)

            VStack(spacing: 16) {
                Text("Build Custom Workouts")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Create personalized workout routines with our extensive exercise library. Set your sets, reps, and rest periods.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()
        }
    }
}

struct OnboardingPage3: View {
    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            Image(systemName: "mic.fill")
                .font(.system(size: 80))
                .foregroundColor(.orange)

            VStack(spacing: 16) {
                Text("Voice-Powered Logging")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Say \"135 pounds for 12 reps\" and we'll automatically log your set. No more fumbling with the keyboard during workouts!")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()
        }
    }
}

struct OnboardingPage4: View {
    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 80))
                .foregroundColor(.purple)

            VStack(spacing: 16) {
                Text("Track Your Progress")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Monitor your strength gains, training volume, and workout consistency with detailed analytics and charts.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Spacer()
        }
    }
}

// MARK: - Main Content View
struct ContentView: View {
    @StateObject private var exerciseDB = ExerciseDatabase.shared
    @StateObject private var workoutStore = WorkoutStore.shared
    @StateObject private var onboardingStore = OnboardingStore.shared
    @State private var selectedTab = 0

    var body: some View {
        if onboardingStore.hasCompletedOnboarding {
            TabView(selection: $selectedTab) {
                WorkoutBuilderTab(workoutStore: workoutStore)
                    .tabItem {
                        Image(systemName: "plus.circle")
                        Text("Build")
                    }
                    .tag(0)

                WorkoutLibraryTab(workoutStore: workoutStore)
                    .tabItem {
                        Image(systemName: "list.bullet")
                        Text("Workouts")
                    }
                    .tag(1)

                ExerciseLibraryTab()
                    .tabItem {
                        Image(systemName: "dumbbell")
                        Text("Exercises")
                    }
                    .tag(2)

                ProgressTab()
                    .tabItem {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                        Text("Progress")
                    }
                    .tag(3)
            }
            .preferredColorScheme(.dark)
        } else {
            OnboardingView()
        }
    }
}

// MARK: - Workout Builder Tab
struct WorkoutBuilderTab: View {
    @ObservedObject var workoutStore: WorkoutStore
    @State private var showingWorkoutBuilder = false
    @State private var showingWorkoutNaming = false

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if workoutStore.savedWorkouts.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "dumbbell.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)

                        Text("Ready to Build?")
                            .font(.title)
                            .fontWeight(.bold)

                        Text("Create custom workouts with detailed exercise configurations")
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                }

                Button("Create New Workout") {
                    showingWorkoutNaming = true
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .background(Color.blue)
                .cornerRadius(10)

                if !workoutStore.savedWorkouts.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Recent Workouts")
                            .font(.headline)
                            .padding(.horizontal)

                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(workoutStore.savedWorkouts.prefix(3)) { workout in
                                    RecentWorkoutCard(workout: workout)
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                }

                Spacer()
            }
            .navigationTitle("Workout Builder")
        }
        .sheet(isPresented: $showingWorkoutNaming) {
            WorkoutNamingSheet(isPresented: $showingWorkoutNaming) { workoutName in
                // Create a new workout with the given name
                let newWorkout = DetailedWorkout(name: workoutName, exercises: [])
                workoutStore.savedWorkouts.append(newWorkout)
                // Then open the workout builder
                showingWorkoutBuilder = true
            }
        }
        .sheet(isPresented: $showingWorkoutBuilder) {
            AdvancedWorkoutBuilder(workoutStore: workoutStore)
        }
    }
}

// MARK: - Advanced Workout Builder
struct AdvancedWorkoutBuilder: View {
    @ObservedObject var workoutStore: WorkoutStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var exerciseDB = ExerciseDatabase.shared

    @State private var workoutName = "My Workout"
    @State private var workoutExercises: [WorkoutExercise] = []
    @State private var showingExerciseSelector = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Workout Header
                VStack(spacing: 12) {
                    TextField("Workout Name", text: $workoutName)
                        .font(.title2)
                        .fontWeight(.bold)
                        .textFieldStyle(RoundedBorderTextFieldStyle())

                    if !workoutExercises.isEmpty {
                        HStack(spacing: 20) {
                            StatCard(title: "Exercises", value: "\(workoutExercises.count)", icon: "list.bullet")
                            StatCard(title: "Total Sets", value: "\(workoutExercises.reduce(0) { $0 + $1.sets })", icon: "number")
                            StatCard(title: "Est. Time", value: "\(estimatedDuration)m", icon: "clock")
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))

                // Exercise List
                if workoutExercises.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)

                        Text("No exercises added yet")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        Button("Add First Exercise") {
                            showingExerciseSelector = true
                        }
                        .foregroundColor(.blue)

                        Spacer()
                    }
                } else {
                    List {
                        ForEach(workoutExercises.indices, id: \.self) { index in
                            WorkoutExerciseRow(
                                exercise: $workoutExercises[index],
                                onDelete: {
                                    workoutExercises.remove(at: index)
                                }
                            )
                            .deleteDisabled(true)
                        }
                        .onMove(perform: moveExercises)

                        Button("Add Exercise") {
                            showingExerciseSelector = true
                        }
                        .foregroundColor(.blue)
                        .padding()
                    }
                }
            }
            .navigationTitle("Build Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveWorkout()
                    }
                    .disabled(workoutExercises.isEmpty || workoutName.isEmpty)
                }
            }
        }
        .sheet(isPresented: $showingExerciseSelector) {
            ExerciseSelector { exercise in
                addExercise(exercise)
                showingExerciseSelector = false
            }
        }
    }

    private var estimatedDuration: Int {
        let total = workoutExercises.reduce(0) { total, exercise in
            total + (exercise.sets * 30) + (exercise.sets * exercise.restSeconds)
        }
        return total / 60
    }

    private func addExercise(_ exercise: DetailedExercise) {
        let workoutExercise = WorkoutExercise(
            exerciseName: exercise.name,
            sets: 3,
            reps: 10,
            restSeconds: 60
        )
        workoutExercises.append(workoutExercise)
    }

    private func deleteExercises(offsets: IndexSet) {
        workoutExercises.remove(atOffsets: offsets)
    }

    private func moveExercises(from: IndexSet, to: Int) {
        workoutExercises.move(fromOffsets: from, toOffset: to)
    }

    private func saveWorkout() {
        let workout = DetailedWorkout(name: workoutName, exercises: workoutExercises)
        workoutStore.saveWorkout(workout)
        dismiss()
    }
}

// MARK: - Exercise Selector
struct ExerciseSelector: View {
    let onSelection: (DetailedExercise) -> Void
    @StateObject private var exerciseDB = ExerciseDatabase.shared
    @State private var searchText = ""
    @State private var selectedEquipment = "All"
    @Environment(\.dismiss) private var dismiss

    var filteredExercises: [DetailedExercise] {
        exerciseDB.searchExercises(query: searchText, equipment: selectedEquipment)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search and Filter
                VStack(spacing: 12) {
                    SearchBar(text: $searchText)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(exerciseDB.equipmentTypes, id: \.self) { equipment in
                                FilterChip(
                                    title: equipment,
                                    isSelected: selectedEquipment == equipment
                                ) {
                                    selectedEquipment = equipment
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
                .background(Color(.systemGray6))

                // Exercise List
                List(filteredExercises) { exercise in
                    DetailedExerciseRow(exercise: exercise) {
                        onSelection(exercise)
                    }
                }
            }
            .navigationTitle("Exercise Library")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Supporting Views
struct WorkoutExerciseRow: View {
    @Binding var exercise: WorkoutExercise
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(exercise.exerciseName)
                    .font(.headline)
                Spacer()
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }

            HStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text("Sets")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack {
                        Button("-") {
                            if exercise.sets > 1 { exercise.sets -= 1 }
                        }
                        .disabled(exercise.sets <= 1)

                        Text("\(exercise.sets)")
                            .font(.headline)
                            .frame(minWidth: 30)

                        Button("+") {
                            if exercise.sets < 10 { exercise.sets += 1 }
                        }
                        .disabled(exercise.sets >= 10)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }

                VStack(spacing: 4) {
                    Text("Reps")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack {
                        Button("-") {
                            if exercise.reps > 1 { exercise.reps -= 1 }
                        }
                        .disabled(exercise.reps <= 1)

                        Text("\(exercise.reps)")
                            .font(.headline)
                            .frame(minWidth: 30)

                        Button("+") {
                            if exercise.reps < 50 { exercise.reps += 1 }
                        }
                        .disabled(exercise.reps >= 50)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }

                VStack(spacing: 4) {
                    Text("Rest")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    HStack {
                        Button("-") {
                            if exercise.restSeconds > 30 { exercise.restSeconds -= 30 }
                        }
                        .disabled(exercise.restSeconds <= 30)

                        Text(exercise.restDisplay)
                            .font(.headline)
                            .frame(minWidth: 50)

                        Button("+") {
                            if exercise.restSeconds < 300 { exercise.restSeconds += 30 }
                        }
                        .disabled(exercise.restSeconds >= 300)
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct DetailedExerciseRow: View {
    let exercise: DetailedExercise
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Image(systemName: "dumbbell")
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.name)
                        .font(.headline)
                        .foregroundColor(.primary)

                    HStack {
                        Text(exercise.primaryMuscle)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.2))
                            .cornerRadius(8)

                        Text(exercise.equipment)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .cornerRadius(8)
                    }

                    Text(exercise.instructions.prefix(60) + "...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "plus.circle")
                    .foregroundColor(.blue)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SearchBar: View {
    @Binding var text: String

    var body: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("Search exercises...", text: $text)
            if !text.isEmpty {
                Button("Clear") {
                    text = ""
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .padding(.horizontal)
    }
}

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(isSelected ? Color.blue : Color(.systemGray5))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(16)
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.blue)
            Text(value)
                .font(.headline)
                .fontWeight(.semibold)
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct RecentWorkoutCard: View {
    let workout: DetailedWorkout

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(workout.name)
                .font(.headline)

            HStack {
                Text("\(workout.exercises.count) exercises")
                Spacer()
                Text(workout.difficulty)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(8)
                    .font(.caption)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

// MARK: - Other Tabs
struct WorkoutLibraryTab: View {
    @ObservedObject var workoutStore: WorkoutStore
    @State private var workoutToDuplicate: DetailedWorkout?
    @State private var showingDuplicationSheet = false

    var body: some View {
        NavigationView {
            if workoutStore.savedWorkouts.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "list.bullet.clipboard")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)

                    Text("No Workouts Yet")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Create your first workout in the Build tab")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else {
                List {
                    ForEach(workoutStore.savedWorkouts.indices, id: \.self) { index in
                        NavigationLink(destination: WorkoutDetailView(workout: $workoutStore.savedWorkouts[index], workoutStore: workoutStore)) {
                            WorkoutLibraryRow(workout: workoutStore.savedWorkouts[index])
                        }
                        .contextMenu {
                            Button(action: {
                                showDuplicationSheet(for: workoutStore.savedWorkouts[index])
                            }) {
                                Label("Duplicate", systemImage: "doc.on.doc")
                            }

                            Button(action: {
                                deleteWorkout(at: index)
                            }) {
                                Label("Delete", systemImage: "trash")
                            }
                            .foregroundColor(.red)
                        }
                    }
                    .onDelete(perform: deleteWorkouts)
                }
            }
        }
        .navigationTitle("My Workouts")
        .sheet(isPresented: $showingDuplicationSheet) {
            if let workout = workoutToDuplicate {
                WorkoutDuplicationSheet(
                    isPresented: $showingDuplicationSheet,
                    originalWorkout: workout
                ) { newName in
                    duplicateWorkout(workout, newName: newName)
                }
            }
        }
    }

    private func showDuplicationSheet(for workout: DetailedWorkout) {
        workoutToDuplicate = workout
        showingDuplicationSheet = true
    }

    private func duplicateWorkout(_ workout: DetailedWorkout, newName: String) {
        let duplicatedWorkout = DetailedWorkout(
            name: newName,
            exercises: workout.exercises
        )
        workoutStore.savedWorkouts.append(duplicatedWorkout)
    }

    private func deleteWorkout(at index: Int) {
        workoutStore.savedWorkouts.remove(at: index)
    }

    private func deleteWorkouts(offsets: IndexSet) {
        workoutStore.deleteWorkout(at: offsets)
    }
}

struct WorkoutDetailView: View {
    @Binding var workout: DetailedWorkout
    @ObservedObject var workoutStore: WorkoutStore
    @State private var showingEditSheet = false
    @State private var showingWorkoutSession = false

    var body: some View {
        List {
            Section {
                Button(action: {
                    showingWorkoutSession = true
                }) {
                    HStack {
                        Spacer()
                        Image(systemName: "play.fill")
                        Text("Start Workout")
                            .fontWeight(.semibold)
                        Spacer()
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
                }
                .buttonStyle(PlainButtonStyle())
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section("Workout Info") {
                HStack {
                    Text("Exercises")
                    Spacer()
                    Text("\(workout.exercises.count)")
                }
                HStack {
                    Text("Total Sets")
                    Spacer()
                    Text("\(workout.totalSets)")
                }
                HStack {
                    Text("Est. Duration")
                    Spacer()
                    Text("\(workout.estimatedDuration) min")
                }
                HStack {
                    Text("Difficulty")
                    Spacer()
                    Text(workout.difficulty)
                }
            }

            Section("Exercises") {
                ForEach(workout.exercises) { exercise in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(exercise.exerciseName)
                            .font(.headline)
                        Text("\(exercise.sets) sets × \(exercise.reps) reps • Rest: \(exercise.restDisplay)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle(workout.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") {
                    showingEditSheet = true
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditWorkoutView(workout: $workout, workoutStore: workoutStore)
        }
        .fullScreenCover(isPresented: $showingWorkoutSession) {
            WorkoutSessionView(workout: workout)
        }
    }
}

struct WorkoutLibraryRow: View {
    let workout: DetailedWorkout

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(workout.name)
                    .font(.headline)
                Spacer()
                Text(workout.difficulty)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(8)
            }

            HStack {
                Text("\(workout.exercises.count) exercises • \(workout.totalSets) sets")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                Text("\(workout.estimatedDuration) min")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Edit Workout View
struct EditWorkoutView: View {
    @Binding var workout: DetailedWorkout
    @ObservedObject var workoutStore: WorkoutStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var exerciseDB = ExerciseDatabase.shared

    @State private var workoutName: String
    @State private var workoutExercises: [WorkoutExercise]
    @State private var showingExerciseSelector = false

    init(workout: Binding<DetailedWorkout>, workoutStore: WorkoutStore) {
        self._workout = workout
        self.workoutStore = workoutStore
        self._workoutName = State(initialValue: workout.wrappedValue.name)
        self._workoutExercises = State(initialValue: workout.wrappedValue.exercises)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Workout Header
                VStack(spacing: 12) {
                    TextField("Workout Name", text: $workoutName)
                        .font(.title2)
                        .fontWeight(.bold)
                        .textFieldStyle(RoundedBorderTextFieldStyle())

                    if !workoutExercises.isEmpty {
                        HStack(spacing: 20) {
                            StatCard(title: "Exercises", value: "\(workoutExercises.count)", icon: "list.bullet")
                            StatCard(title: "Total Sets", value: "\(workoutExercises.reduce(0) { $0 + $1.sets })", icon: "number")
                            StatCard(title: "Est. Time", value: "\(estimatedDuration)m", icon: "clock")
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))

                // Exercise List
                if workoutExercises.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)

                        Text("No exercises in this workout")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        Button("Add Exercise") {
                            showingExerciseSelector = true
                        }
                        .foregroundColor(.blue)

                        Spacer()
                    }
                } else {
                    List {
                        ForEach(workoutExercises.indices, id: \.self) { index in
                            WorkoutExerciseRow(
                                exercise: $workoutExercises[index],
                                onDelete: {
                                    workoutExercises.remove(at: index)
                                }
                            )
                            .deleteDisabled(true)
                        }
                        .onMove(perform: moveExercises)

                        Button("Add Exercise") {
                            showingExerciseSelector = true
                        }
                        .foregroundColor(.blue)
                        .padding()
                    }
                }
            }
            .navigationTitle("Edit Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveWorkout()
                    }
                    .disabled(workoutExercises.isEmpty || workoutName.isEmpty)
                }
            }
        }
        .sheet(isPresented: $showingExerciseSelector) {
            ExerciseSelector { exercise in
                addExercise(exercise)
                showingExerciseSelector = false
            }
        }
    }

    private var estimatedDuration: Int {
        let total = workoutExercises.reduce(0) { total, exercise in
            total + (exercise.sets * 30) + (exercise.sets * exercise.restSeconds)
        }
        return total / 60
    }

    private func addExercise(_ exercise: DetailedExercise) {
        let workoutExercise = WorkoutExercise(
            exerciseName: exercise.name,
            sets: 3,
            reps: 10,
            restSeconds: 60
        )
        workoutExercises.append(workoutExercise)
    }

    private func moveExercises(from: IndexSet, to: Int) {
        workoutExercises.move(fromOffsets: from, toOffset: to)
    }

    private func saveWorkout() {
        let updatedWorkout = DetailedWorkout(name: workoutName, exercises: workoutExercises)
        workoutStore.updateWorkout(updatedWorkout)
        workout = updatedWorkout
        dismiss()
    }
}

// MARK: - Workout Session View
struct WorkoutSessionView: View {
    let workout: DetailedWorkout
    @State private var session: WorkoutSession
    @State private var currentExerciseIndex = 0
    @State private var restTimer: Timer?
    @State private var restTimeRemaining: Int = 0
    @State private var isResting = false
    @Environment(\.dismiss) private var dismiss

    init(workout: DetailedWorkout) {
        self.workout = workout
        self._session = State(initialValue: WorkoutSession(workout: workout))
    }

    var currentExercise: SessionExercise? {
        guard currentExerciseIndex < session.sessionExercises.count else { return nil }
        return session.sessionExercises[currentExerciseIndex]
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with workout progress
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(workout.name)
                                .font(.title2)
                                .fontWeight(.bold)
                            Text("Exercise \(currentExerciseIndex + 1) of \(session.sessionExercises.count)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()

                        Text(formatDuration(session.duration))
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                    }

                    // Progress bar
                    ProgressView(value: Double(currentExerciseIndex), total: Double(session.sessionExercises.count))
                        .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                }
                .padding()
                .background(Color(.systemGray6))

                if let currentExercise = currentExercise {
                    if isResting {
                        RestTimerView(
                            timeRemaining: restTimeRemaining,
                            onComplete: {
                                endRest()
                            },
                            onSkip: {
                                endRest()
                            }
                        )
                    } else {
                        ExerciseSessionView(
                            exercise: $session.sessionExercises[currentExerciseIndex],
                            onSetCompleted: { set in
                                completeSet(set)
                            },
                            onExerciseCompleted: {
                                completeExercise()
                            }
                        )
                    }
                } else {
                    // Workout completed
                    WorkoutCompletedView(session: session) {
                        dismiss()
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("End Workout") {
                        endWorkout()
                    }
                    .foregroundColor(.red)
                }
            }
        }
    }

    private func completeSet(_ set: LoggedSet) {
        session.sessionExercises[currentExerciseIndex].completedSets.append(set)

        // Check if exercise is completed
        if session.sessionExercises[currentExerciseIndex].isCompleted {
            completeExercise()
        } else {
            // Start rest timer
            startRest()
        }
    }

    private func completeExercise() {
        if currentExerciseIndex < session.sessionExercises.count - 1 {
            currentExerciseIndex += 1
        } else {
            // Workout completed
            session.endTime = Date()
        }
    }

    private func startRest() {
        guard let currentExercise = currentExercise else { return }
        isResting = true
        restTimeRemaining = currentExercise.restSeconds

        restTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if restTimeRemaining > 0 {
                restTimeRemaining -= 1
            } else {
                endRest()
            }
        }
    }

    private func endRest() {
        isResting = false
        restTimer?.invalidate()
        restTimer = nil
    }

    private func endWorkout() {
        session.endTime = Date()
        dismiss()
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Exercise Session View
struct ExerciseSessionView: View {
    @Binding var exercise: SessionExercise
    let onSetCompleted: (LoggedSet) -> Void
    let onExerciseCompleted: () -> Void

    @State private var currentWeight: String = "135"
    @State private var currentReps: String = ""
    @StateObject private var voiceInput = VoiceInputManager()
    @State private var showingVoiceInput = false

    var body: some View {
        VStack(spacing: 20) {
            // Exercise info
            VStack(spacing: 8) {
                Text(exercise.exerciseName)
                    .font(.title)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)

                Text("\(exercise.completedSets.count) / \(exercise.targetSets) sets completed")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                // Progress bar for this exercise
                ProgressView(value: exercise.completionPercentage)
                    .progressViewStyle(LinearProgressViewStyle(tint: .green))
                    .frame(height: 8)
            }
            .padding()

            // Voice-First Set logging interface
            VStack(spacing: 16) {
                Text("Log Set \(exercise.completedSets.count + 1)")
                    .font(.headline)

                // Voice Input Section
                VStack(spacing: 12) {
                    if voiceInput.hasPermission {
                        Button(action: {
                            if voiceInput.isListening {
                                voiceInput.stopListening()
                                processVoiceInput()
                            } else {
                                voiceInput.transcribedText = "" // Clear previous text
                                voiceInput.startListening()
                            }
                        }) {
                            HStack {
                                Image(systemName: voiceInput.isListening ? "stop.circle.fill" : "mic")
                                    .font(.title2)
                                Text(voiceInput.isListening ? "Tap to Stop & Parse" : "🎤 Say Your Set")
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(voiceInput.isListening ? Color.red : Color.blue)
                            .cornerRadius(12)
                            .scaleEffect(voiceInput.isListening ? 1.05 : 1.0)
                            .animation(.easeInOut(duration: 0.1), value: voiceInput.isListening)
                        }

                        if !voiceInput.transcribedText.isEmpty {
                            VStack(spacing: 8) {
                                Text("You said:")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\"\(voiceInput.transcribedText)\"")
                                    .font(.subheadline)
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)

                                if !voiceInput.isListening {
                                    Text("↓ Tap the button above to parse this into weight & reps")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                        .multilineTextAlignment(.center)
                                }
                            }
                        }
                    } else {
                        Text("Voice recognition requires microphone permission")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    Text("or enter manually")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Manual Input (Fallback)
                HStack(spacing: 20) {
                    VStack {
                        Text("Weight (lbs)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("Weight", text: $currentWeight)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.decimalPad)
                            .frame(width: 100)
                    }

                    VStack {
                        Text("Reps")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextField("\(exercise.targetReps)", text: $currentReps)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.numberPad)
                            .frame(width: 80)
                    }
                }

                Button("Complete Set") {
                    completeCurrentSet()
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .background(Color.green)
                .cornerRadius(10)
                .disabled(currentWeight.isEmpty)
            }
            .padding()

            // Previous sets
            if !exercise.completedSets.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Completed Sets")
                        .font(.headline)
                        .padding(.horizontal)

                    ForEach(Array(exercise.completedSets.enumerated()), id: \.element.id) { index, set in
                        HStack {
                            Text("Set \(index + 1)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("\(Int(set.weight)) lbs × \(set.reps) reps")
                                .font(.subheadline)
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .padding(.horizontal)
                    }
                }
            }

            Spacer()

            if exercise.isCompleted {
                Button("Next Exercise") {
                    onExerciseCompleted()
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .background(Color.blue)
                .cornerRadius(10)
                .padding()
            }
        }
    }

    private func processVoiceInput() {
        let (weight, reps) = voiceInput.parseSetInput(voiceInput.transcribedText)
        print("🔄 Processing voice input - Weight: \(weight?.description ?? "nil"), Reps: \(reps?.description ?? "nil")")

        if let parsedWeight = weight {
            currentWeight = String(Int(parsedWeight))
            print("✅ Set weight to: \(currentWeight)")
        }

        if let parsedReps = reps {
            currentReps = String(parsedReps)
            print("✅ Set reps to: \(currentReps)")
        }

        // Show feedback to user about what was parsed
        if weight != nil || reps != nil {
            print("✅ Successfully parsed voice input!")
        } else {
            print("⚠️ Could not parse weight or reps from: '\(voiceInput.transcribedText)'")
        }
    }

    private func completeCurrentSet() {
        let weight = Double(currentWeight) ?? 0
        let reps = Int(currentReps) ?? exercise.targetReps
        let set = LoggedSet(weight: weight, reps: reps, isCompleted: true)
        onSetCompleted(set)

        // Reset for next set
        currentReps = ""
        voiceInput.transcribedText = ""

        // Suggest next weight (progressive overload)
        if let lastWeight = Double(currentWeight) {
            currentWeight = String(Int(lastWeight + 5)) // Suggest 5lb increase
        }
    }
}

// MARK: - Rest Timer View
struct RestTimerView: View {
    let timeRemaining: Int
    let onComplete: () -> Void
    let onSkip: () -> Void

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            VStack(spacing: 16) {
                Text("Rest Time")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text(formatTime(timeRemaining))
                    .font(.system(size: 60, weight: .bold, design: .monospaced))
                    .foregroundColor(.blue)

                ProgressView(value: 1.0 - (Double(timeRemaining) / 120.0))
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    .frame(width: 200)
            }

            HStack(spacing: 20) {
                Button("Skip Rest") {
                    onSkip()
                }
                .font(.headline)
                .foregroundColor(.blue)
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(10)

                if timeRemaining == 0 {
                    Button("Continue") {
                        onComplete()
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.green)
                    .cornerRadius(10)
                }
            }

            Spacer()
        }
        .padding()
    }

    private func formatTime(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Workout Completed View
struct WorkoutCompletedView: View {
    let session: WorkoutSession
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 30) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.green)

                Text("Workout Complete!")
                    .font(.title)
                    .fontWeight(.bold)

                VStack(spacing: 8) {
                    Text("Duration: \(formatDuration(session.duration))")
                        .font(.headline)
                    Text("Total Sets: \(totalSetsCompleted)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Button("Finish") {
                onDismiss()
            }
            .font(.headline)
            .foregroundColor(.white)
            .padding()
            .background(Color.blue)
            .cornerRadius(10)

            Spacer()
        }
        .padding()
    }

    private var totalSetsCompleted: Int {
        session.sessionExercises.reduce(0) { $0 + $1.completedSets.count }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct ExerciseLibraryTab: View {
    @StateObject private var exerciseDB = ExerciseDatabase.shared
    @State private var searchText = ""
    @State private var selectedEquipment = "All"

    var filteredExercises: [DetailedExercise] {
        exerciseDB.searchExercises(query: searchText, equipment: selectedEquipment)
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                VStack(spacing: 12) {
                    SearchBar(text: $searchText)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(exerciseDB.equipmentTypes, id: \.self) { equipment in
                                FilterChip(
                                    title: equipment,
                                    isSelected: selectedEquipment == equipment
                                ) {
                                    selectedEquipment = equipment
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
                .background(Color(.systemGray6))

                List(filteredExercises) { exercise in
                    NavigationLink(destination: ExerciseDetailView(exercise: exercise)) {
                        ExerciseLibraryRow(exercise: exercise)
                    }
                }
            }
            .navigationTitle("Exercise Library")
        }
    }
}

struct ExerciseDetailView: View {
    let exercise: DetailedExercise

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Primary Muscle")
                        .font(.headline)
                    Text(exercise.primaryMuscle)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)

                    if !exercise.secondaryMuscles.isEmpty {
                        Text("Secondary Muscles")
                            .font(.headline)
                        Text(exercise.secondaryMuscles.joined(separator: ", "))
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(8)
                    }

                    Text("Equipment")
                        .font(.headline)
                    Text(exercise.equipment)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Text("Instructions")
                        .font(.headline)
                    Text(exercise.instructions)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
            }
            .padding()
        }
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.large)
    }
}

struct ExerciseLibraryRow: View {
    let exercise: DetailedExercise

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "dumbbell")
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(exercise.name)
                    .font(.headline)

                HStack {
                    Text(exercise.primaryMuscle)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(8)

                    Text(exercise.equipment)
                        .font(.caption)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.2))
                        .cornerRadius(8)
                }

                Text(exercise.instructions.prefix(60) + "...")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Progress Analytics Models
enum ProgressTimeframe: String, CaseIterable {
    case week = "week"
    case month = "month"
    case quarter = "quarter"
    case year = "year"

    var displayName: String {
        switch self {
        case .week: return "Week"
        case .month: return "Month"
        case .quarter: return "3 Months"
        case .year: return "Year"
        }
    }

    var days: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        case .quarter: return 90
        case .year: return 365
        }
    }
}

struct ProgressData {
    let date: Date
    let totalVolume: Double  // weight * reps
    let workoutCount: Int
    let exerciseRecords: [String: ExerciseRecord] // exerciseName: record
}

struct ExerciseRecord {
    let exerciseName: String
    let maxWeight: Double
    let maxReps: Int
    let estimatedOneRM: Double
    let totalVolume: Double
}

class ProgressStore: ObservableObject {
    static let shared = ProgressStore()

    @Published var progressData: [ProgressData] = []

    var hasData: Bool {
        !progressData.isEmpty
    }

    private init() {
        loadMockData() // For demo purposes
    }

    func addWorkoutData(_ session: WorkoutSession) {
        // This would be called when a workout is completed
        // For now, we'll use mock data
    }

    private func loadMockData() {
        // Generate mock progress data for the last 30 days
        let calendar = Calendar.current
        let endDate = Date()

        for i in 0..<30 {
            if let date = calendar.date(byAdding: .day, value: -i, to: endDate) {
                // Simulate some workout days (not every day)
                if i % 3 == 0 || i % 4 == 0 {
                    let mockData = ProgressData(
                        date: date,
                        totalVolume: Double.random(in: 5000...15000),
                        workoutCount: Int.random(in: 1...2),
                        exerciseRecords: [
                            "Bench Press": ExerciseRecord(
                                exerciseName: "Bench Press",
                                maxWeight: Double.random(in: 135...225),
                                maxReps: Int.random(in: 5...12),
                                estimatedOneRM: Double.random(in: 180...250),
                                totalVolume: Double.random(in: 2000...4000)
                            ),
                            "Squat": ExerciseRecord(
                                exerciseName: "Squat",
                                maxWeight: Double.random(in: 185...315),
                                maxReps: Int.random(in: 5...10),
                                estimatedOneRM: Double.random(in: 220...350),
                                totalVolume: Double.random(in: 3000...6000)
                            )
                        ]
                    )
                    progressData.append(mockData)
                }
            }
        }
        progressData.sort { $0.date < $1.date }
    }

    func getDataForTimeframe(_ timeframe: ProgressTimeframe) -> [ProgressData] {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -timeframe.days, to: Date()) ?? Date()
        return progressData.filter { $0.date >= cutoffDate }
    }

    func getTotalVolume(for timeframe: ProgressTimeframe) -> Double {
        getDataForTimeframe(timeframe).reduce(0) { $0 + $1.totalVolume }
    }

    func getWorkoutCount(for timeframe: ProgressTimeframe) -> Int {
        getDataForTimeframe(timeframe).reduce(0) { $0 + $1.workoutCount }
    }

    func getStrengthProgress(for exercise: String, timeframe: ProgressTimeframe) -> [ExerciseRecord] {
        return getDataForTimeframe(timeframe)
            .compactMap { $0.exerciseRecords[exercise] }
            .sorted { $0.maxWeight < $1.maxWeight }
    }
}

// MARK: - Progress Views
struct ProgressSummaryView: View {
    let timeframe: ProgressTimeframe
    @StateObject private var progressStore = ProgressStore.shared

    var body: some View {
        VStack(spacing: 16) {
            Text("Summary (\(timeframe.displayName))")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: 16) {
                SummaryCard(
                    title: "Total Volume",
                    value: "\(Int(progressStore.getTotalVolume(for: timeframe)/1000))K lbs",
                    icon: "scalemass",
                    color: .blue
                )

                SummaryCard(
                    title: "Workouts",
                    value: "\(progressStore.getWorkoutCount(for: timeframe))",
                    icon: "figure.strengthtraining.traditional",
                    color: .green
                )

                SummaryCard(
                    title: "Avg/Week",
                    value: "\(Int(Double(progressStore.getWorkoutCount(for: timeframe)) / (Double(timeframe.days) / 7.0)))",
                    icon: "calendar",
                    color: .orange
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct SummaryCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)

            Text(value)
                .font(.title3)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }
}

struct VolumeChartView: View {
    let timeframe: ProgressTimeframe
    @StateObject private var progressStore = ProgressStore.shared

    var chartData: [ProgressData] {
        progressStore.getDataForTimeframe(timeframe)
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Training Volume")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            if chartData.isEmpty {
                Text("No data available")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                // Simple bar chart representation
                VStack(spacing: 8) {
                    HStack(alignment: .bottom, spacing: 4) {
                        ForEach(Array(chartData.enumerated()), id: \.offset) { index, data in
                            VStack {
                                Rectangle()
                                    .fill(Color.blue)
                                    .frame(width: 20, height: CGFloat(data.totalVolume / 500))
                                    .cornerRadius(2)

                                Text("\(Calendar.current.component(.day, from: data.date))")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .frame(height: 100)

                    Text("Training volume by day (lbs)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct StrengthProgressView: View {
    let timeframe: ProgressTimeframe
    @StateObject private var progressStore = ProgressStore.shared

    var body: some View {
        VStack(spacing: 16) {
            Text("Strength Progress")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 12) {
                StrengthProgressRow(
                    exerciseName: "Bench Press",
                    timeframe: timeframe
                )

                StrengthProgressRow(
                    exerciseName: "Squat",
                    timeframe: timeframe
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct StrengthProgressRow: View {
    let exerciseName: String
    let timeframe: ProgressTimeframe
    @StateObject private var progressStore = ProgressStore.shared

    var progressData: [ExerciseRecord] {
        progressStore.getStrengthProgress(for: exerciseName, timeframe: timeframe)
    }

    var strengthGain: String {
        guard let first = progressData.first, let last = progressData.last else {
            return "No data"
        }
        let gain = last.maxWeight - first.maxWeight
        return gain > 0 ? "+\(Int(gain)) lbs" : "\(Int(gain)) lbs"
    }

    var currentMax: String {
        guard let latest = progressData.last else { return "0 lbs" }
        return "\(Int(latest.maxWeight)) lbs"
    }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(exerciseName)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text("Current: \(currentMax)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(strengthGain)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(strengthGain.hasPrefix("+") ? .green : .red)

                Text("Progress")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }
}

struct RecentWorkoutsView: View {
    @StateObject private var progressStore = ProgressStore.shared

    var recentWorkouts: [ProgressData] {
        Array(progressStore.progressData.suffix(5).reversed())
    }

    var body: some View {
        VStack(spacing: 16) {
            Text("Recent Workouts")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 8) {
                ForEach(Array(recentWorkouts.enumerated()), id: \.offset) { index, workout in
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(workout.date, style: .date)
                                .font(.subheadline)
                                .fontWeight(.medium)

                            Text("\(workout.exerciseRecords.count) exercises")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 4) {
                            Text("\(Int(workout.totalVolume/1000))K lbs")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            Text("Volume")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct ProgressTab: View {
    @StateObject private var progressStore = ProgressStore.shared
    @State private var selectedTimeframe: ProgressTimeframe = .month

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Timeframe Selector
                    VStack(spacing: 12) {
                        Text("Progress Overview")
                            .font(.title2)
                            .fontWeight(.bold)

                        Picker("Timeframe", selection: $selectedTimeframe) {
                            ForEach(ProgressTimeframe.allCases, id: \.self) { timeframe in
                                Text(timeframe.displayName).tag(timeframe)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)

                    if progressStore.hasData {
                        // Summary Stats
                        ProgressSummaryView(timeframe: selectedTimeframe)

                        // Volume Chart
                        VolumeChartView(timeframe: selectedTimeframe)

                        // Strength Progress
                        StrengthProgressView(timeframe: selectedTimeframe)

                        // Recent Workouts
                        RecentWorkoutsView()
                    } else {
                        // Empty State
                        VStack(spacing: 16) {
                            Image(systemName: "chart.line.uptrend.xyaxis")
                                .font(.system(size: 60))
                                .foregroundColor(.secondary)

                            Text("No Progress Data Yet")
                                .font(.title2)
                                .fontWeight(.semibold)

                            Text("Complete some workouts to see your progress analytics")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                    }
                }
                .padding()
            }
            .navigationTitle("Progress")
        }
    }
}

#Preview {
    ContentView()
}