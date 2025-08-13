# encoding: utf-8
module DefaultHelper

  def default_prompt
    'Please select'
  end

  def currency_options
    ApplicationRecord::CURRENCY.to_a.map(&:reverse)
  end

  def currency_display(val)
    ApplicationRecord::CURRENCY[val] || val
  end

  def currency_symbol(val)
    { 'RMB' => '¥', 'USD' => '$' }[val] || val
  end

  # 用于 Doctor new/edit form
  # def province_options
  #   LocationDatum.provinces.order(code: :asc).pluck(:name, :id)
  # end

  def hospital_options
    Hospital.all.order(created_at: :asc).pluck(:name, :id)
  end

  def hospital_department_options(hos_id)
    hospital = Hospital.where(id: hos_id).first
    return [] if hospital.nil?
    hospital.departments.order(created_at: :asc).pluck(:name, :id)
  end

  def hospital_level_options
    Hospital::LEVEL
  end

  def ld_city_options(province_id)
    province = LocationDatum.provinces.where(id: province_id).first
    if province.nil?
      options = []
      LocationDatum.provinces.each do |prov|
        options += prov.direct_children.pluck(:name, :id)
      end
    else
      options = province.direct_children.pluck(:name, :id)
    end
    options  # return
  end

  def bank_options
    Bank.all.order(:name).pluck(:name)
  end

  def industry_options
    Industry.all.order(:name).pluck(:name)
  end

  def company_industry_options
    %w[咨询公司 公募基金 PE/VC 券商 企业客户]
  end

  def month_picker_pattern
    '^\d{4}-(0?[1-9]|1[0-2])$'
  end

  ##
  # boolean options for select tag
  def boolean_options
    [[t(:true), 'true'], [t(:false), 'false']]
  end

  def boolean_display(val)
    val.nil? ? val : t(val.to_s.to_sym)
  end

  ##
  # show creator of instance
  def show_creator(instance)
    creator = instance.creator.try(:name_cn) || 'NA'
    "#{mt(:candidate, :created_by)}: #{creator}"
  end

  ##
  # show timestamps of instance
  def show_timestamps(instance)
    if %w[new create].include? action_name

    else
      arr = []
      arr << "#{mt(:user, :created_at)}: #{instance.created_at.strftime('%F %T')}" if instance.created_at
      arr << "#{mt(:user, :updated_at)}: #{instance.updated_at.strftime('%F %T')}" if instance.updated_at
      arr.join(', ')
    end
  end

  def count_badge(count, options={})
    content_tag :span, "#{options[:prefix]}#{count}#{options[:postfix]}", :class => 'badge badge-success' if count > 0
  end

  def return_to(default_path)
    if params[:return_to].present?
      params[:return_to]
    else
      default_path || 'javascript:history.go(-1);'
    end
  end

end