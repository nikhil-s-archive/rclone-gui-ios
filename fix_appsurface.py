with open("Rclone GUI/Views/Shared/AppUIComponents.swift", "r") as f:
    content = f.read()

import re

# We will replace the whole appGlassSurface function.

new_func = """    @ViewBuilder
    func appGlassSurface(cornerRadius: CGFloat = AppSurface.cornerRadius, interactive: Bool = false) -> some View {
        #if os(iOS)
        if #available(iOS 17.0, *) {
            self
                .background(.ultraThinMaterial, in: .rect(cornerRadius: cornerRadius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(LinearGradient(
                            colors: [.white.opacity(0.4), .white.opacity(0.0)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ), lineWidth: 0.5)
                        .blendMode(.overlay)
                }
                .shadow(color: .black.opacity(interactive ? 0.1 : 0.05), radius: interactive ? 8 : 4, x: 0, y: interactive ? 4 : 2)
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

# Find the start of func appGlassSurface and the end of it
pattern = r"    @ViewBuilder\n    func appGlassSurface.*?#endif\n    \}"
content = re.sub(pattern, new_func, content, flags=re.DOTALL)

with open("Rclone GUI/Views/Shared/AppUIComponents.swift", "w") as f:
    f.write(content)
