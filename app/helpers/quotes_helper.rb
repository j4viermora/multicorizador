module QuotesHelper
  def quote_status_color(status)
    case status
    when "draft" then "ghost"
    when "client_pending" then "warning"
    when "quoting" then "info"
    when "quoted" then "primary"
    when "pending_payment" then "secondary"
    when "purchased" then "success"
    when "cancelled" then "error"
    else "ghost"
    end
  end
end
