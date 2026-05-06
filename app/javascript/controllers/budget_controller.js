import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  // We define the elements we need to watch/update
  static targets = [ "paperCount", "costDisplay", "chapter" ]
  // We pass the pricing from Rails to JS via values
  static values = { paperCost: Number, chapterCost: Number }

  connect() {
    this.calculate()
  }

  // Stimulus 3 automatically fires this when a new chapter target is added to the DOM!
  chapterTargetConnected() {
    this.calculate()
  }

  chapterTargetDisconnected() {
    this.calculate()
  }

  calculate() {
    const paperCount = parseInt(this.paperCountTarget.value) || 0
    
    // Count how many chapters are actually visible (not removed)
    let activeChapters = 0
    this.chapterTargets.forEach(el => {
      if (el.style.display !== 'none') {
        activeChapters++
      }
    })

    const total = (paperCount * this.paperCostValue) + (activeChapters * this.chapterCostValue)
    
    // Update the HTML span with the formatted price
    this.costDisplayTarget.textContent = total.toFixed(2)
  }
}