//
//  GameViewController.swift
//  Luigi Mansion
//
//  Created by rikuya on 2024/10/14.
//

import UIKit
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
        view.backgroundColor = .black
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
         ghostImageView.contentMode = .scaleAspectFit
         ghostImageView.frame = CGRect(x: (view.bounds.width - 300) / 2,
                                       y: (view.bounds.height - 300) / 2,
                                       width: 300,
                                       height: 300)
         ghostImageView.isHidden = true
         view.addSubview(ghostImageView)
         
         // Dummy ImageView の設定
         dummyImageView = UIImageView(image: UIImage(named: "dummy"))
         dummyImageView.contentMode = .scaleAspectFit
         dummyImageView.frame = CGRect(x: (view.bounds.width - 300) / 2,
                                       y: (view.bounds.height - 300) / 2,
                                       width: 300,
                                       height: 300)
         dummyImageView.isHidden = true
         view.addSubview(dummyImageView)
         
         // 現在のQRコードの画像ビュー（ghostかdummyが表示される）
         currentQRCodeImageView = UIImageView()
         currentQRCodeImageView.contentMode = .scaleAspectFit
         currentQRCodeImageView.frame = CGRect(x: (view.bounds.width - 300) / 2,
                                               y: (view.bounds.height - 300) / 2,
                                               width: 300,
                                               height: 300)
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
        } else {
            print("画面がタッチされましたが、dummyです")
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
                startDummyMode() // dummyの場合は自動的に操作不能モード
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
    
    // 吸い取りモードを開始する
    func startSuctionMode() {
        isSuctionMode = true
        ghostImageView.isHidden = false
        hideQRCodeImage()
        // QRコードの画像を非表示にする
        print("吸い込みモードに入りました")
        
        // 画面の色を白にして吸い込みモードを示す
        view.backgroundColor = .white
        
        // QRコードの読み取りを一時停止
        stopQRCodeScanning()
        
        // モーションデータを開始して、スマホを振ることで吸い込み速度を調整
        motionManager.startAccelerometerUpdates(to: OperationQueue.current!) { [weak self] (data, error) in
            guard let data = data, error == nil else { return }
            let acceleration = sqrt(pow(data.acceleration.x, 2) + pow(data.acceleration.y, 2) + pow(data.acceleration.z, 2))
                   
            if acceleration > 1.5 { // 振りのしきい値を設定（この値は調整可能）
                print("スマホを振りました！吸い込み速度が上がります")
                self?.suctionDuration -= 1.0 // 吸い込み時間を短縮
            }
        }
        
        // 吸い込みが完了した後、QRコードの読み取りを再開
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.endSuctionMode()
        }
    }
    
    func endSuctionMode() {
        isSuctionMode = false
        ghostImageView.isHidden = true
        print("吸い込みモードが終了しました")
        // 吸い込みモードが終了したら背景色を黒に戻す
        view.backgroundColor = .black
                
        // モーションデータの取得を停止
        motionManager.stopAccelerometerUpdates()
            
        // QRコードリーダーを再開
        captureSession.startRunning()
        
        // QRコード配列を更新し、読み取ったQRコードがdummyに変わる処理
        if let detectedQRCodeType = detectedQRCodeType, let qrCodeNumber = Int(detectedQRCodeType) {
            if detectedQRCodeType == "ghost" {
                gameArray[qrCodeNumber] = "dummy" // 吸い込んだQRコードをdummyに変更
                print("QRコード \(qrCodeNumber) が dummy に変わりました")
            }
        }
        // 再度QRコードの読み取り待機状態に戻す
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
