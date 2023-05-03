import Vapor
import Fluent

// Chapter needs a path, and an underlying url for image, a url for pdf file which is the main content of the chapter, and directories/files which will be linked in the pdf. How these resource files are structured are trivial, since the link destinations in pdf should be point to the right relative resource url ultimately, as long as they all use a same shared standard for easier future maintain.
struct Chapter: Content {
	
    let directoryURL: URL
    let name: String
	let isFree: Bool
	
    var pdfURL: URL
    var imageURL: URL?
    
	// pdfPath and imageURL have to be set in initializer, just as in Course.PublicInfo, if we only make it a computed property here without setting in init function, request will always return nothing for these 2 properties.
    init(directoryURL: URL) {
        self.directoryURL = directoryURL
        let name = directoryURL.lastPathComponent
		
		if let trialChapterRange = name.range(of: trialChpaterRegex, options: .regularExpression) {
			self.name = name.replacingCharacters(in: trialChapterRange, with: "")
			self.isFree = true
		} else {
			self.name = name
			self.isFree = false
		}
		
		self.pdfURL = directoryURL.appendingPathComponent("teacher.pdf")
		self.imageURL = getImageURLInDirectory(url: directoryURL)
    }
}
