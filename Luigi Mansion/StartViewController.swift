//
//   StartViewController.swift
//  Luigi Mansion
//
//  Created by rikuya on 2024/10/14.
//

import UIKit

class StartViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        setupStartButton()
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

    @objc func startGame() {
        // チュートリアルモードへ移行
        let tutorialVC = TutorialViewController()
        tutorialVC.modalPresentationStyle = .fullScreen
        present(tutorialVC, animated: true, completion: nil)
    }
}
