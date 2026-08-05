import { Controller } from "@hotwired/stimulus"

// Formulario de cotización en una sola pantalla.
// Las edades son inputs fijos: al menos uno debe completarse; el resto es opcional.
// `travelers_count` se sincroniza con la cantidad de edades informadas.
export default class extends Controller {
  static targets = ["ages", "count"]

  connect() {
    this.sync()
  }

  sync() {
    const fields = this.ageFields
    let filledCount = 0

    fields.forEach((field, index) => {
      const input = field.querySelector("input")
      if (!input) return

      input.setAttribute("aria-label", `Edad del pasajero ${index + 1}`)
      if (input.value.trim()) filledCount += 1
    })

    if (this.hasCountTarget) this.countTarget.value = filledCount
  }

  clearError(event) {
    const agesBox = this.hasAgesTarget ? this.agesTarget.closest(".qbar-field") : null
    if (agesBox) agesBox.classList.remove("qbar-invalid")

    const box = event.target.closest(".qbar-field, .qbar-age")
    if (box) box.classList.remove("qbar-invalid")
    event.target.classList.remove("qbar-invalid")
  }

  validate(event) {
    let firstInvalid = null

    if (this.hasAgesTarget) {
      const ageInputs = this.ageFields.map((field) => field.querySelector("input")).filter(Boolean)
      const filledCount = ageInputs.filter((input) => input.value.trim()).length
      const agesBox = this.agesTarget.closest(".qbar-field")

      if (filledCount === 0) {
        agesBox?.classList.add("qbar-invalid")
        firstInvalid = ageInputs[0]
      } else {
        agesBox?.classList.remove("qbar-invalid")
      }
    }

    this.element.querySelectorAll("[required]").forEach((input) => {
      if (input.closest("[data-age-field]")) return

      const box = input.closest(".qbar-field, .qbar-age") || input
      if (input.value.trim()) {
        box.classList.remove("qbar-invalid")
        return
      }

      box.classList.add("qbar-invalid")
      if (!firstInvalid) firstInvalid = input
    })

    if (!firstInvalid) {
      this.sync()
      return
    }

    event.preventDefault()
    firstInvalid.focus()
  }

  get ageFields() {
    return Array.from(this.agesTarget.querySelectorAll("[data-age-field]"))
  }
}
