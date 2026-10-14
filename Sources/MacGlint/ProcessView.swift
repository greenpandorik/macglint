import SwiftUI
import Charts
import MacGlintCore

struct ProcessView: View {
    @ObservedObject var store: AppStore
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Найти приложение, процесс или PID", text: $store.search).textFieldStyle(.plain)
                Toggle("Только мои", isOn: $store.onlyMine).toggleStyle(.checkbox).font(.caption)
            }.padding(10).background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8)).padding(.bottom, 12)
            HStack {
                Text("Приложение / процесс"); Spacer()
                Button("CPU " + (store.sortMemory ? "" : "↓")) { store.sortMemory = false }.frame(width: 80, alignment: .trailing)
                Button("Память " + (store.sortMemory ? "↓" : "")) { store.sortMemory = true }.frame(width: 105, alignment: .trailing)
            }.font(.system(size: 11, weight: .medium)).foregroundStyle(.secondary).buttonStyle(.plain).padding(.horizontal, 12).padding(.bottom, 8)
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(store.groups) { group in
                        groupRow(group)
                        if store.expandedGroups.contains(group.id) {
                            ForEach(group.processes) { process in processRow(process) }
                        }
                    }
                    if store.groups.isEmpty { Text("Ничего не найдено").foregroundStyle(.secondary).padding(30) }
                }
            }.background(.quaternary.opacity(0.15), in: RoundedRectangle(cornerRadius: 10))
            if let selected = store.selected { inspector(selected).padding(.top, 13) }
            HStack { Text("CPU — доля общей мощности Mac · память — физический footprint"); Spacer(); Text("\(store.processes.count) процессов") }
                .font(.system(size: 9)).foregroundStyle(.secondary).padding(.vertical, 10)
        }.padding(.horizontal, 24)
    }
    private func groupRow(_ group: ProcessGroup) -> some View {
        HStack(spacing: 10) {
            Button {
                if store.expandedGroups.contains(group.id) { store.expandedGroups.remove(group.id) } else { store.expandedGroups.insert(group.id) }
            } label: { Image(systemName: store.expandedGroups.contains(group.id) ? "chevron.down" : "chevron.right").font(.system(size: 10, weight: .semibold)).frame(width: 14, height: 28) }
                .buttonStyle(.plain).accessibilityLabel("Раскрыть " + group.name)
            AppIcon(key: group.id)
            VStack(alignment: .leading, spacing: 2) {
                Text(group.name).font(.system(size: 13, weight: .medium)).lineLimit(1)
                if group.processes.count > 1 { Text("\(group.processes.count) процессов").font(.system(size: 9)).foregroundStyle(.secondary) }
            }
            Spacer(minLength: 10)
            Text(Format.percent(group.cpu)).monospacedDigit().frame(width: 70, alignment: .trailing)
            Text(Format.bytes(group.memoryBytes)).monospacedDigit().frame(width: 105, alignment: .trailing)
        }.padding(.horizontal, 12).padding(.vertical, 8).contentShape(Rectangle())
            .onTapGesture { if let process = group.processes.first { store.choose(process); store.expandedGroups.insert(group.id) } }
    }
    private func processRow(_ process: ProcessSample) -> some View {
        Button { store.choose(process) } label: {
            HStack(spacing: 10) {
                Image(systemName: "arrow.turn.down.right").foregroundStyle(.tertiary).frame(width: 24)
                VStack(alignment: .leading, spacing: 3) {
                    Text(process.name).font(.system(size: 12)).lineLimit(1)
                    Text("PID \(process.identity.pid)").font(.system(size: 10)).foregroundStyle(.secondary)
                }
                Spacer()
                Text(Format.percent(process.cpu)).monospacedDigit().frame(width: 70, alignment: .trailing)
                Text(Format.bytes(process.memoryBytes)).monospacedDigit().frame(width: 105, alignment: .trailing)
            }.padding(.leading, 35).padding(.trailing, 12).padding(.vertical, 8)
                .background(store.selected?.identity == process.identity ? Color.blue.opacity(0.15) : Color.clear, in: RoundedRectangle(cornerRadius: 6))
        }.buttonStyle(.plain)
    }
    private func inspector(_ process: ProcessSample) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()
            HStack(alignment: .center, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(process.name).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                    Text("PID \(process.identity.pid) · " + (store.selectedIsLive ? "Процесс активен" : "Процесс завершён")).font(.caption).foregroundStyle(.secondary)
                    if process.name.localizedCaseInsensitiveContains("webkit") || process.appName == "Safari" {
                        Text("Привязка к вкладке не определена").font(.system(size: 10)).foregroundStyle(.secondary)
                    }
                }.frame(maxWidth: .infinity, alignment: .leading)
                Sparkline(values: store.selectedTrace().map(\.value)).frame(width: 120, height: 35)
                Menu {
                    Button("Завершить процесс…") { store.terminateSelected(force: false) }
                    Button("Завершить принудительно…", role: .destructive) { store.terminateSelected(force: true) }
                } label: { Text("Завершить…") }.disabled(!store.mayTerminate).frame(width: 140)
            }
            Text(process.path.isEmpty ? "Путь недоступен" : process.path).font(.system(size: 9)).foregroundStyle(.tertiary).lineLimit(1).truncationMode(.middle).textSelection(.enabled)
        }
    }
}
