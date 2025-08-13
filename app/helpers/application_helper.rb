module ApplicationHelper
  def display_flash_message
    msg = ''
    %w[notice success warning error].each do |category|
      msg << flash_tag(category.to_sym) if flash[category.to_sym]
    end
    msg.html_safe
  end

  def flash_tag(category)
    _type_ =  {:error => 'danger', :warning => 'warning', :success => 'success', :notice => 'info' }[category]
    content_tag(:div, :class => "alert alert-#{_type_} alert-dismissible fade show mb-2") do
      button_tag('&times;'.html_safe, :type => 'button', :class => 'close', :data => { :dismiss => 'alert' }) +
      flash[category]
    end
  end

  def fa_icon_tag(category, color='')
    if color.present?
      content_tag :i, nil, :class => "fa fa-#{category}", :style => "color: #{color}"
    else
      content_tag :i, nil, :class => "fa fa-#{category}"
    end
  end

  def model_icon(model_name)
    case model_name
      when 'Doctor'        then fa_icon_tag('heartbeat', '#dc3545')
      when 'Hospital'      then fa_icon_tag('heartbeat', '#dc3545')
      when 'LocationDatum' then fa_icon_tag('location-arrow', '#007bff')
    end
  end

  def model_error_tag(instance)
    if instance.errors.any?
      content_tag :ul, :class => 'model-error' do
        instance.errors.full_messages.map do |message|
          content_tag :li, message, :class => 'model-error-item'
        end.join.html_safe
      end
    end
  end

  ##
  # I18n for models
  def mt(model, attr=nil)
    if attr.nil?
      I18n.t("activerecord.models.#{model}")
    else
      if I18n.exists?("activerecord.attributes.#{model}.#{attr}")
        I18n.t("activerecord.attributes.#{model}.#{attr}")
      elsif I18n.exists?("attributes.#{attr}")
        I18n.t("attributes.#{attr}")
      else
        I18n.t("activerecord.attributes.#{model}.#{attr}")
      end
    end
  end

  ##
  # activate sidebar options
  def activate_sidebar
    nav_item = :"nav_#{controller_name}"
    # special settings here >>
    nav_item = :nav_projects if controller_name == 'project_requirements'
    nav_item = :nav_companies if controller_name == 'clients'
    nav_item = :nav_yibao if controller_name == 'candidates' && action_name == 'yibao'
    nav_item = :nav_statistic if controller_name == 'costs'
    nav_item = :nav_statistic if controller_name == 'kpi_summaries'
    nav_item = :nav_statistic if controller_name == 'company_summaries'
    nav_item = :nav_statistic if controller_name == 'statistics' && %w[finance_summary current_month_task_ranking v_monthly_new].include?(action_name)
    # >>
    provide nav_item, 'active'
  end
end
