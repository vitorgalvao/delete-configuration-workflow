import Foundation

// Grab relevant directories
let libraryPaths = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)
let excludedDirs = ProcessInfo.processInfo.environment["ignored_suffixes"]?.split(separator: "\n").map { libraryPaths[0].appending(path: $0).path } ?? []

// Prepare query
let query = CommandLine.arguments[1]
let searchQuery = MDQueryCreate(kCFAllocatorDefault, "kMDItemFSName == '*\(query)*'c" as CFString, nil, nil)

// Run query
MDQuerySetSearchScope(searchQuery, libraryPaths as CFArray, 0)
MDQueryExecute(searchQuery, CFOptionFlags(kMDQuerySynchronous.rawValue))
let resultCount = MDQueryGetResultCount(searchQuery)

// No results
guard resultCount > 0 else {
  print(
    """
    {\"items\":[{\"title\":\"No Results\",
    \"subtitle\":\"No paths found\",
    \"valid\":false}]}
    """
  )

  exit(EXIT_SUCCESS)
}

// Prepare items
struct ScriptFilterItem: Codable {
  let variables: [String: String]
  let uid: String
  let title: String
  let subtitle: String
  let type: String
  let icon: FileIcon
  let arg: String

  struct FileIcon: Codable {
    let path: String
    let type: String
  }
}

let sfItems: [ScriptFilterItem] = (0..<resultCount).compactMap { resultIndex in
  let rawPointer = MDQueryGetResultAtIndex(searchQuery, resultIndex)
  let resultItem = Unmanaged<MDItem>.fromOpaque(rawPointer!).takeUnretainedValue()

  guard
    let resultPath = MDItemCopyAttribute(resultItem, kMDItemPath) as? String,
    !excludedDirs.contains(where: resultPath.hasPrefix)
  else { return nil }

  return ScriptFilterItem(
    variables: ["search_query": query],
    uid: resultPath,
    title: URL(fileURLWithPath: resultPath).lastPathComponent,
    subtitle: (resultPath as NSString).abbreviatingWithTildeInPath,
    type: "file",
    icon: ScriptFilterItem.FileIcon(path: resultPath, type: "fileicon"),
    arg: resultPath
  )
}

// Output JSON
let jsonData = try JSONEncoder().encode(["items": sfItems])
print(String(data: jsonData, encoding: .utf8)!)
