//
//  HWFengNiaoSpec.swift
//  HWFengNiaoTests
//
//  Created by 黄威 on 2021/4/2.
//

import Foundation
import Spectre
@testable import HWFengNiaoKit
import PathKit

public func specFengNiaoKit(){
describe("HWFengNiaoKit") {
    
    let fixtures = Path(#file).parent().parent() + "Fixtures"

    
    $0.describe("StringExtension") {
        $0.it("should return plain name") {
            let s1 = "image@2x.tmp"
            let s2 = "/usr/local/bin/find"
            let s3 = "a/image@3X.png"
            let s4 = "local.host"
            let s5 = "local.host.png"
            
            let exts = ["png"]
            try expect(s1.plainName(extensions: exts)) == "image@2x.tmp"
            try expect(s2.plainName(extensions: exts)) == "find"
            try expect(s3.plainName(extensions: exts)) == "image"
            try expect(s4.plainName(extensions: exts)) == "local.host"
            try expect(s5.plainName(extensions: exts)) == "local.host"
        }
        
        $0.it("should filter similar pattern string") {
            
            let s1 = "suffix_1"
            let s1_pattern = "suffix_%d"
            try expect(s1_pattern.similarPatternWithNumberIndex(other: s1)).beTrue()
            
            
            let s2 = "1_prefix"
            let s2_pattern = "\\(i)_prefix"
            try expect(s2_pattern.similarPatternWithNumberIndex(other: s2)).beTrue()
            
            
            let s3 = "1_prefix"
            let s3_pattern = "\\(i)_prefix"
            try expect(s3_pattern.similarPatternWithNumberIndex(other: s3)).beTrue()

        }
    }
    
    $0.describe("String Searcher") {
        $0.it("Swift Searcher works") {
            let content = "[UIImage imageName:@\"hello\"]\nNSString *imageName = @\"world@2x\"\n[[NSBundle mainBundle] pathForResource:@\"foo/bar/aaa\" ofType:@\"png\"]"
            let searcher = SwiftSearcher(extensions: ["png"])
            let result = searcher.search(in: content)
            let expected: Set<String> = ["hello", "world", "aaa", "png"]
            try expect(result) == expected
            
            let s5 = "\"local.host\""
            let s5Ret = searcher.search(in: s5)
            let ex = Set(["local.host"])
            try expect(s5Ret) == ex
            
        }
        
        $0.it("Objc Searcher works") {
            
        }
    }
    
    $0.describe("FengNiaoKit Function") {
        
        $0.it("should find used strings in Swift") {
            let path = fixtures + "FileStringSearcher"
            let fengniao = FengNiao(projectPath: path.string, excludedPaths: [], resourceExtensions: ["png","jpg"], fileExtensions: ["swift"])
            let result = fengniao.allStringInUse()
            let expected: Set<String> = ["common.login",
                                         "common.logout",
                                         "live_btn_connect",
                                         "live_btn_connect",
                                         "name-key",
                                         "无法支持"]
            try expect(result) == expected
        }
        
        $0.it("can find all resources in project") {
            let path = fixtures + "FindProcess"
            let fengniao = FengNiao(projectPath: path.string, excludedPaths: ["Ignore","ignore.jpg"], resourceExtensions: ["png","jpg","imageset"], fileExtensions: [])
            let result = fengniao.allResources()
            //print("ressss:\n\(result)\n\n")
        }
        
//        $0.it("should not filter similar pattern") {
//            let all: [String: Set<String>] = [
//                "face": ["face.png"],
//                "image01": ["image01.png"],
//                "image02": ["image02.png"],
//                "image03": ["image03.png"],
//                "1_set": ["001_set.jpg"],
//                "2_set": ["002_set.jpg"],
//                "3_set": ["003_set.jpg"],
//                "middle_01_bird": ["middle_01_bird@2x.png"],
//                "middle_02_bird": ["middle_02_bird@2x.png"],
//                "middle_03_bird": ["middle_03_bird@2x.png"],
//                "suffix_1": ["suffix_1.jpg"],
//                "suffix_2": ["suffix_2.jpg"],
//                "suffix_3": ["suffix_3.jpg"],
//                "unused_1": ["unused_1.png"],
//                "unused_2": ["unused_2.png"],
//                "unused_3": ["unused_3.png"],
//            ]
//            let used: Set<String> = ["image%02d", "%d_set", "middle_%d_bird","suffix_"]
//            let result = FengNiao.filterUnused(from: all, used: used)
//            let expected: Set<String> = ["face.png", "unused_1.png", "unused_2.png", "unused_3.png"]
//            try expect(result) == expected
//        }
        
    }
    
    
    $0.describe("FindProcess") {
        $0.it("should find correct files") {
            let path = fixtures + "FindProcess"
            let process = ExtensionFindProcess(path: path, extensions: ["png","jpg","imageset"], excluded: ["Ignore"])
            let result = process?.execute() ?? []
            let expected: Set<String> = []
            
            //print("ssss:\n\n\(result)\n\n")
            
            //try expect(result) == expected
            
        }
    }
}}
