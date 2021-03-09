cross_references_directory="$cache_directory/further_cross_references"

ensembl_file="$cross_references_directory/gene2ensembl"
refseq_file="$cross_references_directory/gene2refseq"
uniprot_and_refseq_file="$cross_references_directory/gene_refseq_uniprotkb_collab"

uniprot_file="$cross_references_directory/HUMAN_9606_idmapping.dat"
uniprot_prefixes_translated="../files/uniprot_prefixes_translated.csv"

human_tax_id="9606"

for x in "ena" "uniprot" "entrez" "refseq" ;
do eval "ensembl_to_$x=$cross_references_directory/Homo_sapiens.GRCh38.103.$x.tsv";
done ;

kegg_cross_references_dir="$cross_references_directory_new"




use_all_translations () {
  unset number_of_cross_references_before number_of_cross_references_after ;
  hsa_file_name="$1"
  hsa_file_path="$kegg_cross_references_dir/$hsa_file_name"

  number_of_cross_references_before="$(wc -l "$kegg_cross_references_dir"/"$hsa_file_name" | cut -d ' ' -f 1 )"

  while  true ;
  do
refseq_to_hsa_file_append ;
ensembl_to_hsa_file_append ;

#    ensembl_to_all ; #we don't do it because it's redundant, other databases already cover ensembl
   refseq_and_uniprot  ;
   uniprot_to_hsa_file_append  ;

    number_of_cross_references_after="$(wc -l "$kegg_cross_references_dir"/"$hsa_file_name" | cut -d ' ' -f 1 )"
    if test "$number_of_cross_references_before" -eq "$number_of_cross_references_after" ;
    then break ;
    else number_of_cross_references_before="$number_of_cross_references_after" ;
    fi ;
  done ;
}


ensembl_to_hsa_file_append () {
  hsa_gene_id="$(echo "$hsa_file_name" | cut -d : -f 2 )" ;
  cat "$hsa_file_path" | grep '	ncbi' | while IFS='	' read hsa ncbi link_type ;
  do
#echo 111111 hsa:$hsa , ncbi:$ncbi , link_type=$link_type
    ncbi_identifier="$(echo  $ncbi | cut -d ':' -f '2' )";
    ncbi_prefix="$(echo  $ncbi | cut -d ':' -f '1' )";
#echo ncbi_prefix ncbi_identifier $ncbi_prefix $ncbi_identifier
    case $ncbi_prefix in
    'ncbi-geneid') offset=3
    ;;
    'ncbi-proteinid') offset=7
    ;;
    esac ;
#echo oooooooooffset $offset
    cat "$ensembl_file" | tail -n +2 | grep "^$human_tax_id	$hsa_gene_id	" | grep  "$ncbi_identifier"  | cut -f "$offset" | grep -v -x '-' | while read ensembl_identifier ;
    do
      x="ensembl:$ensembl_identifier"
#echo $x
      if ! grep  -q "	$x	" "$hsa_file_path" ;
      then echo "$hsa	$x	$link_type[NCBI to Ensembl]$x";
#      else echo $ensembl_identifier already in
      fi ;
    done >>"$hsa_file_path" ;
  done ;
}



refseq_to_hsa_file_append () {
    hsa_gene_id="$(echo "$hsa_file_name" | cut -d : -f 2 )" ;
    cat "$refseq_file" | tail -n +2 | grep "^$human_tax_id	$hsa_file_name" | while IFS='	' read _ _  _  _1 _2 _3 _4 _5 _6   _ _  _  _   _7 _8  _ ;
    do
     for translation in "$_1" "$_2" "$_3" "$_4" "$_5" "$_6" "$_7" "$_8" ;
     do
       if test "$translation" = '-' ; then continue ; fi ;
       if grep -q "	rs:$translation	" "$hsa_file_path" ; then continue ; fi ;
       echo "hsa:$hsa_gene_id	rs:$translation	[NCBI to RefSeq]rs:$translation" ;
     done >>"$hsa_file_path"  ;
   done ;
}

refseq_and_uniprot () {
  cat "$hsa_file_path" | egrep  "	rs:|	up:" | while IFS='	' read hsa other link_type ;
  do
    other_without_prefix="$(echo "$other" | cut -d : -f 2 )" ;
    grep "$other_without_prefix" "$uniprot_and_refseq_file" | while IFS='	' read refseq uniprot ;
    do

      has_refseq="$(grep "	rs:$refseq	" "$hsa_file_path" | cut -f 2 )"
      has_uniprot="$(grep "	up:$uniprot	" "$hsa_file_path" | cut -f 2 )"

      if test "$has_refseq" && ! test "$has_uniprot" ;
      then  echo "$hsa	up:$uniprot	${link_type}[NCBI RefSeq UniProt collab]up:$uniprot"
      fi ;
      if ! test "$has_refseq" && test "$has_uniprot" ; #and not refseq, due to the else statement
      then  echo "$hsa	rs:$refseq	${link_type}[NCBI RefSeq UniProt collab]rs:$refseq" ;
      fi ;
    done >>"$hsa_file_path" ;
  done ;

}

uniprot_to_hsa_file_append () {
  cat "$hsa_file_path" | grep "	up:" |while IFS='	' read hsa_field uniprot_field link_type_field ;
  do
    uniprot_field_postfix="$(echo $uniprot_field | cut -d : -f 2)"
    cat "$uniprot_file" | grep "^$uniprot_field_postfix" | while IFS='	' read _ via_db  identifier
    do
      if test "$identifier" = '-' ; then continue ; fi ;
      has_column="$(echo "$identifier" | grep ":")"
      post_column="$(echo "$identifier" | cut -d : -f 2 )"
      if test "$has_column" ;
      then identifier="$post_column"
      fi ;

      via_db_translated="$(cat "$uniprot_prefixes_translated" | grep "$via_db"',' | cut -d ',' -f 2 | head -n 1)"
      if ! test "$via_db_translated" || test "$via_db_translated" = 'null' ; then continue ; fi ;
      uniprot_field_translated="$via_db_translated":"$identifier"

      if ! grep -q "^$hsa_field	$uniprot_field_translated	" "$hsa_file_path" ;
      then
        echo "$hsa_field	$uniprot_field_translated	${link_type_field}[UniProt to all]$uniprot_field_translated"  >>"$hsa_file_path"
      fi ;
    done ;
  done;
}

ensembl_to_all () {
cat "$hsa_file_path" | grep 'ensembl:'  | while IFS='	' read hsa_field ensembl_field link_type_field ;
do
  ensembl_field_identifier="$(echo "$ensembl_field" | cut -d : -f 2)"
#actually the following grep checks if the ensembl link is present, not if it is in the right column
    for db in "ENA" "entrez" "UniProt" "RefSeq" ;
      do
        unset _ ensg enst ensp _1 _2
        if test "$db" = 'ena' ;
        then header='_ _ ensg enst ensp _1 _2 _ ' ;
        else header='ensg enst ensp _1 _' ;
        fi ;
#echo HEREEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEE identifier===$ensembl_field_identifier
        eval 'cat $'"ensembl_to_$db"  | tail -n +2 | sed 's/		/	-	/g' | sed 's/	$/	-/g'  | grep "	$ensembl_field_identifier"  |  while read $header ;
      do
#echo ensg $ensg enst $enst ensp $ensp _1 $_1 _1 $_2
        for x in "$ensg" "$enst" "$ensp" ;
        do
          if test "$x" != '-' && test "$x" != "$ensembl_field_identifier" && ! grep -q "	ensembl:$x" "$hsa_file_path" ;
          then echo "$hsa_field	ensembl:$x	$link_type_field[Ensembl to $db]ensembl:$x" ;
          fi ;
        done ;


        db_prefix_translated="$(cat ../files/ensembl_prefixes_translated.csv | grep "^$db," | cut -d , -f 2 )" ; #assumes there is only one line
        vars='_1 '"$(if test "$db" = 'ena' && test $_2 ; then echo _2 ; fi ;)" ;

        for x in $vars ; #_2 may be empty
        do
          x="$(eval 'echo $'"$x")";

          addendum="${db_prefix_translated}:$x"

           if test "$x" != '-' && ! grep -q "	$addendum" "$hsa_file_path" ;
           then echo "$hsa_field	$addendum	$link_type_field[Ensembl to $db]$addendum" ;
           fi ;

        done ;
      done ;
  done >>"$hsa_file_path";
done ;
}

if_one_then_the_other () {
#   echo HHHHHHH $1 $2 $3 $4 $5 $6
#   $prefix1 $postfix1 $prefix2 $postfix2 $link_type $hsa_file_path
    if test "$2" = '-' || test "$4" = '-' ; then return ; fi ;
    x="$3:$4"
    if grep -q "	$x	" "$6" ; then return ; fi ;
    grep "	$1:$2	" "$6" | while IFS='	' read hsa other link_type ;
   do echo "$hsa	$x	$link_type[$5]$x";
   done ;
}


use_all_translations "$@"


