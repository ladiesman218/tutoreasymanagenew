import Vapor
import Fluent

// Chapter needs a path, and an underlying url for image, a url for pdf file which is the main content of the chapter, and directories/files which will be linked in the pdf. How these resource files are structured are trivial, since the link destinations in pdf should be point to the right relative resource url ultimately, as long as they all use a same shared standard for easier future maintain.
struct Chapter: Content {
    
    var path: URL       // Make this a string and try if it can be gettable in controller
    var pdfURL: URL
    var imageURL: URL
    
}
