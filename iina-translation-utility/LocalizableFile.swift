//
//  LocalizableFile.swift
//  iina-translation-utility
//
//  Created by Collider LI on 20/12/2017.
//  Copyright © 2017 Collider LI. All rights reserved.
//

import Cocoa

class LocalizableFile: NSObject {

  var url: URL
  var baseLanguageURL: URL?
  var baseFileIsXIB = false

  var contentDict: [String: String] = [:]
  var content: [LocalizationItem] = []
  var baseDict: [String: String] = [:]
  var baseClassDict: [String: String] = [:]

  var missingKeyCount = 0

  private var xibLoader: XIBLoader?

  init(url: URL, basedOn baseLangURL: URL?) {
    self.url = url
    self.baseLanguageURL = baseLangURL
    super.init()
    self.removeFallbacks()
  }

  func removeFallbacks() {
    do {
      let strings = try String.init(contentsOf: url, encoding: .utf8)
      let lines = strings.split(separator: "\n")
      let FIXME = "FIXME: Using English localization instead"
      var foundFixme = false
      var toWrite = ""
      for currentLine in lines {
        if (foundFixme) {
          foundFixme = false
          continue
        }
        if (currentLine.contains(FIXME)) {
          foundFixme = true
          continue
        }
        toWrite.append(String(currentLine) + "\n")
      }
      try toWrite.write(toFile: url.path, atomically: false, encoding: .utf8)
    } catch let error {
      Utils.showAlert(message: error.localizedDescription)
    }

  }

  func loadFile() {
    content.removeAll()
    if let dict = NSDictionary(contentsOf: url) as? [String: String] {
      contentDict = dict
      dict.forEach { (key, value) in
        content.append(LocalizationItem(key: key, base: nil, localization: value))
      }
    } else {
      return
    }
  }

  func saveToDisk() {
    var string = "/** Generated by IINA Translation Utility */\n\n"
    content.sorted { $0.key < $1.key }.forEach { item in
      guard let localization = item.escapedLocalization, let _ = item.base else { return }
      let splitted = item.key.components(separatedBy: ".")
      let objID = splitted.first!
      let titleName = splitted.dropFirst().joined(separator: ".")
      if baseFileIsXIB {
        string += "/* Class = \"\(item.baseClassName ?? "")\"; \(titleName) = \"\(item.baseStringForDisplay)\"; ObjectID = \"\(objID)\"; */\n"
      }
      string += "\"\(item.key)\" = \"\(localization)\";\n"
      if baseFileIsXIB {
        string += "\n"
      }
    }
    do {
      try string.write(to: url, atomically: true, encoding: .utf8)
    } catch let error {
      Utils.showAlert(message: error.localizedDescription)
    }
  }

  func update() {
    loadFile()
    loadBase()
    checkForIssues()
  }

  func checkForIssues(appendMissingValues: Bool = true) {
    missingKeyCount = 0
    for (key, value) in baseDict {
      if contentDict[key] == nil {
        missingKeyCount += 1
        if appendMissingValues {
          let item = LocalizationItem(key: key, base: value, localization: nil)
          if let baseClassName = baseClassDict[key] {
            item.baseClassName = baseClassName
          }
          content.append(item)
        }
      }
    }
    content.sort { $0.key.lexicographicallyPrecedes($1.key) }
  }

  private func loadBase() {
    guard let baseLangURL = baseLanguageURL else { return }
    let baseStringsURL = baseLangURL.appendingPathComponent(url.lastPathComponent)
    let baseXIBURL = baseStringsURL.deletingPathExtension().appendingPathExtension("xib")
    if FileManager.default.fileExists(atPath: baseStringsURL.path) {
      // is string file
      baseFileIsXIB = false
      if let dict = NSDictionary(contentsOf: baseStringsURL) as? [String: String] {
        baseDict = dict
      } else {
        return
      }
    } else if FileManager.default.fileExists(atPath: baseXIBURL.path) {
      // is base xib file
      baseFileIsXIB = true
      let xibLoader = XIBLoader(baseXIBURL)
      if xibLoader.parse() {
        baseDict = xibLoader.titles
        baseClassDict = xibLoader.classes
      }
    }
    content.forEach { item in
      item.base = baseDict[item.key]
      item.baseClassName = baseClassDict[item.key]
    }
  }
}
