// import all custom js files
import './custom.candidate'
import './custom.project'
import './custom.czbank'


// DOMContentLoaded events ----------------------------------------------------------------------
$(document).on('turbolinks:load', function(){
    setTimeout("$('.alert').css('display','none')",5000);
    $('.datetimepicker').datetimePicker();
    $('.datepicker').datePicker();
    $('.monthpicker').monthPicker();
    if($('select.select2').next('.select2-container').length){
        $('.select2-container').remove();  // turbolinks:reload + select2 重复加载bug修复
    }
    $('select.select2').select2();
    $('input[type=number]').mousewheel(function(){
        disableMouseWheelScroll();  // 全局禁用 number 的滚轮
    });
    $('[data-toggle="popover"]').popover();
    $('select.select2-province-options').select2({
        ajax: {
            url: '/location_data/province_options.json',
            dataType: 'json',
            type: 'get',
            delay: 250,
            data: function (params) {
                return { name: params.term };
            },
            processResults: function (data) {
                var options = [ { id: '', text: 'Please select' } ];
                $(data).each(function(i, o){ options.push({ id: o.id, text: o.name }) });
                return { results: options };
            },
            cache: true
        }
    });
    $('select.select2-hospital-options').select2({
        ajax: {
            url: '/hospitals/hospital_options.json',
            dataType: 'json',
            type: 'get',
            delay: 250,
            data: function (params) {
                return { name: params.term };
            },
            processResults: function (data) {
                var options = [ { id: '', text: 'Please select' } ];
                $(data).each(function(i, o){ options.push({ id: o.id, text: o.name }) });
                return { results: options };
                // return { results: $(data).map(function(i,o) { return { id: o.id, text: o.name } }) };
            },
            cache: true
        }
    })
    $('select.select2-gender-with-icon').select2({
        templateResult: genderFormat,
        templateSelection: genderFormat
    })
    $('select.select2-boolean-with-icon').select2({
        templateResult: booleanFormat,
        templateSelection: booleanFormat
    })
});

function genderFormat(state){
    if (!state.id) { return state.text; }
    var $state = $('<span>' + state.text + '</span>');
    if(state.id === 'male') {
        $state = $('<span><i class="fa fa-male text-primary mr-2"></i>' + state.text + '</span>');
    } else if ( state.id === 'female') {
        $state = $('<span><i class="fa fa-female text-danger mr-2"></i>' + state.text + '</span>');
    }
    return $state;
}

function booleanFormat(state){
    if (!state.id) { return state.text; }
    var $state = $('<span>' + state.text + '</span>');
    if(state.id === 'true') {
        $state = $('<span><i class="fa fa-circle-o text-success mr-2"></i>' + state.text + '</span>');
    } else if ( state.id === 'false') {
        $state = $('<span><i class="fa fa-times text-danger mr-2"></i>' + state.text + '</span>');
    } else {
        $state = $('<span><i class="fa fa-question text-secondary mr-2"></i>' + state.text + '</span>');
    }
    return $state;
}

// select all checkbox
window.selectAll = function(ele, name){
    name = name || 'uids[]';
    const target = $('input:checkbox[name="' + name + '"]');
    target.each(function(){
        this.checked = ele.checked;
    });
};

// ===== Date & Time picker =====
$.fn.datePicker = function(){
    $(this).datetimepicker(
        {
            format: 'Y-m-d',
            timepicker: false,
            allowBlank: true
        }
    );
};

$.fn.datetimePicker = function(){
    $(this).datetimepicker(
        {
            format: 'Y-m-d H:i',
            timepicker: true,
            allowBlank: true
        }
    );
};

$.fn.monthPicker = function(){
    $(this).datetimepicker(
        {
            format: 'Y-m',
            timepicker: false,
            allowBlank: true
        }
    );
};

// form activate/deactivate
window.form_activate = function(field){
    let ele = $('#' + field);
    ele.attr('required', true);
    ele.parent().show();
};

window.form_deactivate = function(field){
    let ele = $('#' + field);
    ele.attr('required', false);
    ele.val('');
    ele.parent().hide();
};

window.form_show = function(field){
    let ele = $('#' + field);
    ele.parent().show();
};

window.form_hide = function(field){
    let ele = $('#' + field);
    ele.val('');
    ele.parent().hide();
};

// forbid mouse wheel scroll event
window.disableMouseWheelScroll = function(e){
    e = e || window.event;
    if(e.preventDefault) {
        // Firefox
        e.preventDefault();
        e.stopPropagation();
    } else {
        // IE
        e.cancelBubble=true;
        e.returnValue = false;
    }
    return false;
};

window.utilsLoadingModal = function(params){
    console.log('utilsLoadingModal:', params);
    $.get('/utils/loading_modal.js', params);
};