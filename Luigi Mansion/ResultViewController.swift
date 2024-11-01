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
        
        let data = "-10".data(using: .utf8)!
        TCPClient.shared.start(data: data)
        
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
        
        // 退治数と残り時間のラベルを表示
        let detailLabel = UILabel(frame: CGRect(x: 0, y: 150, width: view.bounds.width, height: 50))
        detailLabel.textAlignment = .center
        detailLabel.font = UIFont.systemFont(ofSize: 20)
        detailLabel.text = "退治数: \(exterminatedCount), 残り時間: \(remainingTime)秒"
        view.addSubview(detailLabel)
        
        // 一定時間後にチュートリアルモードに戻る
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
            
            self.resetGame()
            self.returnToTutorial()
        }
    }
    
    func returnToTutorial() {
        let tutorialVC = TutorialViewController()
        tutorialVC.modalPresentationStyle = .fullScreen
        present(tutorialVC, animated: true, completion: nil)
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
    func resetGame() {
        // 退治数、タイマー、QRコード配列などゲームの状態をリセット
        exterminatedCount = 0
        remainingTime = 180 // 3分にリセット
        
        // QRコードの配列をリセットし、シャッフル
        let gameVC = GameViewController()
        gameVC.gameArray = ["dummy", "dummy", "ghost", "ghost", "ghost", "ghost", "ghost"].shuffled()
    }
}
