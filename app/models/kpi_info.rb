# frozen_string_literal: true

class KpiInfo < ApplicationRecord
  belongs_to :kpi_summary, class_name: 'KpiSummary'

  # 不能修改的类型
  NAME_DISABLED = %w[
    访谈小时
    管理小时
    总访谈收入
    总专家支出
    总访谈毛利
    访谈平均单价/h
    专家平均单价/h
    新专家率
    个人总收入
    当月奖金
    绩效倍数
  ]

  def to_api
    expose_fields(:id, :name, :price, :remark, :created_at, :updated_at)
  end

  def to_init_data
    { name: name, price: price&.to_f, remark: remark, disabled: NAME_DISABLED.include?(name) }
  end

end