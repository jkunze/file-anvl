use 5.006;
use Test::More qw( no_plan );

use strict;
use warnings;

my $script = "anvl";		# script we're testing

# as of 2009.08.27  (SHELL stuff, remake_td, Config perlpath)
#### start boilerplate for script name and temporary directory support

use Config;
$ENV{SHELL} = "/bin/sh";
my $td = "td_$script";		# temporary test directory named for script
# Depending on circs, use blib, but prepare to use lib as fallback.
my $blib = (-e "blib" || -e "../blib" ?	"-Mblib" : "-Ilib");
my $bin = ($blib eq "-Mblib" ?		# path to testable script
	"blib/script/" : "") . $script;
my $perl = $Config{perlpath} . $Config{_exe};	# perl used in testing
my $cmd = "2>&1 $perl $blib " .		# command to run, capturing stderr
	(-x $bin ? $bin : "../$bin") . " ";	# exit status in $? >> 8

my ($rawstatus, $status);		# "shell status" version of "is"
sub shellst_is { my( $expected, $output, $label )=@_;
	$status = ($rawstatus = $?) >> 8;
	$status != $expected and	# if not what we thought, then we're
		print $output, "\n";	# likely interested in seeing output
	return is($status, $expected, $label);
}

use File::Path;
sub remake_td {		# make $td with possible cleanup
	-e $td			and remove_td();
	mkdir($td)		or die "$td: couldn't mkdir: $!";
}
sub remove_td {		# remove $td but make sure $td isn't set to "."
	! $td || $td eq "."	and die "bad dirname \$td=$td";
	eval { rmtree($td); };
	$@			and die "$td: couldn't remove: $@";
}

#### end boilerplate

use File::ANVL;

{ 	# ANVL conversion, interleaving output formats for easy comparison

remake_td();	# xxx not using this (yet?)

my $x;
my $recstream = "a: b
c: d
";

$x = `echo "$recstream" | $cmd --format xml`;
like $x, qr{
<recs>\n\s*
 <rec>\n\s*
  <a>b</a>\n\s*
  <c>d</c>\n\s*
 </rec>\n\s*
</recs>\s*
}xs, 'basic single record anvl2xml conversion';

$x = `echo "$recstream" | $cmd --format turtle`;
is $x, '@prefix erc: <http://purl.org/kernel/elements/1.1/> .
<b>
    erc:a """b""" ;
    erc:c """d""" .

', 'basic single record anvl2turtle conversion';

$recstream .= "#note to self
";

$x = `echo "$recstream" | $cmd --comment --format xml`;
like $x, qr{
<rec>\n\s*
 <a>b</a>\n\s*
 <c>d</c>\n\s*
 <!--\s*note.*\s-->\n\s*
</rec>\n\s*
}xs, 'anvl2xml conversion with comment';

$x = `echo "$recstream" | $cmd --comment -m turtle --subjelpat '^c\$'`;
is $x, '@prefix erc: <http://purl.org/kernel/elements/1.1/> .
<d>
    erc:a """b""" ;
    erc:c """d"""
#note to self
 .

', 'anvl2turtle conversion with comment and --subjelpat';

$recstream .= "e: f
	g
    h
";

$x = `echo "$recstream" | $cmd -m XML`;
like $x, qr{
<rec>\n\s*
<a>b</a>\n\s*
<c>d</c>\n\s*
<e>f\ g\ h</e>\n\s*
</rec>\n\s*
}xs, 'anvl2xml with multi-line element, uppercase XML, stripped comment';

$x = `echo "$recstream" | $cmd --format tURtlE --comments`;
is $x, '@prefix erc: <http://purl.org/kernel/elements/1.1/> .
<b>
    erc:a """b""" ;
    erc:c """d"""
#note to self
 ;
    erc:e """f g h""" .

', 'anvl2turtle with multi-line element, crazy case tURtlE, "--comments"';

$recstream .= "i: j k";

$x = `echo "$recstream" | $cmd --form xml`;
like $x, qr{
<a>b</a>\n\s*
<c>d</c>\n\s*
<e>f\ g\ h</e>\n\s*
<i>j\ k</i>\n\s*
</rec>\n\s*
</recs>\n\s*
}xs, 'anvl2xml with non-newline-terminated record';

$x = `echo "$recstream" | $cmd -m turtle --comm`;
is $x, '@prefix erc: <http://purl.org/kernel/elements/1.1/> .
<b>
    erc:a """b""" ;
    erc:c """d"""
#note to self
 ;
    erc:e """f g h""" ;
    erc:i """j k""" .

', 'anvl2turtle with non-newline-terminated record, "--com"';

$recstream .= "
identifier:
	sujet
";

$x = `echo "$recstream" | $cmd --format xml`;
like $x, qr{
<a>b</a>\n\s*
<c>d</c>\n\s*
<e>f\ g\ h</e>\n\s*
<i>j\ k</i>\n\s*
<identifier>sujet</identifier>\n\s*
</rec>\n\s*
</recs>\n\s*
}xs, 'anvl2xml with identifier element starting on continuation line';

$x = `echo "$recstream" | $cmd --format turtle --predns http://purl.org/k1.1/`;
is $x, '@prefix erc: <http://purl.org/k1.1/> .
<sujet>
    erc:a """b""" ;
    erc:c """d""" ;
    erc:e """f g h""" ;
    erc:i """j k""" ;
    erc:identifier """sujet""" .

', 'anvl2turtle with identifier element on continuation line, --predns';

$recstream = "
aa:b

cc: d
   e

ff: g
h: i
";					# 3 ANVL records

$x = `echo "$recstream" | $cmd --verbose --format anvl --comments`;
is $x, '# from record 1, line 2
aa: b

# from record 2, line 4
cc: d e

# from record 3, line 7
ff: g
h: i

', 'anvl2anvl with 3 input records and 3 verbose output records';

$x = `echo "$recstream" | $cmd --verbose --format json --comments`;
is $x, '[
  { "#": "from record 1, line 2",
    "aa": "b"
  },
  { "#": "from record 2, line 4",
    "cc": "d e"
  },
  { "#": "from record 3, line 7",
    "ff": "g",
    "h": "i"
  }
]
', 'anvl2json with 3 input records and 3 verbose output records';

$x = `echo "$recstream" | $cmd --verbose --format plain`;
is $x, '# from record 1, line 2
b

# from record 2, line 4
d e

# from record 3, line 7
g
i

', 'anvl2plain with 3 input records and 3 verbose output records';

$x = `echo "$recstream" | $cmd --verbose --format xml`;
like $x, qr{
<recs>\n\s*
<rec>\s*<!--\ from\ record\ 1,\ line\ 2.*
<rec>\s*<!--\ from\ record\ 2,\ line\ 4.*
<rec>\s*<!--\ from\ record\ 3,\ line\ 7.*
</recs>\n\s*
}xs, 'anvl2xml with 3 input records and 3 verbose output records';

$x = `echo "$recstream" | $cmd --verbose --format turtle`;
is $x, '@prefix erc: <http://purl.org/kernel/elements/1.1/> .
# from record 1, line 2
<b>
    erc:aa """b""" .

# from record 2, line 4
<d e>
    erc:cc """d e""" .

# from record 3, line 7
<g>
    erc:ff """g""" ;
    erc:h """i""" .

', 'anvl2turtle with 3 input records and 3 verbose output records';

$recstream = "
foo:
erc: ab | cd
   | ef
   | gh | ij | kl | mn |
   op | qr
bar:
erc: another | erc | how | can
  | that | be?
# hmm
zaf: not empty
";

$x = `echo "$recstream" | $cmd --format json`;
is $x, '[
  {
    "foo": "",
    "erc": "",
    "who": "ab",
    "what": "cd",
    "when": "ef",
    "where": "gh",
    "how": "ij",
    "why": "kl",
    "huh": "mn",
    "huh": "op",
    "huh": "qr",
    "bar": "",
    "erc": "",
    "who": "another",
    "what": "erc",
    "when": "how",
    "where": "can",
    "how": "that",
    "why": "be?",
    "zaf": "not empty"
  }
]
', 'anvl2json with 2 short form ERCs in one oddly formed ERC';

$x = `echo "$recstream" | $cmd --format plain`;
is $x, 'ab
cd
ef
gh
ij
kl
mn
op
qr
another
erc
how
can
that
be?
not empty

', 'anvl2plain with 2 short form ERCs in one oddly formed ERC';
# yyy dunno if that's actually the best plain text conversion??
#     it strips blank lines

$x = `echo "$recstream" | $cmd --co --format xml`;
like $x, qr{
<rec>\n\s*
<foo></foo>\n\s*
<erc></erc>\n\s*
<who>ab.*
<what>cd.*
<when>ef.*
<where>gh.*
<how>ij.*
<why>kl.*
<huh>mn.*
<huh>op.*
<huh>qr.*
<bar>.*
<erc>.*
<who>another.*
<where>can.*
<!--.*
<zaf>.*
}xs, 'anvl2xml with 2 short form ERCs in one oddly formed ERC';

$x = `echo "$recstream" | $cmd --co --format turtle`;
is $x, '@prefix erc: <http://purl.org/kernel/elements/1.1/> .
<gh>
    erc:foo """""" ;
    erc:erc """""" ;
    erc:who """ab""" ;
    erc:what """cd""" ;
    erc:when """ef""" ;
    erc:where """gh""" ;
    erc:how """ij""" ;
    erc:why """kl""" ;
    erc:huh """mn""" ;
    erc:huh """op""" ;
    erc:huh """qr""" ;
    erc:bar """""" ;
    erc:erc """""" ;
    erc:who """another""" ;
    erc:what """erc""" ;
    erc:when """how""" ;
    erc:where """can""" ;
    erc:how """that""" ;
    erc:why """be?"""
# hmm
 ;
    erc:zaf """not empty""" .

', 'anvl2turtle with 2 short form ERCs in one oddly formed ERC';

$recstream = 'erc:
  aa|bb|cc|
  dd';
$x = `echo "$recstream" | $cmd --comments -m turtle`;
is $x, '@prefix erc: <http://purl.org/kernel/elements/1.1/> .
<dd>
    erc:erc """""" ;
    erc:who """aa""" ;
    erc:what """bb""" ;
    erc:when """cc""" ;
    erc:where """dd""" .

', 'anvl2turtle with odd short form ERC';

$recstream = 'erc:
  
  
  dd|cc|b|
   
  a
  ';		# there are no empty lines (but lines with spaces)
$x = `echo "$recstream" | $cmd --comments -m turtle`;
is $x, '@prefix erc: <http://purl.org/kernel/elements/1.1/> .
<a>
    erc:erc """""" ;
    erc:who """dd""" ;
    erc:what """cc""" ;
    erc:when """b""" ;
    erc:where """a""" .

', 'anvl2turtle with strange short form ERC';

$recstream = '# A way to kernel knowledge.
erc: Kunze, John A. | A Metadata Kernel for Electronic Permanence
     | 20011106 | http://journals.tdl.org/jodi/article/view/43';

$x = `echo "$recstream" | $cmd --comments -m turtle`;
is $x, '@prefix erc: <http://purl.org/kernel/elements/1.1/> .
<http://journals.tdl.org/jodi/article/view/43>
# A way to kernel knowledge.

    erc:erc """""" ;
    erc:who """Kunze, John A.""" ;
    erc:what """A Metadata Kernel for Electronic Permanence""" ;
    erc:when """20011106""" ;
    erc:where """http://journals.tdl.org/jodi/article/view/43""" .

', 'anvl2turtle with true ERC and initial comment';

$x = `echo "$recstream" | $cmd --comments -m anvl`;
is $x, '# A way to kernel knowledge.
erc:
who: Kunze, John A.
what: A Metadata Kernel for Electronic Permanence
when: 20011106
where: http://journals.tdl.org/jodi/article/view/43

', 'anvl2anvl with short true ERC and initial comment';

$x = `echo "$recstream" | $cmd`;
is $x, 'erc:
who: Kunze, John A.
what: A Metadata Kernel for Electronic Permanence
when: 20011106
where: http://journals.tdl.org/jodi/article/view/43

', 'anvl2anvl as default with short ERC (pod example)';

$recstream = 'erc: a | b | c | d';
$x = `echo "$recstream" | $cmd --format json`;
is $x, '[
  {
    "erc": "",
    "who": "a",
    "what": "b",
    "when": "c",
    "where": "d"
  }
]
', 'anvl2json with pod example';

$recstream = 'a: b
#note to self
c: d';
$x = `echo "$recstream" | $cmd --verbose --comments -m xml`;
is $x, '<recs>
  <rec>   <!-- from record 1, line 1 -->
    <a>b</a>
    <!-- note to self -->
    <c>d</c>
  </rec>
</recs>
', 'anvl2xml with pod example';

$x = `$cmd --listformats`;
is $x, 'ANVL
JSON
Plain
Turtle
XML
', 'anvl --listformats';

remove_td();

}

