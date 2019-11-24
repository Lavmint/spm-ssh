import XCTest
@testable import SSH

final class SSHTests: XCTestCase {

    func testExample() {
        
        //Change to your own settings
        
        let ssh = SSH()
        ssh.session.host.set(value: "localhost")
        ssh.session.port.set(value: 22)
        ssh.session.user.set(value: "user")
        
        do {
            try ssh.session.execute(command: "open /Applications/Safari.app", password: "password")
        } catch {
            XCTFail(error.localizedDescription)
        }
    }

    static var allTests = [
        ("testExample", testExample),
    ]
    
}
