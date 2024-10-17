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

class GameViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    
    var isQRCodeVisible: Bool = false// QRコードが見えているかのフラグ
    var qrCodeLostTimer: Timer? // QRコードが見えなくなった時のタイマー
    var isDummyMode: Bool = false // ダミーQRコードが読み取られたかどうかのフラグ
    var isSuctionMode = false // 吸い取りモードかどうかのフラグ
    
    var detectedQRCodeType: String? // 読み取られたQRコードのタイプ ("ghost" か "dummy")
    var exterminatedCount = 0
    let maxExterminationCount = 5
    var remainingTime: Int = 180 // 3分
    var gameTimer: Timer?
    var suctionDuration: TimeInterval = 10.0
    let motionManager = CMMotionManager()
    
    var player: AVPlayer!
    var playerViewController: AVPlayerViewController!
    
    var ghostImageView: UIImageView!
    var dummyImageView: UIImageView!
    var currentQRCodeImageView: UIImageView!
    
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
        startGameTimer()
        setupPlayer()
        view.backgroundColor = .black
    }
    
    func setupPlayer() {
        // 動画URLを設定し、AVPlayerを初期化
        let videoURL = URL(string: "vacuum")!
        player = AVPlayer(url: videoURL)
        // AVPlayerLayerを設定
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.frame = self.view.bounds
        self.view.layer.addSublayer(playerLayer)
    }
    
    func setupCamera() {
        captureSession = AVCaptureSession()
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return }
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
        
        // カメラのプレビュー設定
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill  // 映像を画面にフィットさせる
        
        // カメラの向きを横画面に設定
        if let connection = previewLayer.connection {
            if connection.isVideoOrientationSupported {
                connection.videoOrientation = .landscapeRight  // 横向きの向きに合わせる
            }
        }
        
        // カメラプレビューを表示
        view.layer.addSublayer(previewLayer)
        
        
        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession.startRunning() // ここをバックグラウンドスレッドで実行
        }
    }
    
    func setupImageViews() {
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
    }
    
    func setupTouchGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleScreenTap))
        view.addGestureRecognizer(tapGesture)
    }
    
    @objc func handleScreenTap() {
        if isSuctionMode || detectedQRCodeType == nil { return }//吸い取りモード中やQRコードがない場合は無視
        if detectedQRCodeType == "ghost" {
            print("画面がタッチされ、吸い込みモードに移行します")
            startSuctionMode() // 吸い取りモードに移行
        } else if detectedQRCodeType == "dummy"{
            print("画面がタッチされましたが、dummyです。操作不能にします。")
            startDummyMode()
        }
    }
    
    func startGameTimer() {
        gameTimer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(updateGameTimer), userInfo: nil, repeats: true)
    }
    
    @objc func updateGameTimer() {
        if remainingTime > 0 {
            remainingTime -= 1
            print("残り時間: \(remainingTime)秒")
            // タイマー表示を更新する場合はここで処理
        } else {
            gameTimer?.invalidate()
        }
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
        }
    }
    
    func handleQRCodeDetected(qrCodeNumber: Int) {
        // QRコードが検出された時の処理
        if !isQRCodeVisible {
            isQRCodeVisible = true
            print("QRコードが見えています: \(qrCodeNumber)")
        }
        
        // QRコードに対応する処理（ghostかdummyかの判定）
        if qrCodeNumber >= 0 && qrCodeNumber < gameArray.count {
            let qrCodeType = gameArray[qrCodeNumber]
            
            if qrCodeType == "ghost" {
                detectedQRCodeType = "ghost"
                print("QRコードがghostです。画面タッチで吸い込みモードに移行できます")
                showQRCodeImage(image: ghostImageView.image!)
                
            } else if qrCodeType == "dummy" {
                detectedQRCodeType = "dummy"
                print("QRコードがdummyです")
                showQRCodeImage(image: dummyImageView.image!)
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
                }
            }
        }
    }
    
    func showQRCodeImage(image: UIImage) {
        currentQRCodeImageView.image = image
        currentQRCodeImageView.isHidden = false
    }
    
    func hideQRCodeImage(){
        currentQRCodeImageView.isHidden = true
        currentQRCodeImageView.image = nil
    }
    
    func startSuctionMode() {
        isSuctionMode = true
        hideQRCodeImage()
        
        // プレースホルダー画像を表示
        let placeholderImageView = UIImageView(image: UIImage(named: "placeholder"))
        placeholderImageView.frame = self.view.bounds
        placeholderImageView.contentMode = .scaleAspectFill
        view.addSubview(placeholderImageView)
        
        // 動画の準備を開始
        if let videoURL = Bundle.main.url(forResource: "vacuum", withExtension: "mp4") {
            player = AVPlayer(url: videoURL)
            playerViewController = AVPlayerViewController()
            playerViewController.player = player
            playerViewController.videoGravity = .resizeAspectFill
            
            // 動画を画面いっぱいに表示
            playerViewController.view.frame = self.view.bounds
            self.view.addSubview(playerViewController.view)
            
            // 動画の準備が完了しているか確認
            player?.currentItem?.addObserver(self, forKeyPath: "status", options: [.initial, .new], context: nil)
            
            // 動画再生終了時に吸い込みモードを終了
            if let currentItem = player.currentItem {
                NotificationCenter.default.addObserver(self, selector: #selector(endSuctionMode), name: .AVPlayerItemDidPlayToEndTime, object: currentItem)
            }
        }
        
        // プレースホルダーの削除を行う
        DispatchQueue.main.async {
            placeholderImageView.removeFromSuperview()
        }
        
        // 加速度センサーを使ってデバイスの揺れを検知
        motionManager.startAccelerometerUpdates(to: OperationQueue.current!) { [weak self] (data, error) in
            guard let data = data, error == nil else { return }
            let acceleration = sqrt(pow(data.acceleration.x, 2) + pow(data.acceleration.y, 2) + pow(data.acceleration.z, 2))
            
            if acceleration > 1.3 { // デバイスが揺れたとき
                print("デバイスが揺れました！動画の再生速度を倍速します。")
                self?.increasePlaybackSpeed()
            }
        }
    }

    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
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
        let newRate: Float = currentRate + 0.5 // 0.5ずつ増やす

        UIView.animate(withDuration: 0.5) { // アニメーションで速度変更
                player.rate = newRate
        }
    }
    
    
    
    @objc func endSuctionMode() {
        isSuctionMode = false
        print("吸い込みモードが終了しました")
        // 動画停止
        player.pause()
        
        // 動画表示の削除
        playerViewController.view.removeFromSuperview()
        
        // モーションデータの取得を停止
        motionManager.stopAccelerometerUpdates()
        
        // QRコードリーダーを再開
        startQRCodeScanning()
        
        // QRコード配列を更新し、読み取ったQRコードがdummyに変わる
        if let detectedQRCodeType = detectedQRCodeType, detectedQRCodeType == "ghost", let qrCodeNumber = gameArray.firstIndex(of: "ghost") {
            gameArray[qrCodeNumber] = "dummy" // 吸い込んだQRコードをdummyに変更
            print("QRコード \(qrCodeNumber) が dummy に変わりました")
        }
        detectedQRCodeType = nil
    }
    
    // ダミーモードを開始する
    func startDummyMode() {
        isDummyMode = true
        hideQRCodeImage() // QRコードの画像を非表示にする
        
        print("Dummy QRコードが読み取られました。操作を3秒間停止します")
        
        // QRコードの読み取りを一時停止
        stopQRCodeScanning()
        
        // 3秒間の待機後に、通常モードに戻る
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.endDummyMode()
        }
    }
    
    func endDummyMode() {
        isDummyMode = false
        print("Dummyモードが終了しました")
        
        // QRコードの読み取りを再開
        startQRCodeScanning()
        detectedQRCodeType = nil
    }
    
    // QRコードの読み取りを一時停止する
    func stopQRCodeScanning() {
        captureSession.stopRunning()
    }
    
    // QRコードの読み取りを再開する
    func startQRCodeScanning() {
        captureSession.startRunning()
    }
}
