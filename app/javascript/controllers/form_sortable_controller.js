import { Controller } from "@hotwired/stimulus"
import Sortable from "https://esm.sh/sortablejs@1.15.7?standalone"

export default class extends Controller {
  connect() {
    this.sortable = new Sortable(this.element, {
      handle: ".drag-handle", // Only drag via the ☰ icon
      animation: 150,
      ghostClass: "sortable-ghost",
      onEnd: this.updateOrder.bind(this)
    })
  }

  disconnect() {
    if (this.sortable) {
      this.sortable.destroy()
    }
  }

  updateOrder() {
    // Find all chapter fields inside the container
    const items = this.element.querySelectorAll(".chapter-field")
    
    let currentOrder = 0
    items.forEach((item) => {
      // Skip items that have been "Removed" but not yet saved (display: none)
      if (item.style.display !== "none") {
        const orderInput = item.querySelector(".order-input")
        if (orderInput) {
          orderInput.value = currentOrder
        }
        currentOrder++
      }
    })
  }
}