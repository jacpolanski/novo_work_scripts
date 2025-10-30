// ==UserScript==
// @name         RCP MainPage
// @namespace    http://tampermonkey.net/
// @version      0.1
// @description  try to take over the world!
// @author       You
// @match        https://rcp.novomatic-tech.com/Home.aspx
// @match        https://rcp.novomatic-tech.com/default.aspx
// @grant        none
// ==/UserScript==

(function () {
     if(document.querySelector('#headMenuRight ul').children.length) {
    var nowDate = new Date();
    var now = nowDate.getHours() + ':' + nowDate.getMinutes() + ':' + nowDate.getSeconds();

    var startDay = $("#log strong:last").html();
    if (startDay !== '') {
        getDailyData();
        jQuery.ajax({
            url: "https://rcp.novomatic-tech.com/Rcp.aspx/MyViewRegistrationsCustomize",
            success: getMonthlyData
        });
    }

     }

    function getMonthlyData(result) {
         var myDataPage = $('<div>').html(result);
         let dniWolne = 0;


           let summary = $(myDataPage).find('.tablesummary');
           let norma = summary[0].cells[2].textContent.trim().split(':');
           let zalicz = summary[0].cells[3].textContent.trim().split(':');
           let cells = $(myDataPage).find('.tablecell');
           $(cells).each(function(it) {if($(this)[0].children[1].textContent.trim()=="DWH") dniWolne++ })

        requiredStr = ($(myDataPage).find('.tablesummary td:last')).prev().html();
        includedStr = ($(myDataPage).find('.tablesummary td:last')).html();
        var balance = getSeconds(includedStr) - (getSeconds(requiredStr)-dniWolne*8*3600) - getSeconds('8:00:00') + getSeconds(now) - getSeconds(startDay);
        displayMonthlyBalance(balance);
        displayMonthlyBalanceCompletes( getSeconds(startDay) + getSeconds('8:00:00') - ( getSeconds(includedStr) - (getSeconds(requiredStr)-dniWolne*8*3600)) );
    }



    function getDailyData() {
        var timeTillNow = getSeconds(now) - getSeconds(startDay);
        displayTimeSpent(timeTillNow);
        displayDayCompleted(getSeconds(startDay) + getSeconds('8:00:00'));
        displayDailyBalance(timeTillNow - getSeconds('8:00:00'));
    }

    function getSeconds(timeStr) {
        var splitted = timeStr.split(':');
        if (splitted.length == 2) {
            splitted[2] = 0;
        }
        return parseInt(splitted[0]) * 3600 + parseInt(splitted[1]) * 60 + parseInt(splitted[2]);
    }

    function getSign(val) {
        return val > 0 ? '+' : '-';
    }

    function parseUnits(val) {
        var result = [];
        if (!isNaN(val)) {
            var valAbs = Math.abs(val);
            var hours = Math.floor(valAbs / 3600);
            var minutes = Math.floor(valAbs / 60 - 60 * hours);
            var seconds = Math.floor(valAbs - 3600 * hours - 60 * minutes);
            result[0] = hours;
            result[1] = minutes;
            result[2] = seconds;
        }

        return result;
    }

    function toClockFormat(val) {
        var units = parseUnits(val);
        for (var i = 0; i < units.length; i++) {
            if (units[i] < 10) {
                units[i] = '0' + units[i];
            }
        }

        return units[0] + ':' + units[1];
    }

    function toHumanFormat(val) {
        var result = parseUnits(val)[1] + 'min ' + parseUnits(val)[2] + 's';
        if (parseUnits(val)[0] !== 0) {
            result = parseUnits(val)[0] + 'h ' + result;
        }

        return result;
    }

    function displayTimeSpent(value) {
        $("<div class='info'>Jesteś w pracy już: <span class='value" + value + "'>" + toHumanFormat(value) + "</span></div>").appendTo("#contContent");
    }

    function displayDailyBalance(value) {
        $("<div class='info'>Bilans dzienny: <span  class='value" + value + "'>" + getSign(value) + toHumanFormat(value) + "</span></div>").appendTo("#contContent");
        style(value);
    }

    function displayMonthlyBalance(value) {
        $("<div class='info'>Bilans miesięczny: <span  class='value" + value + "'>" + getSign(value) + toHumanFormat(value) + "</span></div>").appendTo("#contContent");
        style(value);
    }

    function displayDayCompleted(value) {
        $("<div class='info'>Osiem godzin minie o <span  class='value" + value + "'>" + toClockFormat(value) + "</span></div>").appendTo("#contContent");
    }

    function displayMonthlyBalanceCompletes(value) {
        $("<div class='info'>Będziesz na 0 w tym miesiącu o <span  class='value" + value + "'>" + toClockFormat(value) + "</span></div>").appendTo("#contContent");
        style(value);
    }

    function style(value) {
        $(".info").css('padding-top', '10px').css("font-family", "Roboto").css("font-size", "14px").css("color", "#696969");
        if (value >= 0) {
            $(".value" + value).css('color', 'green');
        } else {
            $(".value" + value).css('color', 'red');
        }
    }
})();