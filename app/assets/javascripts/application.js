//= require jquery-ui.min
//= require select2.min
//= require echarts.min
//= require echarts-gl.min
//= require jquery.datetimepicker.full
//= require clipboard.min
//= require vue
//= require element-ui
//= require xlsx.full.min

Vue.config.productionTip = false
Vue.prototype.$echarts = echarts
Vue.filter('truncate', function(val, length) {
  if (!val) return ''
  val = val.toString()
  if (val.length > length) {
      return val.substring(0, length) + '...'
  } else {
      return val
  }
})

Vue.filter('url_basename', function(val) {
  if (!val) return ''
  val = val.toString()
  let res = val.split('/')[val.split('/').length -1]
  return decodeURI(res || '')
})

const open_spreadsheet = (file) => {
  return new Promise((resolve, reject) => {
    let arr = file.name.split('.');
    let extname = arr[arr.length - 1]
    if (!['xlsx', 'xls'].includes(extname)) {
      return reject({ msg: '不支持解析该文件格式' })
    }

    const reader = new FileReader();
      reader.readAsBinaryString(file.raw);
      reader.onload = e => {
          const data = e.target.result;
          const excel = window.XLS.read(data, { type: 'binary' });
          const sheet = window.XLS.utils.sheet_to_csv(excel.Sheets[excel.SheetNames[0]], { FS: '|' })
          let rows = []
          sheet.split("\n").forEach((item, index) => {
            rows.push(item.split('|'))
          })
          resolve({ rows: rows, sheet_name: excel.SheetNames[0] })
      }
  })
}

// 导出excel的封装方法
function exportDataAsExcel(header, dataList, filename) {
  // 验证是否有导出数据
  if(!Array.isArray(dataList) || dataList.length < 1) {
    alert('可导出的数据为空')
    return;
  }
  let sheetName = filename || 'export';
  // 生成sheet
  let excelData = [header, ...dataList]
  let ws = this.aoa_to_sheet(excelData, 1);
  ws['!cols'] = []
  header.forEach(() => {
    ws['!cols'].push({ wpx: 140 });
  })
  let workbook = {
    SheetNames: [sheetName],
    Sheets: {}
  };
  workbook.Sheets[sheetName] = ws;
  // excel样式
  let wopts = {
    bookType: 'xlsx',
    bookSST: false,
    type: 'binary',
    cellStyles: true
  };
  let wbout = XLSX.write(workbook, wopts);
  let blob = new Blob([s2ab(wbout)], { type: "application/octet-stream" });
  this.openDownloadXLSXDialog(blob, sheetName + '.xlsx')
}

function aoa_to_sheet(data, headerRows) {
  const ws = {};
  const range = { s: { c: 10000000, r: 10000000 }, e: { c: 0, r: 0 } };
  for (let R = 0; R !== data.length; ++R) {
    for (let C = 0; C !== data[R].length; ++C) {
      if (range.s.r > R) {
        range.s.r = R;
      }
      if (range.s.c > C) {
        range.s.c = C;
      }
      if (range.e.r < R) {
        range.e.r = R;
      }
      if (range.e.c < C) {
        range.e.c = C;
      }
      /// 这里生成cell的时候，使用上面定义的默认样式
      const cell = {
        v: data[R][C] == 0 ? data[R][C] : (data[R][C] || ''),
        s: {
          font: { name: "宋体", sz: 11, color: { auto: 1 } },
          alignment: {
            /// 自动换行
            wrapText: 1,
            // 居中
            horizontal: "center",
            vertical: "center",
            indent: 0
          }
        }
      };
      // 头部列表加边框
      if (R < headerRows) {
        cell.s.border = {
          top: { style: 'thin', color: { rgb: "000000" } },
          left: { style: 'thin', color: { rgb: "000000" } },
          bottom: { style: 'thin', color: { rgb: "000000" } },
          right: { style: 'thin', color: { rgb: "000000" } },
        };
        cell.s.fill = {
          patternType: 'solid',
          fgColor: { theme: 3, "tint": 0.3999755851924192, rgb: 'C5DAF1' },
          bgColor: { theme: 7, "tint": 0.3999755851924192, rgb: '8064A2' }
        }
      }
      const cell_ref = XLSX.utils.encode_cell({ c: C, r: R });
      if (typeof cell.v === 'number') {
        cell.t = 'n';
      } else if (typeof cell.v === 'boolean') {
        cell.t = 'b';
      } else {
        cell.t = 's';
      }
      ws[cell_ref] = cell;
    }
  }
  if (range.s.c < 10000000) {
    ws['!ref'] = XLSX.utils.encode_range(range);
  }
  return ws;
}

function s2ab(s) {
  let buf = new ArrayBuffer(s.length);
  let view = new Uint8Array(buf);
  for (let i = 0; i !== s.length; ++i) {
    view[i] = s.charCodeAt(i) & 0xFF;
  }
  return buf;
}

function openDownloadXLSXDialog(url, saveName) {
  if (typeof url == 'object' && url instanceof Blob) {
    url = URL.createObjectURL(url); // 创建blob地址
  }
  var aLink = document.createElement('a');
  aLink.href = url;
  aLink.download = saveName || ''; // HTML5新增的属性，指定保存文件名，可以不要后缀，注意，file:///模式下不会生效
  var event;
  if (window.MouseEvent) {
    event = new MouseEvent('click');
  } else {
    event = document.createEvent('MouseEvents');
    event.initMouseEvent('click', true, false, window, 0, 0, 0, 0, 0, false,
      false, false, false, 0, null);
  }
  aLink.dispatchEvent(event);
}