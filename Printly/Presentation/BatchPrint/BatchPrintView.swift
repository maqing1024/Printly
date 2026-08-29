import SwiftUI

/// Main batch print screen matching the MVP wireframe.
struct BatchPrintView: View {
    @StateObject private var viewModel: BatchPrintViewModel

    init(viewModel: BatchPrintViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(String(localized: "app.title"))
                .font(.largeTitle.bold())
                .frame(maxWidth: .infinity)

            FolderDropZone(
                isEnabled: viewModel.state.isDropEnabled,
                onFolderDropped: { viewModel.handleFolderDrop($0) },
                onClick: { viewModel.pickFolder() }
            )

            if viewModel.state.phase == .scanning {
                ProgressView(String(localized: "status.scanning"))
                    .frame(maxWidth: .infinity)
            }

            if !viewModel.state.files.isEmpty || viewModel.state.phase == .ready {
                summarySection
            }

            printerSection

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
        .frame(minWidth: 420, idealWidth: 480, minHeight: 520)
        .onAppear { viewModel.refreshPrinter() }
        .toolbar { toolbarContent }
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
