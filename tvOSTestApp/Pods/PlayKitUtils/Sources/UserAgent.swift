//
//  UserAgent.swift
//  PlayKitUtils
//
//  Created by Noam Tamim on 29/05/2019.
//

import Foundation

public class UserAgent {
    
    // Sample user agents:
    // iPhone:      "iPhone; CPU iPhone OS 12_2 like Mac OS X"
    // iPad:        "iPad; CPU OS 12_2 like Mac OS X"
    // Apple TV:    "Apple TV; CPU OS 12_3 like Mac OS X"

    // The returned string is "$clientTag $appName/$appVersion ($platformUserAgent)"
    // Example: "playkit/ios-3.2.1 MyApp/1.2.3 (iPhone; CPU iPhone OS 12_2 like Mac OS X)"
    public static func build(clientTag: String) -> String {
        let model = UIDevice.current.model
        
        // For iPhone ONLY, the OS is "iPhone OS"; for the rest it's just "OS".
        let osName = model == "iPhone" ? "iPhone OS" : "OS"
        
        // Dots in the version are replaced by underscores
        let osVersion = UIDevice.current.systemVersion.replacingOccurrences(of: ".", with: "_")
        
        // Add the app name and version like in the default URLSession user agent
        let appName = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") ?? "Unknown"
        let appVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") ?? "0.0"
        
        return "\(clientTag) \(appName)/\(appVersion) (\(model); CPU \(osName) \(osVersion) like Mac OS X)"
    }
}
