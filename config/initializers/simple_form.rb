# frozen_string_literal: true

SimpleForm.setup do |config|
  config.wrappers :default, class: "mb-4" do |b|
    b.use :html5
    b.use :placeholder
    b.optional :maxlength
    b.optional :minlength
    b.optional :pattern
    b.optional :min_max
    b.optional :readonly

    b.use :label, class: "block text-sm font-medium text-gray-700 mb-1"
    b.use :input, class: "block w-full rounded-md border border-gray-300 px-3 py-2 text-sm shadow-sm focus:border-indigo-500 focus:outline-none focus:ring-1 focus:ring-indigo-500",
                  error_class: "border-red-500 focus:border-red-500 focus:ring-red-500"
    b.use :hint,  wrap_with: { tag: :p, class: "mt-1 text-xs text-gray-500" }
    b.use :error, wrap_with: { tag: :p, class: "mt-1 text-xs text-red-600" }
  end

  config.wrappers :boolean, class: "mb-4 flex items-center gap-2" do |b|
    b.use :html5
    b.optional :readonly

    b.use :input, class: "h-4 w-4 rounded border-gray-300 text-indigo-600 focus:ring-indigo-500"
    b.use :label, class: "text-sm font-medium text-gray-700"
    b.use :hint,  wrap_with: { tag: :p, class: "mt-1 text-xs text-gray-500" }
    b.use :error, wrap_with: { tag: :p, class: "mt-1 text-xs text-red-600" }
  end

  config.default_wrapper = :default
  config.boolean_style = :inline

  config.wrapper_mappings = { boolean: :boolean }

  config.button_class = "inline-flex justify-center rounded-md bg-indigo-600 px-4 py-2 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500 focus:outline-none focus:ring-2 focus:ring-indigo-500"

  config.error_notification_tag = :div
  config.error_notification_class = "mb-4 rounded-md bg-red-50 p-4 text-sm text-red-700"

  config.browser_validations = false

  config.label_class = nil
  config.input_class = nil

  config.input_field_error_class = "border-red-500"
end
