import Vapor
import Fluent

// Chapter needs a path, and an underlying url for image, a url for pdf file which is the main content of the chapter, and directories/files which will be linked in the pdf. How these resource files are structured are trivial, since the link destinations in pdf should be point to the right relative resource url ultimately, as long as they all use a same shared standard for easier future maintainance.
struct Chapter: Content {
	
	let directoryURL: URL
	let name: String
	let isFree: Bool
	
	var pdfURL: URL = URL(fileURLWithPath: "")
	var bInstructionURL: URL?	// For lego building instruction pdf
	var teachingPlanURL: URL?
#warning("how to display this file on client end?")
	var codeFile: URL?
	var imageURL: URL?
	
	// All properties have to be set in initializer, just as in Course.PublicInfo, if we only make them as computed properties without setting in init function, request will always return nothing.
	init(directoryURL: URL) {
		self.directoryURL = directoryURL
		let namePath = directoryURL.lastPathComponent
		self.name = namePath.withoutTrail.withoutNum
		self.isFree = namePath.contains(trailRegex)

		// Get urls for all pdfs if file is found.
		// Say for example, a chapter is named by its directory name"第1课：埃菲尔铁塔-免费", check if a pdf file with the given name suffix exists in directoryURL among the combinations of the following 4: its full form, without trail form(第1课：埃菲尔铁塔), without number prefix form(埃菲尔铁塔-免费), and pure name without both form(埃菲尔铁塔). So All 4 following cases return the url: 第1课：埃菲尔铁塔-免费教案.pdf, 第1课：埃菲尔铁塔教案.pdf, 埃菲尔铁塔-免费教案.pdf, 埃菲尔铁塔教案.pdf
		for fileName in [namePath, namePath.withoutTrail, namePath.withoutNum, namePath.withoutTrail.withoutNum] {
			let mainPDF = fileName + PDFName.main.rawValue
			let tPlanPDF = fileName + PDFName.teachingPlan.rawValue
			let bInsPDF = fileName + PDFName.buildingInstruction.rawValue
			
			if FileManager.default.fileExists(atPath: directoryURL.appendingPathComponent(mainPDF).path) {
				self.pdfURL = directoryURL.appendingPathComponent(mainPDF)
			}
			if FileManager.default.fileExists(atPath: directoryURL.appendingPathComponent(tPlanPDF).path) {
				self.teachingPlanURL = directoryURL.appendingPathComponent(tPlanPDF)
			}
			if FileManager.default.fileExists(atPath: directoryURL.appendingPathComponent(bInsPDF).path) {
				self.bInstructionURL = directoryURL.appendingPathComponent(bInsPDF)
			}
		}
				
		self.imageURL = getImageURLInDirectory(url: directoryURL)
	}
	
	enum PDFName: String {
		case main = "课程.pdf"
		case teachingPlan = "教案.pdf"
		case buildingInstruction = "搭建说明.pdf"
	}
}
