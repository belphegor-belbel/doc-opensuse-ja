#!/bin/sh

# This script requires:
# * "msgmerge", "msginit" from gettext-tools package

LANGCODE=ja

DIR=`dirname $0`

for i in `dirname $0`/srcxml/*.xml;
do
  POT=$DIR/pot/`basename $i`.pot
  PO=$DIR/po/`basename $i`.$LANGCODE.po
  XML=$DIR/xml/`basename $i`

  if [ "`basename $i`" != "common_legal.xml" ]; then
    echo -n Updating POT: `basename $i`..
    $DIR/xml_po.pl --xml2pot $i > $POT
    echo done.

    echo -n Updating PO: `basename $i`..
    if [ -f $PO ]; then
      msgmerge -U $PO $POT
    else
      msginit -i $POT --no-translator -o $PO
    fi
    echo done.

    echo -n Updating XML: `basename $i`..
    $DIR/xml_po.pl --po2xml $i $PO > $XML
    echo done.
  else
    echo Skipping common_legal.
  fi
done

