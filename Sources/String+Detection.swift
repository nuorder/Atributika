//
//  Detection.swift
//  Atributika
//
//  Created by Pavel Sharanda on 21.02.17.
//  Copyright © 2017 psharanda. All rights reserved.
//

import Foundation

public struct Tag {
    public let name: String
    public let attributes: [String: String]
}

public struct TagInfo {
    public let tag: Tag
    public let range: Range<String.Index>
}

public enum TagType {
    case start
    case end
}

public struct TagTransformer {

    public let tagName: String
    public let tagType: TagType
    public let transform: (Tag) -> String
    
    public init(tagName: String, tagType: TagType, replaceValue: String) {
        self.tagName = tagName
        self.tagType = tagType
        self.transform = { _ in replaceValue }
    }
    
    public init(tagName: String, tagType: TagType, transform: @escaping (Tag) -> String) {
        self.tagName = tagName
        self.tagType = tagType
        self.transform = transform
    }
    
    public static var brTransformer: TagTransformer {
        return TagTransformer(tagName: "br", tagType: .start , replaceValue: "\n")
    }
}

extension String {
    
    private func parseTag(_ tagString: String, parseAttributes: Bool) -> Tag? {
        
        let tagScanner = Scanner(string: tagString)
        
        guard let tagName = tagScanner.scanCharacters(from: CharacterSet.alphanumerics) else {
            return nil
        }
        
        var attrubutes = [String: String]()
        
        while parseAttributes && !tagScanner.isAtEnd {
            
            guard let name = tagScanner.scanUpTo("=") else {
                break
            }
            guard tagScanner.scanString("=") != nil else {
                break
            }

            guard tagScanner.scanString("'") != nil else {
                break
            }

            let value = tagScanner.scanUpTo("'") ?? ""

            guard tagScanner.scanString("'") != nil else {
                break
            }
            
            attrubutes[name] = value.replacingOccurrences(of: "&quot;", with: "\"")
        }
        
        return Tag(name: tagName, attributes: attrubutes)
    }
    
    private static let specials = ["quot":"\"",
                                   "amp":"&",
                                   "apos":"'",
                                   "lt":"<",
                                   "gt":">"]
    
    public func detectTags(transformers: [TagTransformer] = []) -> (string: String, tagsInfo: [TagInfo]) {


        let scanner = Scanner(string: self)
        scanner.charactersToBeSkipped = nil
        var resultString = String()
        var tagsResult = [TagInfo]()
        var tagsStack = [(Tag, String.Index)]()

        let charaterSet:String = "<"

        while !scanner.isAtEnd {



            if let textString = scanner.scanUpToCharacters(from: CharacterSet(charactersIn: charaterSet)) {
                resultString += textString
            } else {
                if scanner.scanString("<") != nil {
                    let tagType = scanner.scanString("/") == nil ? TagType.start : TagType.end
                    if let tagString = scanner.scanUpTo(">") {
                        
                        if let tag = parseTag(tagString, parseAttributes: tagType == .start ) {
                            
                            let resultTextEndIndex = resultString.endIndex
                            
                            if let transformer = transformers.first(where: {
                                $0.tagName == tag.name && $0.tagType == tagType
                            }) {
                                resultString += transformer.transform(tag)
                            }
                            
                            if tagType == .start {
                                tagsStack.append((tag, resultTextEndIndex))
                            } else {
                                for (index, (tagInStack, startIndex)) in tagsStack.enumerated().reversed() {
                                    if tagInStack.name == tag.name {
                                        tagsResult.append(TagInfo(tag: tagInStack, range: startIndex..<resultTextEndIndex))
                                        tagsStack.remove(at: index)
                                        break
                                    }
                                }
                            }
                        }
                        scanner.scanString(">")
                    }
                }
            }
        }
        
        return (resultString, tagsResult)
    }
    
    public func detectHashTags() -> [Range<String.Index>] {
        
        return detect(regex: "[#]\\w\\S*\\b")
    }
    
    public func detectMentions() -> [Range<String.Index>] {
        
        return detect(regex: "[@]\\w\\S*\\b")
    }
    
    public func detect(regex: String, options: NSRegularExpression.Options = []) -> [Range<String.Index>] {
        
        var ranges = [Range<String.Index>]()
        
        let dataDetector = try? NSRegularExpression(pattern: regex, options: options)
        dataDetector?.enumerateMatches(in: self, options: [], range: NSMakeRange(0, (self as NSString).length), using: { (result, flags, _) in
            if let r = result, let range = Range(r.range, in: self) {
                ranges.append(range)
            }
        })
        
        return ranges
    }
    
    public func detect(textCheckingTypes: NSTextCheckingResult.CheckingType) -> [Range<String.Index>] {
        
        var ranges = [Range<String.Index>]()
        
        let dataDetector = try? NSDataDetector(types: textCheckingTypes.rawValue)
        dataDetector?.enumerateMatches(in: self, options: [], range: NSMakeRange(0, (self as NSString).length), using: { (result, flags, _) in
            if let r = result, let range = Range(r.range, in: self) {
                ranges.append(range)
            }
        })
        return ranges
    }
}
