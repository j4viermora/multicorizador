import { Controller } from "@hotwired/stimulus"

// Wraps the Flowbite datepicker (flowbite-datepicker, loaded via CDN as window.Datepicker).
// es locale, ISO yyyy-mm-dd values (so Rails parses them natively), autohide, week starts Monday.
// Optional data attributes:
//   data-datepicker-min-value="2026-07-15"  -> minimum selectable date
//   data-datepicker-max-value="2026-12-31"  -> maximum selectable date
// El bundle `datepicker-full` sólo trae el locale `en`: los demás viven en
// archivos aparte (dist/js/locales/*.js). Lo registramos acá para no depender
// de otra request al CDN — sin esto `language: "es"` cae de vuelta en inglés.
const ES_LOCALE = {
  days: ["Domingo", "Lunes", "Martes", "Miércoles", "Jueves", "Viernes", "Sábado"],
  daysShort: ["Dom", "Lun", "Mar", "Mié", "Jue", "Vie", "Sáb"],
  daysMin: ["Do", "Lu", "Ma", "Mi", "Ju", "Vi", "Sá"],
  months: [
    "Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio",
    "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"
  ],
  monthsShort: ["Ene", "Feb", "Mar", "Abr", "May", "Jun", "Jul", "Ago", "Sep", "Oct", "Nov", "Dic"],
  today: "Hoy",
  monthsTitle: "Meses",
  clear: "Borrar",
  weekStart: 1,
  format: "dd/mm/yyyy"
}

export default class extends Controller {
  static values = {
    min: String,
    max: String,
    format: { type: String, default: "yyyy-mm-dd" }
  }

  connect() {
    const Datepicker = window.Datepicker
    if (!Datepicker) {
      console.warn("[datepicker] window.Datepicker is not loaded (check CDN script)")
      return
    }

    if (Datepicker.locales && !Datepicker.locales.es) Datepicker.locales.es = ES_LOCALE

    const options = {
      format: this.formatValue,
      language: "es",
      autohide: true,
      todayHighlight: true,
      weekStart: 1,
      orientation: "bottom",
      buttonClass: "button"
    }
    if (this.hasMinValue && this.minValue) options.minDate = this.minValue
    if (this.hasMaxValue && this.maxValue) options.maxDate = this.maxValue

    try {
      this.instance = new Datepicker(this.element, options)
    } catch (error) {
      console.warn("[datepicker] failed to initialise", error)
    }
  }

  disconnect() {
    if (this.instance && typeof this.instance.destroy === "function") {
      this.instance.destroy()
    }
    this.instance = null
  }
}
