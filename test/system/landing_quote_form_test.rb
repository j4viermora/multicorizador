require "application_system_test_case"

class LandingQuoteFormTest < ApplicationSystemTestCase
  setup { @company = companies(:ruka) }

  test "travelers_count refleja solo las edades completadas" do
    visit public_landing_path(@company.slug)

    assert_selector "[data-age-field]", count: 6
    assert_equal "0", find("[data-quote-form-target=count]", visible: false).value

    all("[data-age-field] input").first.set("34")
    all("[data-age-field] input")[2].set("8")

    assert_equal "2", find("[data-quote-form-target=count]", visible: false).value
  end

  test "seleccionar una fecha en el datepicker oculta el calendario" do
    visit public_landing_path(@company.slug)

    find("input[placeholder='Salida']").click
    assert_selector ".datepicker.active", visible: true

    find(".datepicker-cell.day:not(.disabled)", match: :first).click
    assert_no_selector ".datepicker.active", visible: true
  end

  test "enviar sin ninguna edad marca la sección de pasajeros" do
    visit public_landing_path(@company.slug)

    find(".qbar-submit").click

    assert_selector ".qbar-field.qbar-invalid", minimum: 1
    assert_no_current_path public_landing_results_path(@company.slug, "x"), ignore_query: true
  end
end
