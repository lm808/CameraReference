import Foundation
let original="# Section\r\nsideSearchPercent = 40  # search range\r\naxLibraryBottomOffsetPoints = 25 # split only\r\n# untouched\r\n"
var doc=ConfigEditorDocument(original)
assert(doc.rows.count==2 && doc.rows[0].name=="sideSearchPercent")
assert(doc.rows[0].comment=="Section search range")
assert(try! doc.rendered()==original)
doc.rows[1].value="30"
let expected=original.replacingOccurrences(of:"= 25",with:"= 30")
assert(try! doc.rendered()==expected)
let dir=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
try FileManager.default.createDirectory(at:dir,withIntermediateDirectories:true)
defer { try? FileManager.default.removeItem(at:dir) }
let url=dir.appendingPathComponent("config.conf")
try original.write(to:url,atomically:true,encoding:.utf8)
try doc.save(to:url)
assert(try! String(contentsOf:url,encoding:.utf8)==expected)
do { try doc.save(to:url);fatalError("External edit must be rejected") } catch {}
var invalid=ConfigEditorDocument(expected);invalid.rows[0].value="99"
do { try invalid.save(to:url);fatalError("Out of range must be rejected") } catch {}
assert(try! String(contentsOf:url,encoding:.utf8)==expected)
invalid.rows[0].value="40\nleft=photo"
do { _ = try invalid.rendered();fatalError("Multiline input must be rejected") } catch {}
let future=ConfigEditorDocument("futureSetting = hello # future comment\n")
assert(future.rows.count==1 && future.rows[0].value=="hello")
assert(try! future.rendered()==future.original)
print("PASS: file-driven config rows, exact round-trip, comment preservation, validation, conflict protection and atomic save")

assert(doc.matchingRows("LIBRARY")==[1])
assert(doc.matchingRows("search range")==[0])
assert(doc.matchingRows("nothing matches").isEmpty)
assert(doc.matchingRows(" ")==[0,1])
var filtered=ConfigEditorDocument(original)
let row=filtered.matchingRows("library")[0]
filtered.rows[row].value="35"
assert(try! filtered.rendered()==original.replacingOccurrences(of:"= 25",with:"= 35"))
assert(filtered.rows[0].value=="40")
print("PASS: name/comment search, case-insensitivity, empty/no matches, correct filtered-row editing")
