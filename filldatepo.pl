#!/usr/bin/perl

use Locale::PO;

my $aref = Locale::PO->load_file_asarray("/dev/stdin");

foreach my $poitem (@{$aref}) {
  if ($poitem->{"automatic"} =~ /Tag: date/) {
    if ($poitem->{"msgid"} =~ /^\"[0-9]{4}-[0-9]{2}-[0-9]{2}\"$/) {
      $poitem->{"msgstr"} = $poitem->{"msgid"};
    }
  }
}

Locale::PO->save_file_fromarray("/dev/stdout", $aref);
