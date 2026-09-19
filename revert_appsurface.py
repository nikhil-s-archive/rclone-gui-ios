import re

with open("Rclone GUI/Views/Shared/AppUIComponents.swift", "r") as f:
    content = f.read()

new_func = """    @ViewBuilder
    func appGlassSurface(cornerRadius: CGFloat = AppSurface.cornerRadius, interactive: Bool = false) -> some View {
        #if os(iOS)
        if #available(iOS 26.0, *) {
            if interactive {
                self
                    .background(.ultraThinMaterial, in: .rect(cornerRadius: cornerRadius, style: .continuous))
                    .glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius, style: .continuous))
            } else {
                self
                    .background(.ultraThinMaterial, in: .rect(cornerRadius: cornerRadius, style: .continuous))
                    .glassEffect(.regular, in: .rect(cornerRadius: cornerRadius, style: .continuous))
            }
        } else {
            self
                .background(.thinMaterial, in: .rect(cornerRadius: cornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(.quaternary)
                }
        }
        #else
        self
            .background(.thinMaterial, in: .rect(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(.quaternary)
            }
        #endif
    }"""

pattern = r"    @ViewBuilder\n    func appGlassSurface.*?#endif\n    \}"
content = re.sub(pattern, new_func, content, flags=re.DOTALL)

with open("Rclone GUI/Views/Shared/AppUIComponents.swift", "w") as f:
    f.write(content)
