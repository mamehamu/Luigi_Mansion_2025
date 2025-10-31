//
//  AppDelegate.swift
//  Luigi Mansion
//
//  Created by ryu on 2025/10/27.
//

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication,
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        window = UIWindow(frame: UIScreen.main.bounds)
        let startVC = StartViewController()
        window?.rootViewController = startVC
        window?.makeKeyAndVisible()
        
        // ▽▽▽ TCP接続を開始 ▽▽▽
        TCPClient.shared.start()
        
        return true
    }
    
    // アプリがバックグラウンドから復帰した時
    func applicationWillEnterForeground(_ application: UIApplication) {
        // TCP接続を再開 (切断されていた場合に備える)
        TCPClient.shared.start()
    }
    
    // アプリ終了時
    func applicationWillTerminate(_ application: UIApplication) {
        TCPClient.shared.stop()
    }
}
