#!/usr/bin/perl

use XML::LibXML;

my $XMLDIR = "xml/";
my $PODIR = "po/";
my $LANG = "ja";
my $TARGETOS = "osuse";
my $MAIN = "MAIN.opensuse.xml";

my $parser = XML::LibXML->new({
  line_numbers => 1,
  expand_entities => 0,
  no_network => 1,
  load_ext_dtd => 0,
  expand_xinclude => 0,
});

my %XmlFileList = ();

&ProcessXML($MAIN);

for my $XmlFile (sort(keys(%XmlFileList))) {
  print $XmlFile . ": ";
  system("LANG=C /usr/bin/msgfmt -c -v -o /dev/null " . $PODIR . $XmlFile . "."  . $LANG . ".po 2>&1");
}

sub ProcessXML {
  my ($XmlFile) = @_;

  $XmlFileList{$XmlFile} = 1;

  # tweak; in order to avoid parsing of entity ref
  open(my $src, "cat " . $XMLDIR . $XmlFile . " | sed \"s/&/__XML_PO__&amp;/g\" |");
  my $d = $parser->load_xml(IO => $src);
  close($src);

  &ProcessNode($d);
};

sub ProcessNode {
  my ($node) = @_;

  if ($node->nodeType == 1) {
    if ($node->hasAttributes) {
      foreach my $attr ($node->attributes) {
        if (lc($attr->nodeName) eq "os") {
          my @oslist = split(/;/, $attr->value);
          my $hasTargetOs = 0;

          foreach my $os (@oslist) {
            $os =~ s/^ *(.*?) *$/$1/;

            if (lc($os) eq lc($TARGETOS)) {
              $hasTargetOs = 1;
            }
          }

          if (!$hasTargetOs) {
            return;
          }
        }
      }
    }
  }

  my @children = $node->childNodes;
  foreach my $child (@children) {
    &ProcessNode($child);
  }

  if (lc($node->nodeName) eq "xi:include") {
    if ($node->hasAttributes) {
      foreach my $attr ($node->attributes) {
        if (lc($attr->nodeName) eq "href") {
          &ProcessXML($attr->value);
        }
      }
    }
  }
};
