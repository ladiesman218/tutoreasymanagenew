import Vapor
import Fluent

// Chapter needs a path, and an underlying url for image, a url for pdf file which is the main content of the chapter, and directories/files which will be linked in the pdf. How these resource files are structured are trivial, since the link destinations in pdf should be point to the right relative resource url ultimately, as long as they all use a same shared standard for easier future maintainance.
struct Chapter: Content {
	static let pdfExt = "pdf"
	static let videoExts = ["mp4", "mov", "m4v"]

	enum PDFName: String {
		case teachingPlan = "教案"
		case buildingInstruction = "搭建说明"
		case sst = "双师堂"
	}
	
	let directoryURL: URL
	let name: String
	let isFree: Bool
	
	var pdfURL: URL
	var bInstructionURL: URL?	// For lego building instruction pdf
	var teachingPlanURL: URL?
	var sstURL: URL?
#warning("how to display this file on client end?")
	var codeFile: URL?
	var imageURL: URL?
	
	// All properties have to be set in initializer, just as in Course.PublicInfo, if we only make them as computed properties without setting in init function, request will always return nothing.
	init(directoryURL: URL) {
		self.directoryURL = directoryURL
		// Depending on directory name, namePath could contain number prefix, free trial identifier, or both.
		let namePath = directoryURL.lastPathComponent
		self.name = namePath.withoutTrail.withoutNum
		self.isFree = namePath.contains(trialRegex)

		// Get urls for all pdfs if file is found.
		// A chapter may be named by its directory name"第1课：埃菲尔铁塔-免费", check if a pdf file with the given name suffix exists in directoryURL among the combinations of the following 4: its full form, without trail form(第1课：埃菲尔铁塔), without number prefix form(埃菲尔铁塔-免费), and pure name without both form(埃菲尔铁塔). So All 4 following cases return the url: 第1课：埃菲尔铁塔-免费教案.pdf, 第1课：埃菲尔铁塔教案.pdf, 埃菲尔铁塔-免费教案.pdf, 埃菲尔铁塔教案.pdf
		
		// Set a initial value for main pdf, change it in for loop if another path actually found an existing file. 
		self.pdfURL = directoryURL.appendingPathComponent(name).appendingPathExtension(Self.pdfExt)

		for fileName in [namePath, namePath.withoutTrail, namePath.withoutNum, namePath.withoutTrail.withoutNum] {
			
			let mainPDFURL = directoryURL.appendingPathComponent(fileName).appendingPathExtension(Self.pdfExt)
			if FileManager.default.fileExists(atPath: mainPDFURL.path) {
				self.pdfURL = mainPDFURL
			}
			
			let tPlanURL = directoryURL.appendingPathComponent(fileName + PDFName.teachingPlan.rawValue).appendingPathExtension(Self.pdfExt)
			if FileManager.default.fileExists(atPath: tPlanURL.path) {
				self.teachingPlanURL = tPlanURL
			}
			
			let bInsURL = directoryURL.appendingPathComponent(fileName + PDFName.buildingInstruction.rawValue).appendingPathExtension(Self.pdfExt)
			if FileManager.default.fileExists(atPath: bInsURL.path) {
				self.bInstructionURL = bInsURL
			}
			
			for ext in Self.videoExts {
				let sstURL = directoryURL.appendingPathComponent(fileName + PDFName.sst.rawValue).appendingPathExtension(ext)
				if FileManager.default.fileExists(atPath: sstURL.path) {
					self.sstURL = sstURL
				}
			}
		}
				
		self.imageURL = getImageURLInDirectory(url: directoryURL)
	}
}
