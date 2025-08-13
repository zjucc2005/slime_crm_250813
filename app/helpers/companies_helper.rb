# encoding: utf-8
module CompaniesHelper

  def company_options
    user_channel_filter(Company.all).order(last_active_time: :desc).map do |company|
      [company.uid_name, company.id]
    end
  end

  # category display style
  def company_category_badge(category)
    dict = { :normal => 'secondary', :client => 'primary' }.stringify_keys
    content_tag :span, Company::CATEGORY[category], :class => "badge badge-#{dict[category]}"
  end

  # signed status display style
  def company_signed_badge(is_signed=true)
    if is_signed
      content_tag :span, t(:company_signed), :class => 'badge badge-danger'
    else
      content_tag :span, t(:company_not_signed), :class => 'badge badge-secondary'
    end
  end

  def client_active_badge(active=true)
    if active
      content_tag :span, t(:client_active), class: 'badge badge-danger'
    end
  end
end