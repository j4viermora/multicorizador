import { Controller } from "@hotwired/stimulus"

/**
 * Country/region autocomplete controller.
 *
 * Usage:
 *   <div data-controller="country-autocomplete"
 *        data-country-autocomplete-items-value='[{"name":"Argentina","code":"AR","type":"country"},...]'>
 *     <input data-country-autocomplete-target="input"
 *            data-action="input->country-autocomplete#filter focus->country-autocomplete#open" />
 *     <ul data-country-autocomplete-target="list"></ul>
 *   </div>
 */
export default class extends Controller {
  static targets = ["input", "list"]
  static values  = { items: Array }

  connect() {
    this.selectedIndex = -1
    this._buildList()
    this._onClickOutside = (e) => {
      if (!this.element.contains(e.target)) this.close()
    }
    document.addEventListener("click", this._onClickOutside)
  }

  disconnect() {
    document.removeEventListener("click", this._onClickOutside)
  }

  filter() {
    if (this._justSelected) { this._justSelected = false; return }
    const q = this.inputTarget.value.trim().toLowerCase()
    if (q.length === 0) {
      this._showAll()
      return
    }

    const items = this.listTarget.querySelectorAll("[data-item]")
    let visibleCount = 0

    items.forEach((li) => {
      const name = li.dataset.name.toLowerCase()
      const match = name.includes(q)
      li.classList.toggle("hidden", !match)
      if (match) visibleCount++
    })

    this.selectedIndex = -1
    if (visibleCount > 0) this._showList()
    else this.close()
  }

  open() {
    const q = this.inputTarget.value.trim()
    if (q.length === 0) this._showAll()
    else this.filter()
    this._showList()
  }

  close() {
    this.listTarget.classList.add("hidden")
    this.selectedIndex = -1
    this._clearHighlight()
  }

  select(e) {
    const li = e.currentTarget
    this._justSelected = true
    this.inputTarget.value = li.dataset.name
    this.close()
    // Dispatch change event so other controllers (quote-wizard) can react
    this.inputTarget.dispatchEvent(new Event("change", { bubbles: true }))
    // Move focus to next field
    const next = this.element.nextElementSibling?.querySelector("input")
    if (next) next.focus()
  }

  keydown(e) {
    const visible = this._visibleItems()
    if (visible.length === 0) return

    if (e.key === "ArrowDown") {
      e.preventDefault()
      this.selectedIndex = Math.min(this.selectedIndex + 1, visible.length - 1)
      this._highlightItem(visible)
    } else if (e.key === "ArrowUp") {
      e.preventDefault()
      this.selectedIndex = Math.max(this.selectedIndex - 1, 0)
      this._highlightItem(visible)
    } else if (e.key === "Enter" && this.selectedIndex >= 0) {
      e.preventDefault()
      visible[this.selectedIndex].click()
    } else if (e.key === "Escape") {
      this.close()
    }
  }

  // Private

  _buildList() {
    const frag = document.createDocumentFragment()

    // Group: regions first, then countries
    const regions = this.itemsValue.filter(i => i.type === "region")
    const countries = this.itemsValue.filter(i => i.type === "country")

    if (regions.length > 0) {
      const header = document.createElement("li")
      header.className = "ac-header"
      header.textContent = "Regiones"
      frag.appendChild(header)

      regions.forEach(item => frag.appendChild(this._createItem(item, "🌍")))

      const divider = document.createElement("li")
      divider.className = "ac-divider"
      frag.appendChild(divider)

      const header2 = document.createElement("li")
      header2.className = "ac-header"
      header2.textContent = "Países"
      frag.appendChild(header2)
    }

    countries.forEach(item => frag.appendChild(this._createItem(item, this._flag(item.code))))

    this.listTarget.appendChild(frag)
  }

  _createItem(item, icon) {
    const li = document.createElement("li")
    li.className = "ac-item"
    li.dataset.item = ""
    li.dataset.name = item.name
    li.dataset.action = "click->country-autocomplete#select"
    li.innerHTML = `<span class="ac-flag">${icon}</span><span>${item.name}</span>`
    return li
  }

  _flag(code) {
    if (!code || code.length !== 2) return "🌍"
    return String.fromCodePoint(
      ...code.toUpperCase().split("").map(c => 0x1F1E6 + c.charCodeAt(0) - 65)
    )
  }

  _showAll() {
    this.listTarget.querySelectorAll("[data-item]").forEach(li => li.classList.remove("hidden"))
  }

  _showList() {
    this.listTarget.classList.remove("hidden")
  }

  _visibleItems() {
    return [...this.listTarget.querySelectorAll("[data-item]:not(.hidden)")]
  }

  _highlightItem(visible) {
    this._clearHighlight()
    if (visible[this.selectedIndex]) {
      visible[this.selectedIndex].classList.add("is-highlighted")
      visible[this.selectedIndex].scrollIntoView({ block: "nearest" })
    }
  }

  _clearHighlight() {
    this.listTarget.querySelectorAll(".is-highlighted").forEach(el => el.classList.remove("is-highlighted"))
  }
}
