# encoding: utf-8
class ProjectTaskCost < ApplicationRecord
  # ENUM
  CATEGORY = {
    expert:      '专家费用',
    expert_tax:  '税费（专家费用）',
    recommend:   '推荐费用',
    translation: '翻译费用',
    others:      '其他费用'
  }.stringify_keys

  CATEGORY_LIMIT = {
    expert:      1,  # 费用条目限制
    expert_tax:  0,
    recommend:   1,
    translation: 1,
    others:      999
  }.stringify_keys

  # Associations
  belongs_to :project_task, :class_name => 'ProjectTask'

  # Validations
  validates_inclusion_of :category, :in => CATEGORY.keys
  validates_presence_of :price, :currency

  before_validation :setup, :on => :create

  scope :expert, -> { where(category: 'expert') }

  # 用于表格导出
  def bank_or_alipay
    if self.payment_info['category'] == 'alipay'
      CandidatePaymentInfo::CATEGORY['alipay']
    elsif self.payment_info['category'] == 'unionpay'
      self.payment_info['bank']
    end
  end

  # def self.cost_monthly(category, expert_id, t=Time.now)
  #   cur_month = t.beginning_of_month
  #   start_time = t.day > 15 ? cur_month + 15.days : cur_month - 1.month + 15.days
  #   project_task_costs = self.joins(:project_task).
  #     where('project_task_costs.category': category).
  #     where('project_tasks.expert_id': expert_id, 'project_tasks.status': 'finished').
  #     where('project_tasks.started_at BETWEEN ? AND ?', start_time, start_time + 1.month)
  #   project_task_costs.sum(:price)
  # end

  def self.tax_free_used_monthly(expert_id, t=Time.now)
    cur_month = t.beginning_of_month
    start_time = t.day > 15 ? cur_month + 15.days : cur_month - 1.month + 15.days
    project_task_costs = self.joins(:project_task).
      where('project_task_costs.category': 'expert').
      where('project_tasks.expert_id': expert_id, 'project_tasks.status': 'finished').
      where('project_tasks.started_at BETWEEN ? AND ?', start_time, start_time + 1.month)
    project_task_costs.sum(:tax_free_value)
  end

  # 生成专家费用税费（根据专家费判断），免税额度：800元/月
  # 税费 = 0.25 * 专家费
  def create_expert_tax_instance
    if category != 'expert'
      puts "只有专家费可调用该方法" and return
    end
    tax_free_value = project_task.expert.expert_tax_free_limit(project_task.started_at) # 免税额度
    tax_price = (price - tax_free_value) * 0.2
    if tax_price > 0
      instance = project_task.costs.create(
        user_channel_id: user_channel_id,
        category: 'expert_tax',
        price: tax_price,
        currency: currency,
        payment_info: payment_info
      )
      self.update(tax_free_value: tax_free_value)
    else
      self.update(tax_free_value: price)
    end
  end

  def update_expert_tax_instance
    if category != 'expert'
      puts "只有专家费可调用该方法" and return
    end
    tax_price = (price - tax_free_value) * 0.2
    tax_instance = project_task.costs.where(category: 'expert_tax').first
    if tax_price > 0
      if tax_instance
        tax_instance.update(price: tax_price)
      else
        tax_instance = project_task.costs.create(
          user_channel_id: user_channel_id,
          category: 'expert_tax',
          price: tax_price,
          currency: currency,
          payment_info: payment_info
        )
      end
    else
      tax_instance&.destroy
    end
  end

  private
  def setup
    self.payment_status ||= 'unpaid'  # init
  end
end
