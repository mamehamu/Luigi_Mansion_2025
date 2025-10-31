//
//  TCPClient.swift
//  Luigi Mansion
//
//  Created by ryu on 2025/10/27.
//

import Foundation
import Network

// Notification名を定義
extension Notification.Name {
    static let tcpMessageReceived = Notification.Name("tcpMessageReceived")
    static let tcpConnectionStatusChanged = Notification.Name("tcpConnectionStatusChanged")
}

enum TCPConnectionStatus {
    case connected
    case disconnected(Error?)
    case connecting
}

class TCPClient {
    static let shared = TCPClient(host: "10.33.165.94", port: 50002) // サーバーのIPとポートに要変更
    //テスト用
    //static let shared = TCPClient(host: "192.168.1.83", port: 50002) // 自宅
    //static let shared = TCPClient(host: "10.33.213.66", port: 50002) //学校
    
    private var host: NWEndpoint.Host
    private var port: NWEndpoint.Port
    private var connection: NWConnection?
    private var isConnecting = false
    private var retryTimer: Timer?
    
    public var currentState: NWConnection.State? {
        return connection?.state
    }

    private init(host: String, port: UInt16) {
        self.host = NWEndpoint.Host(host)
        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            fatalError("無効なポート番号です: \(port)")
        }
        self.port = nwPort
    }

    func start() {
        guard connection == nil, !isConnecting else {
            print("TCPClient: 接続済み、または接続試行中です。")
            return
        }
        
        print("TCPClient: サーバーへ接続を開始します...")
        isConnecting = true
        NotificationCenter.default.post(name: .tcpConnectionStatusChanged, object: TCPConnectionStatus.connecting)
        
        connection = NWConnection(host: host, port: port, using: .tcp)
        
        connection?.stateUpdateHandler = { [weak self] newState in
            guard let self = self else { return }
            
            switch newState {
            case .ready:
                print("TCPClient: サーバーに接続しました。")
                self.isConnecting = false
                self.retryTimer?.invalidate()
                self.retryTimer = nil
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .tcpConnectionStatusChanged, object: TCPConnectionStatus.connected)
                }
                self.receive() // 接続が確立したら受信待機開始
                
            case .failed(let error):
                print("TCPClient: 接続に失敗しました: \(error.localizedDescription)")
                self.handleDisconnect(error: error)
                
            case .waiting(let error):
                print("TCPClient: 接続待機中: \(error.localizedDescription)")
                
            case .cancelled:
                print("TCPClient: 接続がキャンセルされました。")
                self.handleDisconnect(error: nil)

            default:
                break
            }
        }
        
        connection?.start(queue: .global(qos: .userInitiated))
    }

    private func handleDisconnect(error: Error?) {
        isConnecting = false
        connection = nil
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .tcpConnectionStatusChanged, object: TCPConnectionStatus.disconnected(error))
        }
        
        // 5秒後に自動再接続を試みる
        guard retryTimer == nil else { return }
        print("TCPClient: 5秒後に再接続を試みます...")
        DispatchQueue.main.async {
            self.retryTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
                print("TCPClient: 再接続中...")
                self?.retryTimer = nil
                self?.start()
            }
        }
    }

    func stop() {
        retryTimer?.invalidate()
        retryTimer = nil
        connection?.cancel()
        connection = nil
    }

    // メッセージを送信する (末尾に改行コードを追加する例)
    func send(message: String) {
        guard let connection = connection, connection.state == .ready else {
            print("TCPClient: 接続されていません。メッセージを送信できません: \(message)")
            return
        }
        
        // サーバーが改行コードを期待する場合 (不要なら message のみ)
        let messageWithNewline = message + "\n"
        
        guard let data = messageWithNewline.data(using: .utf8) else {
            print("TCPClient: メッセージのエンコードに失敗しました。")
            return
        }
        
        connection.send(content: data, completion: .contentProcessed({ error in
            if let error = error {
                print("TCPClient: 送信エラー: \(error.localizedDescription)")
            } else {
                print("TCPClient: メッセージ送信成功: \(message)")
            }
        }))
    }

    private func receive() {
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] (data, _, isComplete, error) in
            guard let self = self else { return }

            if let data = data, !data.isEmpty {
                if let message = String(data: data, encoding: .utf8) {
                    print("TCPClient: メッセージ受信: \(message)")
                    
                    // 改行などで複数のコマンドが一度に来る場合を考慮
                    let commands = message.split(whereSeparator: \.isNewline)
                    for command in commands {
                        // NotificationCenter を使ってアプリ全体に通知
                        DispatchQueue.main.async {
                            NotificationCenter.default.post(
                                name: .tcpMessageReceived,
                                object: nil,
                                userInfo: ["command": String(command)]
                            )
                        }
                    }
                }
            }

            if isComplete {
                print("TCPClient: サーバーが接続を切断しました。")
                self.connection?.cancel()
            } else if let error = error {
                print("TCPClient: 受信エラー: \(error.localizedDescription)")
                self.connection?.cancel()
            } else {
                // 受信が完了したら、再度受信待機
                self.receive()
            }
        }
    }
}
