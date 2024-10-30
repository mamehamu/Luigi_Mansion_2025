//
//  TutorialViewController.swift
//  Luigi Mansion
//
//  Created by rikuya on 2024/10/14.
//

import UIKit
import AVFoundation

class TutorialViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {

    var hasSentData = false

    var isDebugMode = false
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    var isSuctionMode = false
    var ghostImageView: UIImageView!
    public let client = TCPClient(host: "10.202.253.246", port: 8080)

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
        setupGhostImageView()
        startConnection()
        sendToUnity(sendnum: -1)
        view.backgroundColor = .black
    }
/*
    func sendToUnity(sendnum: Int) {
        client.send(data: String(sendnum).data(using: .utf8)!)
        
    }
  */
    func sendToUnity(sendnum: Int) {
        guard !hasSentData else { return }  // 既に送信済みの場合は処理をスキップ
        
        let data = String(sendnum).data(using: .utf8)!
        do {
            try client.start(data: data)
            print("Data sent successfully: \(sendnum)")
            hasSentData = true  // 送信フラグを設定
        } catch {
            print("Failed to send data: \(error.localizedDescription)")
        }
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
                enterSuctionMode()
            }
        }
    }

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

    func waitForTouchToStartGame() {
        // タップ待機のメッセージ表示
        let tapToStartLabel = UILabel()
        tapToStartLabel.text = "タッチしてゲームを始める"
        tapToStartLabel.font = UIFont.systemFont(ofSize: 24)
        tapToStartLabel.textColor = .white
        tapToStartLabel.textAlignment = .center
        tapToStartLabel.frame = view.bounds
        view.addSubview(tapToStartLabel)

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(startMainGame))
        view.addGestureRecognizer(tapGesture)
    }

    @objc func startMainGame() {
        let gameVC = GameViewController()
        gameVC.isDebugMode = isDebugMode
        gameVC.modalPresentationStyle = .fullScreen
        present(gameVC, animated: true, completion: nil)
    }
}

/*
import UIKit
import AVKit
import AVFoundation
import CoreMotion
import MediaPlayer

class GameViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    
    var isQRCodeDetected = false
    
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    
    var isDebugMode = false
    var isQRCodeVisible: Bool = false// QRコードが見えているかのフラグ
    var qrCodeLostTimer: Timer? // QRコードが見えなくなった時のタイマー
    var isSuctionMode = false // 吸い取りモードかどうかのフラグ
    var detectedQRCodeType: String?
        
    var qrCodestring: String?
    var initialVolume: Float = 0.5
    let audioSession = AVAudioSession.sharedInstance()
    
    var captureSession: AVCaptureSession!
    
    var previewLayer: AVCaptureVideoPreviewLayer!
    public let client = TCPClient(host: "10.202.253.246", port: 8080)

    let motionManager = CMMotionManager()
    
    var player: AVPlayer!
    var playerLayer: AVPlayerLayer?
    var playerViewController: AVPlayerViewController!
    
    var ghostImageView: UIImageView!
    var lightImageView: UIImageView!
    
    var lastShakeTime: TimeInterval = 0
    let shakeThreshold: Double = 1.3 //加速度のしきい値
    let cooldownPeriod: TimeInterval = 0.5
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
        setupImageViews()
        setupTouchGesture()
        
        view.backgroundColor = .black
        preloadVideo(named: "vacuum.mp4")
        startConnection()
        sendToUnity(sendnum: -1)

        lightImageView.isHidden = false
    }
/*
    func sendToUnity(sendnum: Int) {
        client.send(data: String(sendnum).data(using: .utf8)!)
        
    }
  */
    func sendToUnity(sendnum: Int) {
        guard !hasSentData else { return }  // 既に送信済みの場合は処理をスキップ
        
        let data = String(sendnum).data(using: .utf8)!
        do {
            try client.start(data: data)
            print("Data sent successfully: \(sendnum)")
            hasSentData = true  // 送信フラグを設定
        } catch {
            print("Failed to send data: \(error.localizedDescription)")
        }
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
          
          // light.png の UIImageView を作成
          lightImageView = UIImageView(image: UIImage(named: "light"))
          lightImageView.contentMode = .scaleAspectFit
          lightImageView.translatesAutoresizingMaskIntoConstraints = false
          view.addSubview(lightImageView)
          
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
    
    func setupTouchGesture() {
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(handleScreenTap))
        view.addGestureRecognizer(tapGesture)
    }
    
    @objc func handleScreenTap() {
        if isSuctionMode || (player.rate > 0.0 || (player?.rate ?? 0.0) > 0.0) {
            return
        }//吸い取りモード中やQRコードがない場合は無視
        if let qrCodestring = self.qrCodestring, detectedQRCodeType == "ghost" {
            print("画面がタッチされ、吸い込みモードに移行します")
            startSuctionMode()
        }
    }
    
    func handleRemoteButtonPress() {
           if isSuctionMode || (player.rate > 0.0 || (player?.rate ?? 0.0) > 0.0) {
               return
           }
        if let qrCodestring = self.qrCodestring, detectedQRCodeType == "ghost" {
            print("リモコンのボタンが押され、吸い込みモードに移行します")
            startSuctionMode()
        }
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
        ghostImageView.image = image
        ghostImageView.isHidden = false
        lightImageView.isHidden = true
        
    }
    
    func hideQRCodeImage(){
        ghostImageView.isHidden = true
        ghostImageView.image = nil
        lightImageView.isHidden = false
    }
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        // 吸い取りモード中、ダミー操作中はQRコードの処理をしない
        if isSuctionMode { return }
        
        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject,
                  let stringValue = readableObject.stringValue,
                  let qrCodeNumber = Int(stringValue) else {
                handleQRCodeLost()
                return
            }
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            lightImageView.isHidden = true
            
            // QRコードが読み取れたので、処理を実行
            handleQRCodeDetected(qrCodeNumber: qrCodeNumber)
        } else {
            handleQRCodeLost()
            lightImageView.isHidden = false
        }
    }
    
    func handleQRCodeDetected(qrCodeNumber: Int) {
        self.qrCodestring = "\(qrCodeNumber)"
        
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
                
            }
        }
    }
        // QRコードを見失った際のタイマーを無効化（見えている間はリセット）
        qrCodeLostTimer?.invalidate()
        qrCodeLostTimer = nil
    }
    
    
    
    
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
                enterSuctionMode()
            }
        }
    }

    func startSuctionMode() {
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
        if currentRate < 3.0{
            player.rate = min(currentRate + 0.5, 3.0)
        }
    }



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

    func waitForTouchToStartGame() {
        // タップ待機のメッセージ表示
        let tapToStartLabel = UILabel()
        tapToStartLabel.text = "タッチしてゲームを始める"
        tapToStartLabel.font = UIFont.systemFont(ofSize: 24)
        tapToStartLabel.textColor = .white
        tapToStartLabel.textAlignment = .center
        tapToStartLabel.frame = view.bounds
        view.addSubview(tapToStartLabel)

        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(startMainGame))
        view.addGestureRecognizer(tapGesture)
    }

    @objc func startMainGame() {
        let gameVC = GameViewController()
        gameVC.isDebugMode = isDebugMode
        gameVC.modalPresentationStyle = .fullScreen
        present(gameVC, animated: true, completion: nil)
    }
}
 */
