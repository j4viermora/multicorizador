require "application_system_test_case"

class LandingQuoteFormTest < ApplicationSystemTestCase
  setup { @company = companies(:ruka) }

  test "agregar y quitar pasajeros mantiene travelers_count en sincronía" do
    visit public_landing_path(@company.slug)

    assert_selector "[data-age-field]", count: 6
    assert_equal "6", find("[data-quote-form-target=count]", visible: false).value

    find(".qbar-add").click
    find(".qbar-add").click

    assert_selector "[data-age-field]", count: 8
    assert_equal "8", find("[data-quote-form-target=count]", visible: false).value

    all(".qbar-age-remove").last.click

    assert_selector "[data-age-field]", count: 7
    assert_equal "7", find("[data-quote-form-target=count]", visible: false).value
  end

  test "seleccionar una fecha en el datepicker oculta el calendario" do
    visit public_landing_path(@company.slug)

    find("input[placeholder='Salida']").click
    assert_selector ".datepicker.active", visible: true

    find(".datepicker-cell.day:not(.disabled)", match: :first).click
    assert_no_selector ".datepicker.active", visible: true
  end

  test "enviar el formulario incompleto marca el primer campo vacío" do
    visit public_landing_path(@company.slug)

    find(".qbar-submit").click

    assert_selector ".qbar-field.qbar-invalid", minimum: 1
    assert_no_current_path public_landing_results_path(@company.slug, "x"), ignore_query: true
  end
end
