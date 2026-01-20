//
//  Created by Alex.M on 20.06.2022.
//

import SwiftUI
import UIKit

struct AttachmentsPage: View {

    @EnvironmentObject var mediaPagesViewModel: FullscreenMediaPagesViewModel
    @Environment(\.chatTheme) private var theme

    let attachment: Attachment

    var body: some View {
        if attachment.type == .gif {
            ChatAnimatedGifView(url: attachment.full, size: CGSize(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height * 0.7))
                .aspectRatio(contentMode: .fit)
        } else if attachment.type == .image {
            CachedAsyncImage(
                url: attachment.full,
                cacheKey: attachment.fullCacheKey
            ) { phase in
                switch phase {
                case let .success(image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                default:
                    ActivityIndicator()
                }
            }
        } else if attachment.type == .video {
            VideoView(viewModel: VideoViewModel(attachment: attachment))
        } else {
            Rectangle()
                .foregroundColor(Color.gray)
                .frame(minWidth: 100, minHeight: 100)
                .frame(maxHeight: 200)
                .overlay {
                    Text("Unknown", bundle: .module)
                }
        }
    }
}
