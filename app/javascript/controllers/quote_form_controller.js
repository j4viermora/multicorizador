import { Controller } from "@hotwired/stimulus"

// Formulario de cotización en una sola pantalla.
// Maneja las cajitas de edad (una por pasajero), mantiene `travelers_count`
// sincronizado con ellas y valida los campos obligatorios al enviar
// (los formularios son `novalidate`, así que la validación es nuestra).
export default class extends Controller {
  static targets = ["ages", "count", "addBtn"]
  static values = { max: { type: Number, default: 10 } }

  connect() {
    this.sync()
  }

  add() {
    if (this.ageFields.length >= this.maxValue) return

    const field = document.createElement("div")
    field.className = "qbar-age age-field-enter"
    field.setAttribute("data-age-field", "")
    field.innerHTML = `
      <input type="number" name="quote[metadata][ages][]" min="0" max="120"
             placeholder="—" required inputmode="numeric"
             data-action="focus->quote-form#clearError">
      <button type="button" class="qbar-age-remove" tabindex="-1"
              aria-label="Quitar pasajero" data-action="quote-form#remove">
        <i class="ti ti-x"></i>
      </button>`

    this.agesTarget.appendChild(field)
    this.sync()
    field.querySelector("input").focus()
  }

  remove(event) {
    if (this.ageFields.length <= 1) return
    event.target.closest("[data-age-field]").remove()
    this.sync()
  }

  clearError(event) {
    const box = event.target.closest(".qbar-field, .qbar-age")
    if (box) box.classList.remove("qbar-invalid")
    event.target.classList.remove("qbar-invalid")
  }

  validate(event) {
    let firstInvalid = null

    this.element.querySelectorAll("[required]").forEach((input) => {
      const box = input.closest(".qbar-field, .qbar-age") || input
      if (input.value.trim()) {
        box.classList.remove("qbar-invalid")
        return
      }
      box.classList.add("qbar-invalid")
      if (!firstInvalid) firstInvalid = input
    })

    if (!firstInvalid) return

    event.preventDefault()
    firstInvalid.focus()
  }

  sync() {
    const fields = this.ageFields

    fields.forEach((field, index) => {
      const input = field.querySelector("input")
      if (input) input.setAttribute("aria-label", `Edad del pasajero ${index + 1}`)

      const removeBtn = field.querySelector(".qbar-age-remove")
      if (removeBtn) removeBtn.classList.toggle("hidden", fields.length === 1)
    })

    if (this.hasCountTarget) this.countTarget.value = fields.length
    if (this.hasAddBtnTarget) this.addBtnTarget.disabled = fields.length >= this.maxValue
  }

  get ageFields() {
    return Array.from(this.agesTarget.querySelectorAll("[data-age-field]"))
  }
}
