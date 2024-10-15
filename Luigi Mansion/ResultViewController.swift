//
//  ResultViewController.swift
//  Luigi Mansion
//
//  Created by rikuya on 2024/10/14.
//

import UIKit

class ResultViewController: UIViewController {

    var win: Bool = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white

        let resultLabel = UILabel()
        resultLabel.text = win ? "ゲームクリア！" : "ゲームオーバー"
        resultLabel.font = UIFont.boldSystemFont(ofSize: 32)
        resultLabel.textColor = .black
        resultLabel.textAlignment = .center
        resultLabel.frame = view.bounds
        view.addSubview(resultLabel)

        // 一定時間後にチュートリアルモードに戻る
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            self.returnToTutorial()
        }
    }

    func returnToTutorial() {
        let tutorialVC = TutorialViewController()
        tutorialVC.modalPresentationStyle = .fullScreen
        present(tutorialVC, animated: true, completion: nil)
    }
}

