#!/usr/bin/perl

use POSIX qw(strftime);
use File::Basename;
use XML::LibXML;
use utf8;

## constants
my @SkipNodes =
  ( "option", "replaceable", "command", "emphasis", "package",
  "literal", "quote", "filename", "link", "systemitem", "xref",
  "menuchoice", "guimenu", "guilabel", "phrase", "remark", "envar", "keycombo",
  "keycap", "co", "prompt", "varname", "citetitle", "tag", "superscript",
  "constant", "email", "trademark", "productname", "productnumber", "uri",
  "parameter", "indexterm", "primary", "secondary", "tertiary", "screen", "function",
  "inlinemediaobject", "orgname", "code" );
my @literalNodes =
  ( "screen" );
my @ignoreNodes =
  ( "#comment", "remark", "xml-stylesheet", "suse-quickstart", "dm:translation" );
my $dummyParaStart =
  "<para xmlns:xlink=\"http://www.w3.org/1999/xlink\" xmlns:xi=\"http://www.w3.org/2001/XInclude\">";
my $dummyParaEnd = "</para>";
my $lang = "ja";
## constants

if ($#ARGV < 1) {
  print "Usage: $0 --xml2pot [XML file (source)] > (generated POT)\n";
  print "   or: $0 --po2xml  [XML file (source)] [PO file (translation)] > (translated XML file)\n";
  exit;
}

my $mode = 0;
if (lc($ARGV[0]) eq "--xml2pot") {
  $mode = 1;
} elsif (lc($ARGV[0]) eq "--po2xml") {
  $mode = 2;

  if ($#ARGV < 2) {
    print "Error: insufficient parameter.\n";
    exit;
  }
} else {
  die("Error: illegal mode \"" . $ARGV[0] . "\".");
}

my ($FileLastUpdated) = (stat($ARGV[1]))[9];
my $FileLastUpdatedStr = strftime("%Y-%m-%d %H:%M+0000", gmtime($FileLastUpdated));

my $parser = XML::LibXML->new({
  line_numbers => 1,
  expand_entities => 0,
  no_network => 1,
  load_ext_dtd => 0,
  expand_xinclude => 0,
});

# tweak; in order to avoid parsing of entity ref
open(my $src, "cat " . $ARGV[1] . " | sed \"s/&/__XML_PO__&amp;/g\" |");
my $d = $parser->load_xml(IO => $src);
close($src);

my %result;
&ProcessNode($d);

sub ProcessNode {
  my ($node) = @_;

  # always skip DTD
  if (ref($node) eq "XML::LibXML::Dtd") {
    return;
  }
  # always skip PI
  if (ref($node) eq "XML::LibXML::PI") {
    return;
  }

  # always skip ignored nodes
  my $isIgnoreNode = 0;
  foreach my $ignoreNodeItem (@ignoreNodes) {
    if (lc($ignoreNodeItem) eq $node->nodeName) {
      $isIgnoreNode = 1;
      last;
    }
  }
  if ($isIgnoreNode) {
    return;
  }

  # check if child nodes contain only skip nodes
  my @children = $node->childNodes;
  my $OnlySkipNodes = 1;
  foreach my $child (@children) {
    if (ref($child) eq "XML::LibXML::Element") {
      my $found = 0;
      foreach my $SkipNode (@SkipNodes) {
        if (lc($SkipNode) eq lc($child->nodeName)) {
          $found = 1;
          last;
        }
      }
      if ($found == 0) {
        $OnlySkipNodes = 0;
        last;
      }
    }
  }

  if ($OnlySkipNodes) {
    my $literal = 0;
    foreach my $literalNode (@literalNodes) {
      if (lc($literalNode) eq lc($node->nodeName)) {
        $literal = 1;
        last;
      }
    }

    my $srctext = "";
    if ($literal) {
      foreach my $child (@children) {
        my $item = $child->toString();
        $srctext .= $item;
      }
    } else {
      if (ref($node) eq "XML::LibXML::Element") {
        foreach my $child (@children) {
          my $item = $child->toString();

          my $literal = 0;
          foreach my $literalNode (@literalNodes) {
            if (lc($literalNode) eq lc($child->nodeName)) {
              $literal = 1;
              last;
            }
          }

          if ($literal < 1) {
            $item =~ s/\r//g;
            $item =~ s/\n//g;
            $item .= " ";
          }

          $srctext .= $item;
        }
      } else {
        $srctext = $node->toString();
      }

      $srctext =~ s/  +/ /g;
    }

   $srctext =~ s/__XML_PO__&amp;/&/g;
   $srctext =~ s/^ *(.*?) *$/$1/;

    if (length($srctext) > 0) {
      # because bare node (i.e. without having any enclosing node) cannot be replaced...
      if (substr($node->nodeName, 0, 1) ne "#") {
        $result{$srctext}{"nodeName"} = $node->nodeName;
        $result{$srctext}{"lineNumber"} = $node->line_number();
        push(@{$result{$srctext}{"ref"}}, \$node);
      }
    }
  } else {
    foreach my $child (@children) {
      &ProcessNode($child);
    }
  }
}

if ($mode == 1) {
  binmode(STDOUT, ":utf8");

  # POT out
  print << "__EOF__";
# SOME DESCRIPTIVE TITLE.
# FIRST AUTHOR <EMAIL\@ADDRESS>, YEAR.
#
#, fuzzy
msgid ""
msgstr ""
"Project-Id-Version: PACKAGE VERSION\\n"
"Report-Msgid-Bugs-To: https://github.com/belphegor-belbel/doc-opensuse-ja\\n"
"POT-Creation-Date: $FileLastUpdatedStr\\n"
"PO-Revision-Date: YEAR-MO-DA HO:MI+ZONE\\n"
"Last-Translator: FULL NAME <EMAIL\@ADDRESS>\\n"
"Language-Team: LANGUAGE <someuser\@example.org>\\n"
"MIME-Version: 1.0\\n"
"Content-Type: text/x-po; charset=UTF-8\\n"
"Content-Transfer-Encoding: 8bit\\n"

__EOF__

  foreach my $r (sort {$result{$a}{"lineNumber"} <=> $result{$b}{"lineNumber"}} keys %result) {
    my $msgid =$r;

    $msgid =~ s/\\/\\\\/g;
    $msgid =~ s/\"/\\\"/g;
    $msgid =~ s/\n/\\n\"\n      \"/g;
    $msgid =~ s/\t/\\t/g;

    print "#. Tag: " . $result{$r}{"nodeName"} . "\n";
    print "#: " . basename($ARGV[1]) . ":" . $result{$r}{"lineNumber"} . "\n";
    print "#, no-c-format\n";
    print "msgid \"" . $msgid . "\"\n";
    print "msgstr \"\"\n";
    print "\n";
  }
} elsif ($mode == 2) {
  # load PO file
  open(my $poFile, "<:utf8", $ARGV[2]) or die;

  my %po;
  my $msgmode = 0;
  my $quote = 0;
  my $msgid="";
  my $msgbuf="";
  while (my $lineData = <$poFile>) {
    if ($lineData !~ /^\s*#/) {
      # not comment
      my $j=0;
      for (my $i=0; $i<length($lineData); $i++) {
        my $ch = substr($lineData, $i, 1);

        if ($ch eq "\"") {
          $quote^=1;
        } elsif (($ch eq "\\") && ($quote)) {
          $msgbuf .= $ch;
          $msgbuf .= substr($lineData, $i+1, 1);

          $i++;
        } elsif (($ch =~ /^\s$/) && (!($quote))) {
          my $str = substr($lineData, $j, $i - $j);
          $j=$i;

          $str =~ s/^ *(.*?) *$/$1/;
          if (lc($str) eq "msgid") {
            if (($msgmode != 0) && ($msgmode != 2)) {
              die "Illegal msgid sequence:" + $str;
            }

            if ($msgmode == 2) {
              $msgid =~ s/\\\\/\\/g;
              $msgid =~ s/\\"/"/g;
              $msgbuf =~ s/\\\\/\\/g;
              $msgbuf =~ s/\\"/"/g;

              $po{$msgid} = $msgbuf;

              $msgid="";
              $msgbuf="";
            }

            $msgmode=1;
          } elsif (lc($str) eq "msgstr") {
            if ($msgmode != 1) {
              die "Illegal msgstr sequence:" + $str;
            }

            $msgid = $msgbuf;
            $msgbuf = "";

            $msgmode=2;
          } else {
            if (($msgmode != 1) && ($msgmode != 2)) {
              die "Illegal string sequence:" + $str;
            }
          }
        } else {
          if ($quote) {
            $msgbuf .= $ch;
          }
        }
      }
    }
  }

  $msgid =~ s/\\\\/\\/g;
  $msgid =~ s/\\"/"/g;
  $msgbuf =~ s/\\\\/\\/g;
  $msgbuf =~ s/\\"/"/g;

  $po{$msgid} = $msgbuf;

  close($poFile);

  # translate
  my @resultkeys = keys(%result);
  foreach my $r (@resultkeys) {
    # if literal node, "\n" must be replaced with "\\n"
    my $literal = 0;
    my $msgid = $r;
    foreach my $literalNode (@literalNodes) {
      if (lc($literalNode) eq lc($result{$r}{"nodeName"})) {
        $literal = 1;
        last;
      }
    }
    if ($literal) {
      $msgid =~ s/\n/\\n/g;
    }

    # replace TABs with \\t
    $msgid =~ s/\t/\\t/g;

    if (exists($po{$msgid})) {
      if (length($po{$msgid}) > 0) {
        my $msgstr = $po{$msgid};
        $msgstr =~ s/&/__XML_PO__&amp;/g; # tweak; in order to avoid entity ref error.

        # if literal node, "\\n" must be replaced back with "\n"
        if ($literal) {
          $msgstr =~ s/\\n/\n/g;
        }

        for my $oldNode (@{$result{$r}{"ref"}}) {
          my $newNode = $$oldNode->getOwner->createElement($$oldNode->nodeName);

          # copy attributes
          if ($$oldNode->hasAttributes) {
            for my $oldAttribute ($$oldNode->attributes) {
              $newNode->setAttribute($oldAttribute->nodeName, $oldAttribute->value);
            }
          }

          my $chunk = $parser->parse_balanced_chunk(
            #dummy <para> in order to resolve XML namespace
            $dummyParaStart . $msgstr . $dummyParaEnd);
          for my $c (($chunk->childNodes)[0]->childNodes) {
            $newNode->addChild($c);
          }

          my $parentNode = $$oldNode->parentNode;
          $parentNode->replaceChild($newNode, $$oldNode);
        }
      }
    }
  }

  # replace values of "xml:lang" attributes with "ja"
  my @attrs = $d->findnodes("//*[\@xml:lang]");
  foreach my $attr (@attrs) {
    $attr->setAttribute("xml:lang", $lang);
  }

  # force encoding="UTF-8" in order to avoid unnecessary escaping @ 2025/08/05
  $d->setEncoding("UTF-8");

  # XML out
  my $dest = $d->toString(2);
  $dest =~ s/__XML_PO__&amp;/&/g;
  # tweak; XML::LibXML removes entity reference??
  $dest =~ s/<!ENTITY % (.*) SYSTEM (.*)>/<!ENTITY % $1 SYSTEM $2>\n%$1;/;
  print $dest;
}

