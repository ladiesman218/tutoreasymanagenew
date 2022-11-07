import Vapor
import Fluent

// Chapter needs a path, and an underlying url for image, a url for pdf file which is the main content of the chapter, and directories/files which will be linked in the pdf. How these resource files are structured are trivial, since the link destinations in pdf should be point to the right relative resource url ultimately, as long as they all use a same shared standard for easier future maintain.
struct Chapter: Content {
    
    let url: URL
    
    var name: String
    
    var pdfPath: String? {
        
        let url = url.appendingPathComponent(name, isDirectory: false)
        
        if FileManager.default.fileExists(atPath: url.path) {
            return url.path
        } else {
            return nil
        }
    }
    
    var imagePath: String? {
        for name in ImageName.allCases {
            for imageExtension in ImageExtension.allCases {
                let url = url.appendingPathComponent(name.rawValue).appendingPathExtension(imageExtension.rawValue)
                
                if FileManager.default.fileExists(atPath: url.path) {
                    return url.path
                }
            }
        }
        return nil
    }
    
    init(url: URL) {
        self.url = url
        self.name = url.lastPathComponent
    }
}
