# app/helpers/application_helper.rb
module ApplicationHelper
  def markdown(text)
    return "" if text.blank?

    # This replaces problematic 'smart' characters with standard ones
    # to ensure Ferrum/Chrome renders them correctly regardless of system locale.
    safe_text = text.to_s
                    .gsub(/[“”]/, '"')
                    .gsub(/[‘’]/, "'")
                    .gsub(/–/, "-")
                    .gsub(/…/, "...")

    Kramdown::Document.new(safe_text).to_html.html_safe
  end
end
