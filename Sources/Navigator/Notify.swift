//
//  File.swift
//  
//
//  Created by Nick Groenke on 8/26/24.
//


// https://github.com/abseil/abseil-cpp/blob/master/absl/synchronization/notification.h

import Foundation

actor Notify {
    private var notified: Bool = false
    private var subscribers: [CheckedContinuation<Void, Never>] = []
    
    func waitForNotification() async {
        await withCheckedContinuation { continuation in
            addSubscriber(continuation: continuation)
        }
    }
    
    func notify() {
        if notified { return }
        notified = true
        for continuation in subscribers {
            continuation.resume()
        }
        subscribers.removeAll()
    }
    
    private func addSubscriber(continuation: CheckedContinuation<Void, Never>) {
        if (notified) {
            continuation.resume()
        } else {
            subscribers.append(continuation)
        }
    }
}
