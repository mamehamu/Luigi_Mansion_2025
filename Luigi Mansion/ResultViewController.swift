//
//  ResultViewController.swift
//  Luigi Mansion
//
//  Created by rikuya on 2024/10/14.
//

import UIKit

class ResultViewController: UIViewController {
    /*
     public let client = TCPClient(host: "10.202.253.246", port: 8080)
     */
    
    var hasSentData = false
    
    var exterminatedCount: Int = 0
    var remainingTime: Int = 0
    var isGameClear: Bool = false
    
    var win: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .white
        
        TCPClient.shared.send(message: "-10")
        
        let resultLabel = UILabel(frame: CGRect(x: 0, y: 100, width: view.bounds.width, height: 50))
        resultLabel.textAlignment = .center
        resultLabel.font = UIFont.boldSystemFont(ofSize: 24)
        
        // クリアかゲームオーバーかを判定してラベルを表示
        if isGameClear {
            resultLabel.text = "ゲームクリア！"
        } else {
            resultLabel.text = "ゲームオーバー"
        }
        view.addSubview(resultLabel)
        
        // 一定時間後にチュートリアルモードに戻る
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            
            self.returnToTutorial()
        }
    }
    
    func returnToTutorial() {
        // 画面スタックをリセットしてチュートリアルに戻る
        // (GameVC -> ResultVC と来ているので、presentingViewController を dismiss する)
                
        // もし StartVC -> TutorialVC -> GameVC -> ResultVC のように重ねている場合
        if let presentingVC = self.presentingViewController?.presentingViewController {
            presentingVC.dismiss(animated: true, completion: nil)
            // これにより TutorialVC に戻る
        } else {
            // フォールバック (StartVC に戻るなど)
            let startVC = StartViewController()
            startVC.modalPresentationStyle = .fullScreen
            present(startVC, animated: true, completion: nil)
        }
    }
}
