// Hints in the panel the first times it is used: Context, 📷, the dialog. See docs/specs/05-ui.md §1.

import SwiftUI
import TipKit

struct ContextTip: Tip {
  var title: Text { Text("Add who you're writing to") }
  var message: Text? {
    Text(
      "Who it's for, what about, or the message you're replying to. Type or paste it, or paste "
        + "a screenshot. The check takes it into account.")
  }
  var image: Image? { Image(systemName: "text.bubble") }
}

struct CaptureTip: Tip {
  var title: Text { Text("Capture this window") }
  var message: Text? {
    Text("The camera button adds a screenshot of the window you're writing in.")
  }
  var image: Image? { Image(systemName: "camera") }
}

struct DialogTip: Tip {
  var title: Text { Text("Ask or tell what to change") }
  var message: Text? {
    Text("Ask whether the text sounds right, or ask for a change, in any language.")
  }
  var image: Image? { Image(systemName: "bubble.left.and.text.bubble.right") }
}
