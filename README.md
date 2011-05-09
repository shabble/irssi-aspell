# aspell-irssi

An [Aspell](http://aspell.net/) based spellchecker for Irssi.

## Requirements

This script requires that you have installed the

[Text::Aspell](http://search.cpan.org/~hank/Text-Aspell-0.09/Aspell.pm) module
from CPAN.

This is probably in your package manager on *nix
(`apt-get install libtext-aspell-perl` for Debian/Ubuntu), or you can
install it via the cpan or cpan-minus applications.

If you're really masochistic, you could just install from the tarball.
You'll probably need to get and configure aspell with your chosen language
dictionary as well. The internets will tell you how.

## Usage

* `/script load aspell.pl` after putting it in `~/.irssi/scripts/`.
* Bind a key to /spellcheck, something like:
* `/bind meta-d /spellcheck`
* Type something (badly).
* Hit Meta-d
* select from the numerical options at the top of the screen, or space to skip
  to the next word.  Any other key cancels.
  
  
## Authors

Original by IsaacG (`yitz_@#irssi/Freenode`), Modifications by
Shabble (`shabble@#irssi/Freenode`).

## TODO:

* Configuration options to select dictionaries
* Support for saving to a user dictionary
* __DONE__ Make the N and P keys cycle though completions > 10
* Do something clever about checking screen width vs suggestion
  string length, and wrap appropriately.
* Document More Better.
* Something about manually editing (just the) incorrect word highlighted.


