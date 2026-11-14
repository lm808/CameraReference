import AppKit

// File-driven rows: preserve every byte outside the edited value.
struct ConfigEditorDocument {
    struct Row {
        let line:Int
        let name:String
        var value:String
        let comment:String
        let prefix:String
        let suffix:String
    }
    let original:String
    var rows:[Row]=[]
    init(_ text:String) {
        original=text
        let pattern = #"^(\s*([A-Za-z][A-Za-z0-9_]*)\s*=\s*)([^#\r]*?)(\s*(?:#.*)?\r?)$"#
        let regex=try! NSRegularExpression(pattern:pattern)
        var comments:[String]=[]
        for (index,line) in text.components(separatedBy:"\n").enumerated() {
            let ns=line as NSString
            if let match=regex.firstMatch(in:line,range:NSRange(location:0,length:ns.length)) {
                let suffix=ns.substring(with:match.range(at:4))
                let inline=suffix.firstIndex(of:"#").map { String(suffix[suffix.index(after:$0)...]).trimmingCharacters(in:.whitespacesAndNewlines) }
                rows.append(Row(line:index,name:ns.substring(with:match.range(at:2)),value:ns.substring(with:match.range(at:3)),comment:([comments.joined(separator:" "),inline ?? ""].filter{!$0.isEmpty}).joined(separator:" "),prefix:ns.substring(with:match.range(at:1)),suffix:suffix))
                comments=[]
            } else {
                let trimmed=line.trimmingCharacters(in:.whitespacesAndNewlines)
                if trimmed.hasPrefix("#") { comments.append(String(trimmed.dropFirst()).trimmingCharacters(in:.whitespaces)) }
                else { comments=[] }
            }
        }
    }
    func matchingRows(_ query:String)->[Int] {
        let query=query.trimmingCharacters(in:.whitespacesAndNewlines)
        return rows.indices.filter { query.isEmpty || rows[$0].name.localizedCaseInsensitiveContains(query) || rows[$0].comment.localizedCaseInsensitiveContains(query) }
    }
    func rendered() throws -> String {
        var lines=original.components(separatedBy:"\n")
        for row in rows {
            let value=row.value.trimmingCharacters(in:.whitespaces)
            guard !value.isEmpty,!value.contains(where:{ $0 == "#" || $0 == "=" || $0.isNewline }) else {
                throw NSError(domain:"ConfigEditor",code:1,userInfo:[NSLocalizedDescriptionKey:"Enter a single value for \(row.name), without comments or new lines."])
            }
            // Untouched rows retain even unusual whitespace verbatim.
            if lines[row.line] != row.prefix+row.value+row.suffix {
                lines[row.line]=row.prefix+value+row.suffix
            }
        }
        return lines.joined(separator:"\n")
    }
    func save(to url:URL) throws {
        let text=try rendered()
        _ = try DetectionConfig.parse(text)
        var coordinationError:NSError?,writeError:Error?
        NSFileCoordinator().coordinate(writingItemAt:url,options:[],error:&coordinationError) { target in
            do {
                guard try Data(contentsOf:target)==Data(original.utf8) else {
                    throw NSError(domain:"ConfigEditor",code:2,userInfo:[NSLocalizedDescriptionKey:"The config file changed outside this window. Cancel and reopen Advanced settings to load the latest values."])
                }
                try Data(text.utf8).write(to:target,options:.atomic)
            } catch { writeError=error }
        }
        if let error=coordinationError { throw error }
        if let error=writeError { throw error }
    }
}

final class ConfigEditorController:NSWindowController,NSTableViewDataSource,NSTableViewDelegate,NSSearchFieldDelegate {
    private var configDocument:ConfigEditorDocument
    private let url:URL
    private let table=NSTableView()
    private let search=NSSearchField()
    private var visibleRows:[Int]=[]
    private let onSave:()->Void
    private let openFile:()->Void
    init(url:URL,onSave:@escaping()->Void,openFile:@escaping()->Void) throws {
        self.url=url;self.onSave=onSave;self.openFile=openFile
        configDocument=ConfigEditorDocument(try String(contentsOf:url,encoding:.utf8))
        let window=NSWindow(contentRect:NSRect(x:0,y:0,width:960,height:560),styleMask:[.titled,.closable,.resizable],backing:.buffered,defer:false)
        super.init(window:window)
        window.title="Advanced settings";window.minSize=NSSize(width:760,height:360);window.isReleasedWhenClosed=false
        visibleRows=configDocument.matchingRows("")
        let root=window.contentView!
        search.placeholderString="Search names and comments";search.delegate=self
        let warning=NSTextField(wrappingLabelWithString:"Advanced settings. Incorrect values may affect placement or performance. Changes apply after saving.")
        warning.font = .boldSystemFont(ofSize:13)
        let scroll=NSScrollView();scroll.hasVerticalScroller=true;scroll.borderType = .bezelBorder
        table.usesAlternatingRowBackgroundColors=true;table.rowHeight=28;table.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        for (key,title,width,editable) in [("name","Name",280.0,false),("value","Value",95.0,true),("comment","Comment",530.0,false)] {
            let column=NSTableColumn(identifier:NSUserInterfaceItemIdentifier(key));column.title=title;column.width=width;column.minWidth=60;column.isEditable=editable
            table.addTableColumn(column)
        }
        table.dataSource=self;table.delegate=self;scroll.documentView=table
        let save=NSButton(title:"Save",target:self,action:#selector(saveChanges));save.keyEquivalent="\r"
        let cancel=NSButton(title:"Cancel",target:self,action:#selector(cancelChanges));cancel.keyEquivalent="\u{1b}"
        let file=NSButton(title:"Open config file",target:self,action:#selector(openTextFile))
        let buttons=NSStackView(views:[file,NSView(),cancel,save]);buttons.orientation = .horizontal;buttons.spacing=10
        for view in [warning,search,scroll,buttons] { view.translatesAutoresizingMaskIntoConstraints=false;root.addSubview(view) }
        NSLayoutConstraint.activate([
            warning.topAnchor.constraint(equalTo:root.topAnchor,constant:16),warning.leadingAnchor.constraint(equalTo:root.leadingAnchor,constant:16),warning.trailingAnchor.constraint(equalTo:root.trailingAnchor,constant:-16),
            search.topAnchor.constraint(equalTo:warning.bottomAnchor,constant:12),search.leadingAnchor.constraint(equalTo:root.leadingAnchor,constant:16),search.trailingAnchor.constraint(equalTo:root.trailingAnchor,constant:-16),
            scroll.topAnchor.constraint(equalTo:search.bottomAnchor,constant:10),scroll.leadingAnchor.constraint(equalTo:root.leadingAnchor,constant:16),scroll.trailingAnchor.constraint(equalTo:root.trailingAnchor,constant:-16),
            buttons.topAnchor.constraint(equalTo:scroll.bottomAnchor,constant:12),buttons.leadingAnchor.constraint(equalTo:root.leadingAnchor,constant:16),buttons.trailingAnchor.constraint(equalTo:root.trailingAnchor,constant:-16),buttons.bottomAnchor.constraint(equalTo:root.bottomAnchor,constant:-16)
        ])
        window.center()
    }
    required init?(coder:NSCoder) { fatalError() }
    func numberOfRows(in tableView:NSTableView)->Int { visibleRows.count }
    func tableView(_ tableView:NSTableView,objectValueFor tableColumn:NSTableColumn?,row:Int)->Any? {
        let entry=configDocument.rows[visibleRows[row]]
        switch tableColumn?.identifier.rawValue { case "name":return entry.name;case "value":return entry.value;default:return entry.comment }
    }
    func tableView(_ tableView:NSTableView,setObjectValue object:Any?,for tableColumn:NSTableColumn?,row:Int) {
        if tableColumn?.identifier.rawValue == "value",let text=object as? String { configDocument.rows[visibleRows[row]].value=text }
    }
    func tableView(_ tableView:NSTableView,toolTipFor cell:NSCell,rect:NSRectPointer,tableColumn:NSTableColumn?,row:Int,mouseLocation:NSPoint)->String { configDocument.rows[visibleRows[row]].comment }
    func controlTextDidChange(_ notification:Notification) {
        guard notification.object as? NSSearchField === search else { return }
        visibleRows=configDocument.matchingRows(search.stringValue);table.reloadData()
    }
    @objc private func saveChanges() {
        guard window?.makeFirstResponder(nil)==true else { return }
        do { try configDocument.save(to:url);onSave();close() }
        catch {
            let alert=NSAlert();alert.messageText="Settings were not saved";alert.informativeText=error.localizedDescription
            if let window { alert.beginSheetModal(for:window) }
        }
    }
    @objc private func cancelChanges() { close() }
    @objc private func openTextFile() { openFile() }
}
