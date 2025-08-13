# encoding: utf-8
class Candidate < ApplicationRecord

  # ENUM
  CATEGORY = { expert: '专家', doctor: '医生', client: '客户', delete: '删除' }.stringify_keys
  DATA_SOURCE = { :manual => '手工录入', :excel => 'Excel导入', :plugin => '插件采集', :api => 'API创建' }.stringify_keys
  GENDER = { :male => '男', :female => '女' }.stringify_keys
  DATA_CHANNEL = {
    :linkedin  => 'Linkedin',
    :liepin    => '猎聘',
    :search    => '搜索（谷歌，百度等）',
    :social    => '社交（微博，脉脉）',
    :recommend => '专家推荐',
    :contact   => '通讯录',
    :gllue     => '谷露导入',
    :excel     => '批量导入',
    :plugin    => '插件采集'
  }.stringify_keys
  JOB_STATUS = { on: '在职', off: '离职' }.stringify_keys

  # Associations
  belongs_to :creator, :class_name => 'User', :foreign_key => :created_by, :optional => true
  belongs_to :user_channel, :class_name => 'UserChannel', :optional => true
  belongs_to :recommender, :class_name => 'Candidate', :foreign_key => :recommender_id, :optional => true
  belongs_to :company, :class_name => 'Company', :optional => true
  has_many :experiences, :class_name => 'CandidateExperience', :dependent => :destroy
  has_many :payment_infos, :class_name => 'CandidatePaymentInfo', :dependent => :destroy
  has_many :comments, :class_name => 'CandidateComment', :dependent => :destroy
  has_many :medical_insurance_infos, :dependent => :destroy
  accepts_nested_attributes_for :medical_insurance_infos, allow_destroy: true, reject_if: :all_blank

  has_many :project_candidates, :class_name => 'ProjectCandidate'
  has_many :projects, :class_name => 'Project', :through => :project_candidates
  has_many :project_tasks, :class_name => 'ProjectTask', :foreign_key => :expert_id
  has_many :candidate_access_logs, :class_name => 'CandidateAccessLog'
  has_many :recommended_experts, :class_name => 'Candidate', :foreign_key => :recommender_id
  has_many :call_records, :class_name => 'CallRecord'

  # Validations
  validates_inclusion_of :category, :in => CATEGORY.keys
  validates_inclusion_of :data_source, in: DATA_SOURCE.keys, allow_nil: true
  validates_inclusion_of :gender, in: GENDER.keys, allow_nil: true
  validates_inclusion_of :currency, in: CURRENCY.keys, allow_nil: true
  validates_presence_of :name, :last_name
  validates_presence_of :cpt

  mount_uploader :file, FileUploader
  mount_uploader :sign_file, FileUploader

  before_validation :setup, :validates_uniqueness_of_phone, :on => [:create, :update]

  # Scopes
  scope :expert, -> { where(category: 'expert') }
  scope :doctor, -> { where(category: 'doctor') }
  scope :client, -> { where(category: 'client') }

  class << self
    def name_split(name)
      if self::FUXING.include?(name[0, 2])
        last_name = name[0, 2]
        first_name = name[2, name.length - 2]
      else
        last_name = name[0]
        first_name = name[1, name.length - 1]
      end
      [first_name, last_name]
    end
  end

  # property fields
  %w[wechat cpt_face_to_face haodf_id linkedin employer0 employer1 employer2 contact_status 
     yibaotanpan_year].each do |k|
    define_method(:"#{k}"){ self.property[k] }
    define_method(:"#{k}="){ |v| self.property[k] = v }
  end

  def can_delete?
    if category == 'client'
      projects.count.zero?  # 未参与项目
    elsif category == 'expert'
      projects.count.zero? && call_records.count.zero? && recommended_experts.count.zero?  # 未参与项目 & 未推荐过其他专家
    elsif category == 'doctor'
      projects.count.zero? && call_records.count.zero?
    end
  end

  def validates_presence_of_experiences
    if category == 'expert'
      if experiences.work.count.zero?
        errors.add(:work_experiences, :blank)
        false
      else
        true
      end
    elsif category == 'doctor'
      if experiences.hospital.count.zero?
        errors.add(:work_experiences, :blank)
        false
      else
        true
      end
    else
      true
    end
  end

  # English name form - Mr./Miss sb.
  def mr_name
    _mr_   = gender == 'female' ? 'Ms.' : 'Mr.'
    _name_ = last_name
    if /\p{Han}+/.match(last_name)
      _name_ = Pinyin.t(last_name).capitalize rescue last_name
    end
    "#{_mr_} #{_name_}"
  end

  def mr_name_cn
    _mr_   = gender == 'female' ? '女士' : '先生'
    "#{last_name}#{_mr_}"
  end

  # uid + name
  def uid_name
    "#{uid} #{name}"
  end

  def work_experiences
    experiences.where(category: %w[work hospital]).order(started_at: :desc)  # 定义属性
  end

  def latest_work_experience
    experiences.where(category: %w[work hospital]).order(started_at: :desc, ended_at: :desc).first
  end

  # new expert has at most 1 task
  def new_expert?
    project_tasks.where(status: 'finished').count <= 1
  end

  def client_active?
    pc = project_candidates.client.order(created_at: :desc).first
    pc ? pc.created_at > Time.now - 3.month : false
  end

  # card template params setting
  def card_template_params(field)
    case field.to_sym
    when :uid          then self.uid
    when :name         then self.name
    when :first_name   then first_name
    when :last_name    then last_name
    when :city         then self.city
    when :phone        then self.phone
    when :description  then self.description
    when :company      then self.latest_work_experience.try(:org_cn)
    when :department   then latest_work_experience.try(:department)
    when :hospital_level then experiences.hospital.first.try(:org_en)
    when :title        then self.latest_work_experience.try(:title)
    when :title2       then latest_work_experience.try(:title1)
    when :expert_level then self._c_t_expert_level
    when :rate         then self.cpt.to_i
    when :rate_2       then _c_t_rate_2_
    when :gj_rate      then self._c_t_gj_rate_
    when :iqvia_rate   then _c_t_iqvia_rate_
    # when :iqvia_rate2  then _c_t_iqvia_rate2_
    else nil
    end
  end

  # for card template use
  def _c_t_expert_level
    case currency
      when 'RMB' then cpt.to_i > 1000 ? 'Premium Expert' : 'Standard Expert'
      when 'USD' then cpt.to_i >= 200 ? 'Premium Expert' : 'Standard Expert'
      else 'Standard Expert'
    end
  end

  def _c_t_rate_2_
    res = case cpt 
      when (0..1200) then 1
      when (1200..1500) then 1.25
      when (1500..1800) then 1.5
      when (1800..2100) then 1.75
      when (2100..2500) then 2
      when (2500..2800) then 2.25
      when (2800..3000) then 2.5
      else ((cpt - 3000) / 500.0).ceil * 0.25 + 2.5
      end
    res = 1 if res < 1
    res
  end

  def _gj_rate_
    case cpt
    when 0 then 0
    when 0..1000 then 2800
    when 1000..1500 then 3360
    when 1500..2000 then 4200
    when 2000..2500 then 5040
    when 2500..3000 then 5600
    else nil
    end
  end

  def _c_t_gj_rate_
    _rate_ = 0
    if currency == 'RMB'
      _rate_ = _gj_rate_ || 'TBD'
    end
    _rate_ == 0 ? '' : "电话-#{_rate_}/小时"
  end

  # 费率映射规则, 招募费
  # ProjectTask#recruitment_fee_for_iqvia 有引用
  def _c_t_iqvia_rate_mapping_
    if cpt < 1000
      0
    elsif cpt < 1500
      200
    elsif cpt < 2000
      300
    elsif cpt < 2500
      400
    elsif cpt < 3000
      500
    elsif cpt == 3000
      600
    else
      nil
    end
    # case cpt
    # when 0..1000 then 0
    # when 1000..1500 then 200
    # when 1500..2000 then 300
    # when 2000..2500 then 400
    # when 2500..3000 then 500
    # when 3000..3000 then 600
    # else nil
    # end
    # cpt.to_i.zero? ? 0 : (840 + 0.26 * cpt.to_i).ceil  # integer
  end

  def _c_t_iqvia_rate_
    _rate_ = 0
    if currency == 'RMB'
      _rate_ = _c_t_iqvia_rate_mapping_ || 'TBD'
    end
    _rate_ == 0 ? '' : "#{_rate_}/小时"
  end

  # def _c_t_iqvia_rate2_
  #   result = 0
  #   if currency == 'RMB'
  #     iqvia_rate = _c_t_iqvia_rate_mapping_
  #     if iqvia_rate
  #       result = (cpt + iqvia_rate) * 0.84 - cpt
  #     end
  #   end
  #   result
  # end

  # 搜索权重算法
  def calculate_coef
    score = 0
    project_tasks_count = project_tasks.count
    score += 2 if (created_at || Time.now) > Time.now - 30.days && project_tasks_count.zero?  # 一个月内新建的专家没做过访谈时, 有额外权重
    score += 0.5 if project_tasks_count > 0  # 做过访谈 + 0.5
    score += 0.5 if phone.present? || phone1.present? # 有电话号码 + 0.5
    score += 0.5 if is_available  # 访谈意愿 + 0.5
    score
  end

  def expert_tax_free_limit(t=Time.now)
    limit = 800 - ProjectTaskCost.tax_free_used_monthly(id, t)
    [limit, 0].max
  end

  def to_api_expert
    expose_fields(:id, :uid, :category, :data_source, :created_by,
      :name, :first_name, :last_name, :nickname, :city, :email, :email1, :phone, :phone1, :industry, :description,
      created_at: created_at&.strftime('%F %T'),
      updated_at: updated_at&.strftime('%F %T'),
      candidate_experiences: work_experiences.map(&:to_api)
    )
  end

  def to_api_match
    expose_fields(:id, :category, :name, :first_name, :last_name, :nickname, :phone, :description,
      created_at: created_at&.strftime('%F %T'),
      updated_at: updated_at&.strftime('%F %T'),
      candidate_experiences: work_experiences.map(&:to_api)
    )
  end

  private
  def setup
    self.category    ||= 'expert'  # init category
    self.data_source ||= 'manual'  # init data_source
    self.first_name    = first_name.try(:strip)
    self.last_name     = last_name.try(:strip)
    self.name          = "#{last_name}#{first_name}"
    self.phone         = phone.to_s.gsub(/[^\d]/, '')  # remove non-numeric chars
    self.phone1        = phone1.to_s.gsub(/[^\d]/, '')
    self.email         = email.strip if email
    self.email1        = email1.strip if email1
    self.coef          = calculate_coef if %w[doctor expert].include?(category)
  end

  def validates_uniqueness_of_phone
    if %w[expert doctor].include?(category)
      query = self.class.where(category: %w[expert doctor]).where.not(id: self.id)
      if phone.present?
        errors.add(:phone, :taken) if query.exists?(phone: phone) || query.exists?(phone1: phone)
      end
      if phone1.present?
        errors.add(:phone1, :taken) if query.exists?(phone: phone1) || query.exists?(phone1: phone1)
      end
    elsif self.category == 'client'
      query = self.class.client.where.not(id: self.id)
      if phone.present?
        errors.add(:phone, :taken) if query.exists?(phone: phone) || query.exists?(phone1: phone)
      end
      if phone1.present?
        errors.add(:phone1, :taken) if query.exists?(phone: phone1) || query.exists?(phone1: phone1)
      end
      if email.present?
        errors.add(:email, :taken) if query.where('email ILIKE ?', email.shellescape).count > 0
      end
    else
      true
    end
  end

end
