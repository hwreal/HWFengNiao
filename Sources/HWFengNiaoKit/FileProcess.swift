//
//  FileProcess.swift
//  HWFengNiaoKit
//
//  Created by 黄威 on 2021/4/2.
//

import Foundation
import PathKit

class ExtensionFindProcess: NSObject {
    
    let p: Process
    
    init?(path: Path, extensions: [String], excluded: [Path]) {
        p = Process()
        p.launchPath = "/usr/bin/find"
        
        guard !extensions.isEmpty else {
            return nil
        }
        
        var args = [String]()
        args.append(path.string)
        
        for (i, ext) in extensions.enumerated() {
            if i == 0 {
                args.append("(")
            } else {
                args.append("-or")
            }
            args.append("-name")
            args.append("*.\(ext)")
            
            if i == extensions.count - 1 {
                args.append(")")
            }
        }
        
        for excludedPath in excluded {
            let filePath = path + excludedPath
            guard filePath.exists else { continue }
            
            args.append("-not")
            args.append("-path")
            
            if filePath.isDirectory {
                args.append("\(filePath.string)/*")
            } else {
                args.append(filePath.string)
            }
        }
        
        p.arguments = args
    }
    
    convenience init?(path: String, extensions: [String], excluded: [String]) {
        self.init(path: Path(path), extensions: extensions, excluded: excluded.map { Path($0) })
    }
    
    func execute() -> Set<String> {
        let pipe = Pipe()
        p.standardOutput = pipe
        
        let fileHandler = pipe.fileHandleForReading
        p.launch()
        
        let data = fileHandler.readDataToEndOfFile()
        if let string = String(data: data, encoding: .utf8) {
            return Set(string.components(separatedBy: "\n").dropLast())
        } else {
            return []
        }
    }
}
