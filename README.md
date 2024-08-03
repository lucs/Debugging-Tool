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

The constructor specifies where to print and how to format the messages you print:

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

Setting `DEBUGGING_TOOL_TO` to a given terminal may be the most useful way to use this module, as your debugging messages won't be interleaved with your program's actual output.

The `$formatter` block may be applied to the message that is to be printed. If not specified but needed, the default one will be used, resulting in strings that look like this:

        «L-⟨line number⟩ ‹⟨message⟩› …/⟨file⟩»

### Printing methods

The basic printing methods are:

        put putf putn putfn
        say sayf sayn sayfn

All have the same structure and build a message to print from their `@elems` argument:

        method ⟨as above, and more⟩ (
            *@elems,
            Real :s($sleep) where * >= 0,
        ) {⋯}

Half of the printing method names start with 'put', and half with 'say'. Before using `@elems` to build the message to print, those that start with 'put' will apply `.Str` to all its elements, and those that start with 'say' will apply `.gist`.

Plain `put` and `say` simply concatenate the `@elems` elements and make that the message that they will display. Note that a newline will be appended to the printed string in both cases.

If 'f' is added to the name, the method will instead interpret `@elems` as a list of arguments (after applying `.Str` or `.gist` n'est-ce pas) to be passed to `sprintf()` to build the message to display.

If 'n' is added to the name, no newline will be added to what is to be printed.

Both 'f' and 'n' can be added (in that order) to either 'put' or 'say' to obtain both effects.

There are also variations of the basic printing methods where their name can be changed by either, or both:

  * Prepending an underscore: The method will print nothing. For example: `_put(⋯)`, `_sayf(⋯)`. This is an easy way to "comment out" such a debugging invocation, and it makes it easy to search for in code too.

  * Appending an underscore: The `$formatter` attribute block will not be applied. For example: `sayn_(⋯)`, `put_(⋯)`.

  * Both can be combined (and nothing gets printed): `_putfn_(⋯)`, `_say_(⋯)`.

If a printing method fails for some reason, a `Debugging::Tool::XCantPrint` exception will be raised.

### Other methods

        method pause    # Printing methods will do nothing until resume() is called.
        method resume   # Resume the printing.

### The `$formatter()` attribute

This attribute is a `Block` that may be invoked by the printing methods. Its default implementation will build a line that looks like this:

        «L-⟨line number⟩ ‹⟨message⟩› …/⟨file⟩»

You can supply your own `$formatter` to the constructor. The `Block` must be declared as taking two arguments and when it gets invoked by the printing methods, the arguments that will be passed to it are the message that was constructed from the printing method's `@elems` and a callframe corresponding to where the printing method was called.

If your formatter is not interested in using either or both of those arguments, just declare them as `Any`. Here are a few illustrations:

            This formatter just returns the message without changing
            anything. It's like if no formatter was being applied or like
            if only methods whose name ends with an underscore were being
            invoked.
        Debugging::Tool.new: 1, -> $msg, Any { $msg }

            This one ignores the message argument and just returns a
            number that increments each time a printing method is called.
            Not really useful, but there it is.
        Debugging::Tool.new: 1, -> Any, Any { state $n = 1; $n++ }

            This one uppercases any message that contains the string
            'error' matched case insensitively.
        Debugging::Tool.new(
            1,
            sub ($msg is copy, Any) {
                $msg .= uc if $msg ~~ m:i/ 'error' /;
                return $msg;
            }
        )

            This is the code of the default formatter.
        sub ($msg, $callframe) {
                The callframe 'file' annotation sometimes
                appends the parenthesized name of the module to
                the file name, so we remove it here.
            (my $filename = $callframe.file) ~~ s/ \s+ '(' \S+ ')' $//;
            sprintf(
                "L-%-5d ‹%s› …/%s",
                $callframe.line,
                $msg,
                $filename.IO.basename,
            );
        }

Examples
--------

This first example presumes that the `DEBUGGING_TOOL_TO` envvar is set to `/dev/pts/8` and that the code is in a file named `wip.raku`:

        use Debugging::Tool;
        my $dt = Debugging::Tool.new;

            # Prints this line in the ‹/dev/pts/8› terminal window:
            # «L-6   ‹The value of $x is 42› …/wip.raku␤»
        $dt.put: 'The value of $x is ', 6 * 7;

This one makes the printing methods output to STDOUT and uses a `$formatter` that uppercases the message to print. It will print a message built with `sprintf()`:

        use Debugging::Tool;
        my $dt = Debugging::Tool.new:
            1,
            :formatter(sub ($msg, Any) {return $msg.uc}),
        ;

            # Will print «ABC - 023␤» to STDOUT.
        $dt.putf: "%s - %03d", 'abc', 23;

This last example will print to STDERR a message without applying the `$formatter` and will sleep a bit after printing it:

        use Debugging::Tool;
        my $dt = Debugging::Tool.new: 2;

            # Prints «Hiya.␤» to STDERR, then sleeps for 1.5 seconds.
        $dt.put_: :s(1.5), 'Hiya.';

AUTHOR
======

Luc St-Louis <lucs@pobox.com>

COPYRIGHT AND LICENSE
=====================

Copyright 2024 Luc St-Louis

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

