# frozen_string_literal: true

class CostSummary < ApplicationRecord
  has_many :costs, class_name: 'Cost', dependent: :destroy
  belongs_to :operator, class_name: 'User', foreign_key: :operator_id
  
  def to_api
    expose_fields(
      :id, :price, :created_at, :updated_at,
      datetime: datetime&.strftime('%F'),
      costs: costs.order(:id).map(&:to_api)
    )
  end

  def update_price!
    self.update!(price: costs.sum(:price))
  end

  # 根据根类型分别汇总费用
  def price_group_by_root_type
    res = []
    CostType.root.order(:id).each do |type|
      type_price = 0
      costs.each do |cost|
        type_price += cost.price if type.has_decendant?(cost.cost_type_id)
      end
      res << { name: type.name, cost_type_id: type.id, price: type_price }
    end
    res
  end
end