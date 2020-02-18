//
//  RequestConfiguration.swift
//  Pods
//
//  Created by Admin on 10/11/2016.
//
//

import UIKit


var defaultTimeOut = 3.0
var defaultRetryCount = 4

@objc public class RequestConfiguration: NSObject {

    public var readTimeOut: Double = defaultTimeOut
    public var writeTimeOut: Double = defaultTimeOut
    public var connectTimeOut: Double = defaultTimeOut
    @objc public var retryCount: Int = defaultRetryCount
    @objc public var ignoreLocalCache: Bool = false
}
