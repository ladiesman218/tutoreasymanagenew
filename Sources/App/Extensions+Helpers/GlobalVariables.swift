import Vapor
import RegexBuilder

// Practically path(string) is better than url, both FileManager functions such as fileExists and swift NIO functions for serving files such as req.fileio.streamFile use paths, also access remote files with urls of a file:// scheme seems very hard to tweak. Using urls here is only because it's a little easier to compose, simply return the composed url.path for whenever needed.
let serviceName = "师轻松"
let workingDirectory = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let coursesDirectoryName = "Courses"
let courseRoot = workingDirectory.deletingLastPathComponent().appendingPathComponent(coursesDirectoryName, isDirectory: true).standardizedFileURL

let appleRootCert = "" // Root certificate for verify in app purchase notifications, wrong value here doesn't change anything, why?
let appleBundleID = "com.dunce.TutorEasy"
let vipIAPIdentifier = "vip_test"

let trialRegex = Regex {
	ZeroOrMore(.whitespace)
	OneOrMore("-")
	OneOrMore {
		ChoiceOf {
			"免费"
			"free"
		}
	}
}
let chapterPrefixRegex = Regex {
	// Each actual word/character may be surrounded by any number of spaces
	
	ZeroOrMore(.whitespace)
	// Things like "第". Digits are also counts as word in regex, so use .reluctant
	ZeroOrMore(.word, .reluctant)
	ZeroOrMore(.whitespace)
	
	// Actual numbers used for sorting chapters
	TryCapture {
		OneOrMore(.digit)
	} transform: {
		Int($0)
	}
	
	ZeroOrMore(.whitespace)
	// Things like "课"
	ZeroOrMore(.word)
	ZeroOrMore(.whitespace)
	
	OneOrMore {
		ChoiceOf {
			":"
			"："
		}
	}
	ZeroOrMore(.whitespace)
}

let userNameLength = Range(4...35)
let nameLength = Range(3...40)
let passwordLength = Range(6...40)

let nonAlphanumerics = CharacterSet.alphanumerics.inverted	// Alphanumerics contains letters in all language, special letters. But doesn't contain tabs, spaces, marks. Alphanumerics could be used in names. Notice here we used the `inverted` function to get the inverted result, to check if illegal characters are presented.

let noCache = HTTPHeaders.CacheControl(noCache: true)
let noStore = HTTPHeaders.CacheControl(noStore: true)

let pdfExt = "pdf"
let videoExts = ["mp4", "mov", "m4v"]
