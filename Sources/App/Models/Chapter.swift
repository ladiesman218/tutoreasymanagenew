import Vapor
import Fluent

// Chapter needs a path, and an underlying url for image, a url for pdf file which is the main content of the chapter, and directories/files which will be linked in the pdf. How these resource files are structured are trivial, since the link destinations in pdf should be point to the right relative resource url ultimately, as long as they all use a same shared standard for easier future maintain.
struct Chapter: Content {
	
    let directoryURL: URL
    let name: String
	let isFree: Bool
	
    var pdfURL: URL
	var bInstructionURL: URL?	// For lego building instruction pdf
	var teachingPlanURL: URL?
	var codeFile: URL?
    var imageURL: URL?
    
	// All properties have to be set in initializer, just as in Course.PublicInfo, if we only make them as computed properties without setting in init function, request will always return nothing.
    init(directoryURL: URL) {
        self.directoryURL = directoryURL
        let namePath = directoryURL.lastPathComponent
		var name: String
		if let trialChapterRange = namePath.range(of: trialChpaterRegex, options: .regularExpression) {
			name = namePath.replacingCharacters(in: trialChapterRange, with: "")
			self.isFree = true
		} else {
			name = namePath
			self.isFree = false
		}
		self.name = name
		self.pdfURL = directoryURL.appendingPathComponent("\(name).pdf")
//		getPDFs()
		let bInstructionURL = directoryURL.appendingPathComponent("\(name)搭建说明.pdf")
		if FileManager.default.fileExists(atPath: bInstructionURL.path) {
			self.bInstructionURL = bInstructionURL
		}
		
		let teachingPlanURL = directoryURL.appendingPathComponent("\(name)教案.pdf")
		if FileManager.default.fileExists(atPath: teachingPlanURL.path) {
			self.teachingPlanURL = teachingPlanURL
		}
		
		if FileManager.default.fileExists(atPath: directoryURL.appendingPathComponent("代码").path) {
			print("found code file")
		}
			
//		for url in try? FileManager.default.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: [], options: .skipsHiddenFiles) ?? [] {
////			let fileURL = url as! URL(fileURLWithPath: url.path)
//		}
		self.imageURL = getImageURLInDirectory(url: directoryURL)
    }
	
//	mutating func getPDFs() {
//			let tPlanName = "教案.pdf"
//			let bInsName = "搭建说明.pdf"
//			enum TPlan: String {
//				typealias RawValue = String
//				
//			case fullname = "self.name + tPlanName"
//			}
//			
//			// Get pdf url for teaching plan file
//			if FileManager.default.fileExists(atPath: directoryURL.appendingPathComponent("教案.pdf").path) {
//				self.teachingPlanURL = directoryURL.appendingPathComponent("教案.pdf")
//			} else if FileManager.default.fileExists(atPath: directoryURL.appendingPathComponent("").path) {
//				
//			}
//			self.bInstructionURL = URL(string: "")
//		}
}
