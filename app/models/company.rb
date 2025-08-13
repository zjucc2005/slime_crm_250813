# encoding: utf-8
class Company < ApplicationRecord
  # ENUM
  CATEGORY = { :normal => '普通', :client => '客户公司' }.stringify_keys

  # Associations
  belongs_to :creator, :class_name => 'User', :foreign_key => :created_by, :optional => true
  has_many :contracts, :class_name => 'Contract', :dependent => :destroy
  has_many :candidates, :class_name => 'Candidate'
  has_many :prepaid_clients, :class_name => 'PrepaidClient'
  has_many :projects, :class_name => 'Project'

  # Validations
  validates_inclusion_of :category, :in => CATEGORY.keys
  validates_presence_of :name, :name_abbr, :city
  validates_uniqueness_of :name
  validates_length_of :name, :minimum => 8

  mount_uploader :compliance_file, FileUploader

  before_validation :setup, :on => :create

  # Scopes
  scope :client, -> { where(category: 'client') }
  scope :signed, -> { joins(:contracts).where('contracts.started_at <= :now AND contracts.ended_at >= :now', { :now => Time.now }).distinct }
  scope :not_signed, -> { joins(:contracts).where('contracts.started_at > :now AND contracts.ended_at < :now', { :now => Time.now }).distinct }

  # property fields
  %w[project_task_notice_email project_task_notice_email_cc].each do |k|
    define_method(:"#{k}"){ self.property[k] }
    define_method(:"#{k}="){ |v| self.property[k] = v }
  end

  def uid_name
    "#{uid} #{name}"
  end

  def uid_name_abbr
    "#{uid} #{name_abbr}"
  end

  def is_client?
    category == 'client'
  end

  # if is signed an available contract
  def is_signed?
    contracts.available.count > 0
  end

  def can_destroy?
    false  # 公司删除条件待确定
  end

  # DEPRECATED
  # 生成知情同意书(图片)
  # options - {
  #   _font_: {
  #     font_family: 'Source Han Serif CN',
  #     font_size: 18,
  #     color: '#000000',
  #   },
  #   project_name: { position: [318, 270] },
  #   duration: { position: [620, 270] },
  #   expert_name: { position: [140, 628] },
  #   price: { position: [400, 856] },
  #   interview_date: { position: [730, 1408] }
  #   sign_file: { position: [190, 1350], resize_to_fit: [300, 60] }
  # }
  def self.draw_consent(options={})
    template_path = 'public/templates/iqvia_consent.jpg'
    # sign_file_path = '/home/caic/Downloads/sign_sample.png'
    sign_file_path = '/home/caic/Pictures/Screenshot from 2022-07-27 15-54-23.png'
    template = Magick::Image.read(template_path).first
    sign_file = Magick::Image.read(sign_file_path).first
    sign_file.resize_to_fit!(300, 60)
    full_height = template.rows
    full_width = template.columns
    canvas = Magick::Image.new(full_width, full_height)        # 设置画布
    canvas.composite!(template, 0, 0, Magick::CopyCompositeOp) # 铺上模板图层
    canvas.composite!(sign_file, 190, 1350, Magick::CopyCompositeOp)
    text = Magick::Draw.new
    text.font_family = 'Source Han Serif CN'
    text.pointsize = 18
    text.fill = '#000000'
    text.annotate(canvas, 0, 0, 318, 270, '中文字体test')
    text.annotate(canvas, 0, 0, 620, 270, '60')
    text.annotate(canvas, 0, 0, 140, 628, '中文名字')
    text.annotate(canvas, 0, 0, 400, 856, '1000')
    text.annotate(canvas, 0, 0, 730, 1408, '2022-06-20')
    save_file = '/home/caic/Downloads/test.jpg'
    canvas.write(save_file)
  end

  private
  def setup
    self.category ||= 'client'
    self.name = self.name.try(:strip)
    self.last_active_time ||= Time.now
  end

end
