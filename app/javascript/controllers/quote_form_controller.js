import { Controller } from "@hotwired/stimulus"

const BOX_SELECTOR = ".qsearch-field, .qsearch-age, .qbar-field, .qbar-age"
const MAX_AGES = 6
const DEFAULT_AGES = 4

// Formulario de cotización en una sola pantalla.
// Las edades son casillas en línea: al menos una debe completarse; el resto es
// opcional. `travelers_count` se sincroniza con la cantidad de edades informadas.
//
// En la landing arrancan visibles DEFAULT_AGES casillas y el botón (+) revela
// las siguientes; el target `addAge` es opcional, así el mismo controlador
// sigue sirviendo al formulario del productor, donde están todas a la vista.
export default class extends Controller {
  static targets = ["ages", "count", "addAge"]

  connect() {
    this.visibleAges = Math.max(DEFAULT_AGES, this.filledAges.length)
    this.render()
  }

  addAge() {
    this.visibleAges = Math.min(MAX_AGES, this.visibleAges + 1)
    this.render()
  }

  sync() {
    this.render()
  }

  render() {
    if (!this.hasAgesTarget) return

    this.ageFields.forEach((field, index) => {
      const input = field.querySelector("input")
      if (input) input.setAttribute("aria-label", `Edad del pasajero ${index + 1}`)

      // Sólo se ocultan donde hay botón (+): sin él todas están a la vista
      if (this.hasAddAgeTarget) field.classList.toggle("hidden", index >= this.visibleAges)
    })

    if (this.hasCountTarget) this.countTarget.value = this.filledAges.length
    if (this.hasAddAgeTarget) this.addAgeTarget.disabled = this.visibleAges >= MAX_AGES
  }

  clearError(event) {
    const agesBox = this.hasAgesTarget ? this.agesTarget.closest(BOX_SELECTOR) : null
    if (agesBox) agesBox.classList.remove("qbar-invalid")

    const box = event.target.closest(BOX_SELECTOR)
    if (box) box.classList.remove("qbar-invalid")
    event.target.classList.remove("qbar-invalid")
  }

  validate(event) {
    let firstInvalid = null

    if (this.hasAgesTarget && this.filledAges.length === 0) {
      this.agesTarget.closest(BOX_SELECTOR)?.classList.add("qbar-invalid")
      firstInvalid = this.ageInputs[0]
    }

    this.element.querySelectorAll("[required]").forEach((input) => {
      if (input.closest("[data-age-field]")) return

      const box = input.closest(BOX_SELECTOR) || input
      if (input.value.trim()) {
        box.classList.remove("qbar-invalid")
        return
      }

      box.classList.add("qbar-invalid")
      if (!firstInvalid) firstInvalid = input
    })

    if (!firstInvalid) {
      this.render()
      return
    }

    event.preventDefault()
    firstInvalid.focus()
  }

  get ageFields() {
    return this.hasAgesTarget ? Array.from(this.agesTarget.querySelectorAll("[data-age-field]")) : []
  }

  get ageInputs() {
    return this.ageFields.map((field) => field.querySelector("input")).filter(Boolean)
  }

  get filledAges() {
    return this.ageFields
      .filter((field) => !this.hasAddAgeTarget || !field.classList.contains("hidden"))
      .map((field) => field.querySelector("input")?.value.trim())
      .filter(Boolean)
  }
}
