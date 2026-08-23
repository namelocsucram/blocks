import SwiftUI

// MARK: - Helpers

func lightenColor(_ c: Color, by a: CGFloat = 0.45) -> Color {
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, alpha: CGFloat = 0
    UIColor(c).getRed(&r, green: &g, blue: &b, alpha: &alpha)
    return Color(red: r + (1-r)*a, green: g + (1-g)*a, blue: b + (1-b)*a)
}

func gemGrad(_ base: Color) -> LinearGradient {
    LinearGradient(colors: [lightenColor(base), base], startPoint: .topLeading, endPoint: .bottomTrailing)
}

// MARK: - Design Tokens

let C_BG_TOP  = Color(red: 0.141, green: 0.071, blue: 0.220)   // #241238
let C_BG_BOT  = Color(red: 0.039, green: 0.020, blue: 0.071)   // #0A0512
let C_PANEL   = Color(red: 0.118, green: 0.063, blue: 0.188)   // #1E1030
let C_BORDER  = Color(red: 0.290, green: 0.180, blue: 0.400)   // #4A2E66
let C_GOLD    = Color(red: 1.000, green: 0.839, blue: 0.353)   // #FFD65A
let C_GOLDTXT = Color(red: 1.000, green: 0.953, blue: 0.769)   // #FFF3C4
let C_ACCENT  = Color(red: 0.788, green: 0.643, blue: 0.910)   // #C9B8E8
let C_MUTED   = Color(red: 0.541, green: 0.486, blue: 0.659)   // #8A7CA8

// Grid internal layout — kept in sync with GameModel.updatePreview
let GRID_PAD: CGFloat  = 6
let GRID_GAP: CGFloat  = 3

// MARK: - Preference Key

private struct GridFrameKey: PreferenceKey {
    static var defaultValue = CGRect.zero
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) { value = nextValue() }
}

// MARK: - Game View

struct GameView: View {
    @StateObject private var model = GameModel()

    var body: some View {
        ZStack {
            LinearGradient(colors: [C_BG_TOP, C_BG_BOT], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                HeaderView(model: model)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                GoalsToggleBtn(model: model)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                StatsRowView(model: model)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                GridBoardView(model: model)
                    .padding(.horizontal, 12)
                    .padding(.top, 8)

                PieceTrayView(model: model)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                BoosterBarView(model: model)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

                Spacer(minLength: 0)
            }
            .padding(.bottom, 60)

            // Floating drag ghost — centered on touch point, lifted 70 pt
            if let piece = model.dragPiece {
                FloatingPieceView(piece: piece)
                    .position(x: model.dragPosition.x,
                              y: model.dragPosition.y - 70)
                    .allowsHitTesting(false)
            }

            if model.jackpotFlash { JackpotFlashOverlay(model: model) }
            if model.gameOver     { GameOverOverlay(model: model) }
            if model.rescuing     { RescuingOverlay() }

            ToastView(message: model.toast)
            ComboPopView(comboPop: model.comboPop)
        }
        // Named coordinate space — drag gestures and grid frame both use this
        .coordinateSpace(name: "board")
        .sheet(isPresented: $model.showGoals)      { DailyGoalsSheet(model: model) }
        .sheet(isPresented: $model.showCoinPicker) { CoinPickerSheet(model: model) }
        .preferredColorScheme(.dark)
        .statusBarHidden()
        .onAppear { model.initializeAds() }
    }
}

// MARK: - Header

private struct HeaderView: View {
    @ObservedObject var model: GameModel

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 0) {
                HStack(spacing: 8) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(C_GOLD)
                        .shadow(color: C_GOLD.opacity(0.6), radius: 6)
                    Text("STOKE")
                        .font(.system(size: 32, weight: .black, design: .rounded))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [C_GOLDTXT, C_GOLD,
                                         Color(red: 0.910, green: 0.655, blue: 0.180)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .shadow(color: C_GOLD.opacity(0.35), radius: 9)
                }
                Spacer()
                HStack(spacing: 6) {
                    iconBtn("music", icon: model.musicMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                            active: !model.musicMuted) {
                        model.musicMuted.toggle(); model.saveCurrent()
                    }
                    iconBtn("sfx", icon: model.sfxMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                            active: !model.sfxMuted) {
                        model.sfxMuted.toggle(); model.saveCurrent()
                    }
                }
            }

            // Badge row
            HStack(spacing: 6) {
                badge(model.heatLabel,
                      color: model.heatPct >= 0.75
                          ? Color(red: 1, green: 0.541, blue: 0.239) : C_GOLD)
                badge("Day \(model.streak) streak")
                if model.freezeAvailable {
                    badge("❄️ freeze", color: Color(red: 0.561, green: 0.827, blue: 0.910))
                }
                badge("🪙 \(model.coins)")
            }
        }
    }

    private func iconBtn(_ label: String, icon: String, active: Bool,
                         action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 1) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(active ? C_GOLD : C_ACCENT)
                Text(label)
                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                    .foregroundStyle(C_MUTED)
                    .textCase(.uppercase)
            }
            .frame(width: 44, height: 36)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(C_PANEL)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(C_BORDER, lineWidth: 1))
            )
        }
    }

    private func badge(_ text: String, color: Color = C_GOLD) -> some View {
        Text(text)
            .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
            .foregroundStyle(color)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(C_PANEL)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(C_BORDER, lineWidth: 1))
            )
    }
}

// MARK: - Goals Toggle Button

private struct GoalsToggleBtn: View {
    @ObservedObject var model: GameModel

    var statusText: String {
        let ready = model.dailyGoals.filter { $0.progress >= $0.target && !$0.claimed }.count
        if ready > 0 { return "\(ready) ready!" }
        let claimed = model.dailyGoals.filter { $0.claimed }.count
        return "\(claimed)/\(model.dailyGoals.count)"
    }

    var body: some View {
        Button { model.showGoals = true } label: {
            HStack {
                Label("Daily Objectives", systemImage: "target")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(C_GOLD)
                Spacer()
                Text(statusText)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(C_ACCENT)
            }
            .padding(.horizontal, 12).padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(C_PANEL)
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(C_BORDER, lineWidth: 1))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Stats Row

private struct StatsRowView: View {
    @ObservedObject var model: GameModel

    var body: some View {
        HStack(spacing: 8) {
            // Score — wider, gold highlight border
            VStack(spacing: 2) {
                Text("SCORE")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(C_GOLDTXT.opacity(0.9))
                Text("\(model.score)")
                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .lineLimit(1).minimumScaleFactor(0.5)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8).padding(.horizontal, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(LinearGradient(
                        colors: [Color(red:0.192,green:0.110,blue:0.290), C_PANEL],
                        startPoint: .top, endPoint: .bottom))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(C_GOLD.opacity(0.4), lineWidth: 1))
            )

            miniBox("BEST",  "\(model.best)")
            miniBox("COMBO", model.combo > 0 ? "\(model.combo)x" : "-")

            // Heat — embedded bar
            VStack(spacing: 4) {
                Text("Heat \(model.multiplierString)")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(C_GOLDTXT.opacity(0.9))
                    .lineLimit(1)
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(C_BG_BOT)
                            .frame(height: 8)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(LinearGradient(
                                colors: [C_GOLD,
                                         Color(red:1, green:0.42, blue:0.42),
                                         Color(red:1, green:0.231, blue:0.361)],
                                startPoint: .leading, endPoint: .trailing))
                            .frame(width: geo.size.width * model.heatPct, height: 8)
                            .shadow(color: Color(red:1, green:0.42, blue:0.42).opacity(0.7), radius: 4)
                            .animation(.easeOut(duration: 0.3), value: model.heatPct)
                    }
                }
                .frame(height: 8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8).padding(.horizontal, 6)
            .background(panelBg)
        }
    }

    private func miniBox(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(C_MUTED)
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundStyle(C_GOLDTXT)
                .lineLimit(1).minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8).padding(.horizontal, 6)
        .background(panelBg)
    }

    private var panelBg: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(C_PANEL)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(C_BORDER, lineWidth: 1))
    }
}

// MARK: - Grid Board

struct GridBoardView: View {
    @ObservedObject var model: GameModel
    @State private var glowPhase = false

    var body: some View {
        GeometryReader { geo in
            let cs     = (geo.size.width - 2*GRID_PAD - GRID_GAP * CGFloat(BOARD_SIZE-1)) / CGFloat(BOARD_SIZE)
            let stride = cs + GRID_GAP

            ZStack(alignment: .topLeading) {
                C_PANEL

                // Placed cells
                ForEach(0..<BOARD_SIZE, id: \.self) { r in
                    ForEach(0..<BOARD_SIZE, id: \.self) { c in
                        let key = "\(r)-\(c)"
                        let clearing = model.clearingCells.contains(key)
                        if let cell = model.grid[r][c] {
                            BlockCell(colorIdx: cell.colorIdx, isGold: cell.isGold)
                                .frame(width: cs, height: cs)
                                .scaleEffect(clearing ? 1.4 : 1.0)
                                .opacity(clearing ? 0 : 1)
                                .animation(.easeOut(duration: 0.18), value: clearing)
                                .offset(x: GRID_PAD + CGFloat(c)*stride,
                                        y: GRID_PAD + CGFloat(r)*stride)
                        }
                        // Transparent tap target for every cell (erase mode)
                        Color.clear
                            .frame(width: cs, height: cs)
                            .contentShape(Rectangle())
                            .offset(x: GRID_PAD + CGFloat(c)*stride,
                                    y: GRID_PAD + CGFloat(r)*stride)
                            .onTapGesture { model.handleCellTap(row: r, col: c) }
                    }
                }

                // Drop preview
                if let piece = model.dragPiece, let cell = model.previewCell {
                    let valid = model.canPlace(shape: piece.shape, at: cell.row, col: cell.col)
                    let previewFill  = valid ? Color(red:0.290,green:0.867,blue:0.502,opacity:0.55)
                                             : Color(red:1,green:0.231,blue:0.361,opacity:0.55)
                    let previewLine  = valid ? Color(red:0.290,green:0.867,blue:0.502)
                                             : Color(red:1,green:0.231,blue:0.361)
                    ForEach(piece.shape.indices, id: \.self) { i in
                        let (dr, dc) = piece.shape[i]
                        let pr = cell.row + dr; let pc = cell.col + dc
                        if pr >= 0 && pr < BOARD_SIZE && pc >= 0 && pc < BOARD_SIZE {
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(previewFill)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 4)
                                        .stroke(previewLine,
                                                style: StrokeStyle(lineWidth: 1, dash: [4,2]))
                                )
                                .frame(width: cs, height: cs)
                                .offset(x: GRID_PAD + CGFloat(pc)*stride,
                                        y: GRID_PAD + CGFloat(pr)*stride)
                        }
                    }
                }
            }
            .modifier(ShakeModifier(active: model.shake))
        }
        .aspectRatio(1, contentMode: .fit)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(C_PANEL)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(model.eraseMode ? Color(red:1,green:0.231,blue:0.361) : C_GOLD,
                        lineWidth: 2)
        )
        .shadow(
            color: (model.eraseMode
                ? Color(red:1,green:0.231,blue:0.361) : C_GOLD)
                .opacity(glowPhase ? 0.55 : 0.18),
            radius: glowPhase ? 12 : 4
        )
        .onAppear { withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) { glowPhase = true } }
        // Capture grid frame in the named "board" coordinate space
        .background(
            GeometryReader { geo in
                Color.clear
                    .preference(key: GridFrameKey.self,
                                value: geo.frame(in: .named("board")))
                    .onAppear {
                        let f = geo.frame(in: .named("board"))
                        if !f.isEmpty { model.gridFrame = f }
                    }
            }
        )
        .onPreferenceChange(GridFrameKey.self) { frame in
            if !frame.isEmpty { model.gridFrame = frame }
        }
    }
}

private struct BlockCell: View {
    let colorIdx: Int
    let isGold: Bool

    var body: some View {
        let base = isGold ? GOLD_BLOCK_COLOR : BLOCK_PALETTE[colorIdx % BLOCK_PALETTE.count]
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(gemGrad(base))
            .overlay(
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(Color.white.opacity(0.4), lineWidth: 0.5)
                    .blendMode(.screen)
            )
            .shadow(color: base.opacity(0.6), radius: 4, x: 0, y: 1)
    }
}

// MARK: - Piece Tray

struct PieceTrayView: View {
    @ObservedObject var model: GameModel

    var body: some View {
        HStack(spacing: 0) {
            ForEach(model.tray) { piece in
                TrayPieceView(piece: piece, model: model)
            }
        }
        .padding(.vertical, 12).padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(C_PANEL)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(C_BORDER, lineWidth: 1))
        )
    }
}

private struct TrayPieceView: View {
    let piece: GamePiece
    @ObservedObject var model: GameModel

    var body: some View {
        let isDragging = model.dragPiece?.id == piece.id
        ZStack {
            Color.clear
            PiecePreview(piece: piece, cellSize: 14)
        }
        .frame(maxWidth: .infinity, minHeight: 68)
        .contentShape(Rectangle())
        .overlay(alignment: .topTrailing) {
            if piece.isGold {
                Image(systemName: "sparkles")
                    .font(.system(size: 9))
                    .foregroundStyle(C_GOLD)
                    .padding(4)
            }
        }
        .opacity(isDragging ? 0.25 : 1.0)
        .gesture(
            DragGesture(minimumDistance: 1, coordinateSpace: .named("board"))
                .onChanged { value in
                    if model.dragPiece?.id != piece.id {
                        model.startDrag(piece: piece, at: value.location)
                    } else {
                        model.updateDrag(at: value.location)
                    }
                }
                .onEnded { _ in model.endDrag() }
        )
        .disabled(model.gameOver || model.eraseMode)
    }
}

struct PiecePreview: View {
    let piece: GamePiece
    let cellSize: CGFloat

    var body: some View {
        let dims = piece.dims
        Canvas { ctx, _ in
            let base    = piece.isBomb ? Color(white: 0.3)
                        : piece.isGold ? GOLD_BLOCK_COLOR
                        : BLOCK_PALETTE[piece.colorIdx % BLOCK_PALETTE.count]
            let lighter = piece.isBomb ? Color(white: 0.5) : lightenColor(base)
            for (r, c) in piece.shape {
                let s = cellSize + 2
                let rect = CGRect(x: CGFloat(c)*s, y: CGFloat(r)*s,
                                  width: cellSize, height: cellSize)
                let path = Path(roundedRect: rect, cornerRadius: 3)
                ctx.fill(path, with: .linearGradient(
                    Gradient(colors: [lighter, base]),
                    startPoint: CGPoint(x: rect.minX, y: rect.minY),
                    endPoint:   CGPoint(x: rect.maxX, y: rect.maxY)))
                ctx.stroke(path, with: .color(.white.opacity(0.35)), lineWidth: 0.5)
            }
            if piece.isBomb {
                var a = AttributedString("💣")
                a.font = .systemFont(ofSize: cellSize * 0.8)
                let cx = CGFloat(dims.cols) * (cellSize + 2) / 2
                let cy = CGFloat(dims.rows) * (cellSize + 2) / 2
                ctx.draw(Text(a), at: CGPoint(x: cx, y: cy), anchor: .center)
            }
        }
        .frame(
            width:  CGFloat(dims.cols) * (cellSize + 2) - 2,
            height: CGFloat(dims.rows) * (cellSize + 2) - 2
        )
    }
}

// MARK: - Floating Drag Ghost

private struct FloatingPieceView: View {
    let piece: GamePiece
    private let cs: CGFloat = 26
    private let gap: CGFloat = 3

    var body: some View {
        let dims = piece.dims
        Canvas { ctx, _ in
            let base    = piece.isBomb ? Color(white: 0.3)
                        : piece.isGold ? GOLD_BLOCK_COLOR
                        : BLOCK_PALETTE[piece.colorIdx % BLOCK_PALETTE.count]
            let lighter = piece.isBomb ? Color(white: 0.5) : lightenColor(base)
            for (r, c) in piece.shape {
                let s = cs + gap
                let rect = CGRect(x: CGFloat(c)*s, y: CGFloat(r)*s,
                                  width: cs, height: cs)
                let path = Path(roundedRect: rect, cornerRadius: 5)
                ctx.fill(path, with: .linearGradient(
                    Gradient(colors: [lighter, base]),
                    startPoint: CGPoint(x: rect.minX, y: rect.minY),
                    endPoint:   CGPoint(x: rect.maxX, y: rect.maxY)))
                ctx.stroke(path, with: .color(.white.opacity(0.4)), lineWidth: 0.8)
            }
        }
        .frame(
            width:  CGFloat(dims.cols) * (cs + gap) - gap,
            height: CGFloat(dims.rows) * (cs + gap) - gap
        )
        .shadow(color: .white.opacity(0.3), radius: 12)
        .opacity(0.9)
    }
}

// MARK: - Booster Bar

private struct BoosterBarView: View {
    @ObservedObject var model: GameModel

    var body: some View {
        HStack(spacing: 8) {
            boosterBtn("🔄 Reroll", cost: REROLL_COST,
                       enabled: model.coins >= REROLL_COST && !model.eraseMode,
                       active: false) { model.rerollTray() }

            boosterBtn("✂️ Erase", cost: ERASER_COST,
                       enabled: model.coins >= ERASER_COST || model.eraseMode,
                       active: model.eraseMode) { model.toggleEraser() }

            Button { model.openCoinPicker() } label: {
                VStack(spacing: 2) {
                    Text("🪙").font(.system(size: 16))
                    Text("Get coins")
                        .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color(red: 0.165, green: 0.106, blue: 0.031))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(LinearGradient(
                            colors: [C_GOLD, Color(red:1,green:0.541,blue:0.239)],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func boosterBtn(_ label: String, cost: Int, enabled: Bool, active: Bool,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(label)
                    .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(active ? Color(red:1,green:0.231,blue:0.361)
                                           : (enabled ? .white : .white.opacity(0.35)))
                Text("\(cost)🪙")
                    .font(.system(size: 9.5, weight: .regular, design: .monospaced))
                    .foregroundStyle(C_MUTED)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(C_PANEL)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(active ? Color(red:1,green:0.231,blue:0.361) : C_BORDER,
                                    lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .disabled(!enabled && !active)
    }
}

// MARK: - Game Over Overlay

private struct GameOverOverlay: View {
    @ObservedObject var model: GameModel

    var body: some View {
        ZStack {
            Color(red:0.039, green:0.020, blue:0.071).opacity(0.87).ignoresSafeArea()
            VStack(spacing: 0) {
                Image(systemName: "flame.fill")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(C_GOLD)
                    .padding(.bottom, 10)
                Text("Table's Closed")
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(C_GOLD)
                    .padding(.bottom, 4)
                Text("No move fits. Final heat reached \(model.multiplierString).")
                    .font(.system(size: 12.5))
                    .foregroundStyle(C_ACCENT)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 16)
                HStack(spacing: 24) {
                    scoreCol("SCORE", "\(model.score)")
                    scoreCol("BEST",  "\(model.best)")
                }
                .padding(.bottom, 16)
                if !model.rescueUsed {
                    Button { model.watchAdToContinue() } label: {
                        Text("Watch ad to clear space & continue")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(Color(red:0.918, green:0.969, blue:0.980))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10).padding(.horizontal, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(Color(red:0.180, green:0.353, blue:0.400))
                                    .overlay(RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color(red:0.243,green:0.463,blue:0.518), lineWidth: 1))
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 10)
                    .disabled(model.rescuing)
                }
                Button { model.restart() } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.counterclockwise").font(.system(size: 12))
                        Text("Play again")
                    }
                    .font(.system(size: 12.5, weight: .bold, design: .monospaced))
                    .textCase(.uppercase)
                    .foregroundStyle(Color(red:0.165, green:0.106, blue:0.031))
                    .padding(.horizontal, 16).padding(.vertical, 9)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(LinearGradient(
                                colors: [C_GOLD, Color(red:1,green:0.541,blue:0.239)],
                                startPoint: .topLeading, endPoint: .bottomTrailing))
                    )
                }
                .buttonStyle(.plain)
            }
            .padding(28)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(C_PANEL)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(C_BORDER, lineWidth: 1))
            )
            .padding(.horizontal, 24)
        }
    }

    private func scoreCol(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                .foregroundStyle(C_MUTED)
            Text(value)
                .font(.system(size: 18, weight: .bold, design: .monospaced))
                .foregroundStyle(C_GOLDTXT)
        }
    }
}

// MARK: - Jackpot Flash

private struct JackpotFlashOverlay: View {
    @ObservedObject var model: GameModel

    var body: some View {
        ZStack {
            Color.yellow.opacity(0.18).ignoresSafeArea()
            VStack(spacing: 8) {
                Text("JACKPOT!")
                    .font(.system(size: 46, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(colors: [C_GOLDTXT, C_GOLD,
                                                Color(red:1,green:0.541,blue:0.239)],
                                       startPoint: .top, endPoint: .bottom))
                    .shadow(color: C_GOLD.opacity(0.7), radius: 16)
                if let bonus = model.jackpotBonus {
                    Text("+\(bonus)")
                        .font(.system(size: 26, weight: .bold, design: .monospaced))
                        .foregroundStyle(C_GOLDTXT)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Rescuing

private struct RescuingOverlay: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            ProgressView().scaleEffect(1.5).tint(C_GOLD)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Toast

private struct ToastView: View {
    let message: String?

    var body: some View {
        VStack {
            Spacer()
            if let msg = message {
                Text(msg)
                    .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(C_GOLD)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(C_PANEL)
                            .overlay(Capsule().stroke(C_GOLD.opacity(0.5), lineWidth: 1))
                    )
                    .transition(.opacity.combined(with: .scale))
                    .animation(.spring(duration: 0.3), value: msg)
            }
        }
        .padding(.bottom, 76)
        .allowsHitTesting(false)
        .animation(.spring(duration: 0.3), value: message)
    }
}

// MARK: - Combo Pop

private struct ComboPopView: View {
    let comboPop: (id: Int, text: String)?

    var body: some View {
        if let pop = comboPop {
            Text(pop.text)
                .font(.system(size: 28, weight: .black, design: .rounded))
                .foregroundStyle(C_GOLDTXT)
                .shadow(color: Color(red:1,green:0.541,blue:0.239).opacity(0.9), radius: 9)
                .id(pop.id)
                .transition(.scale(scale: 0.5).combined(with: .opacity))
                .allowsHitTesting(false)
        }
    }
}

// MARK: - Daily Goals Sheet

struct DailyGoalsSheet: View {
    @ObservedObject var model: GameModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                C_BG_BOT.ignoresSafeArea()
                List {
                    ForEach(model.dailyGoals) { goal in
                        GoalRow(goal: goal) { model.claimGoal(id: goal.id) }
                            .listRowBackground(C_PANEL)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Daily Goals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }.foregroundStyle(C_GOLD)
                }
            }
        }
    }
}

private struct GoalRow: View {
    let goal: DailyGoal
    let onClaim: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(goal.label)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(C_GOLDTXT)
                ProgressView(value: Double(goal.progress), total: Double(goal.target))
                    .tint(goal.claimed ? .green : C_GOLD)
                Text("\(min(goal.progress, goal.target)) / \(goal.target)")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(C_MUTED)
            }
            Spacer()
            if goal.claimed {
                Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
            } else if goal.progress >= goal.target {
                Button("Claim +\(goal.reward)🪙", action: onClaim)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(C_GOLD)
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .tint(C_GOLD)
            } else {
                Text("+\(goal.reward)🪙")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(C_MUTED)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Coin Picker Sheet

struct CoinPickerSheet: View {
    @ObservedObject var model: GameModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ZStack {
                C_BG_BOT.ignoresSafeArea()
                VStack(spacing: 12) {
                    Text("Bigger packs give more coins per dollar.")
                        .font(.system(size: 12.5))
                        .foregroundStyle(C_ACCENT)
                        .padding(.top, 8)
                    ForEach(COIN_PACKS, id: \.id) { pack in
                        Button { model.buyCoinPack(id: pack.id) } label: {
                            HStack {
                                Text("🪙 \(pack.coins)\(pack.id == "coins_2000" ? " · best value" : "")")
                                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(C_GOLD)
                                Spacer()
                                Text(pack.price)
                                    .font(.system(size: 12.5, weight: .medium, design: .monospaced))
                                    .foregroundStyle(C_ACCENT)
                            }
                            .padding(.horizontal, 14).padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(C_BG_TOP)
                                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(C_BORDER, lineWidth: 1))
                            )
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 20)
                    }
                    Spacer()
                }
            }
            .navigationTitle("Get Coins")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(C_ACCENT)
                }
            }
        }
    }
}

// MARK: - Shake Modifier

struct ShakeModifier: ViewModifier {
    let active: Bool
    @State private var offset: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .onChange(of: active) { isActive in
                guard isActive else { offset = 0; return }
                withAnimation(.easeInOut(duration: 0.05).repeatCount(5, autoreverses: true)) {
                    offset = 5
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.28) { offset = 0 }
            }
    }
}
