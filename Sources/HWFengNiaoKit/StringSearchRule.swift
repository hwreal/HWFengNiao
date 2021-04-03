//
//  StringSearchRule.swift
//  HWFengNiaoKit
//
//  Created by 黄威 on 2021/4/2.
//

import Foundation

protocol StringSearcher {
    func search(in content: String) -> Set<String>
}

protocol RegexStringSearcher: StringSearcher {
    var extensions:[String] { get }
    var patterns:[String] { get }
}

extension RegexStringSearcher{
    func search(in content: String) -> Set<String> {
        
        var result = Set<String>()
        
        for pattern in patterns{
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
                print("Failed to create regular expression: \(pattern)")
                continue
            }
            
            let matches = regex.matches(in: content, options: [], range: content.fullRange)
            for checkingResult in matches {
                let range = checkingResult.range(at: 1)
                let extracted = NSString(string: content).substring(with: range)
                result.insert(extracted.plainName(extensions: extensions))
                
            }
        }
        return result
    }
}

struct SwiftSearcher: RegexStringSearcher {
    let extensions: [String]
    let patterns: [String] = ["\"(.+?)\""]
}

struct ObjcSearcher: RegexStringSearcher {
    let extensions: [String]
    let patterns: [String] = ["@\"(.+?)\"","\"(.+?)\""]
}

struct XibSearcher: RegexStringSearcher {
    let extensions: [String]
    let patterns: [String] = ["image name=\"(.+?)\""]
}

struct GeneralSearcher: RegexStringSearcher {
    let extensions: [String]
    var patterns: [String]{
        if extensions.isEmpty {
            return []
        }
        
        let joined = extensions.joined(separator: "|")
        return ["\" (.+?)\\.(\(joined))\""]
    }
}
