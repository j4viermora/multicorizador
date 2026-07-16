import { Controller } from "@hotwired/stimulus"

// Wraps the Flowbite datepicker (flowbite-datepicker, loaded via CDN as window.Datepicker).
// es locale, ISO yyyy-mm-dd values (so Rails parses them natively), autohide, week starts Monday.
// Optional data attributes:
//   data-datepicker-min-value="2026-07-15"  -> minimum selectable date
//   data-datepicker-max-value="2026-12-31"  -> maximum selectable date
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
