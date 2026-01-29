package MT4i::Cache;

##################################################
# Sub ReadCacheOut
##################################################
sub readcacheout {
    my ($key) = @_;

    return 0 if ($::cfg{CacheTime} < 1 || $::admin_mode eq 'yes');

    my $cache_file = $::cfg{MT_DIR}.'mt4i/cache/'.$key;

    # Returns, if the cache file exists or it is size 0.
    return 0 if (!-e $cache_file || -z $cache_file);

    my $mtime = (stat($cache_file))[9];
    my $ntime = time();

    return 0 if ($ntime - $mtime >= $::cfg{CacheTime}*60);

    my $cdata;
    eval { $cdata = lock_retrieve($cache_file); };
    &errout('retrieve cache failed: '.$@) if($@);

    print "Content-Type: text/html\n\n", $$cdata;

    exit;
}

##################################################
# Sub WriteCache
##################################################
sub writecache {
    my ($key, $cdata) = @_;

die "?";
    return 0 if ($::cfg{CacheTime} < 1 || $::admin_mode eq 'yes');

    # make directory
    my @directories = split('/', $key);
    my $dirstr = $::cfg{MT_DIR}.'mt4i/cache/';
    for (my $i = 0; $i < $#directories; $i++) {
        if (!(-d $dirstr.$directories[$i])) {
            mkdir($dirstr.$directories[$i]);
        }
        $dirstr .= $directories[$i].'/';
    }

    # write cache
    my $cache_file = $::cfg{MT_DIR}.'mt4i/cache/'.$key;

    eval { lock_store(\$cdata, $cache_file); };
    &errout('store cache failed: '.$@) if($@);
}

##################################################
# Sub PurgeCache
##################################################
sub purgecache {
    my ($key) = @_;
    my $cache_file = $::cfg{MT_DIR}.'mt4i/cache/'.$key;
    my @fnames = glob($cache_file);
    for my $fname (@fnames) {
        open(OUT,">> $fname") or die "Can't open $fname : $!";
        flock(OUT, 2) or die "Can't flock  : $!";
        truncate(OUT,0) or die "Can't truncate  : $!";
        close(OUT);

        my $log_pl = $Bin.'/mt4ilib/Log.pl';
        eval {require $log_pl; 1} or &errout('File not found: '.$log_pl);
        MT4i::Log::writelog('truncate cache file: '.$fname);
    }
}

1;
