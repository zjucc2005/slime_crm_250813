window.loadCzbankXibaoList = function(belong_date){
    $.get('/czbank/xibao_list.js', { belong_date: belong_date });
};