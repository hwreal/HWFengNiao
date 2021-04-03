import Foundation
import CommandLineKit
import Rainbow
import HWFengNiaoKit

print("Wel...")

let appVersion = "0.7.0"

#if os(Linux)
let EX_OK: Int32 = 0
let EX_USAGE: Int32 = 64
#endif

let cli = CommandLineKit.CommandLine()
cli.formatOutput = { s, type in
    var str: String
    switch(type) {
    case .error: str = s.red.bold
    case .optionFlag: str = s.green.underline
    default: str = s
    }
    
    return cli.defaultFormat(s: str, type: type)
}

let projectOption = StringOption(
    shortFlag: "p", longFlag: "project",
    helpMessage: "Root path of your Xcode project. Default is current folder.")

let excludePathsOption = MultiStringOption(
    shortFlag: "e", longFlag: "exclude",
    helpMessage: "Exclude paths from search.")

let resourceExtensionOption = MultiStringOption(
    shortFlag: "r", longFlag: "resource-extension",
    helpMessage: "Resource file extensions need to be searched. Default is 'imageset jpg png gif pdf'")

let fileExtensionOption = MultiStringOption(
    shortFlag: "f", longFlag: "file-extensions",
    helpMessage: "In which types of files we should search for resource usage. Default is 'm mm swift xib storyboard plist'.")

let help = BoolOption(
    shortFlag: "h", longFlag: "help",
    helpMessage: "Print this help message.")

cli.addOptions([projectOption,excludePathsOption,resourceExtensionOption,fileExtensionOption,help])

do {
    try cli.parse()
}catch {
    cli.printUsage(error)
    exit(EX_USAGE)
}

if help.value{
    cli.printUsage()
    exit(EX_USAGE)
}

let project = projectOption.value ?? ""
let resourceExtensions = resourceExtensionOption.value ?? ["png","jpg","jpeg","imageset"]
let fileExtensions = fileExtensionOption.value ?? ["swift","m","mm","xib","storyboard"]
let excludePaths = excludePathsOption.value ?? []

let fengniao = FengNiao(projectPath: project, excludedPaths: excludePaths, resourceExtensions: resourceExtensions, fileExtensions: fileExtensions)
let unusedFiles: [FileInfo]
do{
    print("working ..".bold)
    unusedFiles = try fengniao.unusedResource()
} catch {
    guard let e = error as? FengNiaoKitError else{
        exit(EX_USAGE)
    }
    
    switch e{
    case .noResourceExtension:
        break
    case .noFileExtension:
        break
    }
    
    exit(EX_USAGE)
}

if unusedFiles.isEmpty{
    print("No unused files!")
    exit(EX_USAGE)
}

for file in unusedFiles{
    print("\(file.size) \(file.path.string)")
}

print("Delete?")

if let input = readLine(), input == "d"{
    let deleteRet = FengNiao.delete(unusedFiles)
    let deleted = deleteRet.deleted
    for d in deleted {
        print("Delete: \(d.path.string)")
    }
    
    let failed = deleteRet.failed
    for fail in failed {
        print("DeleteError: \(fail.0.path.string), Error:\(fail.1.localizedDescription)")
    }
}else{
    print("bye...")
}






