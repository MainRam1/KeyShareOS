import SwiftUI

/// Step list editor for macros. Add, delete, reorder steps.
struct MacroStepEditor: View {
    @Binding var steps: [MacroStepModel]

    var body: some View {
        Section("Macro Steps") {
            if steps.isEmpty {
                emptyState
            } else {
                stepList
            }
            addButtons
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "plus.circle")
                .font(.system(size: 32))
                .foregroundColor(.secondary)
            Text("Add your first step to build a macro sequence")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var stepList: some View {
        List {
            ForEach($steps) { $step in
                HStack {
                    if step.isDelay {
                        DelayStepRow(step: $step)
                    } else {
                        ActionStepRow(step: $step)
                    }
                    Spacer()
                    Button(role: .destructive) {
                        steps.removeAll(where: { $0.id == step.id })
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                }
            }
            .onMove(perform: moveStep)
        }
        .frame(minHeight: 120, maxHeight: 240)
    }

    @ViewBuilder
    private var addButtons: some View {
        HStack {
            Button {
                steps.append(MacroStepModel.newAction())
            } label: {
                Label("Add Action Step", systemImage: "plus")
            }
            .disabled(steps.count >= MacroAction.maxSteps)

            Button {
                steps.append(MacroStepModel.newDelay())
            } label: {
                Label("Add Delay", systemImage: "clock")
            }
            .disabled(steps.count >= MacroAction.maxSteps)
        }
    }

    private func moveStep(from source: IndexSet, to destination: Int) {
        steps.move(fromOffsets: source, toOffset: destination)
    }
}
