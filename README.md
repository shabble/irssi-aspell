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

## Authors

Original by IsaacG (`yitz_@#irssi/Freenode`), Modifications by
Shabble (`shabble@#irssi/Freenode`).

## TODO:

* Configuration options to select dictionaries
* Support for saving to a user dictionary
* Make the N and P keys cycle though completions > 10
* Do something clever about checking screen width vs suggestion
  string length, and wrap appropriately.
* Document More Better.


