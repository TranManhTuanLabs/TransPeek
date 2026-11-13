import Defaults
import SwiftUI

/// Dictionary links section for Settings (SPEC §3.2).
///
/// Self-contained: it reads/writes `Defaults[.dictionaryLinksJSON]` via
/// `DictionaryLink` and needs no arguments. Place its body directly in a
/// `Form` (for example as a tab, or inside `GeneralSettingsView`'s `Form`) —
/// it is a `Group` of `Section`s, not a `Form` itself.
///
/// - Display mode picker (Icon + Text / Icon only).
/// - List of current links with edit (sheet) and delete.
/// - Add form with `{word}` / `{text}` hint and validation.
/// - Reset to the built-in defaults.
struct DictionarySettingsView: View {
    @Default(.dictionaryDisplayMode) private var displayMode
    @Default(.appTextSize) private var appTextSize
    @State private var links: [DictionaryLink] = DictionaryLink.load()
    @State private var newName = ""
    @State private var newTemplate = ""
    @State private var addError: String?
    @State private var editingLink: DictionaryLink?

    var body: some View {
        Group {
            Section(String(localized: "Display")) {
                Picker(String(localized: "Show links as:"), selection: $displayMode) {
                    Text("Icon + Text").tag(DictionaryDisplayMode.iconText)
                    Text("Icon only").tag(DictionaryDisplayMode.iconOnly)
                }
                .pickerStyle(.segmented)
                Text("Icon only shows the site favicon (or the first letter of the name) with the name as a tooltip.")
                    .font(.settingsCaption(appTextSize: appTextSize))
                    .foregroundStyle(.secondary)
            }

            Section(String(localized: "Dictionary Links")) {
                ForEach(links) { link in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(link.name)
                            Text(link.urlTemplate)
                                .font(.settingsCaption(appTextSize: appTextSize))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        Spacer()
                        Button(String(localized: "Edit")) { editingLink = link }
                    }
                }
                .onDelete(perform: deleteLinks)

                Button(String(localized: "Reset to Defaults"), role: .destructive) {
                    links = DictionaryLink.defaults
                    DictionaryLink.save(links)
                }
            }

            Section(String(localized: "Add Link")) {
                // Label above the field (not label + field on one stretched
                // row): the two fields used to run label and placeholder
                // side by side across the whole window.
                VStack(alignment: .leading, spacing: 4) {
                    Text("Name")
                        .font(.settingsCaption(appTextSize: appTextSize))
                        .foregroundStyle(.secondary)
                    TextField("", text: $newName, prompt: Text("e.g. Oxford"))
                        .textFieldStyle(.roundedBorder)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("URL template")
                        .font(.settingsCaption(appTextSize: appTextSize))
                        .foregroundStyle(.secondary)
                    TextField("", text: $newTemplate, prompt: Text("e.g. https://…/{word}"))
                        .textFieldStyle(.roundedBorder)
                        .autocorrectionDisabled()
                }
                Text("Use {word} for the first word of the selected text, or {text} for the whole selection. Example: https://dictionary.cambridge.org/dictionary/english/{word}")
                    .font(.settingsCaption(appTextSize: appTextSize))
                    .foregroundStyle(.secondary)
                if let addError {
                    Text(addError)
                        .font(.settingsCaption(appTextSize: appTextSize))
                        .foregroundStyle(.red)
                }
                Button(String(localized: "Add Link")) { addLink() }
            }
        }
        .sheet(item: $editingLink) { link in
            DictionaryLinkEditorView(link: link) { name, urlTemplate in
                updateLink(link, name: name, urlTemplate: urlTemplate)
            }
        }
    }

    private func addLink() {
        let name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        let template = newTemplate.trimmingCharacters(in: .whitespacesAndNewlines)
        if let error = DictionaryLink.validationError(name: name, urlTemplate: template) {
            addError = error
            return
        }
        links.append(DictionaryLink(name: name, urlTemplate: template))
        DictionaryLink.save(links)
        newName = ""
        newTemplate = ""
        addError = nil
    }

    private func deleteLinks(at offsets: IndexSet) {
        links.remove(atOffsets: offsets)
        DictionaryLink.save(links)
    }

    private func updateLink(_ link: DictionaryLink, name: String, urlTemplate: String) {
        guard let index = links.firstIndex(where: { $0.id == link.id }) else { return }
        links[index] = DictionaryLink(
            id: link.id,
            name: name,
            urlTemplate: urlTemplate,
            iconSystemName: link.iconSystemName
        )
        DictionaryLink.save(links)
    }
}

// MARK: - Edit sheet

/// Inline editor for one dictionary link, presented as a sheet.
/// Validates with the same rules as the add form and only calls `onSave`
/// when the edited link is usable.
private struct DictionaryLinkEditorView: View {
    let link: DictionaryLink
    let onSave: (_ name: String, _ urlTemplate: String) -> Void

    @Default(.appTextSize) private var appTextSize
    @Environment(\.dismiss) private var dismiss
    @State private var name: String
    @State private var urlTemplate: String
    @State private var error: String?

    init(link: DictionaryLink, onSave: @escaping (_ name: String, _ urlTemplate: String) -> Void) {
        self.link = link
        self.onSave = onSave
        _name = State(initialValue: link.name)
        _urlTemplate = State(initialValue: link.urlTemplate)
    }

    var body: some View {
        Form {
            Section {
                TextField(String(localized: "Name"), text: $name)
                TextField(String(localized: "URL template"), text: $urlTemplate)
                    .autocorrectionDisabled()
                Text("Use {word} for the first word of the selected text, or {text} for the whole selection.")
                    .font(.settingsCaption(appTextSize: appTextSize))
                    .foregroundStyle(.secondary)
                if let error {
                    Text(error)
                        .font(.settingsCaption(appTextSize: appTextSize))
                        .foregroundStyle(.red)
                }
            }

            Section {
                HStack {
                    Button(String(localized: "Cancel"), role: .cancel) { dismiss() }
                    Spacer()
                    Button(String(localized: "Save")) { save() }
                        .keyboardShortcut(.defaultAction)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(minWidth: 420, minHeight: 220)
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTemplate = urlTemplate.trimmingCharacters(in: .whitespacesAndNewlines)
        if let validationError = DictionaryLink.validationError(name: trimmedName, urlTemplate: trimmedTemplate) {
            error = validationError
            return
        }
        onSave(trimmedName, trimmedTemplate)
        dismiss()
    }
}
