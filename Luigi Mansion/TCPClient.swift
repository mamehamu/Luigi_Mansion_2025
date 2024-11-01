//
//  TCPClient.swift
//  Luigi Mansion
//
//  Created by rikuya on 2024/10/27.
//

import Foundation
import Network
/*


class TCPClient {
    
    var connection: NWConnection?
    
    init(host: String, port: UInt16) {
        
        let host = NWEndpoint.Host(host)
        
        let port = NWEndpoint.Port(rawValue: port)!
        
        connection = NWConnection(host: host, port: port, using: .tcp)
        
    }
    
    
    func start(data: Data) {
        
        connection?.stateUpdateHandler = { state in
            
            switch state {
                
            case .ready:
                
                print("Connected to the server")
                
                self.send(data: data)
                //self.receive()
                
            case .failed(let error):
                
                print("Failed to connect: \(error)")
                
            default:
                print("default")
                
                break
                
            }
            
        }
        
        connection?.start(queue: .global())
        
    }
    
    func send(data: Data) {
        
        connection?.send(content: data, completion: .contentProcessed({ error in
            
            if let error = error {
                
                print("Send error: \(error)")
                self.receive()
                
            } else {
                
                print("Data sent successfully")
                
            }
            
        }))
        
    }
    
    func receive() {
        
        connection?.receive(minimumIncompleteLength: 1, maximumLength: 65536) { data, _, isComplete, error in
            
            if let data = data, !data.isEmpty {
                
                let message = String(data: data, encoding: .utf8)
                
                print("Received message: \(message ?? "N/A")")
                
            }
            
            if isComplete {
                
                print("Connection closed")
                
                self.connection?.cancel()
                
            } else if let error = error {
                
                print("Receive error: \(error)")
                
            } else {
                
                self.receive() // Continue receiving data
                
            }
            
        }
        
    }
    func stop() {
        
        connection?.cancel()
        
    }
}
*/
/*
class TCPClient {
    
    static let shared = TCPClient(host: "10.202.253.246" ,port: 8080)

    
    var host: String
    var port: UInt16
    
    init(host: String, port: UInt16) {
        self.host = host
        self.port = port
    }
    
    func startAndSend(data: Data) {
        let connection = NWConnection(host: NWEndpoint.Host(self.host), port: NWEndpoint.Port(rawValue: self.port)!, using: .tcp)
        
        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                print("Connected to the server")
                connection.send(content: data, completion: .contentProcessed { error in
                    if let error = error {
                        print("Send error: \(error)")
                    } else {
                        print("Data sent successfully")
                    }
                    connection.cancel()  // データ送信後に接続を閉じる
                })
            case .failed(let error):
                print("Failed to connect: \(error)")
            default:
                break
            }
        }
        
        connection.start(queue: .global())
    }
}
 */
class TCPClient {
 static let shared = TCPClient(host: "127.0.0.1", port: 12345) // 例としてローカルホストとポートを指定

 private var connection: NWConnection?
 private var host: String
 private var port: UInt16
 
 private init(host: String, port: UInt16) {
     self.host = host
     self.port = port
     createConnection()
 }
 
 private func createConnection() {
     let host = NWEndpoint.Host(self.host)
     let port = NWEndpoint.Port(rawValue: self.port)!
     connection = NWConnection(host: host, port: port, using: .tcp)
 }
 
 func start(data: Data) {
     connection?.stateUpdateHandler = { state in
         switch state {
         case .ready:
             print("Connected to the server")
             self.send(data: data)
         case .failed(let error):
             print("Failed to connect: \(error)")
         default:
             break
         }
     }
     
     connection?.start(queue: .global())
 }
 
 func send(data: Data) {
     connection?.send(content: data, completion: .contentProcessed({ error in
         if let error = error {
             print("Send error: \(error)")
         } else {
             print("Data sent successfully")
         }
     }))
 }
 
 func stop() {
     connection?.cancel()
 }
}
