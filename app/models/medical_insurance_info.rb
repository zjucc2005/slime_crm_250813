# encoding: utf-8
class MedicalInsuranceInfo < ApplicationRecord
  belongs_to :candidate
  
  NON_CLINICAL_TYPES = { calculation: '测算组', comprehensive: '综合组' }.stringify_keys
  COMPREHENSIVE_SUB_TYPES = { pharmacy_economics: '药经', pharmacy: '药学', clinical: '临床', 
                             static_distribution: '静配中心', insurance_official: '医保官员' }.stringify_keys
  CALCULATION_SUB_TYPES = { cea: 'CEA', bia: 'BIA' }.stringify_keys
  
  validates :year, presence: true
  validates :year, uniqueness: { scope: :candidate_id }
  validates :non_clinical_type, inclusion: { in: NON_CLINICAL_TYPES.keys }, if: -> { !is_clinical }
  validates :sub_type, inclusion: { in: COMPREHENSIVE_SUB_TYPES.keys }, 
            if: -> { !is_clinical && non_clinical_type == 'comprehensive' }
  validates :sub_type, inclusion: { in: CALCULATION_SUB_TYPES.keys }, 
            if: -> { !is_clinical && non_clinical_type == 'calculation' }
  
  before_validation :log_attributes
  before_save :log_attributes
  after_find :log_loaded_record
  after_initialize :log_initialization
  
  def self.constants_defined?
    begin
      Rails.logger.info "Checking MedicalInsuranceInfo constants..."
      Rails.logger.info "NON_CLINICAL_TYPES defined: #{defined?(NON_CLINICAL_TYPES)}, value: #{NON_CLINICAL_TYPES.inspect}"
      Rails.logger.info "COMPREHENSIVE_SUB_TYPES defined: #{defined?(COMPREHENSIVE_SUB_TYPES)}, value: #{COMPREHENSIVE_SUB_TYPES.inspect}"
      Rails.logger.info "CALCULATION_SUB_TYPES defined: #{defined?(CALCULATION_SUB_TYPES)}, value: #{CALCULATION_SUB_TYPES.inspect}"
      true
    rescue => e
      Rails.logger.error "Error checking MedicalInsuranceInfo constants: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      false
    end
  end
  
  private
  
  def log_initialization
    Rails.logger.debug "MedicalInsuranceInfo initialized: #{attributes.inspect}"
    Rails.logger.debug "New record? #{new_record?}"
  end
  
  def log_loaded_record
    Rails.logger.debug "MedicalInsuranceInfo loaded: ID #{id}, Year #{year}, Clinical? #{is_clinical}"
  end
  
  def log_attributes
    Rails.logger.info "==== 医保信息保存前的属性值 ===="
    Rails.logger.info "  ID: #{id}"
    Rails.logger.info "  年份: #{year}"
    Rails.logger.info "  是否临床: #{is_clinical}"
    Rails.logger.info "  非临床类型: #{non_clinical_type}"
    Rails.logger.info "  子类型: #{sub_type}"
    Rails.logger.info "  所有属性: #{attributes.inspect}"
    
    # 记录验证相关的条件判断
    if !is_clinical
      Rails.logger.info "  需要验证非临床类型"
      if non_clinical_type == 'comprehensive'
        Rails.logger.info "  需要验证综合组子类型，有效值: #{COMPREHENSIVE_SUB_TYPES.keys.join(', ')}"
        Rails.logger.info "  当前子类型值: #{sub_type}"
        Rails.logger.info "  子类型是否有效: #{COMPREHENSIVE_SUB_TYPES.keys.include?(sub_type)}"
      elsif non_clinical_type == 'calculation'
        Rails.logger.info "  需要验证测算组子类型，有效值: #{CALCULATION_SUB_TYPES.keys.join(', ')}"
        Rails.logger.info "  当前子类型值: #{sub_type}"
        Rails.logger.info "  子类型是否有效: #{CALCULATION_SUB_TYPES.keys.include?(sub_type)}"
      end
    else
      Rails.logger.info "  临床类型，不需要验证非临床相关字段"
    end
  end
end