# encoding: utf-8
class ProjectTask < ApplicationRecord
  # ENUM
  CATEGORY = { :interview => '访谈' }.stringify_keys
  STATUS = { :ongoing  => '进展中', :finished => '已结束', :cancelled => '已取消'}.stringify_keys
  CHARGE_STATUS = { :unbilled => '未出账', :billed => '已出账', :paid => '已收费'}.stringify_keys
  PAYMENT_STATUS = { :unpaid => '未支付', :paid => '已支付' }.stringify_keys
  INTERVIEW_FORM = {
    :telephone      => '电话',
    :'face-to-face' => '面谈',
    :data           => '数据',
    :roadshow       => '路演',
    :others         => '其他'
  }.stringify_keys
  EXPERT_LEVEL = { :standard => 'Standard', :premium  => 'Premium' }.stringify_keys
  NOTICE_EMAIL = { A: '标准模板', B: 'iqvia模板', C: 'ipsos模板' }.stringify_keys

  # Associations
  belongs_to :creator, :class_name => 'User', :foreign_key => :created_by, :optional => true
  belongs_to :project, :class_name => 'Project'
  belongs_to :expert, :class_name => 'Candidate', :foreign_key => :expert_id
  belongs_to :client, :class_name => 'Candidate', :foreign_key => :client_id
  belongs_to :pm, :class_name => 'User', :foreign_key => :pm_id

  has_many :costs, :class_name => 'ProjectTaskCost'

  # Validations
  validates_presence_of :started_at
  validates_inclusion_of :category, :in => CATEGORY.keys
  validates_inclusion_of :status, :in => STATUS.keys
  validates_inclusion_of :interview_form, :in => INTERVIEW_FORM.keys

  mount_uploader :jiesuan_file, FileUploader
  mount_uploaders :jiesuan_files, FileUploader

  before_validation :setup, :on => [:create, :update]
  after_update :sync_payment_status

  after_save do
    project.last_update
  end
  # Scopes
  scope :interview, -> { where( category: 'interview') }

  # property fields
  %w[interview_no recruitment_fee notice_email expert_alias].each do |k|
    define_method(:"#{k}"){ self.property[k] }
    define_method(:"#{k}="){ |v| self.property[k] = v }
  end

  def send_notice_email
    if notice_email_sent_at.nil? && NOTICE_EMAIL.keys.include?(notice_email)
      UserMailer.project_task_notice_email(id, notice_email).deliver  # 发送通知邮件,仅1次
      self.update!(notice_email_sent_at: Time.now)
    end
  end

  def finish!
    ActiveRecord::Base.transaction do
      contract = active_contract
      self.status = 'finished'
      self.actual_price ||= base_price                                                      # 实际收费
      self.charge_status = contract.payment_way == 'advance_payment' ? 'paid' : 'unbilled'  # 预付合同直接已收费
      self.is_new_expert = _is_new_expert_
      self.save!

      project_candidate = ProjectCandidate.where(project_id: project_id, candidate_id: expert_id).first
      project_candidate.update!(mark: 'interviewed') if project_candidate  # 自动更新专家项目中标识为已访谈
      expert.save # 触发更新搜索权重
    end

    send_notice_email
  end

  def can_show?
    %w[finished].include? status
  end

  def can_cancel?
    %w[ongoing].include? status
  end

  def can_return_back?
    %w[unbilled].include? charge_status
  end

  def can_be_edited_by(user)
    status == 'ongoing' && (created_by == user.id || pm_id == user.id || user.admin? || user.pd? || user.email == 'cinney.wu@hci-consulting.com')
  end

  # 当前执行中的合同(最新), 用于获取价格计算规则
  def active_contract
    project.active_contract
  end

  # 收费小时(用于财务表格导出)
  def charge_hour
    (charge_duration / 60.0).round(2)
  end

  def charge_rate_realtime
    contract = active_contract
    (contract ? contract.charge_rate : charge_rate) || 0
  end

  # 实际费率，精确到1
  def charge_rate_mod
    ((charge_rate || 0) * (expert_rate || 1)).round.to_f
  end

  def set_charge_timestamp
    case charge_status
      when 'billed' then
        self.billed_at = Time.now
        self.charge_deadline = billed_at + charge_days.to_i.days
      when 'paid'   then
        self.charged_at = Time.now
      else nil
    end
  end

  def expert_cost_friendly
    cost = costs.expert.first
    cost ? cost.price : nil
  end

  # 用户外部展示的专家名称
  def expert_name_for_external
    if expert_alias.present?
      expert_alias
    else
      expert.category == 'doctor' ? expert.name : expert.mr_name_cn
    end
  end

  # format: 2022-01-01（周六）12:00
  def started_at_fwt
    begin
      wday = %w[周日 周一 周二 周三 周四 周五 周六][started_at.wday]
      started_at.strftime("%F（#{wday}）%H:%M")
    rescue
      nil
    end
  end

  # 计算iqvia招募费
  # 优先取填写的招募费, 未填写则根据倍率计算
  def recruitment_fee_for_iqvia
    if recruitment_fee.present?
      recruitment_fee.to_f
    else
      # if expert_rate >= 1 && (expert_rate.to_d - 1) % 0.3 == 0  # 倍率满足 1 + 0.3n (n >= 0)
      #   n = ((expert_rate.to_d - 1) / 0.3).to_i
      #   1500 + 250 * n #  return
      # else
      #   nil
      # end
      # expert._c_t_iqvia_rate_mapping_
      (charge_rate || 2100) * (expert_rate || 1 ) - expert.cpt
    end
  end

  # 用于受访表模板 - 礼金支出数额
  # 访谈时间 < 1h 时, 则优先取填写的礼金数值
  def lijin_for_settlement
    costs.where(category: 'expert').map do |cost|
      # duration >= 60 ? cost.price : (cost.lijin || cost.price)
      cost.lijin || cost.price
    end.sum
  end

  # 绘制知情同意书
  def can_draw_consent?
    File.exists? project.company.consent_file.to_s
  end

  def draw_consent
    template_path = project.company.consent_file
    raise 'template not found' unless File.exists? template_path.to_s
    options = project.company.consent_file_options
    params = {
        project_name: project.name,
        duration: duration.to_s,
        expert_name: expert.name,
        price: actual_price.round.to_s,
        interview_date: started_at.strftime('%F')
    }
    if expert.sign_file.present?
      params[:sign_file] = expert.sign_file.path # 签名文件路径
    end
    puts "SET PARAMS: #{params}"
    template = Magick::Image.read(template_path).first
    full_height = template.rows
    full_width = template.columns
    canvas = Magick::Image.new(full_width, full_height)
    canvas.composite!(template, 0, 0, Magick::CopyCompositeOp) # 铺上模板图层
    text = Magick::Draw.new # 初始化文本格式
    if options['_font_'].present?
      puts "SET FONT: #{options['_font_']}"
      text.font_family = options['_font_']['font_family'] if options['_font_']['font_family'].present?
      text.pointsize = options['_font_']['font_size'] if options['_font_']['font_size'].present?
      text.fill = options['_font_']['color'] if options['_font_']['color'].present?
    end
    params.each do |key, val|
      if %w[sign_file].include?(key.to_s)
        opt = options[key.to_s]
        image_file = Magick::Image.read(params[key]).first
        image_file.resize_to_fit!(*opt['resize_to_fit'])
        canvas.composite!(image_file, *opt['position'], Magick::CopyCompositeOp) # 铺上图片
      else
        opt = options[key.to_s]
        text.annotate(canvas, 0, 0, *opt['position'], val) do |t|
          t.font_family = opt['font_family'] if opt['font_family'].present?
          t.pointsize = opt['font_size'] if opt['font_size'].present?
          t.fill = opt['color'] if opt['color'].present?
        end
      end
    end
    save_file_dir = "public/export/#{Time.now.strftime('%y%m%d')}"
    FileUtils.mkdir_p save_file_dir unless File.exist? save_file_dir
    save_file = "#{save_file_dir}/project_task_consent_#{id}.jpg"
    canvas.write(save_file)
    save_file # return
  end

  # 当前选择的专家公司
  def active_exp
    if candidate_experience_id
      expert.work_experiences.find_by(id: candidate_experience_id) || expert.latest_work_experience
    else
      expert.latest_work_experience
    end
  end

  # 是否新专家判定
  # 1. 专家 - 新建于一个月内 or 一年内无访谈
  # 2. 医生 - 新建于一个月内 or 半年内无访谈
  # 3. 以上时间基准为访谈任务开始时间，即字段started_at
  def _is_new_expert_
    return true if expert.created_at > started_at - 1.month # 新建于一个月内
    prev_task = expert.project_tasks.where('started_at < ?', started_at).order(started_at: :desc).first
    return true if prev_task.nil? # 历史无访谈
    if expert.category == 'expert'
      prev_task.started_at < started_at - 1.year
    elsif expert.category == 'doctor'
      prev_task.started_at < started_at - 6.months
    else
      false
    end
  end

  private
  def setup
    self.status         ||= 'ongoing'   # init
    self.charge_status  ||= 'unbilled'  # init
    self.payment_status ||= 'unpaid'    # init
    contract = active_contract
    self.charge_rate    = contract.charge_rate                                                         # 收费倍率
    self.currency       = contract.currency                                                            # 货币
    self.charge_days    = contract.payment_days                                                        # 账期(天数)

    if charge_duration.present?
      self.ended_at       = started_at + duration.to_i * 60                                            # 结束时间 = 开始时间 + 时长
      self.base_price     = (contract.base_price(charge_duration.to_i, self.f_flag) * expert_rate.to_d).round  # 基础收费(根据收费时长)
      if shorthand_price.blank? # 可修改覆盖
        self.shorthand_price = is_shorthand ? contract.shorthand_price(charge_duration.to_i) : 0         # 速记费用
      end
      self.is_taxed       = contract.is_taxed                                                          # 是否含税
      self.tax            = is_taxed ? 0 : (actual_price.to_f + shorthand_price.to_f) * contract.tax_rate  # 税费 = (实际收费 + 速记费) * 税率
    end
    self.total_price     = actual_price.to_f + shorthand_price.to_f + tax.to_f  # 总费用
  end

  def sync_payment_status
    costs.map{|cost| cost.update(payment_status: self.payment_status) }
  end
end
