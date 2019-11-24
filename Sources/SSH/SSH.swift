//
//  SSH.swift
//  STCore
//
//  Created by Alexey Averkin on 21.11.2019.
//  Copyright © 2019 Alexey AVerkin. All rights reserved.
//

import Foundation
import libssh

/// https://api.libssh.org/stable/libssh_tutor_guided_tour.html
/// https://api.libssh.org/stable/group__libssh__session.html

public class SSH {
    
    public let session: ssh_session
    
    public init() {
        self.session = ssh_new()!
    }
    
    deinit {
        ssh_free(session)
    }
}

public extension ssh_session {
    
    struct Property<T> {
        
        public let session: ssh_session
        public let option: ssh_options_e
        
        public init(session: ssh_session, option: ssh_options_e) {
            self.session = session
            self.option = option
        }
        
        public func get() -> T? {
            var pointee: UnsafeMutablePointer<Int8>?
            ssh_options_get(session, option, &pointee)
            guard let p = pointee else {
                return nil
            }
            return UnsafeRawPointer(p).load(as: T.self)
        }
        
        public func set(value: T?) {
            guard var val = value else {
                return
            }
            ssh_options_set(session, option, &val)
        }
        
    }
    
}

public extension ssh_session {
    
    var host: Property<String> {
        return Property(session: self, option: SSH_OPTIONS_HOST)
    }
    
    var port: Property<Int> {
        return Property(session: self, option: SSH_OPTIONS_PORT)
    }
    
    var user: Property<String> {
        return Property(session: self, option: SSH_OPTIONS_USER)
    }
    
    var authenticationByPassword: Property<Bool> {
        return Property(session: self, option: SSH_OPTIONS_PASSWORD_AUTH)
    }
    
    var authenticationByPublicKey: Property<Bool> {
        return Property(session: self, option: SSH_OPTIONS_PUBKEY_AUTH)
    }
    
    var lastErrorCode: Int32 {
        return ssh_get_error_code(UnsafeMutablePointer(self))
    }
    
    var lastError: Error {
        let cErrorDescription = ssh_get_error(UnsafeMutablePointer(self))!
        return SSHError.custom(description: String(cString: cErrorDescription))
    }
    
    func execute(command: String, password: String, sudo: Bool = false) throws {
        do {
            try connect()
            try authenticate(password: password)
            try execute(command: sudo ? "echo \"\(password)\" | sudo -S \(command)" : command)
        } catch {
            ssh_disconnect(self)
            throw error
        }
    }
    
}

private enum SSHError: LocalizedError {
    
    case custom(description: String)
    case retrievePublicKeyFailed
    case retrievePublicKeyHashFailed
    case readError
    case unknown
    
    var errorDescription: String? {
        switch self {
        case .custom(description: let desc):
            return desc
        default:
            return String(describing: self)
        }
    }
}

private extension ssh_session {
    
    func connect() throws {
        guard ssh_connect(self) == SSH_OK else {
            throw lastError
        }
    }
    
    func verifyKnownHost() throws {
        
        var serverPublicKey: ssh_key!
        var hash: UnsafeMutablePointer<UInt8>? = nil
        var hashLength: Int = 0
        
        guard ssh_get_server_publickey(self, &serverPublicKey) >= 0 else {
            throw SSHError.retrievePublicKeyFailed
        }
        
        guard ssh_get_publickey_hash(serverPublicKey, SSH_PUBLICKEY_HASH_SHA1, &hash, &hashLength) >= 0 else {
            ssh_key_free(serverPublicKey)
            throw SSHError.retrievePublicKeyHashFailed
        }
        ssh_key_free(serverPublicKey)
        
        switch ssh_session_is_known_server(self) {
        case SSH_KNOWN_HOSTS_OK:
            break
        case SSH_KNOWN_HOSTS_CHANGED:
            ssh_clean_pubkey_hash(&hash)
            throw lastError
        case SSH_KNOWN_HOSTS_UNKNOWN, SSH_KNOWN_HOSTS_NOT_FOUND:
            let hexa = ssh_get_hexa(hash, hashLength)!
            ssh_string_free_char(hexa)
            ssh_clean_pubkey_hash(&hash)
            ssh_session_update_known_hosts(self)
        case SSH_KNOWN_HOSTS_ERROR:
            ssh_clean_pubkey_hash(&hash)
            throw lastError
        default:
            throw SSHError.unknown
        }
    
    }
    
    func authenticate(password: String) throws {
        try verifyKnownHost()
        guard ssh_userauth_password(self, nil, password) >= 0 else {
            ssh_disconnect(self)
            throw lastError
        }
    }
}

private extension ssh_session {
    
    private func execute(command: String) throws {
        
        guard let channel = ssh_channel_new(self) else {
            throw lastError
        }
        
        guard ssh_channel_open_session(channel) == SSH_OK else {
          ssh_channel_free(channel)
          throw lastError
        }
        
        guard ssh_channel_request_exec(channel, command) == SSH_OK else {
            ssh_channel_close(channel)
            ssh_channel_free(channel)
            throw lastError
        }

        let bsize: UInt32 = 256
        var buffer: CChar = 0
        var nbytes = ssh_channel_read(channel, &buffer, bsize, 0)
        
        while nbytes > 0 {
            let msg = String(cString: &buffer)
            console(msg)
            nbytes = ssh_channel_read(channel, &buffer, bsize, 0)
        }
        
        ssh_channel_close(channel)
        ssh_channel_free(channel)
    }
    
}

private var isDebug: Bool {
    #if DEBUG
    return true
    #else
    return false
    #endif
}

private func console(_ items: Any?...) {
    guard isDebug else { return }
    if let err = items.first as? Error {
        print("⚠️ \(err)")
    } else {
        let itms = items.compactMap({ $0 })
        if itms.count == 1 {
            print(itms.first!)
        } else {
            print(itms)
        }
    }
}
