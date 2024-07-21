[![Actions Status](https://github.com/lucs/Debugging-Tool/actions/workflows/test.yml/badge.svg)](https://github.com/lucs/Debugging-Tool/actions)

NAME
====

    Debugging::Tool - To print debugging info during development

DESCRIPTION
-----------

Brian Kernighan observed in "Unix for Beginners" (1979) that "The most effective debugging tool is still careful thought, coupled with judiciously placed print statements.".

`Debugging::Tool` instances help placing those print statements, but the careful thought part is left up to you. A `Debugging::Tool` instance's printing methods can print a message you want, mentioning by default on which line of which file the method was called.

SUMMARY
-------

### Constructor

The constructor specifies where to print and how to format the message you print:

        method new (
            $destination?,
            Block $formatter?,
        )

Valid values for `$destination` are:

        1             : $*OUT
        2             : $*ERR
        'wut.debug'   : some arbitrary file name
        '/tmp/baz'    : some other arbitrary file name
        '/dev/pts/8'  : some arbitrary terminal

If `$destination` is not specified or is `Any`, the program will check to see if the `DEBUGGING_TOOL_TO` envvar is set. If it is, it will use that value, otherwise the instance's printing methods will do nothing.

The `$formatter` block may be applied to the message that is to be printed. If not specified but needed, the default one will be used, resulting in strings that look like this:

        «L-⟨line number⟩ ‹⟨message⟩› …/⟨file⟩»

### Printing methods

These methods build a message to print from `@str` elements. They work similarly to the Raku `print`, `printf`, `put`, and `say` routines, but may apply the instance's `$formatter` before printing. They may also sleep a while after printing:

        method ❲
             print  ∣  printf   ∣  put   ∣  say  ∣
             printr ∣  printfr  ∣  putr  ∣  sayr ∣
            _print  ∣ _printf   ∣ _put   ∣ _say  |
            _printr ∣ _printfr  ∣ _putr  ∣ _sayr
        ❳ (
            *@str,
            Real :s($sleep) where * >= 0,
        )

Here's the difference between them:

                                         Apply       Then append
                           ‹@str›        $formatter  newline
                           -----------   ----------  -----------
        print  / printr  : Concat        Yes/No      No/No
        printf / printfr : ‹sprintf()›   Yes/No      No/No
        put    / putr    : Concat .Str   Yes/No      Yes/Yes
        say    / sayr    : Concat .gist  Yes/No      Yes/Yes

The underscore-prefixed ones simply ignore their arguments:

        _print   _printr
        _printf  _printfr
        _put     _putr
        _say     _sayr

If a printing method fails for some reason, a `Debugging::Tool::XCantPrint` exception will be raised.

### Other methods

        method pause    # Printing methods will do nothing until resume() is called.
        method resume   # Resume the printing.

### The `$formatter()` attribute

This attribute is a `Block` that may be invoked by the printing methods. Its default implementation will build a line that looks like this:

        «L-⟨line number⟩ ‹⟨message⟩› …/⟨file⟩»

You can supply your own `$formatter` to the constructor. The `Block` must be declared as taking two arguments and when it gets invoked by the printing methods, the arguments that will be passed to it are the message that was constructed from the printing method's `@str` arguments and a callframe corresponding to where the printing method was called.

If your formatter is not interested in using either or both of those arguments, just declare them as `Any`. Here are a few examples:

            # This formatter just returns the message without changing
            # anything. It's like if no formatter was being applied or
            # like if only methods ending in ‹r› were being invoked.
        Debugging::Tool.new: 1, -> $msg, Any { $msg }

            # This ignores the message to print and just prints a line
            # with a number that increments each time a printing method is
            # called. Not really useful, but there it is.
        Debugging::Tool.new: 1, -> Any, Any { state $n = 0; "$n++\n" }

            # Another dumb example.
        Debugging::Tool.new(
            1,
            sub ($msg is copy, Any) {
                return "I don't want to see the error!" if $msg ~~ m:i/ 'error' /;
                $msg .= uc;
            }
        )

            # This is the code of the default formatter.
        -> $msg, $callframe {
            sprintf(
                "L-%-5d ‹%s› …/%s",
                $callframe.line,
                $msg,
                $callframe.file.IO.basename,
            );
        }

Examples
--------

This first example presumes that the `DEBUGGING_TOOL_TO` envvar is set to `/dev/pts/8` and that the code is in a file named `wip.raku`: Printing to a given terminal window can be useful when you don't want the debugging messages to be interleaved with your program's actual output. It's the approach I use most of the time with this module:

        use Debugging::Tool;
        my $dt = Debugging::Tool.new;

            # Prints this line in the ‹/dev/pts/8› terminal window:
            # «L-6   ‹The value of $x is 42› …/wip.raku␤»
        $dt.put: 'The value of $x is ', 6 * 7;

This one makes the printing methods output to STDOUT and uses a `$formatter` that uppercases the message to print. It prints a message built with `sprintf()`:

        use Debugging::Tool;
        my $dt = Debugging::Tool.new:
            1,
            :formatter(sub ($msg, Any) {return $msg.uc ~ "\n"}),
        ;

            # Will print «ABC - 023␤» to STDOUT.
        $dt.printf: "%s - %03d", 'abc', 23;

This last example prints to STDERR a message without applying the `$formatter` and sleeps a bit after printing it:

        use Debugging::Tool;
        my $dt = Debugging::Tool.new: 2;

            # Prints «Hiya.␤» to STDERR, then sleeps for 1.5 seconds.
        $dt.sayr: :s(1.5), 'Hiya.';

AUTHOR
======

Luc St-Louis <lucs@pobox.com>

COPYRIGHT AND LICENSE
=====================

Copyright 2024 Luc St-Louis

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

