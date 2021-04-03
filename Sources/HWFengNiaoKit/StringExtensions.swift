//
//  StringExtensions.swift
//  HWFengNiaoKit
//
//  Created by 黄威 on 2021/4/2.
//

import Foundation
import PathKit

let digitalRex = try! NSRegularExpression(pattern: "(\\d+)", options: .caseInsensitive)


extension String{
    var fullRange: NSRange{
        return NSMakeRange(0, utf16.count)
    }
    
    func plainName(extensions:[String]) -> String{
        let p = Path(self.lowercased())
        let result: String
        if let ext = p.extension, extensions.contains(ext) {
            result = p.lastComponentWithoutExtension
        }else{
            result = p.lastComponent
        }
        
        var r = result
        if r.hasSuffix("@2x") || r.hasSuffix("@3x") {
            let endIndex = result.index(result.endIndex, offsetBy: -3)
            r = String(result[..<endIndex])
        }
        return r
        
    }
    
    
    
    
    func similarPatternWithNumberIndex(other: String) -> Bool {
        // self -> pattern "image%02d"
        // other -> name "image01"
        let matches = digitalRex.matches(in: other, options: [], range: other.fullRange)
        // No digital found in resource key.
        guard matches.count >= 1 else { return false }
        let lastMatch = matches.last!
        let digitalRange = lastMatch.range(at: 1)
        
        var prefix: String?
        var suffix: String?
        
        let digitalLocation = digitalRange.location
        if digitalLocation != 0 {
            let index = other.index(other.startIndex, offsetBy: digitalLocation)
            prefix = String(other[..<index])
        }
        
        let digitalMaxRange = NSMaxRange(digitalRange)
        if digitalMaxRange < other.utf16.count {
            let index = other.index(other.startIndex, offsetBy: digitalMaxRange)
            suffix = String(other[index...])
        }
        
        switch (prefix, suffix) {
        case (nil, nil):
            return false // only digital
        case (let p?, let s?):
            return hasPrefix(p) && hasSuffix(s)
        case (let p?, nil):
            return hasPrefix(p)
        case (nil, let s?):
            return hasSuffix(s)
        }
    }
    
    
}
