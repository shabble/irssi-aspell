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


our $VERSION = '1.0';
our %IRSSI = (
              authors     => 'IsaacG',
              name        => 'aspell',
              description => 'aspell wrapper',
             );

my $DEBUG = 1;

my @word_pos_array;
my $index = 0;

my @suggestions;

my $aspell;

my $split_win_ref;
my $original_win_ref;

my $corrections_active;

sub check_line {
	my ($line) = @_;
    @word_pos_array = ();
    # split into an array of words on whitespace, keeping track of
    # positions of each.
    my $l_copy = $line;
    my $pos = 0;
    _debug('check_line processing "%s"', $line);
    while ($l_copy =~ m/\G(\S+)(\s*)/g) {
        push @word_pos_array, { word => $1, pos => $pos };
        $pos += length ($1.$2);
    }

    foreach my $word (@word_pos_array) {
        if (not check_word($word)) {
            $corrections_active = 1;
            my @suggestions = get_suggestions($word);

            if (not temp_split_active()) {
                create_temp_split();
            } else {
                print_suggestions();
            }
        }
    }
}




#    Irssi::active_win->print(Dumper(\@array));



# Strip non-alpha/space and form the command
# $inputline =~ tr/a-zA-Z' //cd;


# my $cmd = "aspell -a <<< \"$inputline\"";
# # Run the command and parse the output. Print the output of an all clear message
# my @results = split(/\n/, `$cmd`);
# shift @results;
# @results = grep {$_ ne "*"} @results;
# Irssi::active_win()->print("spell: $_", MSGLEVEL_CRAP ) for @results;
# Irssi::active_win()->print("spell: Nothing found. All good :)", MSGLEVEL_CRAP ) unless @results;
#}

sub check_word {
    my ($word) = @_;
    return $aspell->check($word);
}

sub get_suggestions {
    my ($word) = @_;
    my @suggestions = $aspell->suggest($word);
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

    if ($key = 27) {
        spellcheck_finish();
    } elsif ($key >= ord("0") && $key <= ord("9")) {
        spellcheck_select_word($char);
    } elsif ($key == ord(" ")) {
        spellcheck_next_word();
    } elsif ($key == ord('i')) {
        _print("Not implemented yet :(");
    } else {
        spellcheck_finish();
    }
}

sub spellcheck_select_word {
    my ($num) = @_;
    my $word = $suggestions[$num];
    correct_input_line_word($word_pos_array[$index], $word);

}

sub cmd_spell_skip_next {
    my $word_obj = $word_pos_array[$index++];
    Irssi::gui_input_set_pos($word_obj->{pos});
    _print("Word: %s, pos: %d", $word_obj->{word}, $word_obj->{pos});
    if ($index == @word_pos_array) {
        _print("End of array");
        $index = 0;
    }
}
sub _debug {
    my ($fmt, @args) = @_;
    return unless $DEBUG;

    $fmt = '%%RDEBUG:%%n ' . $fmt;
    my $str = sprintf($fmt, @args);
    Irssi::active_win->print($str);
}

sub _print {
    my ($fmt, @args) = @_;
    my $str = sprintf($fmt, @args);
    Irssi::active_win->print($str);
}

# Read from the argument list

sub cmd_spell_args {
    my ($inputline) = @_;
    check_line($inputline);
}


sub temp_split_active () {
    return defined $split_win_ref;
}

sub create_temp_split {

    Irssi::signal_add_first('window created', 'sig_win_created');
    Irssi::command('window new split');
    Irssi::signal_remove('window created', 'sig_win_created');
}

sub close_temp_split {

    if (temp_split_active()) {
        Irssi::command("window close $split_win_ref->{refnum}");
        undef $split_win_ref;
    }

    # restore original window focus
    if (Irssi::active_win()->{refnum} != $original_win_ref->{refnum}) {
        $original_win_ref->set_active();
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

sub print_suggestions {
    if (@suggestions > 10) {
        @suggestions = @suggestions[0..9];
    }
    my $i = 0;
    my @print_suggestions
      = map { sprintf("(%d) %s", $i++, $_) } @suggestions;
    $split_win_ref->print('%%_Select a number, SPC to ignore, ' .
                          'or i to add to personal dictionary%%_');
    $split_win_ref->print(join(" ", @print_suggestions));
}

  sub correct_input_line_word {
      my ($word_obj, $correction) = @_;
      my $input = Irssi::parse_special('$L');

      substr($input, $word_obj->{pos}, length($word_obj->{word}), $correction);

      Irssi::gui_input_set($input);
      spellcheck_next_word();
  }

sub init {
    _debug("ASpell spellchecker loaded");
    $corrections_active = 0;
    Irssi::signal_add_first('gui key pressed' => \& sig_gui_key_pressed);

    Irssi::command_bind('spellcheck', \&cmd_spellcheck_line);
    Irssi::command_bind('spell_next', \&cmd_spell_skip_next);

    Irssi::command_bind('spell', 'cmd_spell_args');
    Irssi::command("/bind meta-d /spellcheck");
    Irssi::command("/bind meta-f /spell_next");
    $aspell = Text::Aspell->new;
    #    _print(Dumper($aspell->fetch_option_keys()));
}

init();
1;
