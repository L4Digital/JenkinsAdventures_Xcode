//
//  JenkinsAdventuresUITests.swift
//  JenkinsAdventuresUITests
//
//  Created by Brett McGinnis on 1/27/17.
//  Copyright © 2017 L4 Digital. All rights reserved.
//

import XCTest

class JenkinsAdventuresUITests: XCTestCase {

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        XCUIApplication().launch()
    }
    
    func testExample() {
        XCUIApplication().children(matching: .window).element(boundBy: 0).children(matching: .other).element.tap()
    }
}
