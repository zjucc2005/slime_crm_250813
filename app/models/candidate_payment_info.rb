# encoding: utf-8
class CandidatePaymentInfo < ApplicationRecord
  # ENUM
  CATEGORY = {
    :unionpay => '银联',
    :alipay   => '支付宝'
  }.stringify_keys

  ID_NUMBER_FORMAT = /\A[1-9]\d{5}(18|19|20)\d{2}((0[1-9])|(1[0-2]))(([0-2][1-9])|10|20|30|31)\d{3}[0-9Xx]\Z/

  # Assocications
  belongs_to :creator, :class_name => 'User', :foreign_key => :created_by
  belongs_to :candidate, :class_name => 'Candidate'

  # Validations
  validates_presence_of :account, :username
  validates_inclusion_of :category, :in => CATEGORY.keys
  validates_format_of :id_number, :with => ID_NUMBER_FORMAT, :allow_nil => true

  before_validation :setup, :on => [:create, :update]

  def to_template
    case category
      when 'unionpay' then "#{CATEGORY[category]} | #{bank} | #{sub_branch} | #{account} | #{username} | #{id_number}"
      when 'alipay' then "#{CATEGORY[category]} | #{account} | #{username}"
      else category
    end
  end

  private
  def setup
    self.id_number = id_number.blank? ? nil : id_number.strip
  end

end
