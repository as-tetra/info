package MT4i::Ad;

use Encode;

########################################
# Sub Ad_Exchange - 広告ランダム表示
########################################
sub ad_exchange {
    my ($ua) = @_; 
    my @ad_str;

    if ($ua eq 'i-mode' || $ua eq 'ezweb' || $ua eq 'j-sky') {
        #----- 携帯電話からのアクセス -----
    
        # 広告文字列定義
        push(@ad_str,
            '',
        );
        
        # Vodafoneのみ有効な広告文字列を追加
        if ($ua eq 'j-sky') {
            push(@ad_str,
                '',
            );
        }
        
        # EZweb(au)のみ有効な広告文字列を追加
        if ($ua eq 'ezweb') {
            push(@ad_str,
                '',
            );
        }
        
        # i-modeのみ有効な広告文字列を追加
        if ($ua eq 'i-mode') {
            push(@ad_str,
                '',
            );
        }
            
    } else {
        # 携帯電話"以外"からのアクセス
        push(@ad_str,
            '',
        );
    }

    # 配列の最終添字 + 1（添字は0から始まるので）取得
    my $no = $#ad_str + 1;

    # 乱数発生
    srand;
    $no = int(rand($no));

    # 文字列を Shift_JIS に変換
    $ad_str[$no] = Encode::encode("shiftjis", Encode::decode("euc-jp", $ad_str[$no]));

    # 広告文字列を返す
    return $ad_str[$no];
}

1;
