module ApplicationHelper
  REGION_TRANSLATIONS = {
    "Europe" => "Europa",
    "Americas" => "América",
    "Asia" => "Asia",
    "Africa" => "África",
    "Oceania" => "Oceanía"
  }.freeze

  def countries_autocomplete_data
    regions = REGION_TRANSLATIONS.map { |_en, es| { name: es, code: "", type: "region" } }

    countries = ISO3166::Country.all.map do |c|
      { name: c.translations["es"] || c.iso_short_name, code: c.alpha2, type: "country" }
    end.sort_by { |c| c[:name] }

    (regions + countries).to_json
  end
end
