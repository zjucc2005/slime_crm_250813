# encoding: utf-8
module Utils
  class ClientTemplateParser
    # 解析客户Seat导入模板

    attr_accessor :errors, :row, :created_by, :user_channel_id, :candidate_attr

    def initialize(row, created_by=nil, user_channel_id=nil)
      @row = row.map(&method(:cell_strip))
      @errors = []
      @created_by = created_by
      @user_channel_id = user_channel_id
      @candidate_attr = {}
      @edu_exp_attrs = []
      set_candidate_attr
    end

    # 返回值 true/false
    def import
      if valid?
        # import code
        begin
          ActiveRecord::Base.transaction do
            @client = Candidate.client.create!(@candidate_attr)
            @edu_exp_attrs.each do |item|
              @client.experiences.education.create!(item)
            end
          end
          true  # return
        rescue Exception => e
          @errors << e.message
          false # return
        end
      else
        false # return
      end
    end

    # 返回值 true/false
    def valid?
      @errors.empty?
    end

    private
    def cell_strip(cell)
      String === cell ? cell.strip : cell
    end

    def set_candidate_attr
      @company = Company.where(id: @row[0]).first
      company_id     = @company ? @company.id : nil
      last_name      = @row[3].to_s
      first_name     = @row[4].to_s
      nickname       = @row[5].to_s
      gender         = ['0', '女'].include?(@row[6].to_s) ? 'female' : 'male'
      email1         = @row[7].to_s
      email          = @row[8].to_s
      phone1         = @row[9].to_s
      phone          = @row[10].to_s
      wechat         = @row[11].to_s
      title          = @row[12].to_s
      department     = @row[13].to_s
      address        = @row[14].to_s
      linkedin       = @row[15].to_s
      employer0      = @row[16].to_s
      employer1      = @row[17].to_s
      employer2      = @row[18].to_s
      bachelor       = @row[19].to_s
      master         = @row[20].to_s
      doctor         = @row[21].to_s
      contact_status = @row[22].to_s

      # validates_presence_of - last_name, email
      @errors << '姓不能为空' if last_name.blank?
      if phone.present? && Candidate.client.exists?(phone: phone)
        @errors << '电话已被使用'
      end
      @errors << '邮箱不能为空' if email.blank?
      @errors << '重复导入' if Candidate.client.exists?(last_name: last_name, first_name: first_name, email: email)

      @candidate_attr = {
        data_source: 'excel', data_channel: 'excel', created_by: @created_by, user_channel_id: @user_channel_id, company_id: company_id,
        first_name: first_name, last_name: last_name, nickname: nickname, gender: gender, address: address,
        phone: phone, phone1: phone1, email: email, email1: email1, wechat: wechat, linkedin: linkedin,
        title: title, department: department, employer0: employer0, employer1: employer1, employer2: employer2,
        job_status: 'on', contact_status: contact_status, cpt: 0
      }
      @edu_exp_attrs << { org_cn: bachelor }
      @edu_exp_attrs << { org_cn: master }
      @edu_exp_attrs << { org_cn: doctor }
    end

  end
end