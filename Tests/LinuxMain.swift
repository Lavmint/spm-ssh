import XCTest

import SSHTests

var tests = [XCTestCaseEntry]()
tests += SSHTests.allTests()
XCTMain(tests)
