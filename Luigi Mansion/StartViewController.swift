//
//   StartViewController.swift
//  Luigi Mansion
//
//  Created by rikuya on 2024/10/14.
//

import UIKit

class StartViewController: UIViewController {
    
    var isDebugMode = false
    let debugSwitch = UISwitch()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupStartButton()
        setupDebugSwitch()
        view.backgroundColor = .white // 背景色を設定
    }

    func setupStartButton() {
        let startButton = UIButton(type: .system)
        startButton.setTitle("ゲームスタート", for: .normal)
        startButton.titleLabel?.font = UIFont.boldSystemFont(ofSize: 24)
        startButton.addTarget(self, action: #selector(startGame), for: .touchUpInside)
        startButton.frame = CGRect(x: 0, y: 0, width: 200, height: 50)
        startButton.center = view.center
        view.addSubview(startButton)
    }

    func setupDebugSwitch() {
        debugSwitch.isOn = false
        debugSwitch.addTarget(self, action: #selector(toggleDebugMode), for: .valueChanged)
        debugSwitch.frame = CGRect(x: 50, y: view.center.y + 100, width: 0, height: 0)
        view.addSubview(debugSwitch)
        
        let debugLabel = UILabel(frame: CGRect(x: 50, y: view.center.y + 70, width: 200, height: 30))
        debugLabel.text = "デバッグモード"
        view.addSubview(debugLabel)
    }

    @objc func toggleDebugMode() {
        isDebugMode = debugSwitch.isOn
    }
    
    @objc func startGame() {
        // チュートリアルモードへ移行
        let tutorialVC = TutorialViewController()
        tutorialVC.isDebugMode = isDebugMode
        tutorialVC.modalPresentationStyle = .fullScreen
        present(tutorialVC, animated: true, completion: nil)
    }
}
