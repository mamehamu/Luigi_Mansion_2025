//
//  QRCodeScanner.swift
//  Luigi Mansion
//
//  Created by rikuya on 2024/10/14.
//

import AVFoundation
import UIKit
import CoreMotion

class QRCodeScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .landscape
    }

    override var shouldAutorotate: Bool {
        return false
    }
    
    // カメラ関連
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    
    // ゲームと吸い取りモード関連
    var isQRCodeDetected = false
    var isSuctionMode = false
    var exterminatedCount = 0
    let maxExterminationCount = 5
    var remainingTime = 180
    var suctionDuration: TimeInterval = 10.0
    var gameTimer: Timer?
    let motionManager = CMMotionManager()
    
    // UI要素
    var ghostImageView: UIImageView!
    var suctionButton: UIButton!
    var startButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
        setupGhostImageView()
        setupButtons()
        setupAccelerometerUpdates()
    }
    
    // カメラの設定
    func setupCamera() {
        captureSession = AVCaptureSession()
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else { return }
        let videoInput: AVCaptureDeviceInput
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            return
        }
        
        if (captureSession.canAddInput(videoInput)) {
            captureSession.addInput(videoInput)
        } else {
            return
        }
        
        let metadataOutput = AVCaptureMetadataOutput()
        
        if (captureSession.canAddOutput(metadataOutput)) {
            captureSession.addOutput(metadataOutput)
            
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            return
        }
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        captureSession.startRunning()
    }
    
    // QRコードがスキャンされたときの処理
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if let metadataObject = metadataObjects.first {
            guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
            guard let stringValue = readableObject.stringValue else { return }
            AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
            print("Scanned QR Code: \(stringValue)")
            // 吸い取りボタンを表示
            DispatchQueue.main.async {
                // 吸い取りモードに移行するためのボタンを表示
                self.suctionButton.isHidden = false
                // お化けの表示はQRコードがスキャンされた後のみ
                self.ghostImageView.isHidden = false
            }
        }
    }
    
    // おばけの画像の設定
    func setupGhostImageView() {
        ghostImageView = UIImageView(image: UIImage(named: "ghost"))
        ghostImageView.contentMode = .scaleAspectFit
        ghostImageView.frame = CGRect(x: (view.bounds.width - 300) / 2, y: (view.bounds.height - 300) / 2, width: 300, height: 300)
        ghostImageView.isHidden = true
        view.addSubview(ghostImageView)
    }
    
    func resetGhostImageView() {
        // ここでおばけの画像の初期化や位置を設定する処理を追加
        ghostImageView.transform = .identity // スケールを元に戻す
        ghostImageView.alpha = 1.0 // 不透明度を元に戻す
    }
    
    // 吸い込みモード関連ボタンのセットアップ
    func setupButtons() {
        suctionButton = createButton(title: "吸い取り開始", action: #selector(suctionButtonTapped))
        startButton = createButton(title: "ゲームスタート", action: #selector(startGame))
        startButton.isHidden = false
    }
    
    func createButton(title: String, action: Selector) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.addTarget(self, action: action, for: .touchUpInside)
        button.frame = CGRect(x: 50, y: 50, width: 200, height: 50)
        view.addSubview(button)
        return button
    }
    
    // 吸い込みモード開始
    @objc func suctionButtonTapped() {
        guard !isSuctionMode else { return }
        startSuctionMode()
    }
    
    func startSuctionMode() {
        isSuctionMode = true
        suctionButton.isHidden = true
        resetGhostImageView()
        ghostImageView.isHidden = false
        startSuctionTimer()
    }
    
    // 吸い込み完了処理
    func endSuctionMode() {
        isSuctionMode = false
        suctionButton.isHidden = true
        ghostImageView.isHidden = true
        exterminatedCount += 1
        // ゲーム終了のチェック
        if exterminatedCount >= maxExterminationCount {
            endGame(win: true)
        } else {
            // 再びQRコードスキャンを有効にする
            captureSession.startRunning()
        }
    }
    
    // 吸い込み時間の管理
    func startSuctionTimer() {
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
            guard self.isSuctionMode else {
                timer.invalidate()
                return
            }
            self.ghostImageView.transform = CGAffineTransform(scaleX: CGFloat(self.suctionDuration / 10.0), y: CGFloat(self.suctionDuration / 10.0))
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + suctionDuration) {
            if self.isSuctionMode { self.endSuctionMode() }
        }
    }
    
    // ゲーム開始
    @objc func startGame() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.startButton.isHidden = true
            self.startGameTimer()
        }
    }
    
    // ゲームタイマー開始
    func startGameTimer() {
        gameTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.remainingTime -= 1
            if self?.remainingTime == 0 { self?.endGame(win: false) }
        }
    }
    
    // ゲーム終了
    func endGame(win: Bool) {
        gameTimer?.invalidate()
        let result = win ? "ゲームクリア" : "ゲームオーバー"
        print(result)
    }
    
    // 加速度センサの設定
    func setupAccelerometerUpdates() {
        if motionManager.isAccelerometerAvailable {
            motionManager.startAccelerometerUpdates(to: OperationQueue.main) { (data, error) in
                guard let data = data else { return }
                let acceleration = sqrt(data.acceleration.x * data.acceleration.x + data.acceleration.y * data.acceleration.y + data.acceleration.z * data.acceleration.z)
                if acceleration > 1.1 && self.isSuctionMode {
                    self.suctionDuration = max(1.0, self.suctionDuration - 0.5)
                    print("吸い込み時間短縮: \(self.suctionDuration)")
                }
            }
        }
    }
}
