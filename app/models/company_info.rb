# frozen_string_literal: true

class CompanyInfo < ApplicationRecord
  belongs_to :company_summary, class_name: 'CompanySummary'

  # 不能修改的类型
  NAME_DISABLED = %w[
    总访谈小时
    总访谈收入
    总专家支出
    总访谈毛利
    访谈平均单价/h
    专家平均单价/h
    毛利率
  ]

  def to_api
    expose_fields(:id, :name, :price, :remark, :created_at, :updated_at)
  end

  def to_init_data
    { name: name, price: price&.to_f, remark: remark, disabled: NAME_DISABLED.include?(name) }
  end

end