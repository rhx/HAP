import Foundation
import HTTP
import HKDF
import Evergreen

fileprivate let logger = getLogger("encryption")

class UpgradeResponse: Response {
    let cryptographer: Cryptographer
    init(cryptographer: Cryptographer) {
        self.cryptographer = cryptographer
        super.init(status: .ok)
    }
}

class Cryptographer {
    var encryptCount: UInt64 = 0
    var decryptCount: UInt64 = 0
    let decryptKey: Data
    let encryptKey: Data

    init(sharedKey: Data) {
        logger.info("Shared key: \(sharedKey)")
        decryptKey = HKDF.deriveKey(algorithm: .SHA512, seed: sharedKey, info: "Control-Write-Encryption-Key".data(using: .utf8)!, salt: "Control-Salt".data(using: .utf8)!, count: 32)
        encryptKey = HKDF.deriveKey(algorithm: .SHA512, seed: sharedKey, info: "Control-Read-Encryption-Key".data(using: .utf8)!, salt: "Control-Salt".data(using: .utf8)!, count: 32)
    }

    func decrypt(_ data: Data) throws -> Data {

        logger.info("Decrypt message #\(self.decryptCount)")
        logger.info("Data: \(data)")
        guard data.count > 0 else {
            logger.info("No ciphertext")
            return data
        }

        let length = Int(UInt16(data: Data(data[0..<2])))
        precondition(length + 2 + 16 == data.count)

        let nonce = Data(bytes: decryptCount.bigEndian.bytes())
        decryptCount += 1

        let encrypted = data[2..<(2 + length + 16)]
        logger.debug("Ciphertext: \(encrypted), Nonce: \(nonce), Length: \(length)")

        guard let chacha = ChaCha20Poly1305(key: decryptKey, nonce: nonce) else {
            abort()
        }
        guard let response = try? chacha.decrypt(cipher: Data(encrypted), add: Data(data[0..<2])) else {
            abort()
        }

        return response
    }

    func encrypt(_ data: Data) -> Data {
        let nonce = Data(bytes: encryptCount.bigEndian.bytes())
        encryptCount += 1

        let length = Data(UInt16(data.count).bytes.reversed())

        logger.info("Encrypt message: \(self.encryptCount)")
        logger.debug("Message: \(data), Nonce: \(nonce), Length: \(length)")

        guard let chacha = ChaCha20Poly1305(key: encryptKey, nonce: nonce) else { abort() }

        guard let encrypted = try? chacha.encrypt(message: data, add: length) else {
            abort()
        }
        logger.debug("Ciphertext: \(encrypted)")

        return length + encrypted
    }
}

class EncryptionMiddleware: StreamMiddleware {
    init() { }

    func parse(input data: Data, forConnection connection: Connection) -> Data {
        if let cryptographer = connection.context["cryptographer"] as? Cryptographer {
            return try! cryptographer.decrypt(data)
        }

        return data
    }

    func parse(output data: Data, forConnection connection: Connection) -> Data {
        if let cryptographer = connection.context["cryptographer"] as? Cryptographer {
            return cryptographer.encrypt(data)
        }
        if let response = connection.response as? UpgradeResponse {
            connection.context["cryptographer"] = response.cryptographer
        }
        return data
    }
}
