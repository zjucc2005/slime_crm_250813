# frozen_string_literal: true

module Utils
  class CzbankXibaoTemplateParser
    # 解析通话记录导入模板

    attr_accessor :errors, :row, :instance_attr

    def initialize(row)
      @row = row.map(&method(:cell_strip))
      @errors = []
      @instance_attr = {}
      set_instance_attr
    end

    # 返回值 true/false
    def import
      if valid?
        # import code
        begin
          if @instance_attr[:cod_id].present?
            # 1.先匹配系统中该存单号数据, 同步excel数据
            instance = CzbankXibao.where(cod_id: @instance_attr[:cod_id]).first
            if instance
              instance.update!(@instance_attr)
            else
              # 2. 匹配系统中无存单号数据(手工录入或原数据不全), 做数据补全
              instance_no_cod_id = CzbankXibao.where(cod_id: [nil, ''], org_name: @instance_attr[:org_name], staff_name: @instance_attr[:staff_name],
                                                     belong_date: @instance_attr[:belong_date], sale_value: @instance_attr[:sale_value]).first
              if instance_no_cod_id
                instance_no_cod_id.update!(@instance_attr)
              else
                CzbankXibao.create!(@instance_attr) # 新增数据
              end
            end
          else
            # excel中无存单号
            instance_no_cod_id = CzbankXibao.where(cod_id: [nil, ''], org_name: @instance_attr[:org_name], staff_name: @instance_attr[:staff_name],
                                         belong_date: @instance_attr[:belong_date], sale_value: @instance_attr[:sale_value]).first
            if instance_no_cod_id
              instance_no_cod_id.update!(@instance_attr)
            else
              CzbankXibao.create!(@instance_attr)
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

    def set_instance_attr
      cod_id     = @row[1].present? ? @row[1] : nil
      trans_date = @row[9].to_s
      trans_date = @row[10].to_s if trans_date.blank?
      trans_date = Time.parse(trans_date)
      trans_date_b = trans_date.beginning_of_day
      belong_date = trans_date > trans_date_b + 17.hours ? trans_date_b + 1.day : trans_date_b
      staff_id   = (@row[20].present? && @row[20] != '#N/A') ? @row[20].to_s.upcase : @row[17].to_s.upcase
      staff_name = @row[21].present? ? @row[21] : ''
      if staff_name.include?('公共') || staff_name.include?('未认领') || ['', '#N/A'].include?(staff_name)
        is_public = true
      else
        is_public = false
      end
      if @row[22] == '分行本级'
        org_name = '分行本级中后台'
      elsif @row[22] == '业务五部'
        org_name = '分行业务五部'
      else
        org_name = @row[22]
      end
      sale_value = @row[23]
      bill_count = @row[24]

      @instance_attr = {
          cod_id: cod_id, trans_date: trans_date, belong_date: belong_date, staff_id: staff_id, staff_name: staff_name,
          org_name: org_name, sale_value: sale_value, bill_count: bill_count, is_public: is_public
      }
    end

    private
    def cell_strip(cell)
      String === cell ? cell.strip : cell
    end
  end
end