use warnings;
use strict;
use Data::Dumper;
use Irssi;

eval {
    use Text::Aspell;
};

if ($@ && $@ =~ m/Can't locate/) {
    print '%_Bugger, please insteall Text::Aspell%_'
}


our $VERSION = '1.1';
our %IRSSI = (
              authors     => 'IsaacG, Enscienced by Shabble',
              name        => 'aspell',
              description => 'ASpell spellchecking system for Irssi',
             );

# ---------------------------
#           Globals
# ---------------------------

my $DEBUG = 1;

my @word_pos_array;
my $index;

my @suggestions;
my $suggestion_page;

my $aspell;

my $split_win_ref;
my $original_win_ref;

my $corrections_active;


# ---------------------------
#      key constants
# ---------------------------

sub K_ESC () { 27  }
sub K_RET () { 10  }
sub K_SPC () { 32  }
sub K_0   () { 48  }
sub K_9   () { 57  }
sub K_N   () { 110 }
sub K_P   () { 112 }
sub K_I   () { 105 }

# ---------------------------
#        Teh Codez
# ---------------------------

sub check_line {
	my ($line) = @_;

    # reset everything
    $suggestion_page    = 0;
    $corrections_active = 0;
    $index              = 0;
    @word_pos_array     = ();
    @suggestions        = ();
    close_temp_split();

    # split into an array of words on whitespace, keeping track of
    # positions of each, as well as the size of whitespace.

    my $pos = 0;

    _debug('check_line processing "%s"', $line);

    while ($line =~ m/\G(\S+)(\s*)/g) {
        push @word_pos_array, { word => $1, pos => $pos };
        $pos += length ($1.$2);
    }

    return unless @word_pos_array > 0;

    process_word($word_pos_array[0]);
}

sub process_word {
    my ($word_obj) = @_;

    my $word = $word_obj->{word};

    if (not $aspell->check($word)) {

        _debug("Word '%s' is incorrect", $word);
        $corrections_active = 1;
        @suggestions = get_suggestions($word);
        highlight_incorrect_word($word_obj);

        if (not temp_split_active()) {
            _debug("Creating temp split to show candidates");
            create_temp_split();
        } else {
            print_suggestions();
        }
    } else {
        spellcheck_next_word();
    }
}

sub get_suggestions {
    my ($word) = @_;
    my @suggestions = $aspell->suggest($word);
    _debug("Candidates for '$word' are %s", join(", ", @suggestions));
    return @suggestions;
}


# Read from the input line
sub cmd_spellcheck_line {
    my ($args, $server, $witem) = @_;
	my $inputline = Irssi::parse_special('$L');
    check_line($inputline);
}

sub spellcheck_finish {
    $corrections_active = 0;
    close_temp_split();
}

sub sig_gui_key_pressed {
    my ($key) = @_;
    return unless $corrections_active;

    my $char = chr($key);

    if ($key == K_ESC) {
        spellcheck_finish();

    } elsif ($key >= K_0 && $key <= K_9) {
        _debug("Selecting word: $char");
        spellcheck_select_word($char);

    } elsif ($key == K_SPC) {
        _debug("skipping word");
        spellcheck_next_word();
    } elsif ($key == K_I) {
        _print("Not implemented yet :(");
    } elsif ($key == K_N) { # next 10 results

        if ((scalar @suggestions) > (10 * ($suggestion_page + 1))) {
            $suggestion_page++;
        } else {
            $suggestion_page = 0;
        }
        print_suggestions();

    } elsif ($key == K_P) { # prev 10 results
        if ($suggestion_page > 0) {
            $suggestion_page--;
        }
        print_suggestions();

    } else {
        spellcheck_finish();
    }

    Irssi::signal_stop();
}

sub spellcheck_next_word {
    $index++;

    if ($index >= @word_pos_array) {
        _debug("End of words");
        spellcheck_finish();
        return;
    }

    _debug("moving onto the next word: $index");
    process_word($word_pos_array[$index]);

}
sub spellcheck_select_word {
    my ($num) = @_;
    my $word = $suggestions[$num];
    _debug("Selected word $num: $word as correction");
    correct_input_line_word($word_pos_array[$index], $word);
}

sub _debug {
    my ($fmt, @args) = @_;
    return unless $DEBUG;

    $fmt = '%%RDEBUG:%%n ' . $fmt;
    my $str = sprintf($fmt, @args);
    Irssi::window_find_refnum(1)->print($str);
}

sub _print {
    my ($fmt, @args) = @_;
    my $str = sprintf($fmt, @args);
    Irssi::active_win->print('%g' . $str . '%n');
}

# Read from the argument list

sub cmd_spell_args {
    my ($inputline) = @_;
    _print('%%R%%_ Sorry, this command is currently broken. %%_%%n');
#    check_line($inputline);
}


sub temp_split_active () {
    return defined $split_win_ref;
}

sub create_temp_split {
    $original_win_ref = Irssi::active_win();
    Irssi::signal_add_first('window created', 'sig_win_created');
    Irssi::command('window new split');
    Irssi::signal_remove('window created', 'sig_win_created');
}

sub UNLOAD {
    close_temp_split();
}

sub close_temp_split {

    if (temp_split_active()) {
        Irssi::command("window close $split_win_ref->{refnum}");
        undef $split_win_ref;
    }

    # restore original window focus
    return unless defined $original_win_ref;
    return unless ref $original_win_ref;

    if (Irssi::active_win()->{refnum} != $original_win_ref->{refnum}) {
        _debug("Winref: %s: %s", ref($original_win_ref), Dumper($original_win_ref));
        ref($original_win_ref) and $original_win_ref->set_active();
    }
}

sub sig_win_created {
    my ($win) = @_;
    $split_win_ref = $win;
    # printing directly from this handler causes irssi to segfault.
    Irssi::timeout_add_once(10, \&configure_split_win, {});
}

sub configure_split_win {
    $split_win_ref->command("win size 4");
    print_suggestions();
}

sub correct_input_line_word {
    my ($word_obj, $correction) = @_;
    my $input = Irssi::parse_special('$L');

    my $word = $word_obj->{word};
    my $pos  = $word_obj->{pos};

    _debug("Index of incorrect word is %d", $index);
    _debug("Correcting word %s (%d) with %s", $word, $pos, $correction);

    my $orig_length = length $word;
    my $new_length  = length $correction;

    my $diff = $new_length - $orig_length;

    _debug("diff between $word and $correction is $diff");

    $word_pos_array[$index] = { word => $correction, pos => $pos + $diff };
    substr($input, $pos, length($word)) = $correction;
    # now we have to go through and fix up all teh positions since
    # the correction might be a different length.

    #starting at $index, add the diff to each position.
    foreach my $new_obj (@word_pos_array[$index..$#word_pos_array]) {
        $new_obj->{pos} += $diff;
    }

    _debug("Setting input to new value: '%s'", $input);
    Irssi::gui_input_set($input);

    _debug("-------------------------------------------------");
    spellcheck_next_word();
}

sub highlight_incorrect_word {
    my ($word_obj) = @_;
    Irssi::gui_input_set_pos($word_obj->{pos});
}

sub print_suggestions {
    my $count = scalar @suggestions;
    my $pages = int ($count / 10);
    my $bot = $suggestion_page * 10;
    my $top = $bot + 9;

    $top = $#suggestions if $top > $#suggestions;

    my @visible = @suggestions[$bot..$top];
    my $i = 0;
    my @visible
      = map { sprintf("(%d) %s", $i++, $_) } @visible;

    # disable timestamps to ensure a clean window.
    my $orig_ts_level = Irssi::parse_special('$timestamp_level');
    $split_win_ref->command("^set timestamp_level $orig_ts_level -CLIENTCRAP");

    # clear the window
    $split_win_ref->command("/^scrollback clear");
    my $msg = sprintf('%s [Pg %d/%d] Select a number or SPC to ignore this word. Any '
                      . 'other key cancels %s',
                      '%_', $suggestion_page + 1, $pages + 1, '%_');

    my $word = $word_pos_array[$index]->{word};

    $split_win_ref->print($msg);
    $split_win_ref->print('%_<' . $word . '>%_ ' .  join(" ", @visible));

    # restore timestamp settings.
    $split_win_ref->command("^set timestamp_level $orig_ts_level");

}

sub sig_setup_changed {
    $DEBUG = Irssi::settings_get_bool('aspell_debug');
}

sub init {
    Irssi::settings_add_bool('aspellchecker', 'aspell_debug', 0);

    sig_setup_changed();

    Irssi::signal_add('setup changed' => \&sig_setup_changed);

    _debug("ASpell spellchecker loaded");

    $corrections_active = 0;
    $index              = 0;

    Irssi::signal_add_first('gui key pressed' => \&sig_gui_key_pressed);
    Irssi::command_bind('spellcheck', \&cmd_spellcheck_line);

    Irssi::command_bind('spell', 'cmd_spell_args');
    #Irssi::command("/^bind meta-d /spellcheck");
    $aspell = Text::Aspell->new;

}

init();
