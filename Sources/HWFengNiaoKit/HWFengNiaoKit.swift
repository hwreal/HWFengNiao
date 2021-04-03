import Foundation
import PathKit
import Rainbow

enum FileType {
    case swift
    case objc
    case xib
    
    init?(ext: String) {
        switch ext.lowercased() {
        case "swift": self = .swift
        case "m","mm": self = .objc
        case "xib","storyboard": self = .xib
        default: return nil
        }
    }
    
    func serarcher(extensions: [String]) -> StringSearcher{
        switch self {
        case .swift:
            return SwiftSearcher(extensions: extensions)
        case .objc:
            return ObjcSearcher(extensions: extensions)
        case .xib:
            return XibSearcher(extensions: extensions)
        }
    }
}

public struct FileInfo{
    public let path:Path
    public let size: Int
    
    init(path: String) {
        self.path = Path(path)
        self.size = self.path.size
    }
}

extension Path{
    var size: Int{
        if isDirectory{
            let childredPaths = try? children()
            return (childredPaths ?? []).reduce(0) { $0 + $1.size}
        }else{
            if lastComponent.hasPrefix(".") { return 0 }
            let attribute = try? FileManager.default.attributesOfItem(atPath: absolute().string)
            if let num = attribute?[.size] as? NSNumber{
                return num.intValue
            }else{
                return 0
            }
        }
    }
}

public enum FengNiaoKitError: Error{
    case noResourceExtension
    case noFileExtension
}

public struct FengNiao {
    let projectPath: Path
    let excludePaths: [Path]
    let resourceExtensions: [String]
    let fileExtensions: [String]
    
    public init(projectPath: String, excludedPaths: [String], resourceExtensions: [String], fileExtensions: [String]) {
        let path = Path(projectPath).absolute()
        self.projectPath = path
        self.excludePaths = excludedPaths.map{ path + Path($0) }
        self.resourceExtensions = resourceExtensions
        self.fileExtensions = fileExtensions
    }
    
    public func unusedResource() throws -> [FileInfo]{
        guard !resourceExtensions.isEmpty else {
            throw FengNiaoKitError.noResourceExtension
        }
        
        guard !fileExtensions.isEmpty else {
            throw FengNiaoKitError.noFileExtension
        }
        
        let resources = allResources()
        let allString = allStringInUse()
        return FengNiao.filterUnused(from: resources, used: allString).map{FileInfo(path: $0)}
    }
    
    static func filterUnused(from all:[String: String], used: Set<String>) -> Set<String> {
        let unusedPairs = all.filter { (key,value) in
            return !used.contains(key) &&
                !used.contains{ $0.similarPatternWithNumberIndex(other: key)}
        }
        return Set(unusedPairs.map{$0.value})
    }
    
    func allStringInUse() -> Set<String>{
        return stringInUse(at: projectPath)
    }
    
    func stringInUse(at path: Path) -> Set<String>{
        guard let subPaths = try? path.children() else {
            print("Path reading error.".red)
            return []
        }
        
        var result = [String]()
        for subPath in subPaths{
            if subPath.lastComponent.hasPrefix("."){
                continue
            }
            
            if excludePaths.contains(subPath){
                continue
            }
            
            if subPath.isDirectory {
                result.append(contentsOf: stringInUse(at: subPath))
            }else{
                let fileExt = subPath.extension ?? ""
                guard fileExtensions.contains(fileExt) else {
                    continue
                }
                
                let searcher: StringSearcher
                if let fileType = FileType(ext: fileExt){
                    searcher = fileType.serarcher(extensions: fileExtensions)
                }else{
                    searcher = GeneralSearcher(extensions: fileExtensions)
                }
                
                let content = (try? subPath.read()) ?? ""
                result.append(contentsOf: searcher.search(in: content))
            }
        }
        return Set(result)
    }
    
    
    func allResources() -> [String: String]{
        guard let process = ExtensionFindProcess(path: projectPath, extensions: resourceExtensions, excluded: excludePaths) else {
            return [:]
        }
        let found = process.execute()
        
        var files = [String: String]()
        
        let regularDirExtensions = ["imageset","launchimage","appiconset", "bundle"]
        let nonDirExtensions = resourceExtensions.filter{ !resourceExtensions.contains($0)}
        
        
        fileloop: for file in found{
            let dirPath = regularDirExtensions.map{ ".\($0)/" }
            for dir in dirPath where file.contains(dir) {
                continue fileloop
            }
            
            
            let filePath = Path(file)
            if let ext = filePath.extension, filePath.isDirectory && nonDirExtensions.contains(ext){
                continue
            }
            
            let key = file.plainName(extensions: resourceExtensions)
            if let exiting = files[key]{
                print("Found a duplicated file key:\(key). Exiting:\(exiting)".yellow.bold)
            }
            
            files[key] = file
        }
        return files
    }
    
    // Return a failed list of deleting
    static public func delete(_ unusedFiles: [FileInfo]) -> (deleted: [FileInfo], failed :[(FileInfo, Error)]) {
        var deleted = [FileInfo]()
        var failed = [(FileInfo, Error)]()
        for file in unusedFiles {
            do {
                try file.path.delete()
                deleted.append(file)
            } catch {
                failed.append((file, error))
            }
        }
        return (deleted, failed)
    }
}


