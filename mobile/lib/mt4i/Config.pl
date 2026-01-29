package Config;

# 設定読み込み
sub Read {
    my ($cfg_file) = @_;
    
    # 設定ファイルオープン
    open(IN,"< $cfg_file") or return undef;

    # 設定格納用連想配列（ハッシュ）変数宣言
    my %cfg = ();
    
    # 読み込み
    while (<IN>){
        my $tmp = $_;
        
        # 改行コードの削除
        chomp($tmp);
        
        if ($tmp !~ /^#/) {
            my $key;
            my $val;
            ($key, $val) = split(/<>/,$tmp);
            if ($key && ($val || $val eq '0')) {
                $cfg{$key} = $val;
            }
        }
    }

    # 設定ファイルクローズ
    close(IN);
    
    return %cfg;
}

1;
