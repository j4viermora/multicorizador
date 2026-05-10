import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "step", "stepDot", "stepLine", "stepLabel",
    "prevBtn", "nextBtn", "submitBtn",
    "agesContainer", "stepContainer"
  ]
  static values = { current: { type: Number, default: 0 } }

  connect() {
    this.totalSteps = this.stepTargets.length
    this.showStep(this.currentValue, "none")
  }

  next() {
    if (!this.validateCurrentStep()) return
    if (this.currentValue < this.totalSteps - 1) {
      this.currentValue++
      this.showStep(this.currentValue, "forward")
    }
  }

  prev() {
    if (this.currentValue > 0) {
      this.currentValue--
      this.showStep(this.currentValue, "backward")
    }
  }

  showStep(index, direction) {
    this.stepTargets.forEach((step, i) => {
      step.classList.remove("is-active", "slide-out-left")
      if (i === index) {
        step.classList.add("is-active")
      } else if (direction === "forward" && i < index) {
        step.classList.add("slide-out-left")
      }
    })

    this.stepDotTargets.forEach((dot, i) => {
      dot.classList.remove("is-active", "is-complete")
      if (i === index) {
        dot.classList.add("is-active")
        dot.innerHTML = `<span>${i + 1}</span>`
      } else if (i < index) {
        dot.classList.add("is-complete")
        dot.innerHTML = `<svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" fill="none" viewBox="0 0 24 24" stroke="currentColor" stroke-width="3"><path stroke-linecap="round" stroke-linejoin="round" d="M5 13l4 4L19 7" /></svg>`
      } else {
        dot.innerHTML = `<span>${i + 1}</span>`
      }
    })

    this.stepLineTargets.forEach((line, i) => {
      line.classList.toggle("is-complete", i < index)
    })

    this.stepLabelTargets.forEach((label, i) => {
      label.classList.toggle("is-active", i === index)
    })

    this.prevBtnTarget.classList.toggle("invisible", index === 0)
    this.nextBtnTarget.classList.toggle("hidden", index === this.totalSteps - 1)
    this.submitBtnTarget.classList.toggle("hidden", index !== this.totalSteps - 1)

    if (this.hasStepContainerTarget) {
      const activeStep = this.stepTargets[index]
      requestAnimationFrame(() => {
        this.stepContainerTarget.style.minHeight = `${activeStep.offsetHeight}px`
      })
    }
  }

  validateCurrentStep() {
    const currentStep = this.stepTargets[this.currentValue]
    const requiredInputs = currentStep.querySelectorAll("[required]")
    let valid = true
    let firstInvalid = null

    requiredInputs.forEach((input) => {
      if (!input.value || !input.value.trim()) {
        input.classList.add("input-error")
        const card = input.closest(".wizard-age-card")
        if (card) card.style.borderColor = "var(--wz-coral)"
        if (!firstInvalid) firstInvalid = input
        valid = false
      } else {
        input.classList.remove("input-error")
        const card = input.closest(".wizard-age-card")
        if (card) card.style.borderColor = ""
      }
    })

    if (firstInvalid) firstInvalid.focus()
    return valid
  }

  clearError(event) {
    event.target.classList.remove("input-error")
    const card = event.target.closest(".wizard-age-card")
    if (card) card.style.borderColor = ""
  }

  updateAges() {
    const count = parseInt(this.element.querySelector("[data-travelers-count]")?.value) || 1
    const clamped = Math.min(Math.max(count, 1), 10)
    const container = this.agesContainerTarget
    const existing = container.querySelectorAll("[data-age-field]")

    for (let i = existing.length; i < clamped; i++) {
      const wrapper = document.createElement("div")
      wrapper.setAttribute("data-age-field", "")
      wrapper.className = "wizard-age-card age-field-enter"
      wrapper.innerHTML = `
        <label>Pasajero ${i + 1}</label>
        <input type="number" name="quote[metadata][ages][]" min="0" max="120"
               placeholder="—" required
               data-action="focus->quote-wizard#clearError" />
      `
      container.appendChild(wrapper)
    }

    const fields = container.querySelectorAll("[data-age-field]")
    for (let i = fields.length - 1; i >= clamped; i--) {
      fields[i].remove()
    }
  }
}
