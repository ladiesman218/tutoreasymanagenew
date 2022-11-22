import Vapor
import Fluent

// Chapter needs a path, and an underlying url for image, a url for pdf file which is the main content of the chapter, and directories/files which will be linked in the pdf. How these resource files are structured are trivial, since the link destinations in pdf should be point to the right relative resource url ultimately, as long as they all use a same shared standard for easier future maintain.
struct Chapter: Content {
    
    let directoryURL: URL
    
    var name: String
    
    var pdfURL: URL?
    var imagePath: String?
    
	// pdfPath and imagePath have to be set in initializer, just as in Course.PublicInfo, if we only make it a computed property here without setting in init function, request will always return nothing for these 2 properties.
    init(url: URL) {
        self.directoryURL = url
        self.name = url.lastPathComponent
		
        let pdfURL = directoryURL.appendingPathComponent(name).appendingPathExtension("pdf")
        if FileManager.default.fileExists(atPath: pdfURL.path) {
            self.pdfURL = pdfURL
        } else {
            self.pdfURL = nil
        }

		self.imagePath = getImagePathInDirectory(url: url)
    }
}
