//
//  TCPClient.swift
//  Luigi Mansion
//
//  Created by rikuya on 2024/10/27.
//

import Foundation
import Network



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
