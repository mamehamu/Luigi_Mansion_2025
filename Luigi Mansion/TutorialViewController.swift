//
//  TutorialViewController.swift
//  Luigi Mansion
//
//  Created by rikuya on 2024/10/14.
//
/*
import UIKit
import AVKit
import AVFoundation
import CoreMotion
import MediaPlayer
import SwiftUI

class TutorialViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    
    var isQRCodeDetected = false
    
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    
    var isQRCodeVisible: Bool = false
    var qrCodeLostTimer: Timer?
    
    var isSuctionMode = false
    
    var hasSentData = false
    
    var isDebugMode = false
    
    var tutorial_flag = false //吸い取りが完了したらtrue
    
    var start_flag = false
    
    
    var detectedQRCodeType: String? = nil//
    
    
    var suctionDuration: TimeInterval = 10.0
    
    let motionManager = CMMotionManager()
    var qrCodeNumber: Int? //不要かも
    
    var player: AVPlayer!
    var playerLayer: AVPlayerLayer?
    var playerViewController: AVPlayerViewController!
    
    var ghostImageView: UIImageView!
    var lightImageView: UIImageView!
    var currentQRCodeImageView: UIImageView!
    
    var lastShakeTime: TimeInterval = 0
    let shakeThreshold: Double = 1.10 //加速度のしきい値
    let cooldownPeriod: TimeInterval = 0.75
    
    var tapGesture: UITapGestureRecognizer?
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        
        TCPClient.shared.send(message: "-1")
        
        setupCamera()
        setupImageViews()
        prepareVideos()
        view.backgroundColor = .black
        lightImageView.isHidden = false
        
        // 音量変更通知の監視を設定
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleTCPCommand(_:)),
                                               name: .tcpMessageReceived,
                                               object: nil
                                               )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self, name: .tcpMessageReceived, object: nil)
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
            
            ghostImageView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            ghostImageView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            ghostImageView.widthAnchor.constraint(equalTo: view.widthAnchor),
            ghostImageView.heightAnchor.constraint(equalTo: view.heightAnchor)
        ])
    }

    // ▽▽▽ TCPコマンド受信ハンドラ ▽▽▽
    @objc func handleTCPCommand(_ notification: Notification) {
        guard let command = notification.userInfo?["command"] as? String else { return }
            
        print("TutorialVC received command: \(command)")
            
        // "特定の言葉" (例: "START_SUCTION_TUTORIAL") で吸い取りを開始
        if command == "START_SUCTION_TUTORIAL" {
        // 以前の音量ボタン押下時の処理 (handleRemoteButtonPress) と同等のロジックを実行
            handleSuctionTrigger()
        }
    }
        
    // 吸い取りトリガーを共通化
        func handleSuctionTrigger() {
            if isSuctionMode || (player?.rate ?? 0.0) > 0.0 {
                return
            }
            if detectedQRCodeType == "ghost" {
                print("吸い込みモードに移行します (Triggered)")
                startSuctionMode()
            }
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
    
    func setupGhostImageView() {
        ghostImageView = UIImageView(image: UIImage(named: "ghost"))
        ghostImageView.contentMode = .scaleAspectFit
        ghostImageView.frame = CGRect(x: (view.bounds.width - 300) / 2,
                                      y: (view.bounds.height - 300) / 2,
                                      width: 300,
                                      height: 300)
        ghostImageView.isHidden = true
        view.addSubview(ghostImageView)
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        // 吸い取りモード中、ダミー操作中はQRコードの処理をしない
        if isSuctionMode { return }
        
        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
                  let stringValue = readableObject.stringValue,
                  stringValue == "marker_tutorial" else {
                handleQRCodeLost()
                return
            }
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            detectedQRCodeType = "ghost"
            lightImageView.isHidden = true
            
            // QRコードが読み取れたので、処理を実行
            handleQRCodeDetected(qrCodeNumber: stringValue)
            
        } else {
            handleQRCodeLost()
            lightImageView.isHidden = false
        }
    }
    
    
    func handleQRCodeDetected(qrCodeNumber: String) {
        lightImageView.isHidden = true
        // QRコードが検出された時の処理
        if !isQRCodeVisible {
            isQRCodeVisible = true
            print("QRコードが見えています: \(qrCodeNumber)")
        }
        showQRCodeImage(image: ghostImageView.image!)
        view.bringSubviewToFront(ghostImageView)
        lightImageView.isHidden = true
        
        currentQRCodeImageView.isHidden = false
        ghostImageView.isHidden = false
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
                    self?.lightImageView.isHidden = false
                    self?.ghostImageView.isHidden = true
                    self?.currentQRCodeImageView.isHidden = true
                }
            }
        }
    }
    
    
    /*
     func enterSuctionMode() {
     // おばけを表示
     ghostImageView.isHidden = false
     
     // 吸い込みアニメーション
     UIView.animate(withDuration: 3.0, animations: {
     self.ghostImageView.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
     self.ghostImageView.alpha = 0
     }) { _ in
     self.ghostImageView.removeFromSuperview()
     self.waitForTouchToStartGame()
     }
     }
     */
    func waitForTouchToStartGame() {
        // タップ待機のメッセージ表示
        let tapToStartLabel = UILabel()
        tapToStartLabel.text = "タッチしてゲームを始める"
        tapToStartLabel.font = UIFont.systemFont(ofSize: 24)
        tapToStartLabel.textColor = .white
        tapToStartLabel.textAlignment = .center
        tapToStartLabel.frame = view.bounds
        view.addSubview(tapToStartLabel)
        
        tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleTapAndDelayStart))
        if let tapGesture = tapGesture {
            view.addGestureRecognizer(tapGesture)
        }
    }
    
    @objc func handleTapAndDelayStart() {
        start_flag = true
        
        TCPClient.shared.send(message: "-4")
        
        // タップジェスチャーを無効化して、複数回押されるのを防止
        if let tapGesture = tapGesture {
            view.removeGestureRecognizer(tapGesture)
            self.tapGesture = nil
        }
        
        // 3秒の遅延を入れてゲームをスタート
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.startMainGame()
        }
    }
    
    
    @objc func startMainGame() {
        let gameVC = GameViewController()
        gameVC.isDebugMode = isDebugMode
        gameVC.modalPresentationStyle = .fullScreen
        present(gameVC, animated: true, completion: nil)
    }
    
    func startSuctionMode() {
       
        TCPClient.shared.send(message: "-2")
        
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
    
    func showQRCodeImage(image: UIImage) {
        print("showQRCodeImage: 画像が表示されます")
        
        currentQRCodeImageView.image = image
        currentQRCodeImageView.isHidden = false
        lightImageView.isHidden = true
    }
    
    func hideQRCodeImage(){
        currentQRCodeImageView.isHidden = true
        currentQRCodeImageView.image = nil
        lightImageView.isHidden = false
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
        if currentRate < 5.0{
            player.rate = min(currentRate + 0.5, 5.0)
        }
    }
    
    
    
    @objc func endSuctionMode(qrCodeNumber : Int) {
        tutorial_flag = true
        
        TCPClient.shared.send(message: "-3")
        
        isSuctionMode = false
        
        ghostImageView.isHidden = true
        currentQRCodeImageView.isHidden = true
        lightImageView.isHidden = false
        showQRCodeImage(image: lightImageView.image!)
        view.bringSubviewToFront(lightImageView)
        
        print("吸い込みモードが終了しました")
        
        player.pause()
        
        
        // 動画表示の削除
        playerViewController.view.removeFromSuperview()
        
        // モーションデータの取得を停止
        motionManager.stopAccelerometerUpdates()
        
        
        detectedQRCodeType = nil
        waitForTouchToStartGame()
        
    }
    
    
}
*/
