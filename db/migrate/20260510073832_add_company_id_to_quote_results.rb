class AddCompanyIdToQuoteResults < ActiveRecord::Migration[8.0]
  def change
    add_reference :quote_results, :company, null: true, foreign_key: true

    reversible do |dir|
      dir.up do
        execute <<~SQL
          UPDATE quote_results
          SET company_id = (SELECT company_id FROM quotes WHERE quotes.id = quote_results.quote_id)
        SQL
      end
    end

    change_column_null :quote_results, :company_id, false
  end
end
