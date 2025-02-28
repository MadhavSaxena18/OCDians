import SwiftUI
import AVFoundation

struct ContentView: View {
    @State private var showOnboarding = true
    @State private var isPresented = false
    @StateObject private var sharedDataManager = SharedDataManager()
    
    init() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.95)
        
        let itemAppearance = UITabBarItemAppearance()
        itemAppearance.normal.iconColor = UIColor.systemGray2
        itemAppearance.normal.titleTextAttributes = [.foregroundColor: UIColor.systemGray2]
        itemAppearance.selected.iconColor = UIColor.systemBlue
        itemAppearance.selected.titleTextAttributes = [.foregroundColor: UIColor.systemBlue]
        
        appearance.stackedLayoutAppearance = itemAppearance
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
    
    var body: some View {
        Group {
            if showOnboarding {
                OnboardingView(showOnboarding: $showOnboarding)
                    .transition(.opacity)
            } else {
                TabView {
                    TrackerTab()
                        .environmentObject(sharedDataManager)
                        .tabItem {
                            Label("Tracker", systemImage: "chart.bar.fill")
                        }
                    
                    RelaxationTab(showBackButton: false)
                        .environmentObject(sharedDataManager)
                        .tabItem {
                            Label("Relax", systemImage: "leaf.fill")
                        }
                    
                    ERPTab(isPresented: .constant(true))
                        .environmentObject(sharedDataManager)
                        .tabItem {
                            Label("ERP", systemImage: "clock")
                        }
                }
            }
        }
        .animation(.easeInOut, value: showOnboarding)
    }
}


struct TutorialOverlayView: View {
    let title: String
    let steps: [(icon: String, text: String)]
    let onDismiss: () -> Void
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.75)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                VStack(alignment: .leading, spacing: 16) {
                    ForEach(steps, id: \.text) { step in
                        HStack(spacing: 12) {
                            Image(systemName: step.icon)
                                .foregroundColor(.blue)
                                .font(.system(size: 24))
                            
                            Text(step.text)
                                .foregroundColor(.white)
                                .font(.body)
                        }
                    }
                }
                .padding(.vertical)
                
                Button(action: onDismiss) {
                    Text("Got it!")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
            }
            .padding()
            .background(Color.black.opacity(0.5))
            .cornerRadius(20)
            .padding()
        }
    }
}

struct TrackerTab: View {
    @EnvironmentObject private var shared: SharedDataManager
    @State private var newEntry = ""
    @State private var selectedObsession: OCDEntry? = nil
    @State private var compulsion: String = ""
    @State private var showDeleteAllConfirmation = false
    @Environment(\.editMode) private var editMode
    @State private var selectedEntryForStrategies: OCDEntry? = nil
    
    @State private var currentMood: Int = 3
    @State private var showMoodInputs = false
    @State private var selectedTriggers: Set<String> = []
    @State private var moodNote: String = ""
    @State private var showLogs = false
    @State private var selectedEntries = Set<OCDEntry>()
    @State private var isEditing = false
    @State private var showClearHistoryConfirmation = false
    
   
    let copingStrategies: [String: [String]] = [
        "Fear of contamination": [
            "Mindfulness",
            "Gradual Exposure",
            "Hand-washing control",
            "Cognitive Restructuring",
            "Delayed Response Strategy"
        ],
        "Fear of harm": [
            "Thought Defusion",
            "Reality Checking",
            "Exposure Therapy",
            "Cognitive Reframing",
            "Mindfulness-Based Anxiety Reduction"
        ],
        "Checking behavior": [
            "Limiting Checking",
            "Confidence Building",
            "Postpone Checking",
            "Journaling Assurances",
            "Reducing Ritual Frequency"
        ],
        "Intrusive thoughts": [
            "Cognitive Defusion",
            "Exposure & Response Prevention (ERP)",
            "Thought Labeling",
            "Letting Thoughts Pass Without Judgment",
            "Reducing Reassurance Seeking"
        ]
    ]

   
    let triggers = [
        OCDTrigger(name: "Stress", icon: "bolt.circle.fill"),
        OCDTrigger(name: "Social", icon: "person.2.fill"),
        OCDTrigger(name: "Health", icon: "heart.fill"),
        OCDTrigger(name: "Work", icon: "briefcase.fill"),
        OCDTrigger(name: "Family", icon: "house.fill"),
        OCDTrigger(name: "Environment", icon: "leaf.fill")
    ]
    
    var matchingStrategies: [String] {
        return copingStrategies.first { newEntry.lowercased().contains($0.key.lowercased()) }?.value ?? []
    }
    
    var body: some View {
        NavigationView {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("How are you feeling?")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            Button(action: { showMoodInputs = true }) {
                                HStack {
                                    Text(moodEmoji(for: currentMood))
                                        .font(.system(size: 32))
                                    Text("Track your mood")
                                        .foregroundColor(.primary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.secondary)
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 22)
                                        .fill(Color(.systemBackground))
                                        .shadow(color: .black.opacity(0.05), radius: 5)
                                )
                            }
                        }
                        .padding(.horizontal)
                        
                      
                        VStack(spacing: 24) {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Label("Mood Trends", systemImage: "chart.xyaxis.line")
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    Spacer()
                                    
                                    if !shared.moodHistory.isEmpty {
                                        Button(role: .destructive) {
                                            showClearHistoryConfirmation = true
                                        } label: {
                                            Label("Clear History", systemImage: "trash")
                                                .font(.subheadline)
                                        }
                                    }
                                }
                                
                                if shared.moodHistory.isEmpty {
                                    EmptyStateView(
                                        imageName: "chart.bar.fill",
                                        title: "No Mood Data",
                                        message: "Start tracking your moods to see insights"
                                    )
                                } else {
                                    MoodGraphView(moodHistory: shared.moodHistory)
                                }
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(25)
                            .shadow(color: Color.black.opacity(0.05), radius: 5)
                            .padding(.horizontal)
                            .confirmationDialog(
                                "Clear Mood History",
                                isPresented: $showClearHistoryConfirmation,
                                titleVisibility: .visible
                            ) {
                                Button("Clear All History", role: .destructive) {
                                    shared.clearMoodHistory()
                                }
                                Button("Cancel", role: .cancel) {}
                            } message: {
                                Text("This will permanently delete all mood tracking data. This action cannot be undone.")
                            }
                            
                           
                            VStack(alignment: .center, spacing: 16) {
                                Label("Progress Stats", systemImage: "chart.bar.xaxis")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                
                                LazyVGrid(columns: [
                                    GridItem(.flexible(), spacing: 16),
                                    GridItem(.flexible(), spacing: 16)
                                ], spacing: 16) {
                                    StatView(
                                        title: "Average Mood",
                                        value: averageMoodText(),
                                        icon: "gauge.medium",
                                        color: averageMoodColor()
                                    )
                                    
                                    StatView(
                                        title: "Total Entries",
                                        value: "\(shared.moodHistory.count)",
                                        icon: "doc.text.badge.plus",
                                        color: .green
                                    )
                                    
                                    StatView(
                                        title: "Best Day",
                                        value: bestDay(),
                                        icon: "crown.fill",
                                        color: .yellow
                                    )
                                    
                                    StatView(
                                        title: "Streak",
                                        value: "\(currentStreak()) days",
                                        icon: "chart.line.uptrend.xyaxis.circle.fill",
                                        color: .orange
                                    )
                                }
                                .frame(maxWidth: .infinity, alignment: .center)
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(25)
                            .shadow(color: Color.black.opacity(0.05), radius: 5)
                            .padding(.horizontal)
                            
                           
                            VStack(alignment: .leading, spacing: 16) {
                                Label("Common Triggers", systemImage: "exclamationmark.triangle")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                if let triggers = mostCommonTriggers() {
                                    ForEach(Array(triggers.enumerated()), id: \.1) { index, trigger in
                                        HStack {
                                            Text("\(index + 1).")
                                                .foregroundColor(.secondary)
                                            Text(trigger)
                                                .foregroundColor(.primary)
                                            Spacer()
                                            Text("\(triggerCount(trigger))")
                                                .foregroundColor(.secondary)
                                                .font(.caption)
                                        }
                                        if index < triggers.count - 1 {
                                            Divider()
                                        }
                                    }
                                } else {
                                    EmptyStateView(
                                        imageName: "list.bullet",
                                        title: "No Triggers",
                                        message: "Add triggers when logging moods"
                                    )
                                }
                            }
                            .padding()
                            .background(Color(.systemBackground))
                            .cornerRadius(25)
                            .shadow(color: Color.black.opacity(0.05), radius: 5)
                            .padding(.horizontal)
                        }
                        
                        Color.clear.frame(height: 90)
                    }
                }
                .background(Color(.systemGroupedBackground))
                 VStack {
                    Button(action: { showLogs = true }) {
                        HStack(spacing: 8) {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 14))
                            Text("Log Obsession")
                                .font(.system(size: 14))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, maxHeight: 36)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .cornerRadius(18)
                    }
                    .frame(width: UIScreen.main.bounds.width * 0.7)
                    .padding(.bottom, 8)
                }
            }
            .navigationTitle("Hey OCDians,")
            .sheet(isPresented: $showMoodInputs) {
                MoodInputView(
                    currentMood: $currentMood,
                    selectedTriggers: $selectedTriggers,
                    moodNote: $moodNote,
                    moodHistory: $shared.moodHistory,
                    triggers: triggers
                )
            }
            .sheet(isPresented: $showLogs) {
                
                NavigationStack {
                    LogObsessionView(newEntry: $newEntry, selectedEntryForStrategies: $selectedEntryForStrategies)
                }
            }
            
        }
       
        .onAppear {
            shared.loadData()
            currentMood = shared.moodHistory.last?.mood ?? 3
        }
        .overlay(
            Group {
                if !shared.hasSeenTrackerTutorial {
                    TutorialOverlayView(
                        title: "Welcome to Tracker",
                        steps: [
                            ("chart.bar.fill", "Track your daily moods and see patterns"),
                            ("list.bullet", "Log your obsessive thoughts"),
                            ("chart.line.uptrend.xyaxis", "Monitor your progress over time"),
                            ("arrow.clockwise", "Review your common triggers")
                        ],
                        onDismiss: { shared.markTutorialAsSeen("tracker") }
                    )
                }
            }
        )
    }
    
    private func addNewEntry() {
        if !newEntry.isEmpty {
            let newOCDEntry = OCDEntry(obsession: newEntry, compulsion: "")
            shared.addEntry(newOCDEntry)
            newEntry = ""
        }
    }
    
    private func deleteEntry(at offsets: IndexSet) {
        shared.entries.remove(atOffsets: offsets)
        shared.saveData()
    }
    
    private func deleteAllEntries() {
        shared.entries.removeAll()
        shared.saveData()
    }
    
    private func saveData() {
        shared.saveData()
    }
    
    private func loadData() {
        shared.loadData()
    }
    
    private func saveCompulsion(for selectedObsession: OCDEntry) {
        if !compulsion.isEmpty {
            if let index = shared.entries.firstIndex(where: { $0.id == selectedObsession.id }) {
                shared.entries[index].compulsion = compulsion
                saveData()
                self.compulsion = ""
                self.selectedObsession = nil
            }
        }
    }
    
    private func cancelSelection() {
        self.compulsion = ""
        self.selectedObsession = nil
    }
    
    private func findStrategiesForEntry(_ entry: OCDEntry) -> [String] {
        return copingStrategies.first { entry.obsession.lowercased().contains($0.key.lowercased()) }?.value ?? []
    }
    
    private func moodEmoji(for value: Int) -> String {
        switch value {
        case 1: return "😢"
        case 2: return "😕"
        case 3: return "😐"
        case 4: return "🙂"
        case 5: return "😊"
        default: return "😐"
        }
    }
    
    private func addMood(_ value: Int) {
        let newMood = OCDMood(
            date: Date(),
            mood: value,
            triggers: Array(selectedTriggers),
            notes: moodNote
        )
        
        shared.addMood(newMood)
        currentMood = value
        showMoodInputs = false
        selectedTriggers.removeAll()
        moodNote = ""
    }
    private func mostCommonTriggers() -> [String]? {
        var triggerCounts: [String: Int] = [:]
        shared.moodHistory.forEach { mood in
            mood.triggers.forEach { trigger in
                triggerCounts[trigger, default: 0] += 1
            }
        }
        
        if triggerCounts.isEmpty {
            return nil
        }
        
        let sortedTriggers = triggerCounts.sorted { $0.value > $1.value }
        return Array(sortedTriggers.prefix(5).map { $0.key })
    }
    
    private func triggerCount(_ trigger: String) -> Int {
        shared.moodHistory.filter { $0.triggers.contains(trigger) }.count
    }
    
    private func averageMoodText() -> String {
        let average = shared.moodHistory.isEmpty ? 0 :
            Double(shared.moodHistory.reduce(0) { $0 + $1.mood }) / Double(shared.moodHistory.count)
        
        switch average {
        case 0..<1.5: return "Challenging"
        case 1.5..<2.5: return "Struggling"
        case 2.5..<3.5: return "Stable"
        case 3.5..<4.5: return "Good"
        case 4.5...5.0: return "Excellent"
        default: return "Unknown"
        }
    }
    
    private func averageMoodColor() -> Color {
        let average = shared.moodHistory.isEmpty ? 0 :
            Double(shared.moodHistory.reduce(0) { $0 + $1.mood }) / Double(shared.moodHistory.count)
        
        switch average {
        case 0..<1.5: return .red
        case 1.5..<2.5: return .orange
        case 2.5..<3.5: return .yellow
        case 3.5..<4.5: return .green
        case 4.5...5.0: return .blue
        default: return .gray
        }
    }
    
    private func bestDay() -> String {
        shared.moodHistory.max { $0.mood < $1.mood }?.date.formatted(date: .abbreviated, time: .omitted) ?? "No data"
    }
    
    private func currentStreak() -> Int {
        var streak = 0
        var currentDate = Date()
        let calendar = Calendar.current
        
        let sortedMoods = shared.moodHistory.sorted { $0.date > $1.date }
        
        for mood in sortedMoods {
            if calendar.isDate(mood.date, inSameDayAs: currentDate) {
                streak += 1
                currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
            } else {
                break
            }
        }
        
        return streak
    }
}

struct OCDEntry: Identifiable, Codable, Hashable {
    var id = UUID()
    var obsession: String
    var compulsion: String?
    
    init(obsession: String, compulsion: String? = nil) {
        self.obsession = obsession
        self.compulsion = compulsion
    }
}


struct RelaxationTab: View {
    @EnvironmentObject private var shared: SharedDataManager
    let relaxationOptions = [
        RelaxationOption(title: "Breathing Exercise", icon: "lungs.fill", color: .blue),
        RelaxationOption(title: "Body Scan", icon: "figure.stand", color: .purple),
        RelaxationOption(title: "Mindfulness", icon: "brain.head.profile", color: .green)
    ]
    
    @State private var selectedOption: RelaxationOption?
    @Environment(\.presentationMode) var presentationMode
    var showBackButton: Bool
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                    ForEach(relaxationOptions) { option in
                        Button(action: {
                            selectedOption = option
                        }) {
                            RelaxationCardView(option: option)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Relaxation")
            .navigationBarItems(leading: showBackButton ? Button("Back") {
                presentationMode.wrappedValue.dismiss()
            } : nil)
            .sheet(item: $selectedOption) { option in
                switch option.title {
                case "Breathing Exercise":
                    BreathingView()
                case "Body Scan":
                    BodyScanView()
                case "Mindfulness":
                    MindfulnessView()
                default:
                    EmptyView()
                }
            }
        }
        .overlay(
            Group {
                if !shared.hasSeenRelaxationTutorial {
                    TutorialOverlayView(
                        title: "Welcome to Relaxation",
                        steps: [
                            ("lungs.fill", "Practice guided breathing exercises"),
                            ("figure.walk", "Try body scan meditation"),
                            ("brain.head.profile", "Learn mindfulness techniques"),
                            ("heart.fill", "Reduce anxiety and stress")
                        ],
                        onDismiss: { shared.markTutorialAsSeen("relaxation") }
                    )
                }
            }
        )
    }
}

struct RelaxationOption: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let color: Color
}

struct RelaxationCardView: View {
    let option: RelaxationOption
    
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: option.icon)
                .font(.system(size: 40))
                .foregroundColor(option.color)
            
            Text(option.title)
                .font(.headline)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 160)
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}


struct ERPTab: View {
    @EnvironmentObject private var shared: SharedDataManager
    @State private var timeRemaining = 60
    @State private var isTimerRunning = false
    @State private var timer: Timer?
    @State private var exposureChallenge = ""
    @State private var selectedTime = 60
    @State private var anxietyBefore = 5
    @State private var anxietyAfter = 5
    @State private var sessionCompleted = false
    @State private var showCopingTips = false
    @State private var navigateToRelaxation = false
    @Binding var isPresented: Bool
    @State private var autoStart: Bool
    @State private var showBreathingExerciseModal = false
    @State private var breatheIn = true
    @State private var breathMessage = "Breathe In"
    @State private var counter = 0
    @State private var isRunning = false
    @State private var isCompleted = false
    @State private var previousTimerState = false
    @State private var savedTimeRemaining = 0
    @State private var pausedTimeRemaining: Int? = nil
    
    let timeOptions = [60, 300, 600]
    let anxietyLevels = Array(1...10)

    init(isPresented: Binding<Bool>, autoStart: Bool = false) {
        self._isPresented = isPresented
        self._autoStart = State(initialValue: autoStart)
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Describe your challenge")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        TextField("I feel anxious about...", text: $exposureChallenge)
                            .textFieldStyle(.roundedBorder)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemBackground))
                                    .shadow(color: .black.opacity(0.05), radius: 5)
                            )
                        
                        if sessionCompleted {
                            let anxietyChange = anxietyBefore - anxietyAfter
                            VStack(spacing: 12) {
                                Text("Anxiety Change")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                
                                HStack {
                                    Image(systemName: anxietyChange > 0 ? "arrow.down.circle.fill" :
                                            anxietyChange < 0 ? "arrow.up.circle.fill" : "equal.circle.fill")
                                        .foregroundColor(anxietyChange > 0 ? .green :
                                            anxietyChange < 0 ? .red : .orange)
                                        .font(.system(size: 24))
                                    
                                    Text("\(abs(anxietyChange)) point\(abs(anxietyChange) == 1 ? "" : "s") \(anxietyChange > 0 ? "decrease" : anxietyChange < 0 ? "increase" : "no change")")
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(.systemBackground))
                                    .shadow(color: .black.opacity(0.05), radius: 8)
                            )
                            .padding(.top, 8)
                        }
                    }
                    .padding()
                    
                    VStack(spacing: 16) {
                        Text("Duration")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        
                        Picker("Time", selection: $selectedTime) {
                            Text("1 min").tag(60)
                            Text("5 min").tag(300)
                            Text("10 min").tag(600)
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)
                        .disabled(isTimerRunning)
                        
                        if isTimerRunning {
                            Text(formatTime(timeRemaining))
                                .font(.system(size: 54, weight: .bold))
                                .foregroundColor(.blue)
                                .padding()
                        }
                        
                        Button(action: toggleTimer) {
                            Text(isTimerRunning ? "Stop" : "Start")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(isTimerRunning ? Color.red : Color.blue)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.05), radius: 8)
                    )
                    .padding(.horizontal)
                    if !isTimerRunning {
                        VStack(spacing: 16) {
                            Text("Anxiety Levels")
                                .font(.headline)
                                .foregroundColor(.secondary)
                            
                            VStack(spacing: 20) {
                                anxietySlider(value: $anxietyBefore, title: "Before")
                                
                                if sessionCompleted {
                                    anxietySlider(value: $anxietyAfter, title: "After")
                                }
                            }
                        }
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemBackground))
                                .shadow(color: .black.opacity(0.05), radius: 8)
                        )
                        .padding(.horizontal)
                    }
                    
                    HStack(spacing: 20) {
                        Button("Coping Tips") {
                            showCopingTips = true
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 60)
                        .background(Color.green)
                        .cornerRadius(15)
                        .shadow(color: .black.opacity(0.1), radius: 5)
                        .sheet(isPresented: $showCopingTips) {
                            CopingTipsView()
                        }
                        
                        Button("Panic Button") {
                            if isTimerRunning {
                                pausedTimeRemaining = timeRemaining
                                timer?.invalidate()
                                timer = nil
                                isTimerRunning = false
                            }
                            showBreathingExerciseModal = true
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 60)
                        .background(Color.orange)
                        .cornerRadius(15)
                        .shadow(color: .black.opacity(0.1), radius: 5)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                }
            }
            .navigationTitle("ERP Session")
            .background(Color(.systemGroupedBackground))
            .sheet(isPresented: $showBreathingExerciseModal, onDismiss: {
                if let remainingTime = pausedTimeRemaining {
                    timeRemaining = remainingTime
                    isTimerRunning = true
                    timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                        DispatchQueue.main.async {
                            if self.timeRemaining > 0 {
                                self.timeRemaining -= 1
                            } else {
                                self.timer?.invalidate()
                                self.timer = nil
                                self.isTimerRunning = false
                                self.sessionCompleted = true
                            }
                        }
                    }
                    pausedTimeRemaining = nil
                }
            }) {
                NavigationView {
                    BreathingView()
                }
            }
        }
        .overlay(
            Group {
                if !shared.hasSeenERPTutorial {
                    TutorialOverlayView(
                        title: "Welcome to ERP",
                        steps: [
                            ("clock.fill", "Set exposure exercise duration"),
                            ("arrow.up.heart.fill", "Rate your anxiety levels"),
                            ("chart.bar.fill", "Track your progress"),
                            ("checkmark.circle.fill", "Complete exercises at your pace")
                        ],
                        onDismiss: { shared.markTutorialAsSeen("erp") }
                    )
                }
            }
        )
    }
    
    private func toggleTimer() {
        if isTimerRunning {
        
            timer?.invalidate()
            timer = nil
            isTimerRunning = false
            pausedTimeRemaining = nil
            timeRemaining = selectedTime
        } else {
            
            timeRemaining = selectedTime
            isTimerRunning = true
            sessionCompleted = false
            
            timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
                DispatchQueue.main.async {
                    if self.timeRemaining > 0 {
                        self.timeRemaining -= 1
                    } else {
                        self.timer?.invalidate()
                        self.timer = nil
                        self.isTimerRunning = false
                        self.sessionCompleted = true
                    }
                }
            }
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let seconds = seconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private func moodEmoji(for anxietyLevel: Int) -> (emoji: String, description: String) {
        switch anxietyLevel {
        case 1...2:
            return ("😊", "Very Calm")
        case 3...4:
            return ("🙂", "Calm")
        case 5...6:
            return ("😐", "Neutral")
        case 7...8:
            return ("😟", "Anxious")
        case 9...10:
            return ("😰", "Very Anxious")
        default:
            return ("😐", "Neutral")
        }
    }

    private func anxietySlider(value: Binding<Int>, title: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(title) Exposure: \(value.wrappedValue)")
                    .foregroundColor(.secondary)
                let mood = moodEmoji(for: value.wrappedValue)
                Text(mood.emoji)
                    .font(.system(size: 24))
                Text(mood.description)
                    .foregroundColor(.secondary)
                    .font(.subheadline)
            }
            
            Slider(value: Binding(
                get: { Double(value.wrappedValue) },
                set: { value.wrappedValue = Int($0) }
            ), in: 1...10, step: 1)
            .accentColor(.blue)
            HStack {
                Text("Less Anxious")
                    .font(.caption)
                    .foregroundColor(.green)
                Spacer()
                Text("More Anxious")
                    .font(.caption)
                    .foregroundColor(.red)
            }
        }
    }
    
    private func startBreathingExercise() -> some View {
        VStack(spacing: 20) {
            Text(breathMessage)
                .font(.system(size: 32, weight: .bold))
                .foregroundColor(.primary)
                .animation(.easeInOut, value: breathMessage)
                .padding(.top, 30)
            
            ZStack {
                Circle()
                    .stroke(lineWidth: 8)
                    .foregroundColor(.blue.opacity(0.3))
                    .frame(width: 280, height: 280)
                
                Circle()
                    .stroke(lineWidth: 8)
                    .foregroundColor(.blue)
                    .frame(width: 280, height: 280)
                    .scaleEffect(isRunning ? (breatheIn ? 1.3 : 0.8) : 0.8)
                    .opacity(isRunning ? (breatheIn ? 1 : 0.5) : 0.5)
                    .animation(.easeInOut(duration: 5), value: breatheIn)
                    .animation(.easeInOut(duration: 1), value: isRunning)
                
                if isRunning {
                    Text("\(timeRemaining)")
                        .font(.system(size: 72, weight: .bold))
                        .foregroundColor(.blue)
                        .animation(.none, value: timeRemaining)
                }
            }
            .padding(40)
            
            if isCompleted {
                Text("Great job! Take a moment to notice how you feel.")
                    .font(.headline)
                    .foregroundColor(.green)
                    .multilineTextAlignment(.center)
                    .padding()
            }
            
            Spacer()
            
            Button(action: {
                if isRunning {
                    stopBreathing()
                } else {
                    startBreathing()
                }
            }) {
                Text(isRunning ? "Stop" : "Start Breathing")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(isRunning ? Color.red : Color.blue)
                    .cornerRadius(16)
                    .padding(.horizontal)
            }
            .padding(.bottom, 30)
        }
        .navigationTitle("Breathing Exercise")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    stopBreathing()
                    showBreathingExerciseModal = false
                }
                .fontWeight(.bold)
                .foregroundColor(.blue)
            }
        }
        .onDisappear {
            stopBreathing()
            breatheInSound?.stop()
            breatheOutSound?.stop()
            do {
                try AVAudioSession.sharedInstance().setActive(false)
            } catch {
                print("Failed to deactivate audio: \(error)")
            }
        }
    }

    private func startBreathing() {
        timer?.invalidate()
        counter = 0
        timeRemaining = 4
        isRunning = true
        isCompleted = false
        breatheIn = false
        breathMessage = "Get ready..."
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            DispatchQueue.main.async {
                breathMessage = "Breathe in..."
                withAnimation(.easeInOut(duration: 4)) {
                    breatheIn = true
                }

                breatheInSound?.play()
                startBreathingCycle()
            }
        }
    }

    private func startBreathingCycle() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            
            DispatchQueue.main.async {
                if timeRemaining > 0 {
                    timeRemaining -= 1
                } else {
                    withAnimation(.easeInOut(duration: 4)) {
                        breatheIn.toggle()
                    }
                    timeRemaining = 4
                    breathMessage = breatheIn ? "Breathe in..." : "Breathe out..."
                    if breatheIn {
                        breatheInSound?.play()
                    } else {
                        breatheOutSound?.play()
                    }
                    
                    if counter >= 6 {
                        completeExercise()
                        return
                    }
                    counter += 1
                }
            }
        }
    }

    private func completeExercise() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        isCompleted = true
        breathMessage = "Exercise Complete"
        breatheInSound?.stop()
        breatheOutSound?.stop()
        
        triggerHapticFeedback()
    }

    private func triggerHapticFeedback() {
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }

    private func stopBreathing() {
        timer?.invalidate()
        timer = nil
        isRunning = false
        counter = 0
        timeRemaining = 5
        breatheIn = true
        breathMessage = "Breathe In"
    }

    private var breatheInSound: AVAudioPlayer? = {
        guard let url = Bundle.main.url(forResource: "breatheIn", withExtension: "mp3") else {
            print("Could not find breatheIn.mp3")
            return nil
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            return player
        } catch {
            print("Failed to load breatheIn sound: \(error)")
            return nil
        }
    }()

    private var breatheOutSound: AVAudioPlayer? = {
        guard let url = Bundle.main.url(forResource: "breatheOut", withExtension: "mp3") else {
            print("Could not find breatheOut.mp3")
            return nil
        }
        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.prepareToPlay()
            return player
        } catch {
            print("Failed to load breatheOut sound: \(error)")
            return nil
        }
    }()
}

struct CopingTipsView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        
        VStack(spacing: 20) {
            Text("Coping Strategies")
                .font(.largeTitle)
                .padding()
            
            Text("🧘 **Deep Breathing Exercise**: Inhale for 4 seconds, hold for 4 seconds, exhale for 4 seconds.")
                .padding()
                .multilineTextAlignment(.center)
            
            Text("🌿 **Mindfulness Tip**: Focus on the present moment and observe your surroundings without judgment.")
                .padding()
                .multilineTextAlignment(.center)
            
            Text("💡 **Reassuring Message**: You're in control. Anxiety will pass, and you are stronger than your fears.")
                .padding()
                .multilineTextAlignment(.center)
            
            Button("Close") {
                self.presentationMode.wrappedValue.dismiss()
            }
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .frame(maxWidth: 400)
        .padding()
    }
}

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        scanner.currentIndex = hex.startIndex
        _ = scanner.scanString("#")

        var rgbValue: UInt64 = 0
        scanner.scanHexInt64(&rgbValue)

        let red = Double((rgbValue >> 16) & 0xFF) / 255.0
        let green = Double((rgbValue >> 8) & 0xFF) / 255.0
        let blue = Double(rgbValue & 0xFF) / 255.0

        self.init(red: red, green: green, blue: blue)
    }
}

extension UIColor {
    convenience init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        
        let red = CGFloat((rgb >> 16) & 0xFF) / 255.0
        let green = CGFloat((rgb >> 8) & 0xFF) / 255.0
        let blue = CGFloat(rgb & 0xFF) / 255.0
        
        self.init(red: red, green: green, blue: blue, alpha: 1.0)
    }
}

struct EntryCopingStrategiesView: View {
    @Environment(\.presentationMode) var presentationMode
    let entry: OCDEntry
    let strategies: [String]
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Your Entry:")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    
                    Text(entry.obsession)
                        .font(.title3)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemBackground))
                                .shadow(color: .black.opacity(0.05), radius: 5)
                        )
                }
                .padding(.horizontal)
                VStack(alignment: .leading, spacing: 16) {
                    Text("Suggested Coping Strategies")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.top)
                    
                    ForEach(strategies, id: \.self) { strategy in
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.title3)
                            
                            Text(strategy)
                                .font(.body)
                                .foregroundColor(.primary)
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemBackground))
                                .shadow(color: .black.opacity(0.05), radius: 5)
                        )
                    }
                }
                .padding(.horizontal)
                
                if strategies.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "lightbulb.fill")
                            .font(.largeTitle)
                            .foregroundColor(.yellow)
                        Text("General coping strategies:")
                            .font(.headline)
                        Text("1. Practice deep breathing")
                        Text("2. Use mindfulness techniques")
                        Text("3. Challenge negative thoughts")
                        Text("4. Seek support when needed")
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(.systemBackground))
                            .shadow(color: .black.opacity(0.05), radius: 5)
                    )
                    .padding()
                }
            }
            .padding(.vertical)
        }
        .navigationTitle("Coping Strategies")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Done") {
                    presentationMode.wrappedValue.dismiss()
                }
                .fontWeight(.bold)
            }
        }
        .background(Color(.systemGroupedBackground))
    }
}

struct OCDMood: Codable, Identifiable {
    let id = UUID()
    let date: Date
    let mood: Int
    let triggers: [String]
    let notes: String
}

struct OCDTrigger: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
}

struct MoodInputView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject private var sharedDataManager: SharedDataManager
    @Binding var currentMood: Int
    @Binding var selectedTriggers: Set<String>
    @Binding var moodNote: String
    @Binding var moodHistory: [OCDMood]
    let triggers: [OCDTrigger]
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("How are you feeling?")) {
                    Picker("Mood", selection: $currentMood) {
                        Text("😢").tag(1)
                        Text("😕").tag(2)
                        Text("😐").tag(3)
                        Text("🙂").tag(4)
                        Text("😊").tag(5)
                    }
                    .pickerStyle(.segmented)
                    .padding(.vertical, 8)
                    
                    HStack {
                        Text(moodEmoji(for: currentMood))
                            .font(.system(size: 32))
                        Text(moodDescription(for: currentMood))
                            .foregroundColor(.secondary)
                            .font(.headline)
                    }
                    .padding(.top, 8)
                }
                
                Section(header: Text("What triggered these feelings?")) {
                    ForEach(triggers) { trigger in
                        Button(action: {
                            if selectedTriggers.contains(trigger.name) {
                                selectedTriggers.remove(trigger.name)
                            } else {
                                selectedTriggers.insert(trigger.name)
                            }
                        }) {
                            HStack {
                                Image(systemName: trigger.icon)
                                Text(trigger.name)
                                Spacer()
                                if selectedTriggers.contains(trigger.name) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
                
                Section(header: Text("Notes")) {
                    TextEditor(text: $moodNote)
                        .frame(height: 100)
                }
            }
            .navigationTitle("Track Mood")
            .navigationBarItems(
                leading: Button("Cancel") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("Save") {
                    saveMood()
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
    
    private func saveMood() {
        let newMood = OCDMood(
            date: Date(),
            mood: currentMood,
            triggers: Array(selectedTriggers),
            notes: moodNote
        )
        sharedDataManager.addMood(newMood)
        selectedTriggers.removeAll()
        moodNote = ""
    }
    
    private func moodEmoji(for value: Int) -> String {
        switch value {
        case 1: return "😢"
        case 2: return "😕"
        case 3: return "😐"
        case 4: return "🙂"
        case 5: return "😊"
        default: return "😐"
        }
    }
    
    private func moodDescription(for value: Int) -> String {
        switch value {
        case 1: return "Very Low"
        case 2: return "Low"
        case 3: return "Neutral"
        case 4: return "Good"
        case 5: return "Very Good"
        default: return "Neutral"
        }
    }
}

struct MoodTrendsCard: View {
    let moodHistory: [OCDMood]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Mood Trends")
                .font(.headline)
            
            Text("Last 7 days")
                .font(.subheadline)
                .foregroundColor(.secondary)
            MoodBarChart(moodHistory: moodHistory)
            MoodLegend()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}
struct MoodBarChart: View {
    let moodHistory: [OCDMood]
    @Namespace private var animation
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            ForEach(Array(moodHistory.suffix(7)), id: \.id) { mood in
                MoodBar(mood: mood)
                    .transition(.scale)
                    .animation(.easeInOut, value: mood.id)
            }
        }
        .frame(height: 200)
    }
}

struct MoodBar: View {
    let mood: OCDMood
    
    var body: some View {
        VStack(spacing: 8) {
            Text(moodEmoji(for: mood.mood))
                .font(.system(size: 16))
            
            Rectangle()
                .fill(moodColor(for: mood.mood))
                .frame(width: 30, height: CGFloat(mood.mood) * 30)
                .cornerRadius(8)
            
            Text(formatDate(mood.date))
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private func moodEmoji(for value: Int) -> String {
        switch value {
        case 1: return "😢"
        case 2: return "😕"
        case 3: return "😐"
        case 4: return "🙂"
        case 5: return "😊"
        default: return "😐"
        }
    }
    
    private func moodColor(for value: Int) -> Color {
        switch value {
        case 1: return .red
        case 2: return .orange
        case 3: return .yellow
        case 4: return .green
        case 5: return .blue
        default: return .gray
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter.string(from: date)
    }
}

struct MoodLegend: View {
    var body: some View {
        HStack(spacing: 16) {
            ForEach(1...5, id: \.self) { value in
                HStack(spacing: 4) {
                    Circle()
                        .fill(moodColor(for: value))
                        .frame(width: 8, height: 8)
                    Text(moodDescription(for: value))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.top, 8)
    }
    
    private func moodColor(for value: Int) -> Color {
        switch value {
        case 1: return .red
        case 2: return .orange
        case 3: return .yellow
        case 4: return .green
        case 5: return .blue
        default: return .gray
        }
    }
    
    private func moodDescription(for value: Int) -> String {
        switch value {
        case 1: return "Very Low"
        case 2: return "Low"
        case 3: return "Neutral"
        case 4: return "Good"
        case 5: return "Very Good"
        default: return "Neutral"
        }
    }
}

struct InsightsView: View {
    @EnvironmentObject private var shared: SharedDataManager
    let moodHistory: [OCDMood]
    let entries: [OCDEntry]
    @Environment(\.presentationMode) var presentationMode
    @State private var showClearConfirmation = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    GroupBox {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Label("Mood Trends", systemImage: "chart.xyaxis.line")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                Button(role: .destructive) {
                                    showClearConfirmation = true
                                } label: {
                                    Label("Clear History", systemImage: "trash")
                                        .font(.subheadline)
                                }
                            }
                            
                            if moodHistory.isEmpty {
                                EmptyStateView(
                                    imageName: "chart.bar.fill",
                                    title: "No Mood Data",
                                    message: "Start tracking your moods to see insights"
                                )
                            } else {
                                MoodGraphView(moodHistory: moodHistory)
                            }
                        }
                    }
                    GroupBox {
                        VStack(alignment: .leading, spacing: 16) {
                            Label("Common Triggers", systemImage: "exclamationmark.triangle")
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            if let triggers = mostCommonTriggers() {
                                ForEach(Array(triggers.enumerated()), id: \.1) { index, trigger in
                                    HStack {
                                        Text("\(index + 1).")
                                            .foregroundColor(.secondary)
                                        Text(trigger)
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Text("\(triggerCount(trigger))")
                                            .foregroundColor(.secondary)
                                            .font(.caption)
                                    }
                                    if index < triggers.count - 1 {
                                        Divider()
                                    }
                                }
                            } else {
                                EmptyStateView(
                                    imageName: "list.bullet",
                                    title: "No Triggers",
                                    message: "Add triggers when logging moods"
                                )
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(25)
                    .shadow(color: Color.black.opacity(0.05), radius: 5)
                    .padding(.horizontal)

                    GroupBox {
                        VStack(alignment: .center, spacing: 16) {
                            Label("Progress Stats", systemImage: "chart.bar.xaxis")
                                .font(.headline)
                                .foregroundColor(.primary)
                                .frame(maxWidth: .infinity, alignment: .center)
                            LazyVGrid(columns: [
                                GridItem(.flexible(), spacing: 16),
                                GridItem(.flexible(), spacing: 16)
                            ], spacing: 16) {
                                StatView(
                                    title: "Average Mood",
                                    value: averageMoodText(),
                                    icon: "gauge.medium",
                                    color: averageMoodColor()
                                )
                                
                                StatView(
                                    title: "Total Entries",
                                    value: "\(shared.moodHistory.count)",
                                    icon: "doc.text.badge.plus",
                                    color: .green
                                )
                                
                                StatView(
                                    title: "Best Day",
                                    value: bestDay(),
                                    icon: "crown.fill",
                                    color: .yellow
                                )
                                
                                StatView(
                                    title: "Streak",
                                    value: "\(currentStreak()) days",
                                    icon: "chart.line.uptrend.xyaxis.circle.fill",
                                    color: .orange
                                )
                            }
                            .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(25)
                        .shadow(color: Color.black.opacity(0.05), radius: 5)
                        .padding(.horizontal)
                    }
                }
               
                .padding()
            }
            .navigationTitle("Insights")
            .navigationBarTitleDisplayMode(.large)
            .confirmationDialog(
                "Clear Mood History",
                isPresented: $showClearConfirmation,
                titleVisibility: .visible
            ) {
                Button("Clear All History", role: .destructive) {
                    shared.clearMoodHistory()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will permanently delete all mood tracking data. This action cannot be undone.")
            }
        }
    }
    
    private func mostCommonTriggers() -> [String]? {
        var triggerCounts: [String: Int] = [:]
        moodHistory.forEach { mood in
            mood.triggers.forEach { trigger in
                triggerCounts[trigger, default: 0] += 1
            }
        }
        let sortedTriggers = triggerCounts.sorted { $0.value > $1.value }
        return Array(sortedTriggers.prefix(5).map { $0.key })
    }
    
    private func triggerCount(_ trigger: String) -> Int {
        moodHistory.filter { $0.triggers.contains(trigger) }.count
    }
    
    private func averageMood() -> Double {
        let total = moodHistory.reduce(0) { $0 + $1.mood }
        return Double(total) / Double(moodHistory.count)
    }
    
    private func averageMoodText() -> String {
        let average = averageMood()
        switch average {
        case 0..<1.5: return "Challenging"
        case 1.5..<2.5: return "Struggling"
        case 2.5..<3.5: return "Stable"
        case 3.5..<4.5: return "Good"
        case 4.5...5.0: return "Excellent"
        default: return "Unknown"
        }
    }
    
    private func averageMoodColor() -> Color {
        let average = averageMood()
        switch average {
        case 0..<1.5: return .red
        case 1.5..<2.5: return .orange
        case 2.5..<3.5: return .yellow
        case 3.5..<4.5: return .green
        case 4.5...5.0: return .blue
        default: return .gray
        }
    }
    
    private func bestDay() -> String {
        moodHistory.max { $0.date < $1.date }?.date.formatted(date: .abbreviated, time: .omitted) ?? "No data"
    }
    
    private func currentStreak() -> Int {
        var streak = 0
        var currentDate = Date()
        let calendar = Calendar.current
        
        
        let sortedMoods = moodHistory.sorted { $0.date > $1.date }
        
        for mood in sortedMoods {
            if mood.date.isSameDay(as: currentDate) {
                streak += 1
               
                currentDate = calendar.date(byAdding: .day, value: -1, to: currentDate) ?? currentDate
            } else {
                break
            }
        }
        
        return streak
    }
}

struct EmptyStateView: View {
    let imageName: String
    let title: String
    let message: String
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: imageName)
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}

struct StatView: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .center, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, minHeight: 100)
        .frame(height: 100)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(22)
    }
}


class SharedDataManager: ObservableObject {
    @Published var entries: [OCDEntry] = []
    @Published var moodHistory: [OCDMood] = []
    @Published var hasSeenTrackerTutorial = false
    @Published var hasSeenRelaxationTutorial = false
    @Published var hasSeenERPTutorial = false
    
    init() {
        loadData()
        
        hasSeenTrackerTutorial = false
        hasSeenRelaxationTutorial = false
        hasSeenERPTutorial = false
        
        UserDefaults.standard.set(false, forKey: "hasSeenTrackerTutorial")
        UserDefaults.standard.set(false, forKey: "hasSeenRelaxationTutorial")
        UserDefaults.standard.set(false, forKey: "hasSeenERPTutorial")
    }
    
    func loadData() {
      
        if let savedData = UserDefaults.standard.data(forKey: "OCDEntries"),
           let decodedEntries = try? JSONDecoder().decode([OCDEntry].self, from: savedData) {
            entries = decodedEntries
        }
        
        if let savedMoodData = UserDefaults.standard.data(forKey: "moodHistory"),
           let decodedMoodHistory = try? JSONDecoder().decode([OCDMood].self, from: savedMoodData) {
            moodHistory = decodedMoodHistory
        }
    }
    
    func saveData() {
        if let encoded = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(encoded, forKey: "OCDEntries")
        }
        if let encodedMood = try? JSONEncoder().encode(moodHistory) {
            UserDefaults.standard.set(encodedMood, forKey: "moodHistory")
        }
    }
    
    func addEntry(_ entry: OCDEntry) {
        entries.insert(entry, at: 0)
        saveData()
    }
    
    func addMood(_ mood: OCDMood) {
        moodHistory.append(mood)
        saveData()
    }
    
    func clearMoodHistory() {
        moodHistory.removeAll()
        saveData()
        objectWillChange.send()
    }
    
    func markTutorialAsSeen(_ tutorial: String) {
        switch tutorial {
        case "tracker":
            hasSeenTrackerTutorial = true
            UserDefaults.standard.set(true, forKey: "hasSeenTrackerTutorial")
        case "relaxation":
            hasSeenRelaxationTutorial = true
            UserDefaults.standard.set(true, forKey: "hasSeenRelaxationTutorial")
        case "erp":
            hasSeenERPTutorial = true
            UserDefaults.standard.set(true, forKey: "hasSeenERPTutorial")
        default:
            break
        }
    }
}

struct MoodGraphView: View {
    let moodHistory: [OCDMood]
    @State private var scrollViewProxy: ScrollViewProxy?
    
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Mood Scale")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                VStack(alignment: .leading, spacing: 12) {
                    ForEach((1...5).reversed(), id: \.self) { value in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(moodColor(for: value))
                                .frame(width: 10, height: 10)
                            
                            Text(moodText(for: value))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(8)
            .frame(width: 120)
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .bottom, spacing: 12) {
                        ForEach(moodHistory.sorted(by: { $0.date < $1.date }), id: \.id) { mood in
                            VStack(spacing: 4) {
                                Text(moodEmoji(for: mood.mood))
                                    .font(.system(size: 16))
                                
                                Rectangle()
                                    .fill(moodColor(for: mood.mood))
                                    .frame(width: 24, height: CGFloat(mood.mood) * 25)
                                    .cornerRadius(8)
                                    .animation(.spring(), value: mood.mood)
                                
                                Text(formatDate(mood.date))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .fixedSize()
                            }
                            .frame(width: 40)
                            .id(mood.id)
                        }
                    }
                    .padding(.vertical, 8)
                }
                .frame(height: 200)
                .onAppear {
                    if let lastMood = moodHistory.sorted(by: { $0.date < $1.date }).last {
                        withAnimation {
                            proxy.scrollTo(lastMood.id, anchor: .trailing)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date)
    }
    
    private func moodText(for value: Int) -> String {
        switch value {
        case 1: return "Very Low"
        case 2: return "Low"
        case 3: return "Neutral"
        case 4: return "Good"
        case 5: return "Excellent"
        default: return "Unknown"
        }
    }
    
    private func moodEmoji(for value: Int) -> String {
        switch value {
        case 1: return "😢"
        case 2: return "😕"
        case 3: return "😐"
        case 4: return "🙂"
        case 5: return "😊"
        default: return "😐"
        }
    }
    
    private func moodColor(for value: Int) -> Color {
        switch value {
        case 1: return .red
        case 2: return .orange
        case 3: return .yellow
        case 4: return .green
        case 5: return .blue
        default: return .gray
        }
    }
}


extension Date {
    func isSameDay(as date: Date) -> Bool {
        let calendar = Calendar.current
        return calendar.isDate(self, inSameDayAs: date)
    }
}

struct BodyScanView: View {
    @State private var currentBodyPart = 0
    @State private var isActive = false
    @State private var progress: CGFloat = 0
    @State private var showingCompletion = false
    @State private var timeRemaining = 90
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    let bodyParts = [
        (name: "Head & Face", description: "Notice any tension in your forehead, jaw, and facial muscles", icon: "face.smiling"),
        (name: "Shoulders", description: "Feel the weight of your shoulders, any tightness or relaxation", icon: "person.bust"),
        (name: "Arms", description: "Observe sensations in your arms, from shoulders to fingertips", icon: "hand.raised"),
        (name: "Chest", description: "Focus on your breathing, feel your chest rise and fall", icon: "heart.circle"),
        (name: "Back", description: "Notice any areas of tension or comfort in your back", icon: "figure.stand"),
        (name: "Stomach", description: "Observe sensations in your abdomen, any tension or movement", icon: "circle.circle"),
        (name: "Legs", description: "Feel the sensations in your legs, from hips to toes", icon: "figure.walk"),
        (name: "Feet", description: "Notice the connection of your feet with the ground", icon: "shoe")
    ]
    
    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [.blue.opacity(0.3), .purple.opacity(0.3)]),
                          startPoint: .topLeading,
                          endPoint: .bottomTrailing)
                .ignoresSafeArea()
            
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 15)
                        .frame(width: 250, height: 250)
                    
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(Color.blue, style: StrokeStyle(lineWidth: 15, lineCap: .round))
                        .frame(width: 250, height: 250)
                        .rotationEffect(.degrees(-90))
                    
                    VStack {
                        Text(timeString(from: timeRemaining))
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .foregroundColor(.blue)
                        
                        Text(bodyParts[currentBodyPart].name)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(bodyParts[currentBodyPart].description)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
                Button(action: {
                    if isActive {
                        stopExercise()
                    } else {
                        startExercise()
                    }
                }) {
                    Text(isActive ? "Stop" : "Start")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isActive ? Color.red : Color.blue)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
            }
            .padding()
        }
        .onReceive(timer) { _ in
            if isActive {
                if timeRemaining > 0 {
                    timeRemaining -= 1
                    progress = 1.0 - (CGFloat(timeRemaining) / 90.0)
                    let timePerPart = 90 / bodyParts.count
                    currentBodyPart = min((90 - timeRemaining) / timePerPart, bodyParts.count - 1)
                } else {
                    showingCompletion = true
                    stopExercise()
                }
            }
        }
        .sheet(isPresented: $showingCompletion) {
            CompletionView()
        }
    }
    
    private func timeString(from seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
    
    private func startExercise() {
        isActive = true
        progress = 0
        timeRemaining = 90
        currentBodyPart = 0
    }
    
    private func stopExercise() {
        isActive = false
        progress = 0
        timeRemaining = 90
    }
}

struct CompletionView: View {
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)
            
            Text("Great Job!")
                .font(.title)
                .fontWeight(.bold)
            
            Text("You've completed your body scan exercise")
                .font(.body)
                .foregroundColor(.secondary)
            
            Button("Done") {
                presentationMode.wrappedValue.dismiss()
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(width: 200)
            .padding()
            .background(Color.blue)
            .cornerRadius(12)
        }
        .padding()
    }
}

struct BreathingView: View {
    @State private var breatheIn = false
    @State private var isActive = false
    @State private var timeRemaining = 90
    @State private var breathMessage = "Get Ready..."
    @State private var ringScale = 1.0
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    init() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set up audio session: \(error)")
        }
    }

    private var breatheInSound: AVAudioPlayer? = {
        do {
            if let url = Bundle.main.url(forResource: "breatheIn", withExtension: "mp3") {
                print("Found breatheIn.mp3 at: \(url)")
                let player = try AVAudioPlayer(contentsOf: url)
                player.prepareToPlay()
                return player
            }
            print("Could not find breatheIn.mp3")
 
            if let resourcePath = Bundle.main.resourcePath {
                print("Bundle resource path: \(resourcePath)")
                do {
                    let contents = try FileManager.default.contentsOfDirectory(atPath: resourcePath)
                    print("Bundle contents: \(contents)")
                } catch {
                    print("Error listing bundle contents: \(error)")
                }
            }
            
            return nil
        } catch {
            print("Failed to initialize breatheIn sound: \(error)")
            return nil
        }
    }()
    
    private var breatheOutSound: AVAudioPlayer? = {
        do {
            if let url = Bundle.main.url(forResource: "breatheOut", withExtension: "mp3") {
                print("Found breatheOut.mp3 at: \(url)")
                let player = try AVAudioPlayer(contentsOf: url)
                player.prepareToPlay()
                return player
            }
            print("Could not find breatheOut.mp3")
            return nil
        } catch {
            print("Failed to initialize breatheOut sound: \(error)")
            return nil
        }
    }()
    
    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [.blue.opacity(0.3), .cyan.opacity(0.3)]),
                          startPoint: .topLeading,
                          endPoint: .bottomTrailing)
                .ignoresSafeArea()
            
            VStack {
                Spacer()

                Text("Breathing Exercise")
                    .font(.title)
                    .fontWeight(.bold)
                    .padding(.bottom, 4)
                
                Text(breathMessage)
                    .font(.title2)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 40)
                ZStack {
                    Circle()
                        .stroke(Color.blue.opacity(0.3), lineWidth: 40)
                        .frame(width: 260, height: 260)
                    
                    Circle()
                        .stroke(Color.blue, lineWidth: 40)
                        .frame(width: 260, height: 260)
                        .scaleEffect(ringScale)
                        .opacity(2 - ringScale)
                    
                    Text(timeString(from: timeRemaining))
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundColor(.blue)
                }
                .frame(height: 300)
                
                Spacer()
                
                Button(action: {
                    if isActive {
                        stopBreathing()
                    } else {
                        startBreathing()
                    }
                }) {
                    Text(isActive ? "Stop" : "Start")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isActive ? Color.red : Color.blue)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
        }
        .onReceive(timer) { _ in
            if isActive {
                if timeRemaining > 0 {
                    timeRemaining -= 1
                    
                    if timeRemaining % 4 == 0 {
                        withAnimation(.easeInOut(duration: 4)) {
                            breatheIn.toggle()
                            breathMessage = breatheIn ? "Breathe In..." : "Breathe Out..."
                            ringScale = breatheIn ? 1.3 : 1.0
                            if breatheIn {
                                breatheInSound?.stop()
                                breatheInSound?.currentTime = 0
                                breatheInSound?.play()
                            } else {
                                breatheOutSound?.stop()
                                breatheOutSound?.currentTime = 0
                                breatheOutSound?.play()
                            }
                        }
                    }
                } else {
                    stopBreathing()
                }
            }
        }
        .onAppear {
            do {
                try AVAudioSession.sharedInstance().setActive(true)
                breatheInSound?.prepareToPlay()
                breatheOutSound?.prepareToPlay()
            } catch {
                print("Failed to activate audio session: \(error)")
            }
        }
        .onDisappear {
            breatheInSound?.stop()
            breatheOutSound?.stop()
            do {
                try AVAudioSession.sharedInstance().setActive(false)
            } catch {
                print("Failed to deactivate audio session: \(error)")
            }
        }
    }
    
    private func startBreathing() {
        isActive = true
        timeRemaining = 90
        breatheIn = true
        breathMessage = "Breathe In..."
        
        breatheInSound?.stop()
        breatheInSound?.currentTime = 0
        breatheInSound?.play()
        
        withAnimation(.easeInOut(duration: 4)) {
            ringScale = 1.3
        }
    }
    
    private func stopBreathing() {
        isActive = false
        timeRemaining = 90
        breatheIn = false
        breathMessage = "Get Ready..."
        
        breatheInSound?.stop()
        breatheOutSound?.stop()
        
        withAnimation(.easeInOut(duration: 1)) {
            ringScale = 1.0
        }
    }
    
    private func timeString(from seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
}

struct MindfulnessView: View {
    @State private var currentQuote = 0
    @State private var isActive = false
    @State private var timeRemaining = 90
    @Environment(\.dismiss) var dismiss
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    let mindfulnessQuotes = [
        "Be present in this moment",
        "Observe your thoughts without judgment",
        "Focus on your breath",
        "Notice the sensations in your body",
        "Let your thoughts come and go like clouds",
        "You are not your thoughts",
        "Find peace in the present moment",
        "Embrace the silence within"
    ]
    
    var body: some View {
        ZStack {
            LinearGradient(gradient: Gradient(colors: [.green.opacity(0.3), .mint.opacity(0.3)]),
                          startPoint: .topLeading,
                          endPoint: .bottomTrailing)
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                ZStack {
                    Circle()
                        .stroke(Color.green.opacity(0.3), lineWidth: 20)
                        .frame(width: 200, height: 200)
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(timeRemaining) / 90.0) // Changed from 300.0 to 90.0
                        .stroke(Color.green, style: StrokeStyle(lineWidth: 20, lineCap: .round))
                        .frame(width: 200, height: 200)
                        .rotationEffect(.degrees(-90))
                    
                    VStack {
                        Text(timeString(from: timeRemaining))
                            .font(.system(size: 44, weight: .bold, design: .rounded))
                            .foregroundColor(.green)
                    }
                }
                Text(mindfulnessQuotes[currentQuote])
                    .font(.title)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
                    .padding()
                    .animation(.easeInOut, value: currentQuote)
                Image(systemName: "leaf.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.green)
                    .rotationEffect(.degrees(isActive ? 360 : 0))
                    .animation(isActive ? .linear(duration: 20).repeatForever(autoreverses: false) : .default, value: isActive)
                
                Spacer()
      
                Button(action: {
                    withAnimation {
                        if isActive {
                            stopExercise()
                        } else {
                            startExercise()
                        }
                    }
                }) {
                    Text(isActive ? "Stop" : "Start")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isActive ? Color.red : Color.green)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
            .padding()
        }
        .navigationTitle("Mindfulness")
        .navigationBarTitleDisplayMode(.inline)
        .onReceive(timer) { _ in
            if isActive {
                if timeRemaining > 0 {
                    timeRemaining -= 1
                    if timeRemaining % 15 == 0 {
                        withAnimation {
                            currentQuote = (currentQuote + 1) % mindfulnessQuotes.count
                        }
                    }
                } else {
                    stopExercise()
                    showCompletionAlert()
                }
            }
        }
    }
    
    private func timeString(from seconds: Int) -> String {
        let minutes = seconds / 60
        let remainingSeconds = seconds % 60
        return String(format: "%d:%02d", minutes, remainingSeconds)
    }
    
    private func startExercise() {
        isActive = true
    }
    
    private func stopExercise() {
        isActive = false
        timeRemaining = 90
    }
    
    private func showCompletionAlert() {

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}

struct OnboardingView: View {
    @Binding var showOnboarding: Bool
    @State private var currentPage = 0
    
    let onboardingPages = [
        OnboardingPage(
            title: "Welcome to OCDian",
            description: "Your personal companion for managing OCD and anxiety",
            imageName: "heart.circle.fill",
            color: .blue
        ),
        OnboardingPage(
            title: "Track Your Moods",
            description: "Log your daily moods and triggers to identify patterns",
            imageName: "chart.xyaxis.line",
            color: .purple
        ),
        OnboardingPage(
            title: "ERP Exercises",
            description: "Practice Exposure and Response Prevention techniques",
            imageName: "brain.head.profile",
            color: .orange
        ),
        OnboardingPage(
            title: "Relaxation Tools",
            description: "Access breathing exercises and mindfulness techniques",
            imageName: "leaf.fill",
            color: .green
        ),
        OnboardingPage(
            title: "Emergency Help",
            description: "Quick access to breathing exercises when you need them",
            imageName: "exclamationmark.circle.fill",
            color: .red
        )
    ]
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            TabView(selection: $currentPage) {
                ForEach(0..<onboardingPages.count, id: \.self) { index in
                    OnboardingPageView(page: onboardingPages[index])
                        .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .always))
            .indexViewStyle(PageIndexViewStyle(backgroundDisplayMode: .always))
            .overlay(
                Button(action: {
                    withAnimation {
                        showOnboarding = false
                    }
                }) {
                    if currentPage == onboardingPages.count - 1 {
                        Text("Get Started")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                            .padding(.horizontal)
                    }
                }
                .padding(.bottom, 50),
                alignment: .bottom
            )

            Button(action: {
                withAnimation {
                    showOnboarding = false
                }
            }) {
                Text("Skip")
                    .font(.headline)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        Capsule()
                            .fill(Color.white.opacity(0.9))
                            .shadow(color: .black.opacity(0.1), radius: 4)
                    )
            }
            .padding(.top, 8)
            .padding(.trailing, 16)
        }
    }
}

struct OnboardingPage: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let imageName: String
    let color: Color
}

struct OnboardingPageView: View {
    let page: OnboardingPage
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: page.imageName)
                .font(.system(size: 100))
                .foregroundColor(page.color)
                .padding()
                .background(
                    Circle()
                        .fill(page.color.opacity(0.2))
                        .frame(width: 160, height: 160)
                )
            
            Text(page.title)
                .font(.title)
                .fontWeight(.bold)
            
            Text(page.description)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
            
            if page.title == "Emergency Help" {
                VStack(spacing: 12) {
                    TutorialTipView(
                        title: "Quick Access",
                        description: "Tap the panic button for immediate breathing exercise"
                    )
                    TutorialTipView(
                        title: "Track Progress",
                        description: "Monitor your improvement over time"
                    )
                }
                .padding(.top)
            }
        }
        .padding()
    }
}

struct TutorialTipView: View {
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(22)
    }
}

struct LogObsessionView: View {
    @EnvironmentObject private var sharedDataManager: SharedDataManager
    @Binding var newEntry: String
    @Binding var selectedEntryForStrategies: OCDEntry?
    @State private var isEditing = false
    @State private var selectedEntries = Set<OCDEntry>()
    
    let copingStrategies: [String: [String]] = [
        "clean": [
            "Practice deep breathing exercises",
            "Try the 5-4-3-2-1 grounding technique",
            "Remember thoughts are not commands",
            "Use exposure and response prevention",
            "Focus on mindful activities"
        ],
        "check": [
            "Set a specific time limit for checking",
            "Practice delayed checking",
            "Use mindfulness techniques",
            "Challenge the 'what if' thoughts",
            "Remember checking once is enough"
        ],
        "harm": [
            "These thoughts do not define you",
            "Practice self-compassion",
            "Use thought defusion techniques",
            "Remember thoughts are not actions",
            "Reach out to your support system"
        ],
        "order": [
            "Start with small areas of disorder",
            "Practice accepting imperfection",
            "Focus on function over perfection",
            "Use time-limited organizing",
            "Challenge perfectionist thoughts"
        ],
        "contamination": [
            "Use gradual exposure techniques",
            "Practice rational thinking",
            "Focus on probability vs possibility",
            "Set reasonable cleaning limits",
            "Challenge contamination beliefs"
        ]
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    
                    if !isEditing || sharedDataManager.entries.isEmpty {
                        HStack(spacing: 12) {
                            TextField("Log your obsession", text: $newEntry)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            
                            Button(action: {
                                addEntry()
                                isEditing = false
                                selectedEntries.removeAll()
                            }) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 24))
                                    .foregroundColor(.blue)
                            }
                            .disabled(newEntry.isEmpty)
                        }
                        .padding(.horizontal)
                    }
                    ForEach(sharedDataManager.entries) { entry in
                        HStack {
                            if isEditing {
                                Button(action: {
                                    toggleEntrySelection(entry)
                                }) {
                                    Image(systemName: selectedEntries.contains(entry) ? "checkmark.circle.fill" : "circle")
                                        .foregroundColor(selectedEntries.contains(entry) ? .blue : .gray)
                                        .font(.system(size: 22))
                                }
                                .padding(.leading)
                            }
                            
                            Button(action: {
                                if !isEditing {
                                    selectedEntryForStrategies = entry
                                }
                            }) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text(entry.obsession)
                                            .font(.headline)
                                            .foregroundColor(.primary)
                                        
                                        if let compulsion = entry.compulsion, !compulsion.isEmpty {
                                            Text("Response: \(compulsion)")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    Spacer()
                                    if !isEditing {
                                        Image(systemName: "info.circle")
                                            .foregroundColor(.blue.opacity(0.7))
                                            .font(.system(size: 20))
                                    }
                                }
                            }
                            .calmCardStyle()
                        }
                    }
                }
                .padding()
            }
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(.systemBackground),
                        Color(.systemGray6).opacity(0.3),
                        Color(.systemBackground)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .navigationTitle("Log Obsession")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if isEditing && !selectedEntries.isEmpty {
                        Button("Delete", role: .destructive) {
                            withAnimation {
                                sharedDataManager.entries.removeAll { selectedEntries.contains($0) }
                                selectedEntries.removeAll()
                                if sharedDataManager.entries.isEmpty {
                                    isEditing = false
                                }
                                sharedDataManager.saveData()
                            }
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !sharedDataManager.entries.isEmpty {
                        HStack {
                            if isEditing {
                                Button(selectedEntries.count == sharedDataManager.entries.count ? "Deselect All" : "Select All") {
                                    withAnimation {
                                        if selectedEntries.count == sharedDataManager.entries.count {
                                            selectedEntries.removeAll()
                                        } else {
                                            selectedEntries = Set(sharedDataManager.entries)
                                        }
                                    }
                                }
                            }
                            
                            Button(isEditing ? "Done" : "Edit") {
                                withAnimation {
                                    isEditing.toggle()
                                    selectedEntries.removeAll()
                                }
                            }
                        }
                    }
                }
            }
        }
        .sheet(item: $selectedEntryForStrategies) { entry in
            NavigationView {
                let strategies = copingStrategies.first { entry.obsession.lowercased().contains($0.key.lowercased()) }?.value ?? []
                EntryCopingStrategiesView(entry: entry, strategies: strategies)
            }
        }
    }
    
    private func toggleEntrySelection(_ entry: OCDEntry) {
        if selectedEntries.contains(entry) {
            selectedEntries.remove(entry)
        } else {
            selectedEntries.insert(entry)
        }
    }
    
    private func addEntry() {
        withAnimation {
            let trimmedEntry = newEntry.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedEntry.isEmpty {
                let entry = OCDEntry(
                    obsession: trimmedEntry,
                    compulsion: nil
                )
                sharedDataManager.addEntry(entry)
                newEntry = ""
                
                isEditing = false
                selectedEntries.removeAll()
            }
        }
    }
}


extension View {
    func calmCardStyle() -> some View {
        self
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 3, x: 0, y: 1)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.blue.opacity(0.15), lineWidth: 1)
            )
    }
}
