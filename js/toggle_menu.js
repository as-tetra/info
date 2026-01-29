$(function(){

    let timer = false;
    let sp_flag;
    let previous_sp_flag = window.matchMedia( "(max-width: 640px)").matches;

    //複数案を一つの実装で確認するためにurlのqueryで分岐。そのquery抽出する
    //let query_ver;
    //let param = location.search;

    //query_ver = 3;
    //$(".ver3").show();
    //$(".ver1").hide();
    //テスト用実装
    //if (previous_sp_flag) {
    //    $(".ver1").show();
    //    $(".ver3").hide();
    //}

    //トップに戻るボタンスムーズスクロール
    $("#to_top").hide();
    $(window).scroll(function () {
        if ($(this).scrollTop() > 100) {
            $('#to_top').fadeIn();
        } else {
            $('#to_top').fadeOut();
        }
    });
    $('#to_top').click(function () {
        $('body,html').animate({
            scrollTop: 0
        }, 800);
        return false;
    });

    //メニューボタンでSPメニュートグル
    $("#menu_button").on("click", function() {
        $("#nav_wrap").slideToggle();
        $(".fa-chevron-circle-down").toggle();
        $(".fa-times-circle").toggle();
    });
    //リサイズ時に、SP->PCサイズ(640px以上)になったときだけreloadしてメニューを必ず表示する
    //$(window).resize(function() {
    //    sp_flag = window.matchMedia( "(max-width: 640px)").matches;
    //    if (timer !== false) {
    //        clearTimeout(timer);
    //    }
    //    timer = setTimeout(function() {
    //        if ((!sp_flag) && (sp_flag != previous_sp_flag)) {
    //            location.reload();
    //        }
    //        previous_sp_flag = sp_flag;
    //    }, 200);

        //テスト用実装
        //if (sp_flag) {
        //    $(".ver1").show();
        //    $(".ver3").hide();
        //}

    //});
});
