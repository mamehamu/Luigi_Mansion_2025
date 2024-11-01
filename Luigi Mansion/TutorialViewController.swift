//
//  TutorialViewController.swift
//  Luigi Mansion
//
//  Created by rikuya on 2024/10/14.
//

import UIKit
import AVKit
import AVFoundation
import CoreMotion
import MediaPlayer
import SwiftUI

class TutorialViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    
    
    let audioSession = AVAudioSession.sharedInstance()
    
    var initialVolume: Float = 0.0
    var volumeView: MPVolumeView!
    
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
        
        try! audioSession.setActive(true)
        
        let data = "-1".data(using: .utf8)!
        TCPClient.shared.start(data: data)

        setupCamera()
        setupImageViews()
        setupTouchGesture()
        prepareVideos()
        setupCustomVolumeView()
        view.backgroundColor = .black
        lightImageView.isHidden = false
        
        initialVolume = audioSession.outputVolume
        setSystemVolume(initialVolume)
        setupVolumeButtonHandler()
        /*
        sendToUnity(sendnum: -1)
        */
        // 音量変更通知の監視を設定
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(handleVolumeChange),
                                               name: NSNotification.Name("AVSystemController_SystemVolumeDidChangeNotification"),
                                               object: nil)
    }
    /*
     func sendToUnity(sendnum: Int) {
     client.send(data: String(sendnum).data(using: .utf8)!)
     
     }
     */
    
    func startListeningVolumeButton() {
        // MPVolumeViewを画面の外側に追い出して見えないようにする
        let frame = CGRect(x: -100, y: -100, width: 100, height: 100)
        volumeView = MPVolumeView(frame: frame)
        volumeView.sizeToFit()
        view.addSubview(volumeView)
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setActive(true)
            // AVAudioSessionの出力音量を取得して、最大音量と無音に振り切れないように初期音量を設定する
            let vol = audioSession.outputVolume
            initialVolume = Float(vol.description)!
            if initialVolume > 0.9 {
                initialVolume = 0.9
            } else if initialVolume < 0.1 {
                initialVolume = 0.1
            }
            setVolume(initialVolume)
            // 出力音量の監視を開始
            audioSession.addObserver(self, forKeyPath: "outputVolume", options: .new, context: nil)
        } catch {
            print("Could not observer outputVolume ", error)
        }
    }
    
    func setVolume(_ volume: Float) {
        (volumeView.subviews.filter{NSStringFromClass($0.classForCoder) == "MPVolumeSlider"}.first as? UISlider)?.setValue(initialVolume, animated: false)
    }
    
    func stopListeningVolumeButton() {
        // 出力音量の監視を終了
        AVAudioSession.sharedInstance().removeObserver(self, forKeyPath: "outputVolume")
        // ボリュームビューを破棄
        volumeView.removeFromSuperview()
        volumeView = nil
    }
    
    
    
    
    // 音量を強制的に0.6に保つメソッド
    func forceVolumeToFixedValue() {
        if let slider = volumeView.subviews.first(where: { $0 is UISlider }) as? UISlider {
            slider.value = 0.6 // 音量を0.6に設定
        }
    }
    
    
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
    
    /*
    func sendToUnity(sendnum: Int) {
        guard !hasSentData else {
            print("Data already sent, skipping for value: \(sendnum)")
            return
        }
        
        let data = String(sendnum).data(using: .utf8)!
        do {
            print("Data sent successfully with value: \(sendnum)")
        } catch {
            print("Failed to send data for value \(sendnum): \(error.localizedDescription)")
        }
    }
    */
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
    
    
    func setupTouchGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleScreenTap))
        view.addGestureRecognizer(tapGesture)
    }
    
    @objc func handleScreenTap() {
        if isSuctionMode || (player?.rate ?? 0.0) > 0.0 {
            return
        }//吸い取りモード中やQRコードがない場合は無視
        if detectedQRCodeType == "ghost" {
            print("画面がタッチされ、吸い込みモードに移行します")
            startSuctionMode()
        }
    }
    
    func handleRemoteButtonPress() {
        print("ボタンが押されました")
        
        if isSuctionMode || (player?.rate ?? 0.0) > 0.0 {
            return
        }
        if detectedQRCodeType == "ghost" {
            print("リモコンのボタンが押され、吸い込みモードに移行します")
            startSuctionMode()
        }
        if tutorial_flag == true && start_flag == false {
            print("リモコンが押された!!!のでチュートリアル完!!")
            handleTapAndDelayStart()
        }
    }
    /*
     // 音量を監視し、最大の場合に少し下げる
     func checkAndAdjustVolume() {
     let currentVolume = AVAudioSession.sharedInstance().outputVolume
     let maxVolume: Float = 1.0 // 最大音量
     let volumeStep: Float = 0.1 // 下げる音量のステップ
     
     if currentVolume >= maxVolume {
     // 音量を少し下げる
     
     setVolume(volume: currentVolume - volumeStep)
     }
     }
     */
    /*
     // 音量を変更するメソッド
     func setVolume(volume: Float) {
     let audioSession = AVAudioSession.sharedInstance()
     do {
     try audioSession.setActive(true)
     try audioSession.setCategory(.playback, mode: .default)
     try audioSession.setActive(true)
     } catch {
     print("Error setting audio session: \(error.localizedDescription)")
     }
     
     let volumeView = MPVolumeView(frame: .zero)
     if let slider = volumeView.subviews.first(where: { $0 is UISlider }) as? UISlider {
     slider.value = volume
     }
     }
     */
    
    func setVolume(to value: Float) {
        let audioSession = AVAudioSession.sharedInstance()
        
        do {
            try audioSession.setActive(true)
            
            // 音量の制限を設定
            let currentVolume = audioSession.outputVolume
            let newVolume = min(max(currentVolume + value, 0.1), 0.9) // 0.1～0.9の範囲に制限
            
            // 音量を設定する
            let volumeView = MPVolumeView(frame: .zero)
            if let slider = volumeView.subviews.first(where: { $0 is UISlider }) as? UISlider {
                slider.value = newVolume
            }
            
            print("Volume set to: \(newVolume)")
        } catch {
            print("Failed to set audio session active: \(error)")
        }
    }
    
    @objc func handleVolumeChange(notification: Notification) {
        guard let userInfo = notification.userInfo,
              let volumeChange = userInfo["AVSystemController_AudioVolumeNotificationParameter"] as? Float else {
            return
        }
        
        // 音量が最小または最大になるのを防ぐ
        let newVolume = min(max(volumeChange, 0.1), 0.9) // 0.1～0.9の範囲に制限
        setVolume(to: newVolume)
    }
    
    
    
    func startConnection() {
        /*
         do {
         try client.start()
         print("TCP Connection started successfully.")
         } catch {
         print("Failed to start TCP connection: \(error.localizedDescription)")
         
         }
         */
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
    
    /*
     func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
     if isSuctionMode {
     // 吸い込みモード中は新しいスキャンを無視
     return
     }
     
     if let metadataObject = metadataObjects.first {
     guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
     let stringValue = readableObject.stringValue else { return }
     
     if stringValue == "marker_tutorial" {
     // スキャン停止
     captureSession.stopRunning()
     isSuctionMode = true
     startSuctionMode()
     }
     }
     }
     */
    
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
        // タップされたときに sendToUnity を呼び出して -4 を送信
        /*
        sendToUnity(sendnum: -4)
        */
        let data = "-4".data(using: .utf8)!
        TCPClient.shared.start(data: data)
        
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
        /*
        sendToUnity(sendnum: -2)
        */
        let data = "-2".data(using: .utf8)!
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
        
        
        if keyPath == "outputVolume" {
            print("ボタンが押されました2")
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
        tutorial_flag = true
        /*
        sendToUnity(sendnum: -3)
         */
        let data = "-3".data(using: .utf8)!
        TCPClient.shared.start(data: data)
        
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
