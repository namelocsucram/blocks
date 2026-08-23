import SwiftUI

// MARK: - Constants

let BOARD_SIZE = 8
let MAX_HEAT = 24
let REROLL_COST = 20
let ERASER_COST = 15
private let GOLD_CHANCE: Double = 0.08
private let INTERSTITIAL_EVERY = 3

private let ALL_SHAPES: [[(Int, Int)]] = [
    [(0,0)],
    [(0,0),(0,1)],
    [(0,0),(1,0)],
    [(0,0),(0,1),(0,2)],
    [(0,0),(1,0),(2,0)],
    [(0,0),(0,1),(0,2),(0,3)],
    [(0,0),(1,0),(2,0),(3,0)],
    [(0,0),(0,1),(1,0),(1,1)],
    [(0,0),(0,1),(0,2),(1,0)],
    [(0,0),(0,1),(0,2),(1,2)],
    [(1,0),(1,1),(1,2),(0,0)],
    [(1,0),(1,1),(1,2),(0,2)],
    [(0,0),(1,0),(1,1),(2,1)],
    [(0,1),(1,0),(1,1),(2,0)],
    [(0,0),(0,1),(0,2),(1,1)],
    [(0,1),(1,0),(1,1),(1,2)],
    [(0,0),(0,1),(1,0),(1,1),(2,0),(2,1)],
]

private let SIMPLE_SHAPES = ALL_SHAPES.filter { $0.count <= 3 }
private let COMPLEX_SHAPES = ALL_SHAPES.filter { $0.count >= 4 }

let BLOCK_PALETTE: [Color] = [
    Color(red: 1.0,   green: 0.231, blue: 0.361),
    Color(red: 1.0,   green: 0.651, blue: 0.188),
    Color(red: 1.0,   green: 0.878, blue: 0.298),
    Color(red: 0.180, green: 0.835, blue: 0.451),
    Color(red: 0.231, green: 0.510, blue: 0.965),
    Color(red: 0.659, green: 0.333, blue: 0.969),
    Color(red: 0.957, green: 0.447, blue: 0.714),
]

let GOLD_BLOCK_COLOR = Color(red: 1.0, green: 0.839, blue: 0.353)

let COIN_PACKS: [(id: String, coins: Int, price: String)] = [
    ("coins_100",  100,  "$0.99"),
    ("coins_350",  350,  "$2.99"),
    ("coins_800",  800,  "$4.99"),
    ("coins_2000", 2000, "$9.99"),
]

// MARK: - Data Models

struct GridCell: Equatable {
    let colorIdx: Int
    let isGold: Bool
}

struct GamePiece: Identifiable, Equatable {
    let id: Int
    let shape: [(Int, Int)]
    let colorIdx: Int
    let isGold: Bool
    let isBomb: Bool

    var dims: (rows: Int, cols: Int) {
        guard !shape.isEmpty else { return (1, 1) }
        var maxR = 0, maxC = 0
        for (r, c) in shape { maxR = max(maxR, r); maxC = max(maxC, c) }
        return (maxR + 1, maxC + 1)
    }

    static func == (lhs: GamePiece, rhs: GamePiece) -> Bool { lhs.id == rhs.id }
}

enum GoalType: String, Codable {
    case lines, score, jackpot, heat, wildgem, pieces
}

struct DailyGoal: Identifiable, Codable, Equatable {
    var id: String
    var type: GoalType
    var target: Int
    var progress: Int
    var reward: Int
    var claimed: Bool
    var label: String
}

struct SaveData: Codable {
    var best: Int = 0
    var sfxMuted: Bool = false
    var musicMuted: Bool = false
    var streak: Int = 1
    var lastPlayDate: String? = nil
    var freezeAvailable: Bool = false
    var coins: Int = 0
    var dailyGoals: [DailyGoal] = []
    var goalsDate: String? = nil
    var gamesSinceInterstitial: Int = 0
}

// MARK: - Helpers

func todayString() -> String {
    DateFormatter.localizedString(from: Date(), dateStyle: .medium, timeStyle: .none)
}

private func daysBetween(_ a: String, _ b: String) -> Int {
    let df = DateFormatter()
    df.dateStyle = .medium
    df.timeStyle = .none
    guard let da = df.date(from: a), let db = df.date(from: b) else { return 0 }
    return Int(round(db.timeIntervalSince(da) / 86400))
}

private let GOAL_TEMPLATES: [(GoalType, [Int], Int, (Int) -> String)] = [
    (.lines,   [8, 15, 25],      25, { "Clear \($0) lines" }),
    (.score,   [500, 1200, 2500], 30, { "Score \($0) points" }),
    (.jackpot, [1, 2],            50, { "Hit \($0) Jackpot\($0 > 1 ? "s" : "")" }),
    (.heat,    [12, 18, 24],      20, { t in "Reach heat ×\(String(format: "%.1f", 1.0 + Double(t) * 0.125))" }),
    (.wildgem, [2, 4],            20, { "Place \($0) Wild Gem\($0 > 1 ? "s" : "")" }),
    (.pieces,  [30, 60],          15, { "Place \($0) pieces" }),
]

private func generateDailyGoals() -> [DailyGoal] {
    (0..<GOAL_TEMPLATES.count).shuffled().prefix(3).enumerated().map { i, idx in
        let (type, targets, reward, label) = GOAL_TEMPLATES[idx]
        let target = targets.randomElement()!
        return DailyGoal(
            id: "\(type.rawValue)-\(i)-\(Int(Date().timeIntervalSince1970))",
            type: type, target: target, progress: 0,
            reward: reward, claimed: false, label: label(target)
        )
    }
}

// MARK: - Game Model

@MainActor
class GameModel: ObservableObject {
    @Published var grid: [[GridCell?]] = Array(repeating: Array(repeating: nil, count: BOARD_SIZE), count: BOARD_SIZE)
    @Published var tray: [GamePiece] = []
    @Published var score = 0
    @Published var best = 0
    @Published var heat = 0
    @Published var coins = 0
    @Published var combo = 0
    @Published var streak = 1
    @Published var gameOver = false
    @Published var loaded = false
    @Published var clearingCells = Set<String>()
    @Published var bombArmed = false
    @Published var rescueUsed = false
    @Published var rescuing = false
    @Published var eraseMode = false
    @Published var sfxMuted = false
    @Published var musicMuted = false
    @Published var toast: String? = nil
    @Published var jackpotFlash = false
    @Published var jackpotBonus: Int? = nil
    @Published var shake = false
    @Published var comboPop: (id: Int, text: String)? = nil
    @Published var shareReady = false
    @Published var freezeAvailable = false
    @Published var showGoals = false
    @Published var showCoinPicker = false
    @Published var gamesSinceInterstitial = 0
    @Published var dailyGoals: [DailyGoal] = []
    @Published var goalsDate: String? = nil
    @Published var dragPiece: GamePiece? = nil
    @Published var dragPosition = CGPoint.zero
    @Published var previewCell: (row: Int, col: Int)? = nil

    var gridFrame = CGRect.zero
    let sound = SoundManager()

    private var idCounter = 1
    private var observers: [NSObjectProtocol] = []

    var heatPct: Double { Double(heat) / Double(MAX_HEAT) }
    var multiplierString: String { String(format: "×%.2f", 1.0 + Double(heat) * 0.125) }
    var heatLabel: String {
        switch Int(heatPct * 100) {
        case 100...: return "JACKPOT"
        case 75...:  return "FEVER"
        case 45...:  return "HOT"
        default:     return "WARM"
        }
    }

    init() {
        tray = [makePiece(), makePiece(), makePiece()]
        setupObservers()
        Task { await loadSave() }
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    // MARK: - Observers

    private func setupObservers() {
        observers.append(NotificationCenter.default.addObserver(
            forName: .rewardedAdEarned, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.grantRescueReward() }
        })
        observers.append(NotificationCenter.default.addObserver(
            forName: .rewardedAdFailed, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in
                self?.rescuing = false
                self?.showToast("Ad unavailable — try again shortly")
            }
        })
        observers.append(NotificationCenter.default.addObserver(
            forName: .purchaseSuccess, object: nil, queue: .main) { [weak self] note in
            guard let dict = note.object as? [String: String], let ident = dict["identifier"] else { return }
            Task { @MainActor in
                if let pack = COIN_PACKS.first(where: { $0.id == ident }) {
                    self?.coins += pack.coins
                    self?.showToast("+\(pack.coins) coins purchased!")
                    self?.showCoinPicker = false
                    self?.saveCurrent()
                }
            }
        })
        observers.append(NotificationCenter.default.addObserver(
            forName: .purchaseFailed, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.showToast("Purchase failed") }
        })
        observers.append(NotificationCenter.default.addObserver(
            forName: .purchaseCancelled, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor in self?.showToast("Purchase cancelled") }
        })
    }

    // MARK: - Piece Generation

    private func nextId() -> Int { defer { idCounter += 1 }; return idCounter }

    func makePiece(difficultyLevel: Double = 0) -> GamePiece {
        var shape = pickShape(difficulty: difficultyLevel)
        var tries = 0
        while !anyPlacement(shape: shape) && tries < 6 {
            shape = pickShape(difficulty: difficultyLevel)
            tries += 1
        }
        if !anyPlacement(shape: shape) { shape = [(0, 0)] }
        return GamePiece(
            id: nextId(),
            shape: shape,
            colorIdx: Int.random(in: 0..<BLOCK_PALETTE.count),
            isGold: Double.random(in: 0..<1) < GOLD_CHANCE,
            isBomb: false
        )
    }

    private func makeBombPiece() -> GamePiece {
        GamePiece(id: nextId(), shape: [(0, 0)], colorIdx: 0, isGold: false, isBomb: true)
    }

    private func pickShape(difficulty: Double) -> [(Int, Int)] {
        let complexChance = 0.22 + 0.5 * difficulty
        let pool = Double.random(in: 0..<1) < complexChance ? COMPLEX_SHAPES : SIMPLE_SHAPES
        return pool.randomElement()!
    }

    // MARK: - Placement

    func canPlace(shape: [(Int, Int)], at r0: Int, col c0: Int) -> Bool {
        for (dr, dc) in shape {
            let r = r0 + dr, c = c0 + dc
            guard r >= 0, r < BOARD_SIZE, c >= 0, c < BOARD_SIZE else { return false }
            guard grid[r][c] == nil else { return false }
        }
        return true
    }

    func anyPlacement(shape: [(Int, Int)]) -> Bool {
        for r in 0..<BOARD_SIZE {
            for c in 0..<BOARD_SIZE {
                if canPlace(shape: shape, at: r, col: c) { return true }
            }
        }
        return false
    }

    func commitPlacement(piece: GamePiece, row: Int, col: Int) {
        if piece.isBomb { detonateBomb(); return }

        var newGrid = grid
        for (dr, dc) in piece.shape {
            newGrid[row + dr][col + dc] = GridCell(colorIdx: piece.colorIdx, isGold: piece.isGold)
        }

        var fullRows = [Int]()
        var fullCols = [Int]()
        for r in 0..<BOARD_SIZE where newGrid[r].allSatisfy({ $0 != nil }) { fullRows.append(r) }
        for c in 0..<BOARD_SIZE where newGrid.allSatisfy({ $0[c] != nil }) { fullCols.append(c) }
        let linesCleared = fullRows.count + fullCols.count

        let oldHeat = heat
        let newHeat: Int
        if linesCleared > 0 {
            let gain = linesCleared * (linesCleared + 1)
            newHeat = min(oldHeat + gain + (piece.isGold ? 3 : 0), MAX_HEAT)
        } else {
            let cooled = max(oldHeat - max(1, Int(round(Double(oldHeat) / 12.0))), 0)
            newHeat = piece.isGold ? min(cooled + 3, MAX_HEAT) : cooled
        }

        let comboNext = linesCleared > 0 ? combo + 1 : 0
        let comboMult = 1.0 + Double(min(comboNext, 8)) * 0.15
        let burstMult = linesCleared > 1 ? 1.0 + Double(linesCleared - 1) * 0.35 : 1.0
        let heatMult  = 1.0 + Double(newHeat) * 0.125
        let placePts  = piece.shape.count * (piece.isGold ? 6 : 2)
        let clearPts  = linesCleared > 0
            ? Int(round(Double(linesCleared * BOARD_SIZE * 10) * heatMult * comboMult * burstMult))
            : 0

        heat  = newHeat
        score += placePts + clearPts
        combo  = comboNext
        best   = max(best, score)

        if linesCleared > 0 {
            coins += linesCleared + comboNext / 3
            let popText = comboNext > 1 ? "\(comboNext)x combo +\(clearPts)" : "Line clear +\(clearPts)"
            comboPop = (id: Int(Date().timeIntervalSince1970 * 1000), text: popText)
            if linesCleared > 1 || comboNext >= 3 { triggerShake() }
        }

        bumpGoal(.pieces, amount: 1)
        bumpGoal(.score, amount: placePts + clearPts)
        bumpGoal(.heat, amount: newHeat, mode: "max")
        if linesCleared > 0 { bumpGoal(.lines, amount: linesCleared) }
        if piece.isGold { bumpGoal(.wildgem, amount: 1) }

        if linesCleared > 1 { showToast("\(linesCleared) lines! Burst bonus") }
        else if comboNext >= 3 { showToast("\(comboNext)x combo cooking") }
        if piece.isGold { showToast("Wild Gem! Bonus payout") }

        if !sfxMuted {
            if piece.isGold { sound.playGold() }
            else if linesCleared > 0 { sound.playClear(lines: linesCleared, heat: newHeat) }
            else { sound.playPlace() }
        }

        let justHitMax = newHeat >= MAX_HEAT && oldHeat < MAX_HEAT && !bombArmed
        let diff = min(1.0, Double(score) / 4000.0)

        var remaining = tray.filter { $0.id != piece.id }
        var nextTray = remaining.isEmpty
            ? [makePiece(difficultyLevel: diff), makePiece(difficultyLevel: diff), makePiece(difficultyLevel: diff)]
            : remaining
        if justHitMax {
            let slot = Int.random(in: 0..<nextTray.count)
            nextTray[slot] = makeBombPiece()
            bombArmed = true
        }
        tray = nextTray

        if linesCleared > 0 {
            var keys = Set<String>()
            fullRows.forEach { r in (0..<BOARD_SIZE).forEach { c in keys.insert("\(r)-\(c)") } }
            fullCols.forEach { c in (0..<BOARD_SIZE).forEach { r in keys.insert("\(r)-\(c)") } }
            clearingCells = keys
            grid = newGrid
            Task {
                try? await Task.sleep(nanoseconds: 220_000_000)
                var cleared = newGrid
                fullRows.forEach { r in (0..<BOARD_SIZE).forEach { c in cleared[r][c] = nil } }
                fullCols.forEach { c in (0..<BOARD_SIZE).forEach { r in cleared[r][c] = nil } }
                grid = cleared
                clearingCells = []
                checkGameOver()
            }
        } else {
            grid = newGrid
            checkGameOver()
        }

        saveCurrent()
    }

    private func detonateBomb() {
        var filled = [String]()
        for r in 0..<BOARD_SIZE { for c in 0..<BOARD_SIZE { if grid[r][c] != nil { filled.append("\(r)-\(c)") } } }
        let bonus = 300 + filled.count * 15
        clearingCells = Set(filled)
        score += bonus
        coins += 10
        best = max(best, score)
        bumpGoal(.jackpot, amount: 1)
        jackpotBonus = bonus
        jackpotFlash = true
        shareReady = true
        comboPop = (id: Int(Date().timeIntervalSince1970 * 1000), text: "BOARD WIPE +\(bonus)")
        triggerShake()
        if !sfxMuted { sound.playJackpot() }
        heat = MAX_HEAT / 2

        Task {
            try? await Task.sleep(nanoseconds: 260_000_000)
            grid = Array(repeating: Array(repeating: nil, count: BOARD_SIZE), count: BOARD_SIZE)
            clearingCells = []
            checkGameOver()
        }
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            jackpotFlash = false
            jackpotBonus = nil
        }

        let diff = min(1.0, Double(score) / 4000.0)
        var nextTray = tray.filter { !$0.isBomb }
        if nextTray.isEmpty {
            nextTray = [makePiece(difficultyLevel: diff), makePiece(difficultyLevel: diff), makePiece(difficultyLevel: diff)]
        }
        tray = nextTray
        bombArmed = false
        showToast("JACKPOT! +\(bonus)")
        saveCurrent()
    }

    // MARK: - Drag

    func startDrag(piece: GamePiece, at position: CGPoint) {
        dragPiece = piece
        dragPosition = position
        updatePreview(at: position)
    }

    func updateDrag(at position: CGPoint) {
        dragPosition = position
        updatePreview(at: position)
    }

    func endDrag() {
        if let piece = dragPiece, let cell = previewCell,
           canPlace(shape: piece.shape, at: cell.row, col: cell.col) {
            commitPlacement(piece: piece, row: cell.row, col: cell.col)
        } else if dragPiece != nil {
            if !sfxMuted { sound.playInvalid() }
        }
        dragPiece = nil
        previewCell = nil
    }

    private func updatePreview(at globalPoint: CGPoint) {
        guard let piece = dragPiece, !gridFrame.isEmpty else { previewCell = nil; return }
        let cellSize = gridFrame.width / CGFloat(BOARD_SIZE)
        let liftOffset: CGFloat = 70
        let localX = globalPoint.x - gridFrame.minX
        let localY = globalPoint.y - gridFrame.minY - liftOffset
        let dims = piece.dims
        let col = Int(floor(localX / cellSize)) - (dims.cols - 1) / 2
        let row = Int(floor(localY / cellSize)) - (dims.rows - 1) / 2
        previewCell = (row: row, col: col)
    }

    // MARK: - Erase

    func toggleEraser() {
        if eraseMode { eraseMode = false; return }
        guard coins >= ERASER_COST else { showToast("Not enough coins"); return }
        eraseMode = true
        showToast("Tap a block to erase it")
    }

    func handleCellTap(row: Int, col: Int) {
        guard eraseMode else { return }
        guard grid[row][col] != nil else { eraseMode = false; return }
        grid[row][col] = nil
        coins -= ERASER_COST
        eraseMode = false
        if !sfxMuted { sound.playBooster() }
        saveCurrent()
        checkGameOver()
    }

    // MARK: - Reroll

    func rerollTray() {
        guard coins >= REROLL_COST, !eraseMode else { return }
        coins -= REROLL_COST
        let diff = min(1.0, Double(score) / 4000.0)
        tray = [makePiece(difficultyLevel: diff), makePiece(difficultyLevel: diff), makePiece(difficultyLevel: diff)]
        if !sfxMuted { sound.playBooster() }
        showToast("Tray rerolled")
        saveCurrent()
    }

    // MARK: - Daily Goals

    func bumpGoal(_ type: GoalType, amount: Int, mode: String = "add") {
        var completedAny = false
        dailyGoals = dailyGoals.map { g in
            guard g.type == type, !g.claimed else { return g }
            let newProg = mode == "max" ? max(g.progress, amount) : g.progress + amount
            let capped = min(newProg, g.target)
            if capped >= g.target && g.progress < g.target { completedAny = true }
            var updated = g; updated.progress = capped; return updated
        }
        if completedAny { showToast("Daily objective complete!") }
    }

    func claimGoal(id: String) {
        dailyGoals = dailyGoals.map { g in
            guard g.id == id, !g.claimed, g.progress >= g.target else { return g }
            coins += g.reward
            if !sfxMuted { sound.playBooster() }
            showToast("+\(g.reward) coins claimed!")
            var updated = g; updated.claimed = true; return updated
        }
        saveCurrent()
    }

    // MARK: - Rescue

    func watchAdToContinue() {
        rescuing = true
        NativeAdMobBridge.shared.handle(["action": "showRewardVideoAd"])
    }

    private func grantRescueReward() {
        let filled = (0..<BOARD_SIZE).flatMap { r in (0..<BOARD_SIZE).compactMap { c in grid[r][c] != nil ? (r, c) : nil } }.shuffled()
        for (r, c) in filled.prefix(6) { grid[r][c] = nil }
        rescueUsed = true
        gameOver = false
        rescuing = false
        if !sfxMuted { sound.playRescue() }
    }

    // MARK: - Restart

    func restart() {
        grid = Array(repeating: Array(repeating: nil, count: BOARD_SIZE), count: BOARD_SIZE)
        score = 0
        heat = min(streak - 1, 5)
        gameOver = false
        dragPiece = nil
        clearingCells = []
        rescueUsed = false
        bombArmed = false
        eraseMode = false
        combo = 0
        comboPop = nil
        jackpotBonus = nil
        shake = false
        tray = [makePiece(), makePiece(), makePiece()]

        gamesSinceInterstitial += 1
        if gamesSinceInterstitial >= INTERSTITIAL_EVERY {
            gamesSinceInterstitial = 0
            NativeAdMobBridge.shared.handle(["action": "showInterstitial"])
            NativeAdMobBridge.shared.handle(["action": "prepareInterstitial",
                "options": ["adId": "ca-app-pub-7262617456411456/6307395181"]])
        }

        saveCurrent()
    }

    // MARK: - Game Over

    func checkGameOver() {
        guard !gameOver, clearingCells.isEmpty, !tray.isEmpty else { return }
        if tray.allSatisfy({ !anyPlacement(shape: $0.shape) }) {
            if !sfxMuted { sound.playGameOver() }
            gameOver = true
        }
    }

    // MARK: - Animations

    func showToast(_ message: String) {
        toast = message
        Task {
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            if toast == message { toast = nil }
        }
    }

    func triggerShake() {
        shake = true
        Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            shake = false
        }
    }

    // MARK: - Ads

    func initializeAds() {
        NativeAdMobBridge.shared.handle(["action": "initialize"])
        NativeAdMobBridge.shared.handle([
            "action": "showBanner",
            "options": ["adId": "ca-app-pub-7262617456411456/9508273591", "adSize": "BANNER", "position": "BOTTOM_CENTER"]
        ])
        NativeAdMobBridge.shared.handle([
            "action": "prepareRewardVideoAd",
            "options": ["adId": "ca-app-pub-7262617456411456/7812048544"]
        ])
        NativeAdMobBridge.shared.handle([
            "action": "prepareInterstitial",
            "options": ["adId": "ca-app-pub-7262617456411456/6307395181"]
        ])
    }

    // MARK: - Coin Picker

    func openCoinPicker() {
        showCoinPicker = true
        PurchaseManager.shared.fetchOfferings { _ in }
    }

    func buyCoinPack(id: String) {
        PurchaseManager.shared.purchasePackage(identifier: id)
    }

    // MARK: - Persistence

    func loadSave() async {
        var save = SaveData()
        if let json = UserDefaults.standard.string(forKey: "stoke-save"),
           let data = json.data(using: .utf8),
           let decoded = try? JSONDecoder().decode(SaveData.self, from: data) {
            save = decoded
        }

        var newStreak = max(save.streak, 1)
        var newFreeze = save.freezeAvailable
        let today = todayString()

        if let last = save.lastPlayDate, last != today {
            let gap = daysBetween(last, today)
            if gap == 1 { newStreak += 1 }
            else if gap > 1 { if newFreeze { newFreeze = false } else { newStreak = 1 } }
        }
        if newStreak > 0 && newStreak % 7 == 0 { newFreeze = true }

        var newGoals = save.dailyGoals.isEmpty ? generateDailyGoals() : save.dailyGoals
        var newGoalsDate = save.goalsDate
        if newGoalsDate != today { newGoals = generateDailyGoals(); newGoalsDate = today }

        best = save.best
        sfxMuted = save.sfxMuted
        musicMuted = save.musicMuted
        streak = newStreak
        freezeAvailable = newFreeze
        coins = max(save.coins, 0)
        heat = min(newStreak - 1, 5)
        dailyGoals = newGoals
        goalsDate = newGoalsDate
        gamesSinceInterstitial = save.gamesSinceInterstitial
        loaded = true

        saveCurrent()
    }

    func saveCurrent() {
        let save = SaveData(
            best: max(best, score),
            sfxMuted: sfxMuted,
            musicMuted: musicMuted,
            streak: streak,
            lastPlayDate: todayString(),
            freezeAvailable: freezeAvailable,
            coins: coins,
            dailyGoals: dailyGoals,
            goalsDate: goalsDate,
            gamesSinceInterstitial: gamesSinceInterstitial
        )
        if let data = try? JSONEncoder().encode(save), let json = String(data: data, encoding: .utf8) {
            UserDefaults.standard.set(json, forKey: "stoke-save")
        }
    }
}
