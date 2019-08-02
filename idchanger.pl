#!/usr/bin/perl

# change ids in these tags:
#   <xref linkend='XXX'>
#   xml:id='XXX'
use Locale::PO;
use XML::LibXML;
use Data::Dumper;

my $dummyParaStart =
  "<para xmlns:xlink=\"http://www.w3.org/1999/xlink\" xmlns:xi=\"http://www.w3.org/2001/XInclude\">";

my $aref = Locale::PO->load_file_asarray("/dev/stdin");

sub ParseXmlAndReplace {
  my ( $srcString ) = @_;
  $srcString = substr($srcString, 1, length($srcString) - 2);
  $srcString =~ s/\\"/"/g;
  $srcString =~ s/&/__XML_PO__&amp;/g;

  my $xml = XML::LibXML->new({
    line_numbers => 1,
    expand_entities => 0,
    no_network => 1,
    load_ext_dtd => 0,
    expand_xinclude => 0,
  });
  my $d = $xml->load_xml(string => "<xml>" . $dummyParaStart . $srcString . "</para></xml>");

  # replace values of "xml:id"
  my @attrs = $d->findnodes("//*[\@xml:id]");
  foreach my $attr (@attrs) {
    my $val = $attr->getAttribute("xml:id");
    $val =~ s/\./-/g;
    $attr->setAttribute("xml:id", $val);
  }

  # replace values of "linkend" in "xref"
  my @attrs = $d->findnodes("//*[\@linkend]");
  foreach my $attr (@attrs) {
    if (lc($attr->nodeName) eq "xref") {
      my $val = $attr->getAttribute("linkend");
      $val =~ s/\./-/g;
      $attr->setAttribute("linkend", $val);
    }
  }

  # "(root)", "<xml>", "<para>"
  my $dest = $d->childNodes->[0]->childNodes->[0]->toString(2, "UTF-8");
  $dest =~ s/__XML_PO__&amp;/&/g;
  $dest =~ s/"/\\"/g;
  $dest =~ s/^<para.*?>//g;
  $dest =~ s/<\/para>$//g;
  "\"" . $dest . "\"";
};

foreach my $poitem (@{$aref}) {
  if (length($poitem->{"msgid"}) > 2) { # includes quotation char
    my $msgid = &ParseXmlAndReplace($poitem->{"msgid"});
    my $msgstr = &ParseXmlAndReplace($poitem->{"msgstr"});

    $poitem->{"msgid"} = $msgid;
    $poitem->{"msgstr"} = $msgstr;
  }
}

Locale::PO->save_file_fromarray("/dev/stdout", $aref);
