unit class Debugging::Tool:ver<0.3.0>:auth<zef:lucs>;

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

method pause  ( ) { $!is-active = False }
method resume ( ) { $!is-active = True }

method !output ($meth-name, $sleep, *@elems) {
    return unless $!is-active && $meth-name.substr(0, 1) ne '_';

    @elems = $meth-name ~~ / ^ put /
        ?? @elems>>.Str
        !! @elems>>.gist
    ;

    my $msg = $meth-name.substr(3, 1) eq 'f'
        ?? sprintf(| @elems)
        !! @elems.join
    ;

    $msg = $!formatter($msg, callframe(2)) unless $meth-name ~~ / '_' $ /;
    $msg ~= "\n" unless $meth-name ~~ / 'n' /;
    
    try $!dst-io.spurt: :append, $msg;
    XCantPrint.new(excep => $!).throw if $!;

    sleep $sleep;
}

use MONKEY-SEE-NO-EVAL;
for <
     put   putf   putn   putfn
     say   sayf   sayn   sayfn
> -> $name {
    for "$name", "{$name}_", "_$name", "_{$name}_" -> $meth-name {
        EVAL q:c:to/EoC/;
            method {$meth-name} (*@elems, Real :s($sleep) = 0) {
                '{ self!output: &?ROUTINE.name, $sleep, @elems; }'
            }
        EoC
    }
}

