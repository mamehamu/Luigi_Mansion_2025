//
//  GameViewController.swift
//  Luigi Mansion
//
//  Created by rikuya on 2024/10/14.
//

import UIKit
import AVKit
import AVFoundation
import CoreMotion
import MediaPlayer

class GameViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    
    var isQRCodeDetected = false
    
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    
    var hasSentData = false
    
    var isDebugMode = false
    var isQRCodeVisible: Bool = false// QRコードが見えているかのフラグ
    var qrCodeLostTimer: Timer? // QRコードが見えなくなった時のタイマー
    var isDummyMode: Bool = false // ダミーQRコードが読み取られたかどうかのフラグ
    var isSuctionMode = false // 吸い取りモードかどうかのフラグ
    
    var initialVolume: Float = 0.5
    let audioSession = AVAudioSession.sharedInstance()
    
    /*
    public let client = TCPClient(host: "10.202.253.246" ,port: 8080)
    */
    var detectedQRCodeType: String? // 読み取られたQRコードのタイプ ("ghost" か "dummy")
    let maxExterminationCount = 5
    var exterminatedCount = 0 {
        didSet {
            updateDebugLabels()
            checkForGameEnd() // 退治数が増えるたびにゲーム終了判定を行う
        }
    }
    var remainingTime: Int = 180 // 3分
    var gameTimer: Timer?
    var suctionDuration: TimeInterval = 10.0
    let motionManager = CMMotionManager()
    var qrCodeNumber: Int?
    
    var player: AVPlayer!
    var playerLayer: AVPlayerLayer?
    var playerViewController: AVPlayerViewController!
    
    var ghostImageView: UIImageView!
    var dummyImageView: UIImageView!
    var lightImageView: UIImageView!
    var currentQRCodeImageView: UIImageView!
    
    var debugGhostCountLabel: UILabel?
    var debugRemainingTimeLabel: UILabel?
    
    var lastShakeTime: TimeInterval = 0
    let shakeThreshold: Double = 1.10 //加速度のしきい値
    let cooldownPeriod: TimeInterval = 0.75 //次の振動を感知するまでのクールダウン
    
    
    var gameArray: [String] = ["ghost", "ghost", "ghost", "ghost", "ghost", "dummy", "dummy"]
    
    func initializeGameArray() {
        gameArray.shuffle() // 配列をシャッフルする
    }
    
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        initializeGameArray() // 配列の初期化
        setupCamera()
        setupImageViews()
        setupTouchGesture()
        prepareVideos()
        setupCustomVolumeView()
        view.backgroundColor = .black
        /*
        sendToUnity(sendnum: -5)
        */
        
        let data = "-5".data(using: .utf8)!
        TCPClient.shared.start(data: data)
        
        preloadVideo(named: "vacuum.mp4")
        preloadVideo(named: "vacuum_dummy.mp4")
        
        lightImageView.isHidden = false
        
        // 現在の音量を取得
        initialVolume = audioSession.outputVolume
        setSystemVolume(initialVolume)
        setupVolumeButtonHandler()
        
        if isDebugMode {
            setupDebugLabels() // デバッグモードの場合、ラベルを設定
        }
        startGameTimer()
    }
    /*
    func sendToUnity(sendnum: Int) {
        guard !hasSentData else {
            print("Data already sent, skipping for value: \(sendnum)")
            return
        }
        
        let data = String(sendnum).data(using: .utf8)!
        do {
            print("Data sent successfully with value: \(sendnum)")

            // 送信フラグを設定
        } catch {
            print("Failed to send data for value \(sendnum): \(error.localizedDescription)")
        }
    }
         */
    func setupCustomVolumeView() {
        let volumeView = MPVolumeView(frame: CGRect(x: -1000, y: -1000, width: 0, height: 0))
        volumeView.isHidden = true  // 標準の音量ビューを非表示に
        self.view.addSubview(volumeView)
    }
    
    // 音量変更があった時に呼ばれる関数
    @objc func volumeDidChange(notification: NSNotification) {
        // 音量を元の値に戻す
        setSystemVolume(initialVolume)
    }

    // 音量をプログラム的に設定する
    func setSystemVolume(_ volume: Float) {
        let volumeView = MPVolumeView()
        if let slider = volumeView.subviews.first(where: { $0 is UISlider }) as? UISlider {
            slider.value = volume
        }
    }
    
    func setupDebugLabels() {
        debugGhostCountLabel = UILabel(frame: CGRect(x: view.bounds.width - 120, y: 50, width: 100, height: 30))
        debugGhostCountLabel?.textColor = .red
        debugGhostCountLabel?.text = "退治数: \(exterminatedCount)"
        view.addSubview(debugGhostCountLabel!)

        debugRemainingTimeLabel = UILabel(frame: CGRect(x: view.bounds.width - 120, y: 90, width: 100, height: 30))
        debugRemainingTimeLabel?.textColor = .red
        debugRemainingTimeLabel?.text = "残り時間: \(remainingTime)"
        view.addSubview(debugRemainingTimeLabel!)
    }
    
    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        super.pressesBegan(presses, with: event)
        
        // リモコンのボタンが押された場合の処理
        for press in presses {
            if press.type == .playPause || press.type == .select {
                print("Bluetoothリモコンのボタンが押されました")
                handleRemoteButtonPress()
            }
        }
    }

    func setupVolumeButtonHandler() {
        let volumeView = MPVolumeView(frame: .zero)
        view.addSubview(volumeView)
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setActive(true)
        } catch {
            print("Failed to activate audio session")
        }

        audioSession.addObserver(self, forKeyPath: "outputVolume", options: [.old, .new], context: nil)
    }

    func prepareVideos() {
        guard let videoURL = Bundle.main.url(forResource: "vacuum", withExtension: "mp4") else { return }
        let playerItem = AVPlayerItem(url: videoURL)
        playerItem.preferredForwardBufferDuration = 1.0
        player = AVPlayer(playerItem: playerItem)
    }
    
    func preloadVideo(named videoName: String) {
        // 動画ファイルのURLを取得
        if let videoPath = Bundle.main.path(forResource: videoName, ofType: nil) {
            let videoURL = URL(fileURLWithPath: videoPath)
            let asset = AVAsset(url: videoURL)
            let playerItem = AVPlayerItem(asset: asset)
            
            // 動画を再生する準備をする
            player = AVPlayer(playerItem: playerItem)
            playerLayer = AVPlayerLayer(player: player)
            playerLayer?.frame = self.view.bounds
            self.view.layer.addSublayer(playerLayer!)
            
            // 再生前にプレイヤーを一時停止して準備させる
            player?.pause()
        }
    }
    
    deinit {
        // 音量変更の通知を解除
        NotificationCenter.default.removeObserver(self, name: NSNotification.Name("AVSystemController_SystemVolumeDidChangeNotification"), object: nil)
    }
    
    
    func setupCamera() {
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
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            print("Could not add metadata output to capture session")
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
         self.captureSession.startRunning() // ここをバックグラウンドスレッドで実行
         }
    }
    
    func setupImageViews() {
        
        // light.png の UIImageView を作成
        lightImageView = UIImageView(image: UIImage(named: "light"))
        lightImageView.contentMode = .scaleAspectFill
        lightImageView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(lightImageView)
        
        // Ghost ImageView の設定
        ghostImageView = UIImageView(image: UIImage(named: "ghost"))
        ghostImageView.contentMode = .scaleAspectFill
        ghostImageView.frame = view.bounds
        ghostImageView.isHidden = true
        view.addSubview(ghostImageView)
        
        // Dummy ImageView の設定
        dummyImageView = UIImageView(image: UIImage(named: "dummy"))
        dummyImageView.contentMode = .scaleAspectFill
        dummyImageView.frame = view.bounds
        dummyImageView.isHidden = true
        view.addSubview(dummyImageView)
        
        // 現在のQRコードの画像ビュー（ghostかdummyが表示される）
        currentQRCodeImageView = UIImageView()
        currentQRCodeImageView.contentMode = .scaleAspectFill
        currentQRCodeImageView.frame = view.bounds
        currentQRCodeImageView.isHidden = true
        view.addSubview(currentQRCodeImageView)
        
        NSLayoutConstraint.activate([
                    lightImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                    lightImageView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                    lightImageView.widthAnchor.constraint(equalTo: view.widthAnchor),
                    lightImageView.heightAnchor.constraint(equalTo: view.heightAnchor),
                    
                    dummyImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                    dummyImageView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                    dummyImageView.widthAnchor.constraint(equalTo: view.widthAnchor),
                    dummyImageView.heightAnchor.constraint(equalTo: view.heightAnchor),
                    
                    ghostImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
                    ghostImageView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
                    ghostImageView.widthAnchor.constraint(equalTo: view.widthAnchor),
                    ghostImageView.heightAnchor.constraint(equalTo: view.heightAnchor)
                ])
    }
    
    func setupTouchGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleScreenTap))
        view.addGestureRecognizer(tapGesture)
    }
    
    @objc func handleScreenTap() {
        if isSuctionMode || isDummyMode || (player.rate > 0.0 || (player?.rate ?? 0.0) > 0.0) {
            return
        }//吸い取りモード中やQRコードがない場合は無視
        if let qrCodeNumber = self.qrCodeNumber, detectedQRCodeType == "ghost" {
            print("画面がタッチされ、吸い込みモードに移行します")
            startSuctionMode()
            gameArray[qrCodeNumber] = "dummy" // 吸い込み後にdummyに置換
        } else if detectedQRCodeType == "dummy" {
            print("画面がタッチされましたが、dummyです。操作不能にします。")
            startDummyMode()
        }
    }
    
    func handleRemoteButtonPress() {
        
        let currentVolume = AVAudioSession.sharedInstance().outputVolume
        let maxVolume: Float = 0.7 // 最大音量
        
        if currentVolume >= maxVolume {
             // 音量を少し下げる
            
             setVolume(volume: currentVolume - 0.1)
         }
        
        if isSuctionMode || isDummyMode || (player.rate > 0.0 || (player?.rate ?? 0.0) > 0.0) {
            return
        }
        if let qrCodeNumber = self.qrCodeNumber, detectedQRCodeType == "ghost" {
            print("リモコンのボタンが押され、吸い込みモードに移行します")
            startSuctionMode()
            gameArray[qrCodeNumber] = "dummy" // 吸い込み後にdummyに置換
        } else if detectedQRCodeType == "dummy" {
            print("リモコンのボタンが押されましたが、dummyです。操作不能にします。")
            startDummyMode()
        }
    }
    
    func setVolume(volume: Float) {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setActive(true)
            // audioSessionを通じて音量を設定する処理
            // ここで音量設定の処理を追加
        } catch {
            print("Error setting volume: \(error.localizedDescription)")
        }
    }
    
    func startGameTimer() {
        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            self.remainingTime -= 1
            self.updateDebugLabels()

            if self.remainingTime <= 0 {
                timer.invalidate()
                self.endGame(isGameClear: false)
            }
        }
    }
    
    func updateDebugLabels() {
        debugGhostCountLabel?.text = "退治数: \(exterminatedCount)"
        debugRemainingTimeLabel?.text = "残り時間: \(remainingTime)"
    }
    
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        // 吸い取りモード中、ダミー操作中はQRコードの処理をしない
        if isSuctionMode || isDummyMode { return }
        
        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
                  let stringValue = readableObject.stringValue,
                  let qrCodeNumber = Int(stringValue) else {
                
                
                
                
                handleQRCodeLost()
                return
            }
            
            // QRコードが読み取れたので、処理を実行
            handleQRCodeDetected(qrCodeNumber: qrCodeNumber)
            
        } else {
            handleQRCodeLost()
            lightImageView.isHidden = false
        }
    }

    
    func handleQRCodeDetected(qrCodeNumber: Int) {
        self.qrCodeNumber = qrCodeNumber
        lightImageView.isHidden = true
        // QRコードが検出された時の処理
        if !isQRCodeVisible {
            isQRCodeVisible = true
            print("QRコードが見えています: \(qrCodeNumber)")
        }
        
        // QRコードに対応する処理（ghostかdummyかの判定）
        if qrCodeNumber >= 0 && qrCodeNumber < gameArray.count {
            let qrCodeType = gameArray[qrCodeNumber]
            lightImageView.isHidden = false
            
            if qrCodeType == "ghost" {
                detectedQRCodeType = "ghost"
                print("QRコードがghostです。画面タッチで吸い込みモードに移行できます")
               
                lightImageView.isHidden = true
                dummyImageView.isHidden = true
                
                currentQRCodeImageView.isHidden = false
                ghostImageView.isHidden = false
                showQRCodeImage(image: ghostImageView.image!)
                view.bringSubviewToFront(ghostImageView)
                
                if isSuctionMode {
                    ghostImageView.isHidden = true
                }
            } else if qrCodeType == "dummy" {
                detectedQRCodeType = "dummy"
                print("QRコードがdummyです")
                lightImageView.isHidden = true
                ghostImageView.isHidden = true
                
                dummyImageView.isHidden = false
                currentQRCodeImageView.isHidden = false

                showQRCodeImage(image: dummyImageView.image!)
                view.bringSubviewToFront(dummyImageView)
                // ダミーQRコードを読み取った場合、表示を無効にする処理を追加
                if isDummyMode {
                    dummyImageView.isHidden = true // dummyが表示されないように            }
                }
            }
        }
        
        // QRコードを見失った際のタイマーを無効化（見えている間はリセット）
        qrCodeLostTimer?.invalidate()
        qrCodeLostTimer = nil
    }
    
    func handleQRCodeLost() {
        // QRコードが見えなくなった時の処理
        if isQRCodeVisible {
            if qrCodeLostTimer == nil {
                qrCodeLostTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { [weak self] _ in
                    self?.isQRCodeVisible = false
                    self?.detectedQRCodeType = nil
                    print("QRコードが消えました")
                    self?.hideQRCodeImage() // QRコードが消えたら画像も非表示にする
                    self?.ghostImageView.isHidden = true
                    self?.dummyImageView.isHidden = true
                    self?.currentQRCodeImageView.isHidden = true
                    self?.lightImageView.isHidden = false
                    
                }
            }
        }
    }
    
    func showQRCodeImage(image: UIImage) {
        print("showQRCodeImage: 画像が表示されます")

        currentQRCodeImageView.image = image
        currentQRCodeImageView.isHidden = false
        view.bringSubviewToFront(currentQRCodeImageView)
        lightImageView.isHidden = true
    }
    
    func hideQRCodeImage(){
        currentQRCodeImageView.isHidden = true
        currentQRCodeImageView.image = nil
        lightImageView.isHidden = false
    }
    
    func startSuctionMode() {
        /*
        sendToUnity(sendnum: -6)
         */
        let data = "-6".data(using: .utf8)!
        TCPClient.shared.start(data: data)
        
        isSuctionMode = true
        hideQRCodeImage()
        
        // プレースホルダー画像を表示
        let placeholderImageView = UIImageView(image: UIImage(named: "placeholder"))
        placeholderImageView.frame = self.view.bounds
        placeholderImageView.contentMode = .scaleAspectFill
        self.view.addSubview(placeholderImageView)
        
        // 動画の準備を開始
        if let videoURL = Bundle.main.url(forResource: "vacuum", withExtension: "mp4") {
            player = AVPlayer(url: videoURL)
            playerViewController = AVPlayerViewController()
            playerViewController.player = player
            playerViewController.videoGravity = .resizeAspectFill
            
            // 動画を画面いっぱいに表示
            playerViewController.view.frame = self.view.bounds
            self.view.addSubview(playerViewController.view)
            
            // タッチをブロックする透明なビューを追加
            let touchBlockerView = UIView(frame: self.view.bounds)
            touchBlockerView.backgroundColor = UIColor.clear // 透明なビュー
            self.view.addSubview(touchBlockerView)
            
            // 動画の準備が完了しているか確認
            player?.currentItem?.addObserver(self, forKeyPath: "status", options: [.initial, .new], context: nil)
            
            // 動画再生終了時に吸い込みモードを終了
            if let currentItem = player.currentItem {
                NotificationCenter.default.addObserver(self, selector: #selector(endSuctionMode), name: .AVPlayerItemDidPlayToEndTime, object: currentItem)
            }
        } else {
            print("vacuum.mp4 の動画ファイルが見つかりませんでした。")
        }
        
        // プレースホルダーの削除を行う
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
                self.lastShakeTime = currentTime // 最後の揺れ時間を更新
            }
        }
    }
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        
        if keyPath == "outputVolume" {
            handleRemoteButtonPress() // 音量ボタンをリモコンボタンと同様に扱う
        }
        
        if keyPath == "status" {
        if let player = player, player.status == .readyToPlay {
                // 動画の準備が完了したので再生
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
    
    
    
    @objc func endSuctionMode(qrCodeNumber : Int) {
        isSuctionMode = false
        
        dummyImageView.isHidden = true
        ghostImageView.isHidden = true
        currentQRCodeImageView.isHidden = true
        lightImageView.isHidden = false
        showQRCodeImage(image: lightImageView.image!)
        view.bringSubviewToFront(lightImageView)
        
        print("吸い込みモードが終了しました")
        
        // 残りの処理（例: おばけを退治したことを記録）
        exterminatedCount += 1
        /*
        sendToUnity(sendnum: exterminatedCount)
        */
        let data = "\(exterminatedCount)".data(using: .utf8)!
        TCPClient.shared.start(data: data)
        
        player.pause()
        
        
        // 動画表示の削除
        playerViewController.view.removeFromSuperview()
        
        // モーションデータの取得を停止
        motionManager.stopAccelerometerUpdates()
        
        
        // QRコード番号が設定されているか確認し、gameArrayを更新
        if let qrCodeNumber = self.qrCodeNumber, qrCodeNumber >= 0 && qrCodeNumber < gameArray.count {
            if gameArray[qrCodeNumber] == "ghost" {
                gameArray[qrCodeNumber] = "dummy"
                print("QRコード \(qrCodeNumber) は dummy に変換されました")
            } else {
                print("QRコード \(qrCodeNumber) は既に dummy です")
            }
        } else {
            print("QRコード番号が無効です")
        }
        checkForGameEnd()
        detectedQRCodeType = nil
    }
   /*
    func updateGameAfterSuction() {
        // 吸い取りモード後の処理をここに実装
        // たとえば、残り時間の延長や得点の加算など
        // 例:
        exterminatedCount += 1 // おばけを退治した数をカウント
        if exterminatedCount >= maxExterminationCount {
            endGame(isGameClear: true) // ゲーム終了処理
        } else {
            // 再度QRコードのスキャンを可能にする
            
            isQRCodeVisible = false
            detectedQRCodeType = nil
            initializeGameArray() // ゲーム配列を再初期化
        }
    }
    */
    func checkForGameEnd() {
        if exterminatedCount >= 5 {
            let data = "\(exterminatedCount)".data(using: .utf8)!
            TCPClient.shared.start(data: data)
            
            endGame(isGameClear: true) // 退治数が5以上の場合はゲームクリア
        } else if remainingTime <= 0 {
            let data = "\(exterminatedCount)".data(using: .utf8)!
            TCPClient.shared.start(data: data)
            
            endGame(isGameClear: false)// 時間切れの場合はゲームオーバー
        }
        let data = "\(exterminatedCount)".data(using: .utf8)!
        TCPClient.shared.start(data: data)
        
    }
    

    
    func endGame(isGameClear: Bool) {
        // ゲーム終了の処理
        let resultVC = ResultViewController()
        resultVC.modalPresentationStyle = .fullScreen
        resultVC.exterminatedCount = exterminatedCount
        resultVC.remainingTime = remainingTime
        resultVC.isGameClear = isGameClear // ゲームクリアかどうかのフラグを渡す
        present(resultVC, animated: true, completion: nil)
    }
    
    func startDummyMode() {
        isDummyMode = true
        dummyImageView.isHidden = true
        currentQRCodeImageView.isHidden = true
        hideQRCodeImage()
        showQRCodeImage(image: lightImageView.image!)
        view.bringSubviewToFront(lightImageView)

        // vacuum_dummyの動画を準備
        if let videoURL = Bundle.main.url(forResource: "vacuum_dummy", withExtension: "mp4") {
            player = AVPlayer(url: videoURL)
            
            let playerLayer = AVPlayerLayer(player: player)
            playerLayer.frame = self.view.bounds
            self.view.layer.addSublayer(playerLayer)
            
            
            // タッチをブロックする透明なビューを追加
            let touchBlockerView = UIView(frame: self.view.bounds)
            touchBlockerView.backgroundColor = UIColor.clear // 透明なビュー
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
            print("動画ファイルが見つかりません。")
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
        
        // プレイヤービューを削除
        playerViewController?.view.removeFromSuperview() // ここでプレイヤービューを削除
        playerViewController = nil // メモリを解放
        
        view.isUserInteractionEnabled = true
        detectedQRCodeType = nil
        currentQRCodeImageView.isHidden = true
        ghostImageView.isHidden = true
        dummyImageView.isHidden = true
        lightImageView.isHidden = false
        view.bringSubviewToFront(lightImageView)
        print("ダミーモードが終了しました")
    }
    
    // QRコードの読み取りを一時停止する
    func stopQRCodeScanning() {
        captureSession.stopRunning()
    }
    
    // QRコードの読み取りを再開する
    func startQRCodeScanning() {
        captureSession.startRunning()
    }
    
    func transitionToResultViewController() {
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let resultViewController = storyboard.instantiateViewController(withIdentifier: "ResultViewController") as? ResultViewController {
            resultViewController.exterminatedCount = exterminatedCount  // 退治数を渡す
            resultViewController.remainingTime = remainingTime           // 残り時間を渡す
            self.present(resultViewController, animated: true, completion: nil)
        }
    }
    
    
    func startVideoPlayback(for videoName: String) {
        guard let videoURL = Bundle.main.url(forResource: videoName, withExtension: "mp4") else {
            print("動画ファイルが見つかりません。")
            return
        }
        
        player = AVPlayer(url: videoURL)
        
        // AVPlayerLayerを設定
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.frame = self.view.bounds
        self.view.layer.addSublayer(playerLayer)
        
        // 動画再生を開始
        player.play()
    }
}
