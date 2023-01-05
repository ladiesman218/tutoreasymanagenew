import Vapor

// Practically path(string) is better than url, both FileManager functions such as fileExists and swift NIO functions for serving files such as req.fileio.streamFile use paths, also access remote files with urls of a file:// scheme seems very hard to tweak. Using urls here is only because it's a little easier to compose, simply return the composed url.path for whenever needed.
let adminEmail = "chn_dunce@126.com"
let courseRoot = URL(fileURLWithPath: "../Courses", isDirectory: true).standardizedFileURL//URL(string: "../Courses")!
let appleRootCert = ""	// Root certificate for verify in app purchase notifications, wrong value here doesn't change anything, why?
let appleBundleID = "com.dunce.TutorEasy"
let vipIAPIdentifier = "vip_test"

let emailRegex = "[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,64}"
let phoneNumberRegex = "^([+](\\d{1,3}|\\d{1,2}[- ]{1,}\\d{3,4})[- ]{1,}){0,1}\\d{5,20}$"
let userNameLength = Range(4...35)
let nameLength = Range(3...40)
let passwordLength = Range(6...40)

let nonAlphanumerics = CharacterSet.alphanumerics.inverted	// Alphanumerics contains letters in all language, special letters. But doesn't contain tabs, spaces, marks. Alphanumerics could be used in names. Notice here we used the `inverted` function to get the inverted result, to check if illegal characters are presented.

extension URL {
    var isDirectory: Bool {
       (try? resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
    }
}
