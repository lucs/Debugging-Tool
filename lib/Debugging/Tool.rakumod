unit class Debugging::Tool:ver<0.1.0>:auth<zef:lucs>;

has $!dst-io;
has Block $!formatter;
has $!is-active;

class XCantPrint is Exception {
    has $.excep;
    method message { return $.excep.gist }
}

method new ($destination?, Block $formatter?) {
    my $dst-io = do given ($destination // %*ENV<DEBUGGING_TOOL_TO>) {
        when ! .defined { Nil }
        when 1 { $*OUT }
        when 2 { $*ERR }
        default { $_.IO }
    };
    return self.bless:
        :$dst-io,
        :formatter(
            $formatter // sub ($msg, $callframe) {
                    # The callframe 'file' annotation sometimes
                    # appends the parenthesized name of the module to
                    # the file name, so we remove it here.
                (my $filename = $callframe.file) ~~ s/ \s+ '(' \S+ ')' $//;
                sprintf(
                    "L-%-5d ‹%s› …/%s",
                    $callframe.line,
                    $msg,
                    $filename.IO.basename,
                );
            }
        ),
        :is-active(so $dst-io.defined),
    ;
}

method BUILD (:$!dst-io, :$!is-active, :$!formatter?) { }

use MONKEY-SEE-NO-EVAL;
for <
     print   printf   put   say
     printr  printfr  putr  sayr
    _print  _printf  _put  _say
    _printr _printfr _putr _sayr
> -> $routine-name {
    EVAL q:c:to/EoC/;
        method {$routine-name} (*@str, Real :s($sleep) = 0) {
            '{ self!output: &?ROUTINE.name, $sleep, @str; }'
        }
    EoC
}

method pause  ( ) { $!is-active = False }
method resume ( ) { $!is-active = True }

method !output ($routine-name, $sleep, *@str) {
    my $prn-func = S/ r $// given $routine-name;

    return if (! $!is-active) || ($prn-func ~~ /^ _ /);

    my $msg = do given $prn-func {
        when 'print' | 'put' { @str.map({ $_ // $_.WHAT.Str}).join }
        when 'printf' { sprintf @str }
        when 'say' { @str.map({ $_ // $_.WHAT.gist}).join }
    };

    $msg = $!formatter($msg, callframe(2)) unless $routine-name ~~ / r $ /;
    $msg ~= "\n" if $prn-func eq 'put' | 'say';
    
    try $!dst-io.spurt: :append, $msg;
    XCantPrint.new(excep => $!).throw if $!;

    sleep $sleep;
}

