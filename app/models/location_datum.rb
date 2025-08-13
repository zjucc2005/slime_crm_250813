# encoding: utf-8
class LocationDatum < ApplicationRecord

  # Associations
  belongs_to :parent, :class_name => self.name, :optional => true
  has_many :children, :class_name => self.name, :foreign_key => :parent_id

  # Validations
  validates_presence_of :name, :level

  # LEVEL
  # 0 - country
  # 1 - province
  # 2 - city
  # 3 - district

  # Scopes
  scope :countries, -> { where(level: 0) }
  scope :provinces, -> { where(level: 1) }
  scope :cities,    -> { where(level: 2) }
  scope :districts, -> { where(level: 3) }

  DIRECT_CODE = %w[110000 120000 310000 500000 810000 820000]  # 直辖市/港澳

  CITY_TIER = {
      '一线': %w[北京市 上海市 深圳市 广州市],
      '新一线': %w[成都市 杭州市 重庆市 西安市 苏州市 武汉市 南京市 天津市 郑州市 长沙市 东莞市 佛山市 宁波市 青岛市 沈阳市]
  }.stringify_keys

  def is_direct
    DIRECT_CODE.include?(code)
  end

  # 地市级行政单位
  def direct_children
    is_direct ? children.first.children : children
  end

  # 去除省份后缀, 例如: 北京市 -> 北京, 内蒙古自治区 -> 内蒙古
  def name_no_suffix
    name.match(/(黑龙江|内蒙古)/) ? name[0, 3] : name[0,2]
  end

  class << self
    ##
    # import china location data
    def data_seed
      return nil if self.count > 0  # skip if data exists

      self.transaction do
        china     = self.countries.create!(name: '中国', code: 'cn')
        file_path = 'db/import/location_data.json'
        json      = JSON.parse File.open(file_path).read
        json.each do |code, name|
          province_code = code[0,2]
          city_code     = code[2,2]
          district_code = code[4,2]

          if city_code == '00'
            province = china.children.provinces.create!(name: name, code: code)
            if %w[11 12 31 50 81 82].include?(province_code)
              province.children.cities.create!(name: name, code: code)      # 直辖市/港澳特殊处理
            end
          elsif city_code == '90'
            province = self.provinces.where(code: "#{province_code}0000").first
            province.children.cities.create!(name: name, code: code)        # 省辖市特殊处理
          elsif district_code == '00'
            province = self.provinces.where(code: "#{province_code}0000").first
            province.children.cities.create!(name: name, code: code)
          else
            if %w[11 12 31 50 81 82].include?(province_code)
              city = self.cities.where(code: "#{province_code}0000").first  # 直辖市/港澳特殊处理
            else
              city = self.cities.where(code: "#{province_code}#{city_code}00").first
            end
            city.children.districts.create!(name: name, code: code)
          end
        end
      end
    end

    # 解析字符串成省份(简) + 城市(详), 例如: ['北京', '北京市'], ['内蒙古', '呼和浩特市']
    def parse(text)
      return [nil, nil] if text.blank?
      result = [nil, text]
      arr = text.to_s.split(/省|市|自治区/).map(&:strip)
      if arr.length == 1
        prov = provinces.where('name ~ ?', "^#{arr[0][0,2]}").first # 识别省份
        if prov
          if prov.is_direct
            result = [prov.name_no_suffix, prov.name]
          else
            city = prov.children.where('name ~ ?', "^#{arr[0].gsub(/^(#{prov.name}|#{prov.name_no_suffix})/, '')}").first
            result = [prov.name_no_suffix, city.try(:name)]
          end
        else
          q = cities.where('name ~ ?', "^#{arr[0][0,2]}") # 识别城市, 2~3字符用于区分(个别地级市)
          q = cities.where('name ~ ?', "^#{arr[0][0,2]}") if q.count > 1
          city = q.first
          result = [city.parent.name_no_suffix, city.name] if city
        end
      else
        prov = provinces.where('name ~ ?', "^#{arr[0][0,2]}").first # 识别省份
        if prov
          if prov.is_direct
            result = [prov.name_no_suffix, prov.name]
          else
            city = prov.children.where('name ~ ?', "^#{arr[1][0,2]}").first # 识别城市
            result = [prov.name_no_suffix, city.try(:name)]
          end
        else
          q = cities.where('name ~ ?', "^#{arr[0][0,2]}") # 识别城市, 2~3字符用于区分(个别地级市)
          q = cities.where('name ~ ?', "^#{arr[0][0,3]}") if q.count > 1
          city = q.first
          result = [city.parent.name_no_suffix, city.name] if city
        end
      end
      result # return
    end

    # mobile location api
    def mobile_location(num)
      begin
        
        url = "http://phone.yinhangkadata.com/Mobilegsd"
        res = Utils::Api.post(url, { mobile: num }, {}, { set_form_data: true })
        if res.code == '200'
          data = res.body.force_encoding('utf-8')
          puts "data: #{data}"
          arr = data.split("\n")
          raw_city = arr[7]
          m_city = raw_city.match(/<p align="center">(.+)<\/td>/)
          city = m_city ? m_city[1].gsub(' - ', '') : ''
          raw_type = arr[11]
          m_type = raw_type.match(/<p align="center">(.+)<\/td>/)
          type = m_type ? m_type[1] : ''
          [city, type]
        else
          raise "http code: #{res.code}"
        end

        # url = "https://tool.bitefu.net/shouji/?mobile=#{num}"
        # res = Utils::Api.get(url)
        # if res.code == '200'
        #   data = JSON.parse res.body
        #   city = "#{data['province']}#{data['city']}"
        #   type = data['isp']
        #   [city, type]
        # else
        #   raise "http code: #{res.code}"
        # end

        # url = "http://ip168.com/chxip/doGetMobile.do?keyword=#{num}"
        # res = Utils::Api.get(url)
        # if res.code == '200'
        #   str = res.body&.force_encoding('utf-8')
        #   if str
        #     arr = str.split(',')
        #     city = arr[1].split(':')[1]
        #     type = arr[2].split(':')[1]
        #     [city, type]
        #   else
        #     raise "body: #{res.body}"
        #   end
        # else
        #   raise "http code: #{res.code}"
        # end
      rescue => e
        puts e.message
        []
      end
    end
  end

end
