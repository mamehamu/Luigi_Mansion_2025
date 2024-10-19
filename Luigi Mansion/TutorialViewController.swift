//
//  TutorialViewController.swift
//  Luigi Mansion
//
//  Created by rikuya on 2024/10/14.
//

import UIKit
import AVFoundation

class TutorialViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {

    var isDebugMode = false
    var captureSession: AVCaptureSession!
    var previewLayer: AVCaptureVideoPreviewLayer!
    var isSuctionMode = false
    var ghostImageView: UIImageView!

    override func viewDidLoad() {
        super.viewDidLoad()
        setupCamera()
        setupGhostImageView()
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
