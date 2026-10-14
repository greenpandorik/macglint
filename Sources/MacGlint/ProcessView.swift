import SwiftUI
import MacGlintCore

struct ProcessView: View {
    @ObservedObject var store: AppStore
    @FocusState private var searchFocused: Bool
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Приложение, процесс или PID", text: $store.search).textFieldStyle(.plain).focused($searchFocused)
                if !store.search.isEmpty {
                    Button { store.search = "" } label: { Image(systemName: "xmark.circle.fill") }.buttonStyle(.plain).accessibilityLabel("Очистить поиск")
                }
                Toggle("Только мои", isOn: $store.onlyMine).toggleStyle(.checkbox).font(.caption)
                    .help("Показывать процессы текущего пользователя")
            }.padding(10).background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8)).padding(.bottom, 12)
            HStack {
                Text("Приложение / процесс"); Spacer()
                Button("CPU " + (store.sortMemory ? "" : "↓")) { store.sortMemory = false }.frame(width: 70, alignment: .trailing)
                Button("Память " + (store.sortMemory ? "↓" : "")) { store.sortMemory = true }.frame(width: 90, alignment: .trailing)
            }.font(.caption.weight(.medium)).foregroundStyle(.secondary).buttonStyle(.plain).padding(.horizontal, 12).padding(.bottom, 8)
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(store.groups) { group in
                        groupRow(group)
                        if store.expandedGroups.contains(group.id) {
                            ForEach(group.processes) { process in processRow(process) }
                        }
                    }
                    if store.groups.isEmpty {
                        VStack(spacing: 8) {
                            Text(store.processes.isEmpty ? "Собираем список процессов…" : "Ничего не найдено").font(.headline)
                            if !store.search.isEmpty { Button("Очистить поиск") { store.search = "" } }
                        }.foregroundStyle(.secondary).padding(30)
                    }
                }
            }
            if let selected = store.selected { inspector(selected).padding(.top, 12) }
            HStack {
                Text("CPU — доля мощности всего Mac")
                Spacer()
                Text("Показано процессов: \(store.groups.reduce(0) { $0 + $1.processes.count })")
            }.font(.caption).foregroundStyle(.secondary).padding(.vertical, 10)
        }.padding(.horizontal, 24)
        .background(Button("") { searchFocused = true }.keyboardShortcut("f", modifiers: .command).hidden().accessibilityHidden(true))
    }
    private func groupRow(_ group: ProcessGroup) -> some View {
        HStack(spacing: 8) {
            Button {
                if store.expandedGroups.contains(group.id) { store.expandedGroups.remove(group.id) } else { store.expandedGroups.insert(group.id) }
            } label: {
                Image(systemName: store.expandedGroups.contains(group.id) ? "chevron.down" : "chevron.right")
                    .font(.system(size: 11, weight: .semibold)).frame(width: 24, height: 32).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityLabel((store.expandedGroups.contains(group.id) ? "Свернуть " : "Раскрыть ") + group.name)
            Button {
                if let process = group.processes.first { store.choose(process); store.expandedGroups.insert(group.id) }
            } label: {
                HStack(spacing: 10) {
                    AppIcon(key: group.id)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(group.name).font(.system(size: 13, weight: .medium)).lineLimit(1)
                        if group.processes.count > 1 { Text("Процессов: \(group.processes.count)").font(.caption).foregroundStyle(.secondary) }
                    }
                    Spacer(minLength: 8)
                    Text(Format.percent(group.cpu)).monospacedDigit().frame(width: 70, alignment: .trailing)
                    Text(Format.bytes(group.memoryBytes)).monospacedDigit().frame(width: 90, alignment: .trailing)
                }.contentShape(Rectangle())
            }.buttonStyle(.plain)
        }.padding(.horizontal, 10).padding(.vertical, 6)
    }
    private func processRow(_ process: ProcessSample) -> some View {
        Button { store.choose(process) } label: {
            HStack(spacing: 10) {
                Image(systemName: "arrow.turn.down.right").foregroundStyle(.secondary).frame(width: 20)
                VStack(alignment: .leading, spacing: 3) {
                    Text(process.name).font(.system(size: 12)).lineLimit(1)
                    Text("PID \(process.identity.pid)").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text(Format.percent(process.cpu)).monospacedDigit().frame(width: 70, alignment: .trailing)
                Text(Format.bytes(process.memoryBytes)).monospacedDigit().frame(width: 90, alignment: .trailing)
            }.padding(.leading, 32).padding(.trailing, 10).padding(.vertical, 8)
                .background(store.selected?.identity == process.identity ? Color.blue.opacity(0.15) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
        }.buttonStyle(.plain).accessibilityAddTraits(store.selected?.identity == process.identity ? .isSelected : [])
    }
    private func inspector(_ process: ProcessSample) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(process.name).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                    Text("PID \(process.identity.pid) · " + (store.selectedIsLive ? "Процесс активен" : "Процесс завершён")).font(.caption).foregroundStyle(.secondary)
                    Text("CPU " + Format.percent(process.cpu) + " · память " + Format.bytes(process.memoryBytes)).font(.caption).monospacedDigit()
                }.frame(maxWidth: .infinity, alignment: .leading)
                VStack(alignment: .trailing, spacing: 3) {
                    Sparkline(values: store.selectedTrace().map(\.value)).frame(width: 90, height: 28)
                    Text("CPU · до 2 мин").font(.caption2).foregroundStyle(.secondary)
                }
                Menu {
                    Button("Завершить процесс…") { store.terminateSelected(force: false) }
                    Button("Завершить принудительно…", role: .destructive) { store.terminateSelected(force: true) }
                } label: { Text("Завершить…") }.disabled(!store.mayTerminate).frame(width: 125)
                    .help(store.mayTerminate ? "Выбрать способ завершения" : "Завершение недоступно для защищённых, чужих и уже завершённых процессов, а также самого MacGlint")
                Button { store.selected = nil } label: { Image(systemName: "xmark") }.buttonStyle(.plain).accessibilityLabel("Закрыть сведения о процессе")
            }
            if process.name.localizedCaseInsensitiveContains("webkit") || process.appName == "Safari" {
                Text("Связь с конкретной вкладкой Safari не определена.").font(.caption).foregroundStyle(.secondary)
            }
            Text(process.path.isEmpty ? "Путь недоступен" : process.path).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle).textSelection(.enabled)
        }
    }
}
