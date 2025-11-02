//
//  GameViewController.swift
//  Luigi Mansion
//
//  Created by rikuya on 2024/10/14.
//

import UIKit
import AVKit
import AVFoundation // ▽▽▽ [NEW FLOW] サウンド再生のために追加 ▽▽▽
import CoreMotion

class GameViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    
    var isQRCodeDetected = false
    
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    
    var hasSentData = false
    
    var isDebugMode = false
    var isQRCodeVisible: Bool = false// QRコードが見えているかのフラグ
    var qrCodeLostTimer: Timer? // QRコードが見えなくなった時のタイマー
    var isDummyMode: Bool = false // ダミーQRコードが読み取られたかどうかのフラG
    var isSuctionMode = false // 吸い取りモードかどうかのフラグ

    var detectedQRCodeType: String? // 読み取られたQRコードのタイプ
    
    var exterminatedCount = 0
    /*
    var remainingTime: Int = 270 // 4分30秒
    var gameTimer: Timer?
    */
    let motionManager = CMMotionManager()
    var qrCodeNumber: Int?
    var currentSuctionScore: Int = 0
    var currentCartridgeIndexBeingUsed: Int = 0 // ▽▽▽ [FIX] 攻撃中のスロットを記憶する変数 ▽▽▽
    
    var player: AVPlayer!
    var playerLayer: AVPlayerLayer?
    var playerViewController: AVPlayerViewController!

    // ▽▽▽ [NEW FLOW] UI要素をステータス表示用に統一 ▽▽▽
    var statusImageView: UIImageView! // 以前の cartridgeLightImageView
    var currentQRCodeImageView: UIImageView! // おばけ(normal, rea, cannot)表示用
    //var cartridgeLightImageView: UIImageView! // カートリッジ状態ライト表示用
    
    // ▽▽▽ 新しいフラグとタイマー ▽▽▽
    var canStartSuction = false
    var suctionTimer: Timer?
    //var isGameStarted = false // タイマーが作動中か
    var isConnectionEstablished = false // PCとの接続が確立したか
    var isWaitingForFinish = false // Game_Clear/Over後、"Connection_Finished" を待機中
    var isBossScan = false // ボスQRスキャン中かどうか
    
    // ▽▽▽ [NEW FLOW] プリロード用画像 ▽▽▽
    var scanCHImage: UIImage?
    var scan10Image: UIImage?
    var scan25Image: UIImage?
    var scan77Image: UIImage?
    var scanNullImage: UIImage? // ▽▽▽ [FIX-1, 2] 追加 ▽▽▽
    var normalGhostImage: UIImage?
    var reaGhostImage: UIImage?
    var cannotGhostImage: UIImage?
    var bossGhostImage: UIImage?

    // ▽▽▽ [NEW FLOW] サウンドプレーヤー ▽▽▽
    var audioPlayer: AVAudioPlayer?
    
    var debugGhostCountLabel: UILabel?
    var debugRemainingTimeLabel: UILabel?
    
    var lastShakeTime: TimeInterval = 0
    let shakeThreshold: Double = 1.10 //加速度のしきい値
    let cooldownPeriod: TimeInterval = 0.75 //次の振動を感知するまでのクールダウン
    
    // gameScores: 各QRに対応するスコアを保持する配列 (長さ10)
    // 0 = 既に吸い取られた / 存在しない
    // 正の値 = 10 / 25 / 77
    var gameScores: [Int] = []

    // カートリッジ (大きさ4、nilは空)
    var cartridge: [Int?] = [nil, nil, nil, nil]
    var selectedCartridgeIndex: Int = 0
    
    let bossQRCodeString = "BOSS"
    
    // ▽▽▽ [FIX-3] ボス攻撃キュー ▽▽▽
    var bossAttackQueue: [(index: Int, score: Int)] = []

    // ▽▽▽ viewDidLoad (変更なし) ▽▽▽
    override func viewDidLoad() {
        super.viewDidLoad()
        initializeGameArray()
        setupCamera()
        setupImageViews() // 内部で preloadImages() を呼ぶ
        preloadAudio() // ▽ サウンドをロード
        view.backgroundColor = .black
        
        // ▽▽▽ [FIX-1] Scan_Null を初期表示 ▽▽▽
        updateCartridgeLightImage(selectedCartridgeIndex) // scanNullImage がセットされる
        statusImageView.isHidden = false // ▽ 表示する
        // △△△ [FIX-1] △△△
        
        // ▽ 動画のプリロード
        preloadVideo(named: "vacuum.mp4")
        preloadVideo(named: "vacuum_dummy.mp4")
        preloadVideo(named: "10.mp4")
        preloadVideo(named: "25.mp4")
        preloadVideo(named: "77.mp4")
        
        // ▽▽▽ [FIX-4] ボス攻撃動画をプリロード ▽▽▽
        preloadVideo(named: "Boss_10.mp4")
        preloadVideo(named: "Boss_25.mp4")
        preloadVideo(named: "Boss_77.mp4")
        
        if isDebugMode {
            setupDebugLabels() // デバッグモードの場合、ラベルを設定
        }
        // ▽▽▽ [FIX-2] ボスUIセットアップを削除 ▽▽▽
        // setupBossHPUI()
        // △△△ [FIX-2] △△△
        
        // ▽▽▽ [NEW FLOW] TCP接続状態の監視を開始 ▽▽▽
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTCPConnectionStatus(_:)),
            name: .tcpConnectionStatusChanged,
            object: nil
        )
        
        // ▽▽▽ [NEW FLOW] TCPコマンド受信の監視 ▽▽▽
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleTCPCommand(_:)),
            name: .tcpMessageReceived,
            object: nil
        )
        
        // ▽ TCPClient.shared.start() は AppDelegate で実行される想定
        // ▽ 接続が確立したら handleTCPConnectionStatus が呼ばれる
    }
    
    
    // 削除: var cartridgeLabels: [UILabel] = []
    
    // ▽▽▽ [NEW FLOW] ゲーム配列の初期化 (変更なし) ▽▽▽
    func initializeGameArray() {
        gameScores = [] // 配列を初期化

        // 0番目は -1 (インデックス調整用)
        gameScores.append(-1)
        gameScores.append(10) // 1番目は必ず10点

        // 2〜4番目 (10: 90%, 25: 19.5%, 77: 0.5%)
        for _ in 2...4 {
            let r = Double.random(in: 0..<1)
            if r < 0.90 {           // 90%
                gameScores.append(10)
            } else if r < 0.90 + 0.09 { // 19% (0.90 <= r < 0.99)
                gameScores.append(25)
            } else {                  // 1% (r >= 0.99)
                gameScores.append(77)
            }
        }

        for _ in 5...7 {
            let r = Double.random(in: 0..<1)
            if r < 0.70 {           // 80%
                gameScores.append(10)
            } else if r < 0.70 + 0.28 { // 18% (0.80 <= r < 0.99)
                gameScores.append(25)
            } else {                  // 2% (r >= 0.99)
                gameScores.append(77)
            }
        }
        
        
        // 8〜10番目 (25: 98%, 77: 2%)
        for _ in 8...9 {
            let r = Double.random(in: 0..<1)
            if r < 0.96 {           // 96%
                gameScores.append(25)
            } else {                  // 4% (r >= 0.96)
                gameScores.append(77)
            }
        }
        
        for _ in 10...10 {
            let r = Double.random(in: 0..<1)
            if r < 0.90 {           // 96%
                gameScores.append(25)
            } else {                  // 10% (r >= 0.96)
                gameScores.append(77)
            }
        }
        print("ゲーム配列が初期化されました: \(gameScores)")
    }
    
    // ▽▽▽ [NEW FLOW] ゲームリセット処理 (タイマー停止などを追加) ▽▽▽
    public func resetGame() {
        print("--- ▽▽▽ ゲーム状態をリセット ▽▽▽ ---")
        exterminatedCount = 0
        //remainingTime = 270 // 4分30秒
        initializeGameArray()
        cartridge = [nil, nil, nil, nil]
        // bossHP = 100 // 削除
        selectedCartridgeIndex = 0
        
        //isGameStarted = false
        isWaitingForFinish = false
        canStartSuction = false
        isBossScan = false // ▽ ボススキャンフラグをリセット
        
        //gameTimer?.invalidate()
        //gameTimer = nil
        suctionTimer?.invalidate()
        suctionTimer = nil
        qrCodeLostTimer?.invalidate()
        qrCodeLostTimer = nil
        
        DispatchQueue.main.async {
            self.updateDebugLabels()
            // ▽ ボスUIリセットを削除
            // self.updateBossHPUI(animate: false)
            // self.bossHPLabel.isHidden = true
            self.hideQRCodeImage()
            
            // ▽▽▽ [NEW FLOW] ライトをリセット ▽▽▽
            self.updateCartridgeLightImage(self.selectedCartridgeIndex)
            self.statusImageView.isHidden = false
        }
    }
    
    
    
    // ▽▽▽ [NEW FLOW] 画面が表示されたら接続確認 (フォールバック) ▽▽▽
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // もし既に接続済みで、まだ接続確立処理が動いていなかった場合
        if TCPClient.shared.currentState == .ready && !isConnectionEstablished {
             handleConnectionEstablished()
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        suctionTimer?.invalidate()
        qrCodeLostTimer?.invalidate()
        //gameTimer?.invalidate()
    }
    
    // ▽▽▽ [NEW FLOW] 接続状態ハンドラ ▽▽▽
    @objc func handleTCPConnectionStatus(_ notification: Notification) {
        guard let status = notification.object as? TCPConnectionStatus else { return }
        
        switch status {
        case .connected:
            if !isConnectionEstablished {
                 handleConnectionEstablished()
            }
        case .disconnected, .connecting:
            // 接続が切れたらスキャンを停止し、待機状態に戻る
            isConnectionEstablished = false
            DispatchQueue.main.async {
                self.captureSession.stopRunning()
                self.statusImageView.image = nil // 何も表示しないなど
                self.statusImageView.isHidden = true
            }
        }
    }
    
    // ▽▽▽ [NEW FLOW] 接続確立時の処理 ▽▽▽
    func handleConnectionEstablished() {
        print("--- ▽▽▽ 接続確立！ゲーム準備完了 ▽▽▽ ---")
        isConnectionEstablished = true
        TCPClient.shared.send(message: "Connection_Beginning") //
        
        DispatchQueue.main.async {
            // ▽▽▽ [FIX-1] Scan_Null を表示 ▽▽▽
            self.statusImageView.image = self.scanNullImage
            self.statusImageView.isHidden = false
            // △△△ [FIX-1] △△△
            
            // ▽ 接続が確立して初めてQRスキャンを開始
            if !self.captureSession.isRunning {
                DispatchQueue.global(qos: .userInitiated).async {
                    self.captureSession.startRunning()
                }
            }
        }
    }
    
    // ▽▽▽ [NEW FLOW] カートリッジライト表示更新 (Scan_...png を使用) ▽▽▽
    func updateCartridgeLightImage(_ index: Int) {
        let score = cartridge[index]
        switch score {
        case 10:
            statusImageView.image = scan10Image
        case 25:
            statusImageView.image = scan25Image
        case 77:
            statusImageView.image = scan77Image
        default: // nil
            // ▽▽▽ [FIX-2] scanCHImage ではなく scanNullImage を使用 ▽▽▽
            statusImageView.image = scanNullImage
            // △△△ [FIX-2] △△△
        }
    }
    /*
    func setupBossHPUI() {
        // ボスHPラベル (カウンター)
        bossHPLabel = UILabel() // ▽ Frame set with constraints
        bossHPLabel.textColor = .red
        bossHPLabel.font = .systemFont(ofSize: 120, weight: .bold) // ▽ Big font
        bossHPLabel.text = "HP 100"
        bossHPLabel.textAlignment = .center
        bossHPLabel.isHidden = true
        bossHPLabel.translatesAutoresizingMaskIntoConstraints = false // ▽ Use constraints
        view.addSubview(bossHPLabel)
                
        // ▽ Center it
        NSLayoutConstraint.activate([
            bossHPLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            bossHPLabel.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            bossHPLabel.widthAnchor.constraint(equalTo: view.widthAnchor)
        ])
                
        // ▽▽▽ [FIX-5] メーターの初期化を削除 ▽▽▽
        // bossHPBackgroundView = ...
        // bossHPBarView = ...
        // △△△ [FIX-5] △△△
    }
    */
    // MARK: - UI更新
    /*
        func updateBossHPUI(animate: Bool) {
        // ▽▽▽ [FIX-5] メーター関連のロジックをすべて削除 ▽▽▽
        // let hpRatio = ...
        // let barWidth = ...
        // if hpRatio < 0.3 ...
        // let updateBlock = ...
        // △△△ [FIX-5] △△△
        
        bossHPLabel.text = "HP \(bossHP)" // ▽ カウンターのテキストのみ更新
          /*  
        // HPが0以下ならゲームクリア
        if bossHP <= 0 && !isSuctionMode { // 吸い込み中などでないことを確認
            // 少し遅延させて「倒した！」感を出してから画面遷移
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if self.presentedViewController == nil {
                    self.endGame(isGameClear: true) // ▽ ゲームクリア
                }
            }
        }
        */
    }
    */
    // ▽▽▽ [NEW FLOW] サウンド読み込み ▽▽▽
    func preloadAudio() {
        guard let url = Bundle.main.url(forResource: "cartridge_change", withExtension: "mp3") else {
            print("Audio file 'cartridge_change.wav' not found.")
            return
        }
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
        } catch {
            print("Error loading audio file: \(error.localizedDescription)")
        }
    }
    
    // MARK: - TCPコマンド処理
        
    @objc func handleTCPCommand(_ notification: Notification) {
        guard let command = notification.userInfo?["command"] as? String else { return }
        
        print("GameVC received command: \(command)")
        
        // ▽▽▽ [NEW FLOW] ゲーム終了待機中は "Connection_Finished" のみ受け付ける ▽▽▽
        if isWaitingForFinish {
            if command == "Connection_Finished" {
                print("--- ▽▽▽ Connection_Finished 受信。ゲームをリセットします ▽▽▽ ---")
                isWaitingForFinish = false

                //resetGame()
                //handleConnectionEstablished() // ▽ 再接続処理を実行
                
                
                // 1. 
                resetGame()
                
                // 2. 
                //    
                // 
                DispatchQueue.main.async {
                    // 
                    // 
                    self.statusImageView.image = self.scanNullImage
                    self.statusImageView.isHidden = false
                    
                    // 3. 
                    if !self.captureSession.isRunning {
                        DispatchQueue.global(qos: .userInitiated).async {
                            self.captureSession.startRunning()
                        }
                    }
                }
                // 
                // 
            }
            return
        }

        // ▽▽▽ [NEW FLOW] 吸い取りモード中はコマンドを無視 ▽▽▽
        if isSuctionMode { return }

        // ▽▽▽ [Unity Logic] カートリッジ変更 (A, B, X, Y) ▽▽▽
        var newIndex: Int? = nil
        
        switch command {
        case "Selected_A": newIndex = 0
        case "Selected_B": newIndex = 1
        case "Selected_Y": newIndex = 2
        case "Selected_X": newIndex = 3
        default: break
        }
        
        if let newIndex = newIndex {
            print("カートリッジを \(newIndex) に変更します")
                
            // ▽▽▽ [NEW FLOW] 割り込み処理 ▽▽▽
            // 3秒受付時間中だったら、受付をキャンセルする
            if canStartSuction {
                suctionTimer?.invalidate()
                suctionTimer = nil
                canStartSuction = false
                hideQRCodeImage()
                isBossScan = false
                stopShakeDetection() // ▽ 揺れ検知も停止
            }
            
            selectedCartridgeIndex = newIndex
            
            // 1. サウンド再生
            audioPlayer?.play()
            
            // 2. Scan_CH を 0.2秒表示
            statusImageView.image = scanCHImage
            statusImageView.isHidden = false
            
            // 3. 0.2秒後に、選択中のカートリッジのライトに変更
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.updateCartridgeLightImage(newIndex)
                self.statusImageView.isHidden = false
            }
            
        } 
        // ▽▽▽ [NEW FLOW] シャッター（吸い取り/攻撃） ▽▽▽
        else if command == "Release_Shutter" {
            
            // ▽ 3秒受付時間外なら無視
            guard canStartSuction else {
                print("TCP: 'Release_Shutter' received, but not in 3-sec window. Ignoring.")
                return
            }
            
            // ▽ 受付時間を即時終了
            canStartSuction = false
            suctionTimer?.invalidate()
            suctionTimer = nil
            
            // ▽▽▽ [FIX-2] ボスフラグで判定 ▽▽▽
            if isBossScan {
                handleBossAttack() // ▽ ボス攻撃
            } else if qrCodeNumber != nil {
                handleGhostSuction() // ▽ おばけ吸い取り
                    }
            // △△△ [FIX-2] △△△
            
                }
        // ▽ ゲーム判定
        else if command == "Game_Clear" || command == "Game_Over" {
            print("--- ▽▽▽ \(command) 受信。待機状態に移行 ▽▽▽ ---")
            
            // 全てのタイマーを止める
            suctionTimer?.invalidate()
            suctionTimer = nil
            qrCodeLostTimer?.invalidate()
            qrCodeLostTimer = nil
            stopShakeDetection() // ▽ 揺れ検知も停止

            // QRスキャンを停止
            if captureSession.isRunning {
                 captureSession.stopRunning()
            }
            
            isWaitingForFinish = true
            
            // 画面をリセット
            hideQRCodeImage()
            isBossScan = false
            statusImageView.isHidden = true
            }
        }
    
    // ▽ おばけ吸い取り実行
    func handleGhostSuction() {
        if let qrNum = self.qrCodeNumber, qrNum >= 1 && qrNum < gameScores.count {
            let score = gameScores[qrNum]
                
                if score > 0 {
                print("TCP: おばけ吸い込みモードに移行します (score: \(score))")
                startSuctionMode(score: score) // ▽ 揺れ倍速あり
                gameScores[qrNum] = 0
                } else {
                    print("TCP: 既に吸い取られたQRです。")
                // ライトを戻す
                updateCartridgeLightImage(selectedCartridgeIndex)
                statusImageView.isHidden = false
                }
            }
        }
    
    // ▽▽▽ [NEW FLOW] ボス攻撃実行 ▽▽▽
    func handleBossAttack() {
        // 1. カートリッジから攻撃キューを作成 (インデックスとスコア)
        //    (例: [(1, 10), (3, 77)])
        let attackQueue = cartridge.enumerated().compactMap { (index, score) -> (index: Int, score: Int)? in
            guard let score = score else { return nil }
            return (index: index, score: score)
        }.reversed() // 配列の若番（Y, X）から処理
        
        self.bossAttackQueue = Array(attackQueue)
        
        if self.bossAttackQueue.isEmpty {
            print("TCP: カートリッジが空です。攻撃できません。")
        hideQRCodeImage()
        updateCartridgeLightImage(selectedCartridgeIndex)
        statusImageView.isHidden = false
        return
        }

        print("--- ▽▽▽ ボス連続攻撃開始 ▽▽▽ ---")
        isSuctionMode = true // 連続攻撃が完了するまで他の操作をブロック
    hideQRCodeImage()
    statusImageView.isHidden = true

    processNextBossAttack()
    }
    
    //新規追加[3]
    func processNextBossAttack() {
        // 1. キューが空なら、攻撃シーケンスを終了
        guard !bossAttackQueue.isEmpty else {
            endBossAttackSequence()
            return
        }
        
        // 2. キューから次の攻撃を取り出す (例: (index: 3, score: 77))
        let attack = bossAttackQueue.removeFirst()
        
        print("ボス攻撃: \(attack.index) の \(attack.score) で攻撃")
        
        // 3. 
        currentSuctionScore = attack.score
        currentCartridgeIndexBeingUsed = attack.index
        // △△△ [FIX] △△△
        
        // 4. 
        startBossAttackVideo(score: attack.score)
    }

    //新規追加[3]
    func endBossAttackSequence() {
        print("--- △△△ ボス連続攻撃 終了 △△△ ---")
        isSuctionMode = false
        isBossScan = false
        
        // 
        selectedCartridgeIndex = 0
        updateCartridgeLightImage(selectedCartridgeIndex)
        statusImageView.isHidden = false
    }

    
    // MARK: - シェイク検知

    // ▽▽▽ [FIX-2] シェイク検知開始 (新規) ▽▽▽
    func startShakeDetection() {
        guard motionManager.isAccelerometerAvailable else {
            print("加速度センサーが利用できません。")
            return
        }

        print("--- ▽ 揺れ検知を開始 (3秒間) ▽ ---")

        motionManager.accelerometerUpdateInterval = 0.1
        motionManager.startAccelerometerUpdates(to: OperationQueue.current!) { [weak self] (data, error) in
            guard let self = self, let data = data, error == nil else { return }

            let acceleration = sqrt(pow(data.acceleration.x, 2) + pow(data.acceleration.y, 2) + pow(data.acceleration.z, 2))

            let currentTime = Date().timeIntervalSince1970

            //
            if acceleration > self.shakeThreshold && (currentTime - self.lastShakeTime) > self.cooldownPeriod {

                //
                guard self.canStartSuction else { return }

                print("--- シェイク検知！シャッター作動 ---")

                //
                self.canStartSuction = false
                self.stopShakeDetection()
                self.suctionTimer?.invalidate()
                self.lastShakeTime = currentTime

                //
                if self.isBossScan {
                    self.handleBossAttack()
                } else if self.qrCodeNumber != nil {
                    self.handleGhostSuction()
                }
            }
        }
    }

    // ▽▽▽ [FIX-2] シェイク検知停止 (新規) ▽▽▽
    func stopShakeDetection() {
        print("--- △ 揺れ検知を停止 △ ---")
        motionManager.stopAccelerometerUpdates()
    }

    
    
    func setupDebugLabels() {
        debugGhostCountLabel = UILabel(frame: CGRect(x: view.bounds.width - 120, y: 50, width: 100, height: 30))
        debugGhostCountLabel?.textColor = .red
        debugGhostCountLabel?.text = "退治数: \(exterminatedCount)"
        view.addSubview(debugGhostCountLabel!)

        debugRemainingTimeLabel = UILabel(frame: CGRect(x: view.bounds.width - 120, y: 90, width: 100, height: 30))
        debugRemainingTimeLabel?.textColor = .red
        debugRemainingTimeLabel?.text = "時間: (Unity)" // ▽ Unity側で管理
        view.addSubview(debugRemainingTimeLabel!)
    }

    
    // ▽▽▽ [NEW FLOW] 修正: preloadVideo (ファイル名の分割処理) ▽▽▽
    func preloadVideo(named videoNameWithExtension: String) {
        let components = videoNameWithExtension.split(separator: ".")
        guard components.count == 2 else {
            print("preloadVideo Error: Invalid filename format \(videoNameWithExtension)")
            return
        }
        let resourceName = String(components[0])
        let resourceType = String(components[1])
        
        if let videoPath = Bundle.main.path(forResource: resourceName, ofType: resourceType) {
            let videoURL = URL(fileURLWithPath: videoPath)
            let asset = AVAsset(url: videoURL)
            let playerItem = AVPlayerItem(asset: asset)
            player = AVPlayer(playerItem: playerItem)
            
            // ▽ 画面には追加しない。再生準備だけ行う
            if let validPlayer = player {
                playerLayer = AVPlayerLayer(player: validPlayer)
                playerLayer?.frame = self.view.bounds
                validPlayer.pause()
            }
        } else {
             print("preloadVideo Error: Video file not found: \(videoNameWithExtension)")
        }
    }
        
    
    func setupCamera() {
        // (変更なし、以前の .qr ガード節を含む)
        captureSession = AVCaptureSession()
        guard let videoCaptureDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else { return }
        let videoInput: AVCaptureDeviceInput
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            print("Error setting up video input: \(error)")
            return
        }
        
        if captureSession.canAddInput(videoInput) {
            captureSession.addInput(videoInput)
        } else {
            print("Could not add video input to capture session")
            return
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        if captureSession.canAddOutput(metadataOutput) {
            captureSession.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            
            guard metadataOutput.availableMetadataObjectTypes.contains(.qr) else {
                print("QR code metadata is not supported on this device.")
                return
            }
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            print("Could not add metadata output to capture session")
            return
        }

        // ▽ 起動は handleConnectionEstablished() で行う
        // DispatchQueue.global(qos: .userInitiated).async {
        //  self.captureSession.startRunning()
        // }
    }
    
    // ▽▽▽ [NEW FLOW] ImageViewセットアップ (Scan_...png をプリロード) ▽▽▽
    func setupImageViews() {
        
        // カートリッジ状態ライト表示用 (Scan_CH, Scan_10 など)
        statusImageView = UIImageView()
        statusImageView.contentMode = .scaleAspectFill
        statusImageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusImageView)
        
        // おばけ(normal, rea, cannot)表示用
        currentQRCodeImageView = UIImageView()
        currentQRCodeImageView.contentMode = .scaleAspectFill
        currentQRCodeImageView.frame = view.bounds
        currentQRCodeImageView.isHidden = true
        view.addSubview(currentQRCodeImageView)
        
        NSLayoutConstraint.activate([
            statusImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            statusImageView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            statusImageView.widthAnchor.constraint(equalTo: view.widthAnchor),
            statusImageView.heightAnchor.constraint(equalTo: view.heightAnchor),
        ])
        
        // ▽ 画像をプリロード
        scanCHImage = UIImage(named: "Scan_CH")
        scan10Image = UIImage(named: "Scan_10")
        scan25Image = UIImage(named: "Scan_25")
        scan77Image = UIImage(named: "Scan_77")
        scanNullImage = UIImage(named: "Scan_Null") // ▽▽▽ [FIX-1, 2] 追加 ▽▽▽

        normalGhostImage = UIImage(named: "Normal")
        reaGhostImage = UIImage(named: "Rea")
        cannotGhostImage = UIImage(named: "Scan_Unreadable")
        bossGhostImage = UIImage(named: "Boss")
    }

    
    // MARK: - タイマーとQR処理
    /*
    func startGameTimer() {
        guard gameTimer == nil else { return }
        
        print("--- ▽▽▽ ゲームタイマー開始 ▽▽▽ ---")
        isGameStarted = true
        
        gameTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            self.remainingTime -= 1
            self.updateDebugLabels()

            if self.remainingTime <= 0 {
                timer.invalidate()
                self.endGame(isGameClear: false) // ▽ ゲームオーバー
            }
        }
    }
    */
    
    func updateDebugLabels() {
        debugGhostCountLabel?.text = "退治数: \(exterminatedCount)"
        /*
        if isGameStarted {
        debugRemainingTimeLabel?.text = "残り時間: \(remainingTime)"
        } else {
            debugRemainingTimeLabel?.text = "残り時間: --"
        }
        */
    }
    
    
    // ▽▽▽ [NEW FLOW] QRスキャン処理 (待機フラグをチェック) ▽▽▽
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        
        // ▽ 接続中/吸い取り中/終了待機中 はスキャンしない
        if isSuctionMode || isDummyMode || !isConnectionEstablished || isWaitingForFinish { return }
        
        // ▽▽▽ [FIX-4] 'if canStartSuction { return }' を削除 ▽▽▽
        // 連続スキャンを許可し、タイマーリセットは各ハンドラで行う
        
        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
                  let stringValue = readableObject.stringValue else {
                handleQRCodeLost()
                return
            }
            
            isQRCodeVisible = true
            
            // ▽▽▽ ボスQR処理を追加 ▽▽▽
            if stringValue == bossQRCodeString {
                // ▽▽▽ [FIX-2] ボスQR処理 ▽▽▽
                handleBossQRCodeDetected()
            }
            // ▽▽▽ おばけQR処理 (Intに変換) ▽▽▽
            else if let qrCodeNumber = Int(stringValue) {
                handleQRCodeDetected(qrCodeNumber: qrCodeNumber)
            }
            // ▽▽▽ それ以外 ▽▽▽
            else {
                // "marker_tutorial" など、他の文字列QRの可能性
                handleQRCodeLost()
            }
                        
        } else {
            handleQRCodeLost()
        }
    }

    // ▽▽▽ おばけQR検出 ▽▽▽
    func handleQRCodeDetected(qrCodeNumber: Int) {
        
        // ▽ 連続スキャン時のタイマーリセット
        if canStartSuction {
            // ▽ ただし、前回がボススキャンだったら、リセットして通常処理
            if isBossScan {
                suctionTimer?.invalidate()
                stopShakeDetection() // 
            } else {
                // ▽ 前回もおばけスキャンならタイマーリセットのみ
                suctionTimer?.invalidate()
            suctionTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
                print("3-second suction window closed (from reset).")
                self?.canStartSuction = false
                self?.suctionTimer = nil
                self?.hideQRCodeImage()
                self?.stopShakeDetection() // 
                self?.updateCartridgeLightImage(self?.selectedCartridgeIndex ?? 0)
                self?.statusImageView.isHidden = false
            }
            return // 画像を再表示せずにタイマーだけリセット
        }
        }

        // ▽ 以下は初回スキャン時のみ実行される
        suctionTimer?.invalidate()
        canStartSuction = false
        isBossScan = false // ▽ おばけフラグ
        statusImageView.isHidden = true
        
        self.qrCodeNumber = qrCodeNumber

        // QRコードに対応する処理（score が 0 か正の値かで判定）
        guard qrCodeNumber >= 1 && qrCodeNumber < gameScores.count else {
            handleQRCodeLost()
            return
        }
        
        let score = gameScores[qrCodeNumber]

            if score > 0 {
            // --- まだ吸い取られていない ---
                let selectedCartridgeContent = cartridge[selectedCartridgeIndex]
                    
                if selectedCartridgeContent == nil {
                // --- 吸い取り可能 ---
                print("QR \(qrCodeNumber) 検出。吸い取り準備 (3秒)")
                    
                    var imageToShow: UIImage?
                if (1...7).contains(qrCodeNumber) { imageToShow = normalGhostImage }
                else if (8...10).contains(qrCodeNumber) { imageToShow = reaGhostImage }
                    
                if let image = imageToShow { showQRCodeImage(image: image) }
                else { print("Error: normal.png または rea.png が見つかりません。") }
                    
                // 3秒間の "Release_Shutter" 受付開始
                canStartSuction = true
                startShakeDetection()
                // △△△ [FIX-2] △△△
                
                    suctionTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
                        print("3-second suction window closed.")
                        self?.canStartSuction = false
                        self?.suctionTimer = nil
                    self?.hideQRCodeImage()
                    self?.stopShakeDetection() // 
                    self?.updateCartridgeLightImage(self?.selectedCartridgeIndex ?? 0)
                    self?.statusImageView.isHidden = false
                    }
            
            } else {
                // --- カートリッジ満タン ---
                print("QR \(qrCodeNumber) 検出。カートリッジ満タン。")
                if let image = cannotGhostImage { showQRCodeImage(image: image)
                } else {
                    print("Error: cannot.png が見つかりません。")
                }
            }
                
            } else {
            // --- 既に吸い取られている ---
                hideQRCodeImage()
            updateCartridgeLightImage(selectedCartridgeIndex)
            statusImageView.isHidden = false
        }
        
        // QRコードを見失った際のタイマーを無効化（見えている間はリセット）
        qrCodeLostTimer?.invalidate()
        qrCodeLostTimer = nil
    }
    
    // ▽▽▽ [NEW FLOW] ボスQR検出 (3秒タイマー開始) ▽▽▽
    func handleBossQRCodeDetected() {
        
        // ▽▽▽ [FIX-4] 連続スキャン時のタイマーリセット処理 ▽▽▽
        if canStartSuction {
            // ▽ 前回がおばけスキャンだったら、リセットして通常処理
            if !isBossScan {
                suctionTimer?.invalidate()
                stopShakeDetection() // 
            } else {
                // ▽ 前回もボススキャンならタイマーリセットのみ
                suctionTimer?.invalidate()
            suctionTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
                guard let self = self else { return }
                print("3-second suction window closed (from reset).")
                self.canStartSuction = false
                self.suctionTimer = nil
                self.hideQRCodeImage()
                    self.isBossScan = false
                    self.stopShakeDetection() // 
                self.updateCartridgeLightImage(self.selectedCartridgeIndex)
                self.statusImageView.isHidden = false
            }
            return // 画像を再表示せずにタイマーだけリセット
        }
        }
        
        print("ボスQRコードを検出しました")
        self.qrCodeNumber = nil
        self.isBossScan = true // ▽ ボススキャンフラグ
            
        // おばけUIとカートリッジライトを隠す
        hideQRCodeImage()
        statusImageView.isHidden = true
            
        // 吸い取り許可タイマーを停止
        suctionTimer?.invalidate()
        suctionTimer = nil
            
        qrCodeLostTimer?.invalidate()
        qrCodeLostTimer = nil
            
        if cartridge.contains(where: { $0 != nil }) { // 
            // --- [FIX-3] カートリッジに中身あり (Boss.png 表示) ---
            print("ボスQR検出。攻撃準備 (3秒)")
                
            if let image = bossGhostImage {
                showQRCodeImage(image: image)
            } else {
                print("Error: Boss.png が見つかりません。")
            }
                
            canStartSuction = true
            startShakeDetection()
            // △△△ [FIX-2] △△△
            
            suctionTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
                guard let self = self else { return }
                print("3-second suction window closed.")
                self.canStartSuction = false
                self.suctionTimer = nil
                self.hideQRCodeImage()
                self.isBossScan = false
                self.stopShakeDetection() // 
                self.updateCartridgeLightImage(self.selectedCartridgeIndex)
                self.statusImageView.isHidden = false
            }
                
        } else {
            // --- カートリッジが空 (攻撃不可) ---
            print("ボスQR検出。カートリッジが空。")
            if let image = cannotGhostImage {
                showQRCodeImage(image: image)
            } else {
                print("Error: cannot.png が見つかりません。")
            }
            canStartSuction = false
        }
    }
    
    // ▽▽▽ 修正: QRを見失った時の処理 ▽▽▽
    func handleQRCodeLost() {
        // ▽ 3秒受付時間中なら、見失ってもタイマーは続行
        if canStartSuction { return } 
        
        if isQRCodeVisible {
            if qrCodeLostTimer == nil {
                qrCodeLostTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
                    guard let self = self else { return }
                    
                    self.isQRCodeVisible = false
                    print("QRコードが消えました")
                    self.hideQRCodeImage()
                    self.isBossScan = false // ▽
                    self.updateCartridgeLightImage(self.selectedCartridgeIndex)
                    self.statusImageView.isHidden = false
                }
            }
        }
    }
    
    // ▽▽▽ 修正: QR画像表示 ▽▽▽
    func showQRCodeImage(image: UIImage) {
        currentQRCodeImageView.image = image
        currentQRCodeImageView.isHidden = false
        view.bringSubviewToFront(currentQRCodeImageView)
        statusImageView.isHidden = true // ライトを隠す
    }
    
    // ▽▽▽ 修正: QR画像非表示 ▽▽▽
    func hideQRCodeImage(){
        currentQRCodeImageView.isHidden = true
        currentQRCodeImageView.image = nil
    }
    
    // ▽▽▽ 修正: 吸い取り開始 ▽▽▽
    func startSuctionMode(score: Int) {
        
        isSuctionMode = true
        currentSuctionScore = score
        hideQRCodeImage()
        statusImageView.isHidden = true
        
        // プレースホルダー画像を表示
        let placeholderImageView = UIImageView(image: UIImage(named: "placeholder"))
        placeholderImageView.frame = self.view.bounds
        placeholderImageView.contentMode = .scaleAspectFill
        self.view.addSubview(placeholderImageView)
        
        // ▽▽▽ 動画ファイル名をスコアから決定 ▽▽▽
        let videoName: String
        switch score {
        case 10: videoName = "10"
        case 25: videoName = "25"
        case 77: videoName = "77"
        default: videoName = "vacuum"
        }
        
        var videoURL = Bundle.main.url(forResource: videoName, withExtension: "mp4")
        if videoURL == nil {
            videoURL = Bundle.main.url(forResource: "vacuum", withExtension: "mp4")
        }

        guard let finalURL = videoURL else {
            print("vacuum.mp4 も見つかりません。吸い込みをキャンセルします。")
            isSuctionMode = false
            currentSuctionScore = 0
            // 既に 0 にした gameScores を元に戻す (もし qrCodeNumber があれば)
            if let qrNum = self.qrCodeNumber { gameScores[qrNum] = score }
            placeholderImageView.removeFromSuperview()
            updateCartridgeLightImage(selectedCartridgeIndex)
            statusImageView.isHidden = false
            return
        }
            
        // 4. URLが見つかった場合 (finalURL) のみ、プレイヤーを初期化
        player = AVPlayer(url: finalURL)
        playerViewController = AVPlayerViewController()
        playerViewController.player = player
        playerViewController.videoGravity = .resizeAspectFill
        playerViewController.view.frame = self.view.bounds
        self.view.addSubview(playerViewController.view)
                
        // タッチをブロックする透明なビューを追加
        let touchBlockerView = UIView(frame: self.view.bounds)
        touchBlockerView.backgroundColor = UIColor.clear
        self.view.addSubview(touchBlockerView)
                
        // 動画の準備が完了しているか確認
        player?.currentItem?.addObserver(self, forKeyPath: "status", options: [.initial, .new], context: nil)
                
        // 動画再生終了時に吸い込みモードを終了
        NotificationCenter.default.addObserver(self, selector: #selector(endSuctionMode), name: .AVPlayerItemDidPlayToEndTime, object: player.currentItem)
                
        // プレースホルダーの削除
        DispatchQueue.main.async {
            placeholderImageView.removeFromSuperview()
        }
        
        // 加速度センサーを使ってデバイスの揺れを検知
        motionManager.startAccelerometerUpdates(to: OperationQueue.current!) { [weak self] (data, error) in
            guard let self = self, let data = data, error == nil else { return }
            let acceleration = sqrt(pow(data.acceleration.x, 2) + pow(data.acceleration.y, 2) + pow(data.acceleration.z, 2))
            
            let currentTime = Date().timeIntervalSince1970
            if acceleration > self.shakeThreshold && (currentTime - self.lastShakeTime) > self.cooldownPeriod {
                print("デバイスが揺れました！動画の再生速度を倍速します。")
                self.increasePlaybackSpeed()
                self.lastShakeTime = currentTime
            }
        }
    }
    
    // ▽▽▽ [FIX-4] ボス攻撃動画再生 (揺れ倍速なし) ▽▽▽
    func startBossAttackVideo(score: Int) {
        
        // isSuctionMode = true // 
        
        hideQRCodeImage()
        statusImageView.isHidden = true
        
        let placeholderImageView = UIImageView(image: UIImage(named: "placeholder"))
        placeholderImageView.frame = self.view.bounds
        placeholderImageView.contentMode = .scaleAspectFill
        self.view.addSubview(placeholderImageView)
        
        // ▽ ボス動画のファイル名を決定
        let videoName = "Boss_\(score)"
        
        var videoURL = Bundle.main.url(forResource: videoName, withExtension: "mp4")
        if videoURL == nil {
            print("\(videoName).mp4 が見つかりません。フォールバック (vacuum.mp4) を試します。")
            videoURL = Bundle.main.url(forResource: "vacuum", withExtension: "mp4")
        }

        guard let finalURL = videoURL else {
            print("vacuum.mp4 も見つかりません。キャンセルします。")
            // isSuctionMode = false // 
            placeholderImageView.removeFromSuperview()
            // 
            processNextBossAttack()
            return
        }
            
        player = AVPlayer(url: finalURL)
        playerViewController = AVPlayerViewController()
        playerViewController.player = player
        playerViewController.videoGravity = .resizeAspectFill
        playerViewController.view.frame = self.view.bounds
        self.view.addSubview(playerViewController.view)
                
        let touchBlockerView = UIView(frame: self.view.bounds)
        touchBlockerView.backgroundColor = UIColor.clear
        self.view.addSubview(touchBlockerView)
                
        player?.currentItem?.addObserver(self, forKeyPath: "status", options: [.initial, .new], context: nil)
        
        // ▽▽▽ [FIX-3] 終了ハンドラを 'handleBossVideoSegmentFinished' に変更 ▽▽▽
        NotificationCenter.default.addObserver(self, selector: #selector(handleBossVideoSegmentFinished), name: .AVPlayerItemDidPlayToEndTime, object: player.currentItem)
                
        DispatchQueue.main.async {
            placeholderImageView.removeFromSuperview()
        }
        
        // ▽▽▽ [FIX-4] motionManager を起動しない ▽▽▽
        // motionManager.startAccelerometerUpdates(...)
        // △△△ [FIX-4] △△△
    }

    // MARK: - KVO (音量部分を削除)
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        if keyPath == "status" {
        if let player = player, player.status == .readyToPlay {
                player.play()
            } else if let player = player, player.status == .failed {
                print("動画の準備に失敗しました: \(player.error?.localizedDescription ?? "不明なエラー")")
            }
        }
    }
    
    // 動画の再生速度を変更する
    func increasePlaybackSpeed() {
        guard let player = player else { return }
        
        // 現在の速度から1.5倍にゆっくり変更
        let currentRate = player.rate
        if currentRate < 5.0{
            player.rate = min(currentRate + 0.5, 5.0)
        }
    }
    
    
    // ▽▽▽ [NEW FLOW] 吸い取り終了 (TCP送信形式の変更) ▽▽▽
    @objc func endSuctionMode() {
        // 同じ通知が複数回呼ばれるのを防ぐ
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: player.currentItem)
        // KVOも解除
        player?.currentItem?.removeObserver(self, forKeyPath: "status")

        isSuctionMode = false

        print("吸い込みモードが終了しました (スコア: \(currentSuctionScore))")
                
        // ▽▽▽ カートリッジにスコアを追加 ▽▽▽
        if currentSuctionScore > 0 {
            // ▽▽▽ 使用したのは「選択中」のカートリッジ ▽▽▽
            if cartridge[selectedCartridgeIndex] == nil {
                
                // 1. カートリッジに記録
                cartridge[selectedCartridgeIndex] = currentSuctionScore
                // ▽ ライトはまだ更新しない (advanceToNextEmptyCartridge で行う)

                // 2. ▽▽▽ [Unity Logic] PCに吸い取り完了を通知 (Scan_Finished) ▽▽▽
                TCPClient.shared.send(message: "Scan_Finished")
                TCPClient.shared.send(message: "Score:\(currentSuctionScore)")
                // △△△ [Unity Logic] △△△
                
                // ▽▽▽ [FIX-1] 次の空カートリッジに移動 ▽▽▽
                advanceToNextEmptyCartridge()
                // △△△ [FIX-1] △△△
                
            } else {
                // (これは handleQRCodeDetected で防止されているはず)
                print("カートリッジが満タンです！ 吸い取れませんでした。")
                if let qrCodeNumber = self.qrCodeNumber {
                    gameScores[qrCodeNumber] = currentSuctionScore
                    print("QRコード \(qrCodeNumber) のスコアを \(currentSuctionScore) に戻しました。")
                }
                // ▽▽▽ [Unity Logic] 失敗コマンドは不要になったため削除 ▽▽▽
                // TCPClient.shared.send(message: "CARTRIDGE_FULL")
                // △△△ [Unity Logic] △△△
            }
        } else {
            print("スコアが0のため、カートリッジには追加しませんでした。")
        }

        // ▽ ライトを (更新された) selectedCartridgeIndex で表示
        updateCartridgeLightImage(selectedCartridgeIndex)
        statusImageView.isHidden = false
        
        exterminatedCount += 1
        updateDebugLabels()
                
        player?.pause()
        playerViewController?.view.removeFromSuperview()
        playerViewController = nil
                
        motionManager.stopAccelerometerUpdates()
                
        self.qrCodeNumber = nil
        self.currentSuctionScore = 0
    }

    
    // ▽▽▽ endGame を変更 (TCP送信, タイマー停止) ▽▽▽
    /*
    func endGame(isGameClear: Bool) {
        // ゲームが終了したらタイマーを止める
        gameTimer?.invalidate()
        gameTimer = nil
                
        // 他のタイマーも停止
        suctionTimer?.invalidate()
        suctionTimer = nil
        qrCodeLostTimer?.invalidate()
        qrCodeLostTimer = nil

        // QRスキャンを停止
        if captureSession.isRunning {
             captureSession.stopRunning()
        }
        
        // ▽ 既に終了処理が走っていたら何もしない
        if isWaitingForFinish { return }
                
        isWaitingForFinish = true // ▽ "Connection_Finished" 待機状態に移行
                
        // TCPでゲーム終了を通知
        let message = isGameClear ? "Game_Clear" : "Game_Over"
        print("--- ▽▽▽ ゲーム終了: \(message) ▽▽▽ ---")
        TCPClient.shared.send(message: message)
        /*        
        // リザルト画面へ
        let resultVC = ResultViewController()
        resultVC.modalPresentationStyle = .fullScreen
        resultVC.exterminatedCount = exterminatedCount
        resultVC.remainingTime = remainingTime
        resultVC.isGameClear = isGameClear
        present(resultVC, animated: true, completion: nil)
        */
    }
    */
    // ▽▽▽ 修正: startDummyMode ▽▽▽
    func startDummyMode() {
        isDummyMode = true
        // dummyImageView.isHidden = true // 削除
        currentQRCodeImageView.isHidden = true
        hideQRCodeImage()
        
        // ▽▽▽ カートリッジライトを表示 ▽▽▽
        updateCartridgeLightImage(selectedCartridgeIndex)
        statusImageView.isHidden = false

        // vacuum_dummyの動画を準備
        if let videoURL = Bundle.main.url(forResource: "vacuum_dummy", withExtension: "mp4") {
            player = AVPlayer(url: videoURL)
            
            // ▽▽▽ 修正: AVPlayerViewController を使用 ▽▽▽
            playerViewController = AVPlayerViewController()
            playerViewController!.player = player
            playerViewController!.videoGravity = .resizeAspectFill
            playerViewController!.view.frame = self.view.bounds
            self.view.addSubview(playerViewController!.view)
            
            // タッチをブロックする透明なビューを追加
            let touchBlockerView = UIView(frame: self.view.bounds)
            touchBlockerView.backgroundColor = UIColor.clear
            self.view.addSubview(touchBlockerView)
            
            // 動画の準備が完了しているか確認
            player?.currentItem?.addObserver(self, forKeyPath: "status", options: [.initial, .new], context: nil)
            
            // 動画再生終了時にダミーモードを終了
            if let currentItem = player?.currentItem {
                NotificationCenter.default.addObserver(self, selector: #selector(endDummyMode), name: .AVPlayerItemDidPlayToEndTime, object: currentItem)
            }
            
            // 動画再生を開始
            player?.play()
        } else {
            print("動画ファイル (vacuum_dummy.mp4) が見つかりません。")
        }
        // 加速度センサーを停止
        motionManager.stopAccelerometerUpdates()
    }
    
    // ダミーモードの終了処理
    @objc func endDummyMode() {
        isDummyMode = false
        
        playerLayer?.removeFromSuperlayer()
        
        // 動画ビューを削除する
        player?.pause()
        player?.replaceCurrentItem(with: nil)
        player?.currentItem?.removeObserver(self, forKeyPath: "status")
        playerViewController?.view.removeFromSuperview()
        playerViewController = nil
        
        view.isUserInteractionEnabled = true
        detectedQRCodeType = nil
        currentQRCodeImageView.isHidden = true
        
        // ▽▽▽ カートリッジライトを表示 ▽▽▽
        updateCartridgeLightImage(selectedCartridgeIndex)
        statusImageView.isHidden = false
        print("ダミーモードが終了しました")
    }
    
    // QRコードの読み取りを一時停止する
    func stopQRCodeScanning() {
        if captureSession.isRunning {
        captureSession.stopRunning()
        }
    }
    
    // QRコードの読み取りを再開する
    func startQRCodeScanning() {
        if !captureSession.isRunning && isConnectionEstablished {
             DispatchQueue.global(qos: .userInitiated).async {
                self.captureSession.startRunning()
            }
        }
    }
    
    // ▽▽▽ [NEW FLOW] この関数はおそらく不要 ▽▽▽
    func startVideoPlayback(for videoName: String) {
        // ... (startSuctionMode が使われるため、これは呼ばれない想定)
    }

    // ▽▽▽ [FIX-4] ボス攻撃動画 完了 ▽▽▽
    @objc func endBossAttackMode() {
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: player.currentItem)
        player?.currentItem?.removeObserver(self, forKeyPath: "status")

        isSuctionMode = false
        isBossScan = false
        print("ボス攻撃動画が終了しました")
                
        // ▽ TCP送信、カートリッジクリアは動画再生後に行う
        if let score = cartridge[selectedCartridgeIndex] {
            
            // 1. PCに攻撃成功を通知
            print("TCP: Attack:\(score) を送信します")
            TCPClient.shared.send(message: "Attack:\(score)")
            
            // 2. カートリッジを空にする
            cartridge[selectedCartridgeIndex] = nil
                
        } else {
            // (このルートは handleBossAttack で防止されているはず)
            print("エラー: ボス攻撃完了時、カートリッジが空でした。")
        }
        
        // ▽ ライトを Scan_Null に更新
        updateCartridgeLightImage(selectedCartridgeIndex)
        statusImageView.isHidden = false
        
        // (デバッグカウントはボス攻撃では増やさない)
        // updateDebugLabels() 
                
        player?.pause()
        playerViewController?.view.removeFromSuperview()
        playerViewController = nil
                
        // (motionManager は起動していないので停止不要)
        
        self.qrCodeNumber = nil
        self.currentSuctionScore = 0 // (使用していないが一応リセット)
    }

    // ▽▽▽ [FIX-1] カートリッジ自動選択 (新規) ▽▽▽
    func advanceToNextEmptyCartridge() {
        // 
        if !cartridge.contains(where: { $0 == nil }) {
            print("全カートリッジが満タンです。インデックスを変更しません。")
            return
        }
        
        // 
        var nextIndex = selectedCartridgeIndex
        for _ in 0..<4 {
            nextIndex = (nextIndex + 1) % 4 // 
            if cartridge[nextIndex] == nil {
                selectedCartridgeIndex = nextIndex
                print("次の空カートリッジ \(selectedCartridgeIndex) に移動しました。")
                return
            }
        }
    }
    
    // ▽▽▽ [FIX] ボス攻撃動画 *セグメント* 完了 (正しいスロットを空にする) ▽▽▽
    @objc func handleBossVideoSegmentFinished() {
        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: player.currentItem)
        player?.currentItem?.removeObserver(self, forKeyPath: "status")

        // isSuctionMode = false // 
        // isBossScan = false // 
        print("ボス攻撃セグメント終了 (スコア: \(currentSuctionScore))")
                
        // ▽▽▽ [FIX] 
        // 
        // 
        if currentSuctionScore > 0 {
            
            // 1. 
            print("TCP: Attack:\(currentSuctionScore) を送信します")
            TCPClient.shared.send(message: "Attack:\(currentSuctionScore)")
            
            // 2. 
            print("カートリッジ \(currentCartridgeIndexBeingUsed) を空にします。")
            cartridge[currentCartridgeIndexBeingUsed] = nil
            
            currentSuctionScore = 0 // 
                
        } else {
            print("エラー: ボス攻撃完了時、スコアが0でした。")
        }
        
        // ▽ ライトはまだ更新しない (シーケンス完了時)
        // updateCartridgeLightImage(selectedCartridgeIndex)
        // statusImageView.isHidden = false
                
        player?.pause()
        playerViewController?.view.removeFromSuperview()
        playerViewController = nil
                
        // 3. 
        processNextBossAttack()
    }

    // ... (startDummyMode, endDummyMode, stopQRCodeScanning, startQRCodeScanning は変更なし) ...
}
