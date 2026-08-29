import SwiftUI

/// Main batch print screen matching the MVP wireframe.
struct BatchPrintView: View {
    @StateObject private var viewModel: BatchPrintViewModel
    @State private var presetName = ""
    @State private var isHistoryPresented = false

    init(viewModel: BatchPrintViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: 20) {
            Text(String(localized: "app.title"))
                .font(.largeTitle.bold())
                .frame(maxWidth: .infinity)

            FolderDropZone(
                isEnabled: viewModel.state.isDropEnabled,
                onURLsDropped: { viewModel.handleDroppedURLs($0) },
                onClick: { viewModel.pickFolder() }
            )

            if viewModel.state.phase == .scanning {
                ProgressView(String(localized: "status.scanning"))
                    .frame(maxWidth: .infinity)
            }

            if !viewModel.state.files.isEmpty || viewModel.state.phase == .ready {
                summarySection
                sortAndFilterSection
            }

            printerSection
            presetSection
            workflowSection

            if !viewModel.state.files.isEmpty || viewModel.state.phase == .ready {
                printOptionsSection
            }

            if !viewModel.state.jobs.isEmpty {
                queueSection
            }

            if viewModel.state.showsLibreOfficeInstall
                || viewModel.state.libreOfficeInstallPhase.isInProgress
                || viewModel.state.libreOfficeInstallPhase == .succeeded {
                libreOfficeInstallSection
            }

            if viewModel.state.phase == .printing, let progress = viewModel.state.progress {
                progressSection(progress)
            }

            if viewModel.state.phase == .finished {
                finishedSection
            }

            if let errorMessage = viewModel.state.errorMessage,
               viewModel.state.phase != .printing {
                Text(errorMessage)
                    .foregroundStyle(.red)
                    .font(.callout)
            }

            actionButtons
        }
        .padding(28)
        }
        .frame(minWidth: 560, idealWidth: 640, minHeight: 720)
        .onAppear { viewModel.refreshPrinter() }
        .toolbar { toolbarContent }
        .sheet(isPresented: $isHistoryPresented) {
            PrintHistorySheet(
                records: viewModel.state.history,
                onClear: { viewModel.clearHistory() }
            )
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .automatic) {
            Button {
                viewModel.pickFolder()
            } label: {
                Label(String(localized: "button.selectFolder"), systemImage: "folder")
            }
            .disabled(!viewModel.state.isDropEnabled)
            .help(String(localized: "button.selectFolder"))
        }

        ToolbarItem(placement: .automatic) {
            Button {
                viewModel.startPrinting()
            } label: {
                Label(String(localized: "button.startBatchPrint"), systemImage: "printer")
            }
            .disabled(!viewModel.state.canStartPrint)
            .help(String(localized: "button.startBatchPrint"))
        }

        ToolbarItem(placement: .automatic) {
            Button {
                viewModel.cancelPrinting()
            } label: {
                Label(String(localized: "button.cancel"), systemImage: "xmark.circle")
            }
            .disabled(viewModel.state.phase != .printing)
            .help(String(localized: "button.cancel"))
        }

        ToolbarItem(placement: .automatic) {
            printerPicker
                .frame(minWidth: 140, maxWidth: 220)
                .disabled(viewModel.state.phase == .printing)
                .help(String(localized: "printer.pickerHelp"))
        }

        ToolbarItem(placement: .automatic) {
            Button {
                isHistoryPresented = true
            } label: {
                Label(String(localized: "button.history"), systemImage: "clock")
            }
            .help(String(localized: "button.history"))
        }
    }

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(
                String(
                    localized: "summary.fileCount \(viewModel.state.totalCount)"
                )
            )
            .font(.headline)

            kindRow(labelKey: "kind.pdf", count: viewModel.state.pdfCount)
            kindRow(labelKey: "kind.word", count: viewModel.state.wordCount)
            kindRow(labelKey: "kind.excel", count: viewModel.state.excelCount)
            kindRow(labelKey: "kind.images", count: viewModel.state.imageCount)
            kindRow(labelKey: "kind.markdown", count: viewModel.state.markdownCount)
        }
    }

    private func kindRow(labelKey: String.LocalizationValue, count: Int) -> some View {
        HStack {
            Text(String(localized: labelKey))
                .frame(width: 80, alignment: .leading)
            Text("\(count)")
                .monospacedDigit()
            Spacer()
        }
        .font(.body)
    }

    private var sortAndFilterSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(String(localized: "sort.title"))
                Picker(String(localized: "sort.title"), selection: sortBinding) {
                    Text(String(localized: "sort.name")).tag(FileSortOrder.name)
                    Text(String(localized: "sort.kind")).tag(FileSortOrder.kind)
                    Text(String(localized: "sort.path")).tag(FileSortOrder.path)
                }
                .labelsHidden()
                .frame(maxWidth: 160)
                .disabled(viewModel.state.phase == .printing)
            }

            Text(String(localized: "filter.title"))
                .font(.headline)
            HStack(spacing: 12) {
                filterToggle(.pdf, labelKey: "kind.pdf")
                filterToggle(.word, labelKey: "kind.word")
                filterToggle(.excel, labelKey: "kind.excel")
                filterToggle(.image, labelKey: "kind.images")
                filterToggle(.markdown, labelKey: "kind.markdown")
            }
            .disabled(viewModel.state.phase == .printing)
        }
    }

    private func filterToggle(_ kind: FileKind, labelKey: String.LocalizationValue) -> some View {
        Toggle(isOn: kindBinding(kind)) {
            Text(String(localized: labelKey))
        }
        .toggleStyle(.checkbox)
    }

    private var presetSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "preset.title"))
                .font(.headline)
            HStack(spacing: 8) {
                Picker(String(localized: "preset.title"), selection: presetBinding) {
                    Text(String(localized: "preset.none")).tag(UUID?.none)
                    ForEach(viewModel.state.presets) { preset in
                        Text(preset.name).tag(Optional(preset.id))
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 180)
                .disabled(viewModel.state.presets.isEmpty || viewModel.state.phase == .printing)

                TextField(String(localized: "preset.namePlaceholder"), text: $presetName)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 160)
                    .disabled(viewModel.state.phase == .printing)

                Button(String(localized: "button.savePreset")) {
                    viewModel.savePreset(named: presetName)
                    presetName = ""
                }
                .disabled(presetName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    || viewModel.state.phase == .printing)

                Button(String(localized: "button.deletePreset")) {
                    if let id = viewModel.state.selectedPresetID {
                        viewModel.deletePreset(id: id)
                    }
                }
                .disabled(viewModel.state.selectedPresetID == nil || viewModel.state.phase == .printing)
            }
        }
    }

    private var workflowSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: "workflow.title"))
                .font(.headline)

            HStack(spacing: 8) {
                Toggle(isOn: archiveEnabledBinding) {
                    Text(String(localized: "archive.enable"))
                }
                .toggleStyle(.checkbox)
                .disabled(viewModel.state.phase == .printing)

                Text(viewModel.state.archiveFolderName ?? String(localized: "archive.none"))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Button(String(localized: "button.chooseArchiveFolder")) {
                    viewModel.pickArchiveFolder()
                }
                .disabled(viewModel.state.phase == .printing)
            }

            HStack(spacing: 8) {
                Toggle(isOn: hotFolderEnabledBinding) {
                    Text(String(localized: "hotFolder.enable"))
                }
                .toggleStyle(.checkbox)
                .disabled(viewModel.state.phase == .printing)

                Text(viewModel.state.hotFolderName ?? String(localized: "hotFolder.none"))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Button(String(localized: "button.chooseHotFolder")) {
                    viewModel.pickHotFolder()
                }
                .disabled(viewModel.state.phase == .printing)

                Toggle(isOn: hotFolderAutoPrintBinding) {
                    Text(String(localized: "hotFolder.autoPrint"))
                }
                .toggleStyle(.checkbox)
                .disabled(viewModel.state.phase == .printing || !viewModel.state.hotFolderEnabled)
            }
        }
    }

    private var printerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(String(localized: "printer.pickerLabel"))
                printerPicker
                    .frame(maxWidth: 260)
                    .disabled(viewModel.state.phase == .printing)

                Button {
                    viewModel.refreshPrinter()
                } label: {
                    Label(String(localized: "button.refreshPrinters"), systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.state.phase == .printing)
                .help(String(localized: "button.refreshPrinters"))

                Button(String(localized: "button.addNearbyPrinter")) {
                    viewModel.openPrinterSettings()
                }
                .help(String(localized: "button.addNearbyPrinter"))
            }

            if viewModel.state.availablePrinters.isEmpty {
                Text(String(localized: "printer.none"))
                    .font(.callout)
                    .foregroundStyle(.orange)
            }
        }
    }

    private var printOptionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(String(localized: "settings.title"))
                .font(.headline)

            HStack(spacing: 16) {
                HStack(spacing: 8) {
                    Text(String(localized: "settings.copies"))
                    Stepper(
                        value: copiesBinding,
                        in: 1...99
                    ) {
                        Text("\(viewModel.state.printSettings.copies)")
                            .monospacedDigit()
                            .frame(minWidth: 24, alignment: .trailing)
                    }
                }

                HStack(spacing: 8) {
                    Text(String(localized: "settings.duplex"))
                    Picker(String(localized: "settings.duplex"), selection: duplexBinding) {
                        Text(String(localized: "settings.duplex.simplex")).tag(DuplexMode.simplex)
                        Text(String(localized: "settings.duplex.longEdge")).tag(DuplexMode.longEdge)
                        Text(String(localized: "settings.duplex.shortEdge")).tag(DuplexMode.shortEdge)
                    }
                    .labelsHidden()
                    .frame(maxWidth: 160)
                }

                HStack(spacing: 8) {
                    Text(String(localized: "settings.color"))
                    Picker(String(localized: "settings.color"), selection: colorBinding) {
                        Text(String(localized: "settings.color.color")).tag(ColorMode.color)
                        Text(String(localized: "settings.color.blackAndWhite")).tag(ColorMode.blackAndWhite)
                    }
                    .labelsHidden()
                    .frame(maxWidth: 120)
                }
            }
            .disabled(viewModel.state.phase == .printing)

            HStack(spacing: 8) {
                Text(String(localized: "settings.pageRange"))
                TextField(
                    String(localized: "settings.pageRange.placeholder"),
                    text: pageRangeBinding
                )
                .textFieldStyle(.roundedBorder)
                .frame(maxWidth: 180)
                .disabled(viewModel.state.phase == .printing)
            }

            Text(String(localized: "settings.pageRange.hint"))
                .font(.caption)
                .foregroundStyle(.secondary)

            if !viewModel.state.isPageRangeValid {
                Text(String(localized: "error.invalidPageRange"))
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    private var sortBinding: Binding<FileSortOrder> {
        Binding(
            get: { viewModel.state.sortOrder },
            set: { viewModel.setSortOrder($0) }
        )
    }

    private func kindBinding(_ kind: FileKind) -> Binding<Bool> {
        Binding(
            get: { viewModel.state.enabledKinds.contains(kind) },
            set: { viewModel.setKind(kind, enabled: $0) }
        )
    }

    private var presetBinding: Binding<UUID?> {
        Binding(
            get: { viewModel.state.selectedPresetID },
            set: { newValue in
                if let newValue {
                    viewModel.applyPreset(id: newValue)
                }
            }
        )
    }

    private var archiveEnabledBinding: Binding<Bool> {
        Binding(
            get: { viewModel.state.archiveEnabled },
            set: { viewModel.setArchiveEnabled($0) }
        )
    }

    private var hotFolderEnabledBinding: Binding<Bool> {
        Binding(
            get: { viewModel.state.hotFolderEnabled },
            set: { viewModel.setHotFolderEnabled($0) }
        )
    }

    private var hotFolderAutoPrintBinding: Binding<Bool> {
        Binding(
            get: { viewModel.state.hotFolderAutoPrint },
            set: { viewModel.setHotFolderAutoPrint($0) }
        )
    }

    private var copiesBinding: Binding<Int> {
        Binding(
            get: { viewModel.state.printSettings.copies },
            set: { viewModel.setCopies($0) }
        )
    }

    private var duplexBinding: Binding<DuplexMode> {
        Binding(
            get: { viewModel.state.printSettings.duplex },
            set: { viewModel.setDuplex($0) }
        )
    }

    private var colorBinding: Binding<ColorMode> {
        Binding(
            get: { viewModel.state.printSettings.colorMode },
            set: { viewModel.setColorMode($0) }
        )
    }

    private var pageRangeBinding: Binding<String> {
        Binding(
            get: { viewModel.state.printSettings.pageRangeText },
            set: { viewModel.setPageRangeText($0) }
        )
    }

    private var queueSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(String(localized: "queue.title"))
                .font(.headline)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(viewModel.state.jobs) { job in
                        HStack(spacing: 8) {
                            Image(systemName: jobStatusIcon(job.status))
                                .foregroundStyle(jobStatusColor(job.status))
                                .frame(width: 16)
                            Text(job.file.displayName)
                                .lineLimit(1)
                            Spacer()
                            Text(kindLabel(job.file.kind))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(phaseLabel(job.status))
                                .font(.caption)
                                .foregroundStyle(jobStatusColor(job.status))
                            if case .failed = job.status, viewModel.state.phase != .printing {
                                Button(String(localized: "button.retry")) {
                                    viewModel.retryJob(id: job.id)
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                }
            }
            .frame(maxHeight: 180)
        }
    }

    private var printerPicker: some View {
        Picker(String(localized: "printer.pickerLabel"), selection: printerSelection) {
            if viewModel.state.availablePrinters.isEmpty {
                Text(String(localized: "toolbar.printerNone"))
                    .tag(String?.none)
            }
            ForEach(viewModel.state.availablePrinters) { printer in
                Text(printer.name).tag(Optional(printer.name))
            }
        }
        .labelsHidden()
    }

    private var printerSelection: Binding<String?> {
        Binding(
            get: { viewModel.state.printerName },
            set: { newValue in
                if let newValue {
                    viewModel.selectPrinter(newValue)
                }
            }
        )
    }

    private var libreOfficeInstallSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(libreOfficeInstallTitle)
                .font(.callout)
                .foregroundStyle(installTitleColor)

            if viewModel.state.libreOfficeInstallPhase.isInProgress {
                ProgressView(value: installProgressFraction)
                Text(installStatusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button(String(localized: "button.cancelLibreOfficeInstall")) {
                    viewModel.cancelLibreOfficeInstall()
                }
            } else if viewModel.state.libreOfficeInstallPhase == .succeeded {
                Text(String(localized: "libreOffice.installSucceeded"))
                    .font(.caption)
                    .foregroundStyle(.green)
            } else if case .failed(let message) = viewModel.state.libreOfficeInstallPhase {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.red)
                Button(String(localized: "button.installLibreOffice")) {
                    viewModel.installLibreOffice()
                }
                .buttonStyle(.bordered)
            } else if viewModel.state.showsLibreOfficeInstall {
                Button(String(localized: "button.installLibreOffice")) {
                    viewModel.installLibreOffice()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
    }

    private var libreOfficeInstallTitle: String {
        if viewModel.state.isMicrosoftOfficeInstalled {
            String(localized: "libreOffice.installHintWithOffice")
        } else {
            String(localized: "libreOffice.installHint")
        }
    }

    private var installTitleColor: Color {
        if viewModel.state.libreOfficeInstallPhase == .succeeded {
            .secondary
        } else {
            .primary
        }
    }

    private var installProgressFraction: Double {
        switch viewModel.state.libreOfficeInstallPhase {
        case .downloading(let fraction):
            // Reserve the last 15% of the bar for mount/copy steps.
            0.85 * max(0, min(1, fraction))
        case .mounting:
            0.88
        case .copying:
            0.95
        case .cleaningUp:
            0.99
        case .succeeded:
            1
        default:
            0
        }
    }

    private var installStatusText: String {
        switch viewModel.state.libreOfficeInstallPhase {
        case .downloading(let fraction):
            let percent = Int((fraction * 100).rounded())
            return String(localized: "libreOffice.downloading \(percent)")
        case .mounting:
            return String(localized: "libreOffice.mounting")
        case .copying:
            return String(localized: "libreOffice.copying")
        case .cleaningUp:
            return String(localized: "libreOffice.cleaningUp")
        default:
            return ""
        }
    }

    private func progressSection(_ progress: BatchPrintProgress) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ProgressView(
                value: Double(progress.currentIndex),
                total: Double(max(progress.totalCount, 1))
            )
            Text(
                String(
                    localized: "progress.counter \(progress.currentIndex) \(progress.totalCount)"
                )
            )
            .font(.callout)
            if !progress.currentFileName.isEmpty {
                Text(progress.currentFileName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Text(phaseLabel(progress.phase))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var finishedSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let result = viewModel.state.lastResult {
                Text(
                    String(
                        localized: "result.succeeded \(result.succeeded.count)"
                    )
                )
                if !result.failed.isEmpty {
                    Text(
                        String(
                            localized: "result.failed \(result.failed.count)"
                        )
                    )
                    .foregroundStyle(.red)
                }
            }
        }
        .font(.callout)
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            if viewModel.state.phase == .printing {
                Button(String(localized: "button.cancel")) {
                    viewModel.cancelPrinting()
                }
                .keyboardShortcut(.cancelAction)
            } else {
                Button(String(localized: "button.startBatchPrint")) {
                    viewModel.startPrinting()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!viewModel.state.canStartPrint)
                .keyboardShortcut(.defaultAction)

                if viewModel.state.phase == .finished,
                   !viewModel.state.failedFiles.isEmpty {
                    Button(String(localized: "button.retryFailed")) {
                        viewModel.retryFailed()
                    }
                }
            }
            Spacer()
        }
    }

    private func kindLabel(_ kind: FileKind) -> String {
        switch kind {
        case .pdf:
            String(localized: "kind.pdf")
        case .word:
            String(localized: "kind.word")
        case .excel:
            String(localized: "kind.excel")
        case .image:
            String(localized: "kind.images")
        case .markdown:
            String(localized: "kind.markdown")
        }
    }

    private func jobStatusIcon(_ status: PrintJobStatus) -> String {
        switch status {
        case .pending:
            "circle"
        case .converting, .printing:
            "arrow.triangle.2.circlepath"
        case .succeeded:
            "checkmark.circle.fill"
        case .failed:
            "xmark.circle.fill"
        }
    }

    private func jobStatusColor(_ status: PrintJobStatus) -> Color {
        switch status {
        case .pending:
            .secondary
        case .converting, .printing:
            .accentColor
        case .succeeded:
            .green
        case .failed:
            .red
        }
    }

    private func phaseLabel(_ phase: PrintJobStatus) -> String {
        switch phase {
        case .pending:
            String(localized: "phase.pending")
        case .converting:
            String(localized: "phase.converting")
        case .printing:
            String(localized: "phase.printing")
        case .succeeded:
            String(localized: "phase.succeeded")
        case .failed:
            String(localized: "phase.failed")
        }
    }
}

#Preview {
    BatchPrintView(viewModel: AppContainer.live.makeBatchPrintViewModel())
}
