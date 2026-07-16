# frozen_string_literal: true

# Renders a date attribute as a text field wired to the Flowbite datepicker
# (the `datepicker` Stimulus controller). Emits ISO `yyyy-mm-dd` values so Rails
# parses them into Date columns natively.
#
#   <%= f.input :departure_date, as: :datepicker %>
#   <%= f.input :birth_date, as: :datepicker,
#         input_html: { data: { datepicker_min_value: "1900-01-01" } } %>
class DatepickerInput < SimpleForm::Inputs::Base
  def input(wrapper_options = nil)
    merged = merge_wrapper_options(input_html_options, wrapper_options)

    value = object.respond_to?(attribute_name) ? object.public_send(attribute_name) : nil
    formatted = value.respond_to?(:strftime) ? value.strftime("%Y-%m-%d") : value

    options = merged.dup
    options[:class] = "input w-full"
    options[:type]  = "text"
    options[:value] = formatted.presence
    options[:autocomplete] = "off"
    options[:data] = (options[:data] || {}).reverse_merge({ controller: "datepicker" })

    @builder.text_field(attribute_name, options)
  end
end
